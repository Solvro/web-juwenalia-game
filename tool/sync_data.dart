// Build-time helper: pulls the current CMS payload from Directus and
// snapshots it into assets/data/data.json. The bundled snapshot is only
// used as the offline-first fallback before the app has ever reached
// the network — on every release build, regenerate it so the shipped
// binary starts with something fresh.
//
// Run before any release build:
//
//     dart run tool/sync_data.dart
//
// No pub deps: HttpClient + dart:convert only.

import 'dart:convert';
import 'dart:io';
import 'dart:typed_data' show BytesBuilder;

const _directusBase = 'https://cms.juwenalia.solvro.pl';
const _outputPath = 'assets/data/data.json';
const _photosDir = 'assets/data/photos';
const _manifestPath = 'assets/data/photos_manifest.json';

Future<void> main(List<String> args) async {
  final base = args.isNotEmpty ? args.first : _directusBase;
  stdout.writeln('▸ Snapshotting Directus at $base');

  final client = HttpClient();
  client.connectionTimeout = const Duration(seconds: 15);

  try {
    final config = await _getOne(client, base, 'app_config');
    final checkpoints = await _getList(
      client,
      base,
      'checkpoints',
      fields: 'id,qr_code,title,description,image,sort,location.name',
      sort: 'sort',
    );
    final news = await _getList(
      client,
      base,
      'news',
      fields: 'id,title,content,date_created,image,edition',
      sort: '-date_created',
      limit: 100,
    );
    final events = await _getList(
      client,
      base,
      'events',
      fields: 'id,name,start_time,end_time,sort,edition,day.date,location.name',
      sort: 'start_time,sort',
      limit: 200,
    );
    final locations = await _getList(
      client,
      base,
      'locations',
      fields: 'id,name,point,polyline,isPolyline,description,color',
    );
    final partners = await _getList(
      client,
      base,
      'organisations',
      fields: 'id,name,url,logo,logoScale,role,sort',
    );
    final importantInfo = await _getList(
      client,
      base,
      'important_info',
      sort: 'sort',
    );
    final faqs = await _tryGetList(client, base, 'faqs', sort: 'sort');

    final snapshot = _shape(
      base: base,
      config: config,
      checkpoints: checkpoints,
      news: news,
      events: events,
      locations: locations,
      partners: partners,
      importantInfo: importantInfo,
      faqs: faqs,
    );

    final outFile = File(_outputPath);
    await outFile.parent.create(recursive: true);
    final encoder = const JsonEncoder.withIndent('  ');
    await outFile.writeAsString('${encoder.convert(snapshot)}\n');

    stdout.writeln(
      '✓ Wrote $_outputPath — edition ${config['edition']}, '
      '${checkpoints.length} checkpoints, ${news.length} news, '
      '${events.length} events.',
    );

    // Download every referenced Directus asset into the bundle so the
    // first-launch / offline experience has pictures instead of skeletons.
    await _syncPhotos(client, base, snapshot);
  } on SocketException catch (e) {
    stderr.writeln(
      '✖ Network error: ${e.message}. Keeping existing $_outputPath.',
    );
    exit(4);
  } catch (e) {
    stderr.writeln('✖ Sync failed: $e');
    exit(1);
  } finally {
    client.close(force: true);
  }
}

// ── HTTP helpers ─────────────────────────────────────────────────────────────

Future<Map<String, dynamic>> _getOne(
  HttpClient client,
  String base,
  String collection,
) async {
  final body = await _get(client, '$base/items/$collection');
  final decoded = jsonDecode(body) as Map<String, dynamic>;
  return (decoded['data'] as Map).cast<String, dynamic>();
}

Future<List<Map<String, dynamic>>> _getList(
  HttpClient client,
  String base,
  String collection, {
  String? fields,
  String? sort,
  int? limit,
}) async {
  final params = <String, String>{};
  if (fields != null) params['fields'] = fields;
  if (sort != null) params['sort'] = sort;
  if (limit != null) params['limit'] = limit.toString();
  final qs = params.isEmpty
      ? ''
      : '?${params.entries.map((e) => '${e.key}=${Uri.encodeQueryComponent(e.value)}').join('&')}';

  final body = await _get(client, '$base/items/$collection$qs');
  final decoded = jsonDecode(body) as Map<String, dynamic>;
  return (decoded['data'] as List).cast<Map<String, dynamic>>();
}

Future<List<Map<String, dynamic>>> _tryGetList(
  HttpClient client,
  String base,
  String collection, {
  String? fields,
  String? sort,
  int? limit,
}) async {
  try {
    return await _getList(
      client,
      base,
      collection,
      fields: fields,
      sort: sort,
      limit: limit,
    );
  } catch (_) {
    return const [];
  }
}

Future<String> _get(HttpClient client, String url) async {
  final req = await client.getUrl(Uri.parse(url));
  final res = await req.close();
  if (res.statusCode != 200) {
    throw 'GET $url → HTTP ${res.statusCode}';
  }
  return res.transform(utf8.decoder).join();
}

// ── Photo prefetch ───────────────────────────────────────────────────────────

/// Walks the shaped snapshot looking for `<base>/assets/<uuid>` URLs and
/// downloads each one into `assets/data/photos/<uuid>`. Writes a manifest
/// next to data.json listing the UUIDs that succeeded — the Flutter app
/// reads that manifest at startup to short-circuit image loads.
Future<void> _syncPhotos(
  HttpClient client,
  String base,
  Map<String, dynamic> snapshot,
) async {
  final prefix = '$base/assets/';
  final ids = <String>{};
  _collectAssetIds(snapshot, prefix, ids);

  if (ids.isEmpty) {
    stdout.writeln('▸ No photo URLs referenced — skipping prefetch.');
    // Still write an empty manifest so the asset load at runtime doesn't
    // throw a missing-asset error in dev builds.
    await _writeManifest(const []);
    return;
  }

  final dir = Directory(_photosDir);
  await dir.create(recursive: true);

  stdout.writeln('▸ Prefetching ${ids.length} photo(s) into $_photosDir …');
  final downloaded = <String>[];
  var failures = 0;
  for (final id in ids) {
    final ok = await _downloadAsset(client, prefix, id);
    if (ok) {
      downloaded.add(id);
    } else {
      failures += 1;
    }
  }

  // Prune stale files — anything on disk that isn't in the current set is
  // from a previous edition and just bloats the bundle.
  await for (final entry in dir.list(followLinks: false)) {
    if (entry is! File) continue;
    final name = entry.uri.pathSegments.last;
    if (name == '.gitkeep') continue;
    if (!ids.contains(name)) {
      try {
        await entry.delete();
      } catch (_) {}
    }
  }

  await _writeManifest(downloaded);
  stdout.writeln(
    '✓ Prefetched ${downloaded.length}/${ids.length} photo(s)'
    '${failures == 0 ? '' : ' ($failures failed)'}.',
  );
}

void _collectAssetIds(dynamic node, String prefix, Set<String> out) {
  if (node is String) {
    if (node.startsWith(prefix)) {
      // Trim query/fragment and pull the first path segment after /assets/.
      final rest = node.substring(prefix.length);
      final end = rest.indexOf(RegExp(r'[/?#]'));
      final id = (end == -1 ? rest : rest.substring(0, end)).trim();
      if (id.isNotEmpty) out.add(id);
    }
    return;
  }
  if (node is Map) {
    for (final v in node.values) {
      _collectAssetIds(v, prefix, out);
    }
    return;
  }
  if (node is List) {
    for (final v in node) {
      _collectAssetIds(v, prefix, out);
    }
  }
}

Future<bool> _downloadAsset(HttpClient client, String prefix, String id) async {
  final url = '$prefix$id';
  try {
    final req = await client.getUrl(Uri.parse(url));
    final res = await req.close();
    if (res.statusCode != 200) {
      stderr.writeln('  ✖ $id → HTTP ${res.statusCode}');
      return false;
    }
    final bytes = await _collectBytes(res);
    await File('$_photosDir/$id').writeAsBytes(bytes, flush: true);
    return true;
  } catch (e) {
    stderr.writeln('  ✖ $id → $e');
    return false;
  }
}

Future<List<int>> _collectBytes(HttpClientResponse res) async {
  final builder = BytesBuilder(copy: false);
  await for (final chunk in res) {
    builder.add(chunk);
  }
  return builder.takeBytes();
}

Future<void> _writeManifest(List<String> ids) async {
  final sorted = [...ids]..sort();
  final file = File(_manifestPath);
  await file.parent.create(recursive: true);
  const encoder = JsonEncoder.withIndent('  ');
  await file.writeAsString('${encoder.convert({'ids': sorted})}\n');
}

// ── Shape into the AppData.fromJson format ───────────────────────────────────

String _asset(String base, Object? uuid) {
  if (uuid == null) return '';
  final s = uuid.toString();
  if (s.isEmpty) return '';
  return '$base/assets/$s';
}

Map<String, dynamic> _shape({
  required String base,
  required Map<String, dynamic> config,
  required List<Map<String, dynamic>> checkpoints,
  required List<Map<String, dynamic>> news,
  required List<Map<String, dynamic>> events,
  required List<Map<String, dynamic>> locations,
  required List<Map<String, dynamic>> partners,
  required List<Map<String, dynamic>> importantInfo,
  required List<Map<String, dynamic>> faqs,
}) {
  final byDay = <String, List<Map<String, dynamic>>>{};
  final dayVenues = <String, String>{};

  for (final e in events) {
    final day = e['day'] as Map?;
    final loc = e['location'] as Map?;
    final start = e['start_time']?.toString();
    final dayKey =
        (day?['date'] as String?) ??
        (start != null && start.length >= 10
            ? start.substring(0, 10)
            : 'unknown');
    final venue = (loc?['name'] as String?) ?? '';
    dayVenues.putIfAbsent(dayKey, () => venue);
    final hhmm = start != null && start.length >= 16
        ? start.substring(11, 16)
        : '';

    byDay.putIfAbsent(dayKey, () => []).add({
      'id': e['id'].toString(),
      'artist': e['name'] ?? '',
      'genre': '',
      'stage': venue,
      'time': hhmm,
      'image_url': '',
      'start_time': start,
      'end_time': e['end_time']?.toString(),
    });
  }

  final schedule = (byDay.keys.toList()..sort())
      .map((k) => {'label': k, 'venue': dayVenues[k] ?? '', 'events': byDay[k]})
      .toList();

  return {
    'config': {
      'edition': config['edition'],
      'event_starts_at': config['event_starts_at'],
      'event_ends_at': config['event_ends_at'],
      'game_enabled_override': config['game_enabled_override'],
      'game_goal': config['game_goal'],
      'reward_description': config['reward_description'],
      'reward_pin': config['reward_pin'],
      'game_terms': config['game_terms'],
      'festival_plan_url': _asset(base, config['festival_plan']),
      'data_version': config['data_version']?.toString(),
    },
    'checkpoints': checkpoints.map((c) {
      final loc = c['location'] as Map?;
      return {
        'id': c['id'],
        'qr_code': c['qr_code'] ?? '',
        'title': c['title'] ?? '',
        'description': c['description'] ?? '',
        'category': 'other',
        'image': _asset(base, c['image']),
        'location': (loc?['name'] as String?) ?? '',
      };
    }).toList(),
    'news': news
        .map(
          (n) => {
            'id': n['id'].toString(),
            'title': n['title'] ?? '',
            'body': n['content'] ?? '',
            'category': 'general',
            'date': n['date_created'],
            'image_url': _asset(base, n['image']),
          },
        )
        .toList(),
    'schedule': schedule,
    'map_points': locations.map((j) {
      final point = j['point'];
      double? lat;
      double? lng;
      if (point is Map && point['coordinates'] is List) {
        final coords = (point['coordinates'] as List).cast<num>();
        if (coords.length >= 2) {
          lng = coords[0].toDouble();
          lat = coords[1].toDouble();
        }
      }
      return {
        'id': j['id'].toString(),
        'name': j['name'] ?? '',
        'type': 'info',
        'description': j['description'],
        'lat': lat,
        'lng': lng,
        'color': j['color'],
      };
    }).toList(),
    'partners': partners
        .map(
          (p) => {
            'id': p['id'].toString(),
            'name': p['name'] ?? '',
            'tier': p['role']?.toString() ?? '4',
            'logo_url': _asset(base, p['logo']),
            'url': p['url'],
            'logo_scale': p['logoScale'] == null
                ? null
                : double.tryParse(p['logoScale'].toString()),
          },
        )
        .toList(),
    'important_info': importantInfo
        .map(
          (i) => {
            'id': i['id'].toString(),
            'icon': i['icon'] ?? '',
            'title': i['title'] ?? '',
            'body': i['body'] ?? '',
            'color': i['color'] ?? '',
          },
        )
        .toList(),
    'faqs': faqs
        .map(
          (f) => {
            'id': f['id'].toString(),
            'question': f['question'] ?? '',
            'answer': f['answer'] ?? '',
          },
        )
        .toList(),
  };
}
