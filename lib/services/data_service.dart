import 'dart:async';
import 'dart:convert';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../checkpoint.dart';
import '../models/models.dart';
import '../widgets/app_network_image.dart';
import 'connectivity_service.dart';
import 'directus.dart';
import 'image_loader.dart';

const _kCacheBody = 'cached_data_json';
const _kCacheTimestamp = 'cached_data_timestamp';
const _kCacheEdition = 'cached_data_edition';
const _kCompletedCheckpoints = 'completedCheckpoints';
const _kIsLocked = 'isLocked';
const _localAssetPath = 'assets/data/data.json';
const _kForceRefetchAfter = Duration(hours: 24);

class AppData {
  final AppConfig config;
  final List<Checkpoint> checkpoints;
  final List<NewsItem> news;
  final List<ScheduleDay> schedule;
  final List<MapPoint> mapPoints;
  final List<Partner> partners;
  final List<PartnerTier> partnerTiers;
  final List<ImportantInfo> importantInfo;
  final List<FaqItem> faqs;
  final List<Artist> artists;
  final bool isFromCache;

  const AppData({
    required this.config,
    this.checkpoints = const [],
    this.news = const [],
    this.schedule = const [],
    this.mapPoints = const [],
    this.partners = const [],
    this.partnerTiers = const [],
    this.importantInfo = const [],
    this.faqs = const [],
    this.artists = const [],
    this.isFromCache = false,
  });
}

class _Raw {
  static const config = 'app_config';
  static const checkpoints = 'checkpoints';
  static const news = 'news';
  static const events = 'events';
  static const locations = 'locations';
  static const organisations = 'organisations';
  static const importantInfo = 'important_info';
  static const faqs = 'faqs';
  static const artists = 'artists';
  static const roleFieldMeta = 'organisations_role_meta';
}

DateTime? _parseDate(dynamic raw) {
  if (raw == null) return null;
  final s = raw.toString();
  if (s.isEmpty) return null;
  return DateTime.tryParse(s);
}

/// Three-tier fallback: network → SharedPreferences cache → bundled
/// `assets/data/data.json`. Pass [forceNetwork] to skip the fallback
/// chain on pull-to-refresh.
Future<AppData> fetchData(
  http.Client client, {
  bool forceNetwork = false,
}) async {
  final prefs = await SharedPreferences.getInstance();

  Map<String, dynamic>? previousRaw;
  final cached = prefs.getString(_kCacheBody);
  if (cached != null) {
    try {
      previousRaw = (jsonDecode(cached) as Map).cast<String, dynamic>();
    } catch (_) {}
  }

  try {
    final raw = await _fetchRawFromDirectus(previousRaw: previousRaw);
    ConnectivityService.instance.reportFetchSuccess();

    final newEdition = _editionFromRaw(raw);
    final previousEdition = prefs.getString(_kCacheEdition);
    if (previousEdition != null &&
        previousEdition.isNotEmpty &&
        previousEdition != newEdition) {
      await _resetEditionState(prefs);
    }

    await prefs.setString(_kCacheBody, jsonEncode(raw));
    await prefs.setInt(_kCacheTimestamp, DateTime.now().millisecondsSinceEpoch);
    await prefs.setString(_kCacheEdition, newEdition);

    return _appDataFromRaw(raw);
  } catch (e) {
    await ConnectivityService.instance.reportFetchFailure();
    if (forceNetwork) rethrow;
  }

  if (previousRaw != null) {
    return _appDataFromRaw(previousRaw, isFromCache: true);
  }

  try {
    final assetBody = await rootBundle.loadString(_localAssetPath);
    final raw = (jsonDecode(assetBody) as Map).cast<String, dynamic>();
    return _appDataFromRaw(raw, isFromCache: true);
  } catch (_) {
    throw StateError(
      'No network, no cached data, no bundled snapshot — '
      'run `dart run tool/sync_data.dart` to ship a baseline.',
    );
  }
}

String _editionFromRaw(Map<String, dynamic> raw) {
  final cfg = (raw[_Raw.config] as Map?)?.cast<String, dynamic>();
  return (cfg?['edition'] as String?) ?? '';
}

Future<void> _resetEditionState(SharedPreferences prefs) async {
  await prefs.remove(_kCompletedCheckpoints);
  await prefs.remove(_kIsLocked);
  await prefs.remove(_kCacheBody);
  await prefs.remove(_kCacheTimestamp);
}

Future<Map<String, dynamic>> _fetchRawFromDirectus({
  Map<String, dynamic>? previousRaw,
}) async {
  final config = await _directusConfig();
  final edition = (config['edition'] as String?) ?? '';
  final previousEdition = previousRaw == null
      ? ''
      : ((previousRaw[_Raw.config] as Map?)?.cast<String, dynamic>()['edition']
                as String?) ??
            '';
  final sameEdition = previousRaw != null && previousEdition == edition;

  Future<T> withFallback<T>(Future<T> Function() fn, T fallback) async {
    try {
      return await fn();
    } catch (_) {
      return fallback;
    }
  }

  T prev<T>(String key, T empty) {
    if (!sameEdition) return empty;
    final v = previousRaw[key];
    return v is T ? v : empty;
  }

  final results = await Future.wait([
    withFallback<List<dynamic>>(
      () => _directusList('news', _newsQuery(edition)),
      prev<List<dynamic>>(_Raw.news, const <dynamic>[]),
    ),
    withFallback<List<dynamic>>(
      () => _directusList('important_info', _importantInfoQuery(edition)),
      prev<List<dynamic>>(_Raw.importantInfo, const <dynamic>[]),
    ),
    withFallback<List<dynamic>>(
      () => _directusList('events', _eventsQuery(edition)),
      prev<List<dynamic>>(_Raw.events, const <dynamic>[]),
    ),
    withFallback<List<dynamic>>(
      () => _directusList('checkpoints', _checkpointsQuery(edition)),
      prev<List<dynamic>>(_Raw.checkpoints, const <dynamic>[]),
    ),
    withFallback<List<dynamic>>(
      () => _directusList('locations', _locationsQuery(edition)),
      prev<List<dynamic>>(_Raw.locations, const <dynamic>[]),
    ),
    withFallback<List<dynamic>>(
      () => _directusList('organisations', _partnersQuery(edition)),
      prev<List<dynamic>>(_Raw.organisations, const <dynamic>[]),
    ),
    withFallback<List<dynamic>>(
      () => _directusList('faqs', _faqsQuery(edition)),
      prev<List<dynamic>>(_Raw.faqs, const <dynamic>[]),
    ),
    withFallback<Map<String, dynamic>?>(
      () => Directus.field('organisations', 'role'),
      prev<Map<String, dynamic>?>(_Raw.roleFieldMeta, null),
    ),
    withFallback<List<dynamic>>(
      () => _directusList('artists', _artistsQuery(edition)),
      prev<List<dynamic>>(_Raw.artists, const <dynamic>[]),
    ),
  ]);

  return <String, dynamic>{
    _Raw.config: config,
    _Raw.news: results[0],
    _Raw.importantInfo: results[1],
    _Raw.events: results[2],
    _Raw.checkpoints: results[3],
    _Raw.locations: results[4],
    _Raw.organisations: results[5],
    _Raw.faqs: results[6],
    if (results[7] != null) _Raw.roleFieldMeta: results[7],
    _Raw.artists: results[8],
  };
}

AppData _appDataFromRaw(Map<String, dynamic> raw, {bool isFromCache = false}) {
  final cfg = (raw[_Raw.config] as Map?)?.cast<String, dynamic>() ?? const {};
  return AppData(
    config: _parseConfig(cfg),
    news: _parseList(raw[_Raw.news], _parseNews),
    importantInfo: _parseList(raw[_Raw.importantInfo], _parseImportantInfo),
    schedule: _parseSchedule((raw[_Raw.events] as List?) ?? const []),
    checkpoints: _parseList(raw[_Raw.checkpoints], _parseCheckpoint),
    mapPoints: _parseList(raw[_Raw.locations], _parseLocation),
    partners: _parseList(raw[_Raw.organisations], _parsePartner),
    faqs: _parseList(raw[_Raw.faqs], _parseFaq),
    artists: _parseList(raw[_Raw.artists], _parseArtist),
    partnerTiers: _parsePartnerTiers(raw[_Raw.roleFieldMeta]),
    isFromCache: isFromCache,
  );
}

List<T> _parseList<T>(dynamic raw, T Function(Map<String, dynamic>) parse) {
  if (raw is! List) return const [];
  return raw
      .whereType<Map>()
      .map((m) => parse(m.cast<String, dynamic>()))
      .toList();
}

AppConfig _parseConfig(Map<String, dynamic> data) {
  return AppConfig(
    edition: (data['edition'] as String?) ?? '',
    eventStartsAt: _parseDate(data['event_starts_at']),
    gameEnabledOverride: data['game_enabled_override'] as bool?,
    gameGoal: (data['game_goal'] as num?)?.toInt() ?? 0,
    rewardDescription: (data['reward_description'] as String?) ?? '',
    rewardPin: (data['reward_pin'] as String?)?.trim(),
    gameTerms: (data['game_terms'] as String?) ?? '',
    festivalPlanUrl: Directus.assetUrl(data['festival_plan'] as String?),
    minAppVersionIos: (data['min_app_version_ios']?.toString()) ?? '',
    minAppVersionAndroid: (data['min_app_version_android']?.toString()) ?? '',
    minAppVersionWeb: (data['min_app_version_web']?.toString()) ?? '',
    appStoreUrlIos: (data['app_store_url_ios'] as String?)?.trim(),
    appStoreUrlAndroid: (data['app_store_url_android'] as String?)?.trim(),
    downloadQrUrl: (data['download_qr_url'] as String?)?.trim(),
    downloadPanelDescription: (data['download_panel_description'] as String?)
        ?.trim(),
  );
}

NewsItem _parseNews(Map<String, dynamic> j) {
  return NewsItem(
    id: j['id'].toString(),
    title: (j['title'] as String?) ?? '',
    body: (j['content'] as String?) ?? '',
    category: 'general',
    date: _parseDate(j['date_created']) ?? DateTime.now(),
    imageUrl: Directus.assetUrl(j['image'] as String?),
  );
}

ImportantInfo _parseImportantInfo(Map<String, dynamic> j) {
  final url = (j['url'] as String?)?.trim();
  return ImportantInfo(
    id: j['id'].toString(),
    icon: (j['icon'] as String?) ?? '',
    title: (j['title'] as String?) ?? '',
    body: (j['body'] as String?) ?? '',
    color: (j['color'] as String?) ?? '',
    url: (url == null || url.isEmpty) ? null : url,
    expiresAt: _parseDate(j['expires_at']),
  );
}

Checkpoint _parseCheckpoint(Map<String, dynamic> j) {
  final loc = (j['location'] as Map?)?.cast<String, dynamic>();
  final cat = (j['category'] as Map?)?.cast<String, dynamic>();
  return Checkpoint(
    id: (j['id'] as num).toInt(),
    qrCode: (j['qr_code'] as String?) ?? '',
    title: (j['title'] as String?) ?? '',
    description: (j['description'] as String?) ?? '',
    category: (cat?['id'] as String?) ?? '',
    categoryLabel: (cat?['display_name'] as String?) ?? 'Inne',
    categoryColor: (cat?['color'] as String?) ?? '',
    image: Directus.assetUrl(j['image'] as String?),
    location: (loc?['name'] as String?) ?? '',
    locationId: loc?['id']?.toString(),
  );
}

MapPoint _parseLocation(Map<String, dynamic> j) {
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
  final iconRaw = (j['icon'] as String?)?.trim();
  final (planX, planY) = _parsePlanPoint(j['plan_point']);
  return MapPoint(
    id: j['id'].toString(),
    name: (j['name'] as String?) ?? '',
    type: 'info',
    description: j['description'] as String?,
    lat: lat,
    lng: lng,
    color: j['color'] as String?,
    icon: (iconRaw == null || iconRaw.isEmpty) ? null : iconRaw,
    planX: planX,
    planY: planY,
    hidden: (j['hidden'] as bool?) ?? false,
  );
}

(int?, int?) _parsePlanPoint(dynamic raw) {
  Map? map;
  if (raw is Map) {
    map = raw;
  } else if (raw is String && raw.trim().isNotEmpty) {
    try {
      final decoded = jsonDecode(raw);
      if (decoded is Map) map = decoded;
    } catch (_) {}
  }
  if (map == null) return (null, null);
  final x = (map['x'] as num?)?.toInt();
  final y = (map['y'] as num?)?.toInt();
  return (x, y);
}

Partner _parsePartner(Map<String, dynamic> j) {
  return Partner(
    id: j['id'].toString(),
    name: (j['name'] as String?) ?? '',
    tier: (j['role']?.toString()) ?? '4',
    logoUrl: Directus.assetUrl(j['logo'] as String?),
    url: j['url'] as String?,
    logoScale: double.tryParse((j['logoScale']?.toString()) ?? ''),
  );
}

FaqItem _parseFaq(Map<String, dynamic> j) {
  return FaqItem(
    id: j['id'].toString(),
    question: (j['question'] as String?) ?? '',
    answer: (j['answer'] as String?) ?? '',
  );
}

Artist _parseArtist(Map<String, dynamic> j) {
  return Artist(
    id: j['id'].toString(),
    name: (j['name'] as String?) ?? '',
    description: (j['description'] as String?) ?? '',
    imageUrl: Directus.assetUrl(j['image'] as String?),
    instagramUrl: (j['instagramUrl'] as String?)?.trim(),
    spotifyUrl: (j['spotifyUrl'] as String?)?.trim(),
    isPopular: (j['isPopular'] as bool?) ?? false,
  );
}

List<PartnerTier> _parsePartnerTiers(dynamic raw) {
  if (raw is! Map) return const [];
  final meta = raw.cast<String, dynamic>();
  final options = (meta['meta'] as Map?)?.cast<String, dynamic>()['options'];
  final choices = (options is Map)
      ? (options['choices'] as List?) ?? const []
      : const [];
  return choices
      .whereType<Map>()
      .map((c) => c.cast<String, dynamic>())
      .map(
        (c) => PartnerTier(
          value: (c['value']?.toString()) ?? '',
          label: (c['text'] as String?) ?? (c['value']?.toString() ?? ''),
          icon: (c['icon'] as String?),
        ),
      )
      .where((t) => t.value.isNotEmpty)
      .toList();
}

List<ScheduleDay> _parseSchedule(List<dynamic> rawEvents) {
  final byDay = <String, List<ScheduleEvent>>{};

  for (final entry in rawEvents) {
    if (entry is! Map) continue;
    final e = entry.cast<String, dynamic>();
    final day = (e['day'] as Map?)?.cast<String, dynamic>();
    final loc = (e['location'] as Map?)?.cast<String, dynamic>();
    final start = _parseDate(e['start_time']);
    final end = _parseDate(e['end_time']);
    final artists = _extractArtists(e['artists']);
    final artistNames = artists.map((a) => a.name).toList();

    final dayKey =
        (day?['date'] as String?) ??
        (start != null ? DateFormat('yyyy-MM-dd').format(start) : 'unknown');

    final time = start != null ? DateFormat('HH:mm').format(start) : '';
    final fallbackName = (e['name'] as String?)?.trim() ?? '';
    final displayArtist = artistNames.isNotEmpty
        ? artistNames.join(' • ')
        : fallbackName;

    final venue = (loc?['name'] as String?) ?? '';

    final headlinerImage = artists.isNotEmpty ? artists.first.imageUrl : '';
    final headlinerDescription = artists.isNotEmpty
        ? artists.first.description
        : null;
    final headlinerInstagram = artists.isNotEmpty
        ? artists.first.instagramUrl
        : null;
    final headlinerSpotify = artists.isNotEmpty
        ? artists.first.spotifyUrl
        : null;

    byDay
        .putIfAbsent(dayKey, () => [])
        .add(
          ScheduleEvent(
            id: e['id'].toString(),
            artist: displayArtist,
            genre: '',
            stage: venue,
            time: time,
            imageUrl: headlinerImage,
            startTime: start,
            endTime: end,
            artistDescription: headlinerDescription,
            artistInstagramUrl: headlinerInstagram,
            artistSpotifyUrl: headlinerSpotify,
          ),
        );
  }

  final keys = byDay.keys.toList()..sort();
  return keys
      .map((k) => ScheduleDay(label: k, venue: '', events: byDay[k]!))
      .toList();
}

class _ArtistRef {
  final String name;
  final String imageUrl;
  final String? description;
  final String? instagramUrl;
  final String? spotifyUrl;
  const _ArtistRef({
    required this.name,
    required this.imageUrl,
    this.description,
    this.instagramUrl,
    this.spotifyUrl,
  });
}

List<_ArtistRef> _extractArtists(dynamic rawArtists) {
  if (rawArtists is! List) return const [];

  final result = <_ArtistRef>[];
  final seen = <String>{};

  for (final item in rawArtists) {
    if (item is! Map) continue;
    final row = item.cast<String, dynamic>();
    final artistRef = row['artists_id'];
    if (artistRef is! Map) continue;
    final artist = artistRef.cast<String, dynamic>();
    final name = (artist['name'] as String?)?.trim();
    if (name == null || name.isEmpty) continue;
    final key = name.toLowerCase();
    if (!seen.add(key)) continue;
    result.add(
      _ArtistRef(
        name: name,
        imageUrl: Directus.assetUrl(artist['image'] as String?),
        description: (artist['description'] as String?)?.trim(),
        instagramUrl: (artist['instagramUrl'] as String?)?.trim(),
        spotifyUrl: (artist['spotifyUrl'] as String?)?.trim(),
      ),
    );
  }

  return result;
}

Future<Map<String, dynamic>> _directusConfig() async {
  final raw = await Directus.items('app_config');
  return (raw as Map?)?.cast<String, dynamic>() ?? const {};
}

Future<List<dynamic>> _directusList(
  String collection,
  Map<String, String> query,
) async {
  final raw = await Directus.items(collection, query: query);
  return raw as List;
}

Map<String, String> _newsQuery(String edition) => {
  'fields': 'id,title,content,date_created,image,edition',
  'sort': '-date_created',
  'limit': '100',
  ..._jsonEditionFilter(edition),
};

Map<String, String> _importantInfoQuery(String edition) => {
  'fields': 'id,icon,title,body,color,url,expires_at,sort,edition',
  'sort': 'sort',
  ..._jsonEditionFilter(edition),
};

Map<String, String> _eventsQuery(String edition) => {
  'fields':
      'id,name,start_time,end_time,sort,edition,day.date,location.name,'
      'artists.artists_id.name,artists.artists_id.image,'
      'artists.artists_id.description,artists.artists_id.instagramUrl,'
      'artists.artists_id.spotifyUrl,artists.artists_id.sort',
  'sort': 'start_time,sort',
  'limit': '200',
  ..._jsonEditionFilter(edition),
};

Map<String, String> _checkpointsQuery(String edition) => {
  'fields':
      'id,qr_code,title,description,image,sort,'
      'location.id,location.name,'
      'category.id,category.display_name,category.color',
  'sort': 'sort',
  ..._jsonEditionFilter(edition),
};

Map<String, String> _locationsQuery(String edition) => {
  'fields':
      'id,name,point,polyline,isPolyline,description,color,hidden,'
      'icon,plan_point',
  ..._jsonEditionFilter(edition),
};

Map<String, String> _partnersQuery(String edition) => {
  'fields': 'id,name,url,logo,logoScale,role,sort,edition',
  'sort': 'sort',
  ..._jsonEditionFilter(edition),
};

Map<String, String> _faqsQuery(String edition) => {
  'sort': 'sort',
  ..._jsonEditionFilter(edition),
};

Map<String, String> _artistsQuery(String edition) => {
  'fields':
      'id,name,description,image,instagramUrl,spotifyUrl,isPopular,sort,edition',
  'sort': '-isPopular,sort',
  'limit': '500',
  ..._jsonEditionFilter(edition),
};

/// For collections whose `edition` is a CSV multi-select. Matches the
/// target edition or rows with no edition set so editors don't have to
/// tag every shared row.
Map<String, String> _jsonEditionFilter(String edition) {
  final target = edition.trim();
  if (target.isEmpty) return const {};
  return {
    'filter': jsonEncode({
      '_or': [
        {
          'edition': {'_contains': target},
        },
        {
          'edition': {'_null': true},
        },
        {
          'edition': {'_empty': true},
        },
      ],
    }),
  };
}

/// Cap used for partner logos. Mirrors the override in `_PartnerLogo`
/// so the precache and the widget request the same URL.
const int _kPartnerLogoCap = 50;

/// Monotonic counter so overlapping precache passes don't compete; the
/// older pass aborts when it sees a newer id.
int _precacheGeneration = 0;

/// Warms the image cache for every asset in [data] by routing every
/// URL through [imageProviderFor] — the same call AppNetworkImage uses
/// at render time. Identical [ImageProvider]s mean the in-memory and
/// on-disk caches dedupe between precache and runtime, so an offline
/// user sees images on screens they haven't visited yet.
Future<void> precacheAppImages(AppData data, {BuildContext? context}) async {
  final myGen = ++_precacheGeneration;

  final providers = <ImageProvider>[];
  final seenKeys = <Object>{};

  void add(String url, {int width = AppNetworkImage.defaultContentCap}) {
    if (url.isEmpty) return;
    final p = imageProviderFor(url, width: width);
    if (p == null) return;
    final key = _providerKey(p);
    if (seenKeys.add(key)) providers.add(p);
  }

  for (final c in data.checkpoints) {
    add(c.image);
  }
  for (final day in data.schedule) {
    for (final ev in day.events) {
      add(ev.imageUrl);
    }
  }
  for (final n in data.news) {
    add(n.imageUrl);
  }
  for (final a in data.artists) {
    add(a.imageUrl);
  }
  for (final p in data.partners) {
    final url = p.logoUrl;
    if (url != null) add(url, width: _kPartnerLogoCap);
  }
  if (providers.isEmpty) return;

  const concurrency = 4;
  final iter = providers.iterator;

  Future<void> worker() async {
    while (true) {
      if (_precacheGeneration != myGen) return;
      if (!iter.moveNext()) return;
      await _warmProvider(iter.current, context);
    }
  }

  await Future.wait(List.generate(concurrency, (_) => worker()));
}

Object _providerKey(ImageProvider p) {
  if (p is AssetImage) return p.assetName;
  if (p is NetworkImage) return p.url;
  if (p is CachedNetworkImageProvider) return p.url;
  return p;
}

Future<void> _warmProvider(
  ImageProvider provider,
  BuildContext? context,
) async {
  if (context != null && context.mounted) {
    try {
      await precacheImage(provider, context, onError: (_, _) {});
    } catch (_) {}
    return;
  }
  final completer = Completer<void>();
  final stream = provider.resolve(ImageConfiguration.empty);
  late final ImageStreamListener listener;
  listener = ImageStreamListener(
    (_, _) {
      if (!completer.isCompleted) completer.complete();
      stream.removeListener(listener);
    },
    onError: (_, _) {
      if (!completer.isCompleted) completer.complete();
      stream.removeListener(listener);
    },
  );
  stream.addListener(listener);
  await completer.future.timeout(const Duration(seconds: 10), onTimeout: () {});
}

Future<DateTime?> lastSyncTime() async {
  final prefs = await SharedPreferences.getInstance();
  final ms = prefs.getInt(_kCacheTimestamp);
  if (ms == null) return null;
  return DateTime.fromMillisecondsSinceEpoch(ms);
}

Future<bool> shouldForceRefetch() async {
  final last = await lastSyncTime();
  if (last == null) return true;
  return DateTime.now().difference(last) > _kForceRefetchAfter;
}
