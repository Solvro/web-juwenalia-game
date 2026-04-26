// Snapshots the Directus CMS payload to assets/data/data.json for the
// offline fallback. Run before each release:
//
//     dart run tool/sync_data.dart
//
// Output keys = collection names, values = raw API `data` payloads —
// same shape data_service.dart consumes for fresh fetches, cache, and
// the bundled snapshot.

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
    final edition = (config['edition'] as String?)?.trim() ?? '';

    final results = await Future.wait([
      _getList(
        client,
        base,
        'checkpoints',
        fields:
            'id,qr_code,title,description,image,sort,'
            'location.id,location.name,'
            'category.id,category.display_name,category.color',
        sort: 'sort',
        filter: _jsonEditionFilter(edition),
      ),
      _getList(
        client,
        base,
        'news',
        fields: 'id,title,content,date_created,image,edition',
        sort: '-date_created',
        limit: 100,
        filter: _stringEditionFilter(edition),
      ),
      _getList(
        client,
        base,
        'events',
        fields:
            'id,name,start_time,end_time,sort,edition,day.date,location.name,'
            'artists.artists_id.name,artists.artists_id.image,'
            'artists.artists_id.description,artists.artists_id.instagramUrl,'
            'artists.artists_id.spotifyUrl,artists.artists_id.sort',
        sort: 'start_time,sort',
        limit: 200,
        filter: _stringEditionFilter(edition),
      ),
      _getList(
        client,
        base,
        'locations',
        fields:
            'id,name,point,polyline,isPolyline,description,color,hidden,'
            'icon,plan_point',
        filter: _jsonEditionFilter(edition),
      ),
      _getList(
        client,
        base,
        'organisations',
        fields: 'id,name,url,logo,logoScale,role,sort,edition',
        sort: 'sort',
        filter: _stringEditionFilter(edition),
      ),
      _getList(
        client,
        base,
        'important_info',
        fields: 'id,icon,title,body,color,url,expires_at,sort,edition',
        sort: 'sort',
        filter: _jsonEditionFilter(edition),
      ),
      _tryGetList(
        client,
        base,
        'faqs',
        sort: 'sort',
        filter: _jsonEditionFilter(edition),
      ),
      _tryGetList(
        client,
        base,
        'artists',
        fields:
            'id,name,description,image,instagramUrl,spotifyUrl,isPopular,'
            'sort,edition',
        sort: '-isPopular,sort',
        limit: 500,
        filter: _jsonEditionFilter(edition),
      ),
      _tryGetField(client, base, 'organisations', 'role'),
    ]);

    final checkpoints = results[0] as List<dynamic>;
    final news = results[1] as List<dynamic>;
    final events = results[2] as List<dynamic>;
    final locations = results[3] as List<dynamic>;
    final organisations = results[4] as List<dynamic>;
    final importantInfo = results[5] as List<dynamic>;
    final faqs = results[6] as List<dynamic>;
    final artists = results[7] as List<dynamic>;
    final roleFieldMeta = results[8] as Map<String, dynamic>?;

    final snapshot = <String, dynamic>{
      'app_config': config,
      'checkpoints': checkpoints,
      'news': news,
      'events': events,
      'locations': locations,
      'organisations': organisations,
      'important_info': importantInfo,
      'faqs': faqs,
      'artists': artists,
      'organisations_role_meta': ?roleFieldMeta,
    };

    final outFile = File(_outputPath);
    await outFile.parent.create(recursive: true);
    final encoder = const JsonEncoder.withIndent('  ');
    await outFile.writeAsString('${encoder.convert(snapshot)}\n');

    stdout.writeln(
      '✓ Wrote $_outputPath — edition $edition, '
      '${checkpoints.length} checkpoints, ${news.length} news, '
      '${events.length} events, ${artists.length} artists.',
    );

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

Future<Map<String, dynamic>> _getOne(
  HttpClient client,
  String base,
  String collection,
) async {
  final body = await _get(client, '$base/items/$collection');
  final decoded = jsonDecode(body) as Map<String, dynamic>;
  return (decoded['data'] as Map).cast<String, dynamic>();
}

Future<List<dynamic>> _getList(
  HttpClient client,
  String base,
  String collection, {
  String? fields,
  String? sort,
  int? limit,
  String? filter,
}) async {
  final params = <String, String>{};
  if (fields != null) params['fields'] = fields;
  if (sort != null) params['sort'] = sort;
  if (limit != null) params['limit'] = limit.toString();
  if (filter != null && filter.isNotEmpty) params['filter'] = filter;
  final qs = params.isEmpty
      ? ''
      : '?${params.entries.map((e) => '${e.key}=${Uri.encodeQueryComponent(e.value)}').join('&')}';

  final body = await _get(client, '$base/items/$collection$qs');
  final decoded = jsonDecode(body) as Map<String, dynamic>;
  return (decoded['data'] as List);
}

Future<List<dynamic>> _tryGetList(
  HttpClient client,
  String base,
  String collection, {
  String? fields,
  String? sort,
  int? limit,
  String? filter,
}) async {
  try {
    return await _getList(
      client,
      base,
      collection,
      fields: fields,
      sort: sort,
      limit: limit,
      filter: filter,
    );
  } catch (_) {
    return const <dynamic>[];
  }
}

Future<Map<String, dynamic>?> _tryGetField(
  HttpClient client,
  String base,
  String collection,
  String field,
) async {
  try {
    final body = await _get(client, '$base/fields/$collection/$field');
    final decoded = jsonDecode(body) as Map<String, dynamic>;
    final data = decoded['data'];
    if (data is Map) return data.cast<String, dynamic>();
    return null;
  } catch (_) {
    return null;
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

// Mirrors `_jsonEditionFilter` / `_stringEditionFilter` in
// data_service.dart so the snapshot scopes to the active edition.

String _jsonEditionFilter(String edition) {
  if (edition.isEmpty) return '';
  return jsonEncode({
    '_or': [
      {
        'edition': {'_contains': edition},
      },
      {
        'edition': {'_null': true},
      },
      {
        'edition': {'_empty': true},
      },
    ],
  });
}

String _stringEditionFilter(String edition) {
  if (edition.isEmpty) return '';
  return jsonEncode({
    '_or': [
      {
        'edition': {'_eq': edition},
      },
      {
        'edition': {'_null': true},
      },
      {
        'edition': {'_empty': true},
      },
    ],
  });
}

/// Walks the snapshot for image-field UUIDs and downloads each into
/// `assets/data/photos/<uuid>`. Writes a manifest of successful IDs
/// for [BundledPhotos] to consume.
Future<void> _syncPhotos(
  HttpClient client,
  String base,
  Map<String, dynamic> snapshot,
) async {
  final ids = <String>{};
  _collectAssetIds(snapshot, ids);

  if (ids.isEmpty) {
    stdout.writeln('▸ No photo UUIDs referenced — skipping prefetch.');
    await _writeManifest(const []);
    return;
  }

  final dir = Directory(_photosDir);
  await dir.create(recursive: true);

  stdout.writeln('▸ Prefetching ${ids.length} photo(s) into $_photosDir …');
  final downloaded = <String>[];
  var failures = 0;
  for (final id in ids) {
    final ok = await _downloadAsset(client, '$base/assets/', id);
    if (ok) {
      downloaded.add(id);
    } else {
      failures += 1;
    }
  }

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

/// JSON keys known to hold a `directus_files` UUID.
const _imageFieldKeys = {'image', 'logo', 'festival_plan'};

void _collectAssetIds(dynamic node, Set<String> out) {
  if (node is Map) {
    node.forEach((key, value) {
      if (_imageFieldKeys.contains(key) &&
          value is String &&
          value.isNotEmpty) {
        out.add(value);
      } else {
        _collectAssetIds(value, out);
      }
    });
    return;
  }
  if (node is List) {
    for (final v in node) {
      _collectAssetIds(v, out);
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
