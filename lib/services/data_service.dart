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
import 'connectivity_service.dart';
import 'directus.dart';

// ── Persistence keys ─────────────────────────────────────────────────────────

const _kCacheBody = 'cached_data_json';
const _kCacheTimestamp = 'cached_data_timestamp';
const _kCacheEdition = 'cached_data_edition';
const _kCacheDataVersion = 'cached_data_version';
const _kCompletedCheckpoints = 'completedCheckpoints';
const _kIsLocked = 'isLocked';
const _kLastFetchedImageSet = 'cached_image_urls';
const _localAssetPath = 'assets/data/data.json';

/// If a fetch ever succeeds but the `data_version` hasn't changed for
/// longer than this, we still force a full refetch. Keeps the bundled
/// snapshot from going stale when the CMS forgets to bump versions.
const _kForceRefetchAfter = Duration(hours: 24);

// ── AppData ──────────────────────────────────────────────────────────────────

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
    this.isFromCache = false,
  });

  // ── Back-compat getters for callers not yet migrated to AppConfig ──────────
  int get goal => config.gameGoal;
  String get rewardDescription => config.rewardDescription;
  String? get rewardPin => config.rewardPin;

  Iterable<String> get allImageUrls sync* {
    for (final c in checkpoints) {
      if (c.image.isNotEmpty) yield c.image;
    }
    for (final day in schedule) {
      for (final ev in day.events) {
        if (ev.imageUrl.isNotEmpty) yield ev.imageUrl;
      }
    }
    for (final n in news) {
      if (n.imageUrl.isNotEmpty) yield n.imageUrl;
    }
    for (final p in partners) {
      final url = p.logoUrl;
      if (url != null && url.isNotEmpty) yield url;
    }
    if (config.festivalPlanUrl.isNotEmpty) yield config.festivalPlanUrl;
  }

  Map<String, dynamic> toJson() => {
    'config': {
      'edition': config.edition,
      'event_starts_at': config.eventStartsAt?.toIso8601String(),
      'event_ends_at': config.eventEndsAt?.toIso8601String(),
      'game_enabled_override': config.gameEnabledOverride,
      'game_goal': config.gameGoal,
      'reward_description': config.rewardDescription,
      'reward_pin': config.rewardPin,
      'game_terms': config.gameTerms,
      'festival_plan_url': config.festivalPlanUrl,
      'data_version': config.dataVersion,
      'min_app_version_ios': config.minAppVersionIos,
      'min_app_version_android': config.minAppVersionAndroid,
      'min_app_version_web': config.minAppVersionWeb,
      'app_store_url_ios': config.appStoreUrlIos,
      'app_store_url_android': config.appStoreUrlAndroid,
      'plan_bounds': {
        'north': config.planBounds.north,
        'south': config.planBounds.south,
        'east': config.planBounds.east,
        'west': config.planBounds.west,
      },
    },
    'checkpoints': checkpoints
        .map(
          (c) => {
            'id': c.id,
            'qr_code': c.qrCode,
            'title': c.title,
            'description': c.description,
            'category': c.category,
            'category_label': c.categoryLabel,
            'category_color': c.categoryColor,
            'image': c.image,
            'location': c.location,
            'location_id': c.locationId,
          },
        )
        .toList(),
    'news': news
        .map(
          (n) => {
            'id': n.id,
            'title': n.title,
            'body': n.body,
            'category': n.category,
            'date': n.date.toIso8601String(),
            'image_url': n.imageUrl,
          },
        )
        .toList(),
    'schedule': schedule
        .map(
          (d) => {
            'label': d.label,
            'venue': d.venue,
            'events': d.events
                .map(
                  (e) => {
                    'id': e.id,
                    'artist': e.artist,
                    'genre': e.genre,
                    'stage': e.stage,
                    'time': e.time,
                    'image_url': e.imageUrl,
                    'start_time': e.startTime?.toIso8601String(),
                    'end_time': e.endTime?.toIso8601String(),
                    'artist_description': e.artistDescription,
                    'artist_instagram_url': e.artistInstagramUrl,
                    'artist_spotify_url': e.artistSpotifyUrl,
                  },
                )
                .toList(),
          },
        )
        .toList(),
    'map_points': mapPoints
        .map(
          (p) => {
            'id': p.id,
            'name': p.name,
            'type': p.type,
            'description': p.description,
            'lat': p.lat,
            'lng': p.lng,
            'color': p.color,
            'hidden': p.hidden,
          },
        )
        .toList(),
    'partners': partners
        .map(
          (p) => {
            'id': p.id,
            'name': p.name,
            'tier': p.tier,
            'logo_url': p.logoUrl,
            'url': p.url,
            'logo_scale': p.logoScale,
          },
        )
        .toList(),
    'partner_tiers': partnerTiers
        .map((t) => {'value': t.value, 'label': t.label, 'icon': t.icon})
        .toList(),
    'important_info': importantInfo
        .map(
          (i) => {
            'id': i.id,
            'icon': i.icon,
            'title': i.title,
            'body': i.body,
            'color': i.color,
            'url': i.url,
            'expires_at': i.expiresAt?.toIso8601String(),
          },
        )
        .toList(),
    'faqs': faqs
        .map((f) => {'id': f.id, 'question': f.question, 'answer': f.answer})
        .toList(),
  };

  factory AppData.fromJson(
    Map<String, dynamic> json, {
    bool isFromCache = false,
  }) {
    final cfg = (json['config'] as Map?)?.cast<String, dynamic>() ?? const {};
    return AppData(
      config: AppConfig(
        edition: (cfg['edition'] as String?) ?? '',
        eventStartsAt: _parseDate(cfg['event_starts_at']),
        eventEndsAt: _parseDate(cfg['event_ends_at']),
        gameEnabledOverride: cfg['game_enabled_override'] as bool?,
        gameGoal: (cfg['game_goal'] as num?)?.toInt() ?? 0,
        rewardDescription: (cfg['reward_description'] as String?) ?? '',
        rewardPin: (cfg['reward_pin'] as String?)?.trim(),
        gameTerms: (cfg['game_terms'] as String?) ?? '',
        festivalPlanUrl: (cfg['festival_plan_url'] as String?) ?? '',
        dataVersion: (cfg['data_version'] as String?) ?? '',
        minAppVersionIos: (cfg['min_app_version_ios']?.toString()) ?? '',
        minAppVersionAndroid:
            (cfg['min_app_version_android']?.toString()) ?? '',
        minAppVersionWeb: (cfg['min_app_version_web']?.toString()) ?? '',
        appStoreUrlIos: (cfg['app_store_url_ios'] as String?)?.trim(),
        appStoreUrlAndroid: (cfg['app_store_url_android'] as String?)?.trim(),
        planBounds: _parsePlanBounds(cfg['plan_bounds']),
      ),
      checkpoints: ((json['checkpoints'] as List?) ?? const [])
          .cast<Map<String, dynamic>>()
          .map(
            (j) => Checkpoint(
              id: (j['id'] as num).toInt(),
              qrCode: (j['qr_code'] as String?) ?? '',
              title: (j['title'] as String?) ?? '',
              description: (j['description'] as String?) ?? '',
              category: (j['category'] as String?) ?? '',
              categoryLabel: (j['category_label'] as String?) ?? 'Inne',
              categoryColor: (j['category_color'] as String?) ?? '',
              image: (j['image'] as String?) ?? '',
              location: (j['location'] as String?) ?? '',
              locationId: j['location_id']?.toString(),
            ),
          )
          .toList(),
      news: ((json['news'] as List?) ?? const [])
          .cast<Map<String, dynamic>>()
          .map(
            (j) => NewsItem(
              id: j['id'].toString(),
              title: (j['title'] as String?) ?? '',
              body: (j['body'] as String?) ?? '',
              category: (j['category'] as String?) ?? 'general',
              date: _parseDate(j['date']) ?? DateTime.now(),
              imageUrl: (j['image_url'] as String?) ?? '',
            ),
          )
          .toList(),
      schedule: ((json['schedule'] as List?) ?? const [])
          .cast<Map<String, dynamic>>()
          .map(
            (d) => ScheduleDay(
              label: (d['label'] as String?) ?? '',
              venue: (d['venue'] as String?) ?? '',
              events: ((d['events'] as List?) ?? const [])
                  .cast<Map<String, dynamic>>()
                  .map(
                    (e) => ScheduleEvent(
                      id: e['id'].toString(),
                      artist: (e['artist'] as String?) ?? '',
                      genre: (e['genre'] as String?) ?? '',
                      stage: (e['stage'] as String?) ?? '',
                      time: (e['time'] as String?) ?? '',
                      imageUrl: (e['image_url'] as String?) ?? '',
                      startTime: _parseDate(e['start_time']),
                      endTime: _parseDate(e['end_time']),
                      artistDescription: (e['artist_description'] as String?)
                          ?.trim(),
                      artistInstagramUrl: (e['artist_instagram_url'] as String?)
                          ?.trim(),
                      artistSpotifyUrl: (e['artist_spotify_url'] as String?)
                          ?.trim(),
                    ),
                  )
                  .toList(),
            ),
          )
          .toList(),
      mapPoints: ((json['map_points'] as List?) ?? const [])
          .cast<Map<String, dynamic>>()
          .map(
            (j) => MapPoint(
              id: j['id'].toString(),
              name: (j['name'] as String?) ?? '',
              type: (j['type'] as String?) ?? 'other',
              description: j['description'] as String?,
              lat: (j['lat'] as num?)?.toDouble(),
              lng: (j['lng'] as num?)?.toDouble(),
              color: j['color'] as String?,
              hidden: (j['hidden'] as bool?) ?? false,
            ),
          )
          .toList(),
      partners: ((json['partners'] as List?) ?? const [])
          .cast<Map<String, dynamic>>()
          .map(
            (j) => Partner(
              id: j['id'].toString(),
              name: (j['name'] as String?) ?? '',
              tier: (j['tier'] as String?) ?? 'media',
              logoUrl: j['logo_url'] as String?,
              url: j['url'] as String?,
              logoScale: (j['logo_scale'] as num?)?.toDouble(),
            ),
          )
          .toList(),
      partnerTiers: ((json['partner_tiers'] as List?) ?? const [])
          .cast<Map<String, dynamic>>()
          .map(
            (j) => PartnerTier(
              value: (j['value']?.toString()) ?? '',
              label: (j['label'] as String?) ?? '',
              icon: (j['icon'] as String?),
            ),
          )
          .toList(),
      importantInfo: ((json['important_info'] as List?) ?? const [])
          .cast<Map<String, dynamic>>()
          .map(
            (j) => ImportantInfo(
              id: j['id'].toString(),
              icon: (j['icon'] as String?) ?? '',
              title: (j['title'] as String?) ?? '',
              body: (j['body'] as String?) ?? '',
              color: (j['color'] as String?) ?? '',
              url: (j['url'] as String?)?.trim(),
              expiresAt: _parseDate(j['expires_at']),
            ),
          )
          .toList(),
      faqs: ((json['faqs'] as List?) ?? const [])
          .cast<Map<String, dynamic>>()
          .map(
            (j) => FaqItem(
              id: j['id'].toString(),
              question: (j['question'] as String?) ?? '',
              answer: (j['answer'] as String?) ?? '',
            ),
          )
          .toList(),
      isFromCache: isFromCache,
    );
  }
}

DateTime? _parseDate(dynamic raw) {
  if (raw == null) return null;
  final s = raw.toString();
  if (s.isEmpty) return null;
  return DateTime.tryParse(s);
}

// ── Fetch ────────────────────────────────────────────────────────────────────

/// Fetches the composite app payload from Directus with a 3-tier fallback:
///   1. Network → aggregate all collections, cache, return fresh.
///   2. SharedPreferences cache → last successful fetch.
///   3. Bundled asset → snapshot written at build time by `tool/sync_data.dart`.
///
/// Collections are fetched concurrently; individual collection failures
/// degrade to the previously-cached values (when the edition matches) so a
/// flaky CMS doesn't wipe everything the user just saw.
///
/// Pass [forceNetwork] to bypass the cache/asset fallback — used by
/// pull-to-refresh to surface genuine network failures to the user
/// instead of silently returning stale data. Note: partial-collection
/// failures still degrade quietly even when [forceNetwork] is true; only
/// a full failure (e.g. config fetch throws) re-raises.
Future<AppData> fetchData(
  http.Client client, {
  bool forceNetwork = false,
}) async {
  final prefs = await SharedPreferences.getInstance();

  // Load previous cache once, up front — we use it as both the per-collection
  // fallback during the fetch *and* as the overall fallback when the fetch
  // fails outright.
  AppData? previous;
  final cached = prefs.getString(_kCacheBody);
  if (cached != null) {
    try {
      previous = AppData.fromJson(
        jsonDecode(cached) as Map<String, dynamic>,
        isFromCache: true,
      );
    } catch (_) {
      // corrupt cache — ignore, we'll overwrite on success
    }
  }

  try {
    final data = await _fetchFromDirectus(previous: previous);
    ConnectivityService.instance.reportFetchSuccess();

    // Edition-reset: if the new payload is for a different edition than
    // the one we last cached, wipe per-edition state before persisting.
    final previousEdition = prefs.getString(_kCacheEdition);
    if (previousEdition != null &&
        previousEdition.isNotEmpty &&
        previousEdition != data.config.edition) {
      await _resetEditionState(prefs);
    }

    final encoded = jsonEncode(data.toJson());
    await prefs.setString(_kCacheBody, encoded);
    await prefs.setInt(_kCacheTimestamp, DateTime.now().millisecondsSinceEpoch);
    await prefs.setString(_kCacheEdition, data.config.edition);
    await prefs.setString(_kCacheDataVersion, data.config.dataVersion);

    return data;
  } catch (e) {
    await ConnectivityService.instance.reportFetchFailure();
    if (forceNetwork) rethrow;
    // else fall through to cache/asset
  }

  if (previous != null) return previous;

  // Bundled snapshot is optional: it's generated by `tool/sync_data.dart`
  // and gitignored, so a fresh clone doesn't ship one. If it's missing
  // we treat the whole chain as a network failure — the UI handles it.
  try {
    final assetBody = await rootBundle.loadString(_localAssetPath);
    return AppData.fromJson(
      jsonDecode(assetBody) as Map<String, dynamic>,
      isFromCache: true,
    );
  } catch (_) {
    throw StateError(
      'No network, no cached data, no bundled snapshot — '
      'run `dart run tool/sync_data.dart` to ship a baseline.',
    );
  }
}

/// Clears every persisted key that is tied to a specific edition.
/// Called when the CMS switches editions so old-edition state (progress,
/// cached payload, precached image URL list) doesn't leak into the new one.
Future<void> _resetEditionState(SharedPreferences prefs) async {
  await prefs.remove(_kCompletedCheckpoints);
  await prefs.remove(_kIsLocked);
  await prefs.remove(_kCacheBody);
  await prefs.remove(_kCacheTimestamp);
  await prefs.remove(_kCacheDataVersion);
  await prefs.remove(_kLastFetchedImageSet);
}

Future<AppData> _fetchFromDirectus({AppData? previous}) async {
  // Config first — everything else filters by edition. If config fails we
  // want the whole fetch to fail so `fetchData` can fall back to cache.
  final config = await _fetchConfig();

  // Only reuse previous values when the edition matches — otherwise stale
  // rows from the old edition would leak into the new payload.
  final sameEdition =
      previous != null && previous.config.edition == config.edition;

  Future<T> withFallback<T>(Future<T> Function() fn, T fallback) async {
    try {
      return await fn();
    } catch (_) {
      return fallback;
    }
  }

  // All collections in flight concurrently — the previous "two-wave" split
  // serialized the second half behind the first and gave no real ordering
  // benefit since the shell awaits the full AppData anyway.
  final results = await Future.wait([
    withFallback<List<NewsItem>>(
      () => _fetchNews(config.edition),
      sameEdition ? previous.news : const [],
    ),
    withFallback<List<ImportantInfo>>(
      () => _fetchImportantInfo(config.edition),
      sameEdition ? previous.importantInfo : const [],
    ),
    withFallback<List<ScheduleDay>>(
      () => _fetchSchedule(config.edition),
      sameEdition ? previous.schedule : const [],
    ),
    withFallback<List<Checkpoint>>(
      () => _fetchCheckpoints(config.edition),
      sameEdition ? previous.checkpoints : const [],
    ),
    withFallback<List<MapPoint>>(
      () => _fetchLocations(config.edition),
      sameEdition ? previous.mapPoints : const [],
    ),
    withFallback<List<Partner>>(
      () => _fetchPartners(config.edition),
      sameEdition ? previous.partners : const [],
    ),
    withFallback<List<FaqItem>>(
      () => _fetchFaqs(config.edition),
      sameEdition ? previous.faqs : const [],
    ),
    withFallback<List<PartnerTier>>(
      () => _fetchPartnerTiers(),
      sameEdition ? previous.partnerTiers : const [],
    ),
  ]);

  return AppData(
    config: config,
    news: results[0] as List<NewsItem>,
    importantInfo: results[1] as List<ImportantInfo>,
    schedule: results[2] as List<ScheduleDay>,
    checkpoints: results[3] as List<Checkpoint>,
    mapPoints: results[4] as List<MapPoint>,
    partners: results[5] as List<Partner>,
    faqs: results[6] as List<FaqItem>,
    partnerTiers: results[7] as List<PartnerTier>,
  );
}

// ── Collection fetchers ──────────────────────────────────────────────────────

Future<AppConfig> _fetchConfig() async {
  final raw = await Directus.items('app_config');
  final data = (raw as Map?)?.cast<String, dynamic>() ?? const {};
  return AppConfig(
    edition: (data['edition'] as String?) ?? '',
    eventStartsAt: _parseDate(data['event_starts_at']),
    eventEndsAt: _parseDate(data['event_ends_at']),
    gameEnabledOverride: data['game_enabled_override'] as bool?,
    gameGoal: (data['game_goal'] as num?)?.toInt() ?? 0,
    rewardDescription: (data['reward_description'] as String?) ?? '',
    rewardPin: (data['reward_pin'] as String?)?.trim(),
    gameTerms: (data['game_terms'] as String?) ?? '',
    festivalPlanUrl: Directus.assetUrl(data['festival_plan'] as String?),
    dataVersion: (data['data_version']?.toString()) ?? '',
    minAppVersionIos: (data['min_app_version_ios']?.toString()) ?? '',
    minAppVersionAndroid: (data['min_app_version_android']?.toString()) ?? '',
    minAppVersionWeb: (data['min_app_version_web']?.toString()) ?? '',
    appStoreUrlIos: (data['app_store_url_ios'] as String?)?.trim(),
    appStoreUrlAndroid: (data['app_store_url_android'] as String?)?.trim(),
    planBounds: _parsePlanBounds(data['plan_bounds']),
  );
}

PlanBounds _parsePlanBounds(dynamic raw) {
  Map<String, dynamic>? map;
  if (raw is Map) {
    map = raw.cast<String, dynamic>();
  } else if (raw is String && raw.trim().isNotEmpty) {
    try {
      final decoded = jsonDecode(raw);
      if (decoded is Map) map = decoded.cast<String, dynamic>();
    } catch (_) {}
  }
  if (map == null) return PlanBounds.fallback;
  double? numAt(String k) => (map![k] as num?)?.toDouble();
  final n = numAt('north');
  final s = numAt('south');
  final e = numAt('east');
  final w = numAt('west');
  if (n == null || s == null || e == null || w == null) {
    return PlanBounds.fallback;
  }
  return PlanBounds(north: n, south: s, east: e, west: w);
}

Future<List<NewsItem>> _fetchNews(String edition) async {
  final query = <String, String>{
    'fields': 'id,title,content,date_created,image,edition',
    'sort': '-date_created',
    'limit': '100',
    ..._stringEditionFilter(edition),
  };
  final raw = await Directus.items('news', query: query) as List;

  return raw.cast<Map<String, dynamic>>().map((j) {
    return NewsItem(
      id: j['id'].toString(),
      title: (j['title'] as String?) ?? '',
      body: (j['content'] as String?) ?? '',
      category: 'general',
      date: _parseDate(j['date_created']) ?? DateTime.now(),
      imageUrl: Directus.assetUrl(j['image'] as String?),
    );
  }).toList();
}

Future<List<ImportantInfo>> _fetchImportantInfo([String edition = '']) async {
  final query = <String, String>{
    'fields': 'id,icon,title,body,color,url,expires_at',
    'sort': 'sort',
    ..._jsonEditionFilter(edition),
  };
  final raw = await Directus.items('important_info', query: query) as List;

  // We intentionally don't drop expired rows here — the filter runs at
  // render time so a cached payload fetched days ago still hides an
  // announcement once its expiry passes, even with no network.
  return raw.cast<Map<String, dynamic>>().map((j) {
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
  }).toList();
}

Future<List<ScheduleDay>> _fetchSchedule(String edition) async {
  final query = <String, String>{
    'fields':
        'id,name,start_time,end_time,sort,edition,day.date,location.name,'
        'artists.artists_id.name,artists.artists_id.image,'
        'artists.artists_id.description,artists.artists_id.instagramUrl,'
        'artists.artists_id.spotifyUrl,artists.artists_id.sort',
    'sort': 'start_time,sort',
    'limit': '200',
    ..._stringEditionFilter(edition),
  };
  final raw = await Directus.items('events', query: query) as List;

  // Group events by day.date — fall back to the date portion of start_time.
  final byDay = <String, List<ScheduleEvent>>{};

  for (final e in raw.cast<Map<String, dynamic>>()) {
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

    // Use the first artist's image as the event cover image. Falls back to
    // empty, which the UI renders as a text-only card.
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
      .map(
        (k) => ScheduleDay(
          label: _formatDayLabel(k),
          venue: '',
          events: byDay[k]!,
        ),
      )
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

String _formatDayLabel(String isoDate) {
  final dt = DateTime.tryParse(isoDate);
  if (dt == null) return isoDate;
  try {
    return DateFormat('EEEE, d MMMM', 'pl').format(dt).toUpperCase();
  } catch (_) {
    return DateFormat('EEEE, d MMMM').format(dt).toUpperCase();
  }
}

Future<List<Checkpoint>> _fetchCheckpoints(String edition) async {
  final query = <String, String>{
    'fields':
        'id,qr_code,title,description,image,sort,'
        'location.id,location.name,'
        'category.id,category.display_name,category.color',
    'sort': 'sort',
    ..._jsonEditionFilter(edition),
  };
  final raw = await Directus.items('checkpoints', query: query) as List;

  return raw.cast<Map<String, dynamic>>().map((j) {
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
  }).toList();
}

Future<List<MapPoint>> _fetchLocations(String edition) async {
  final query = <String, String>{
    'fields': 'id,name,point,polyline,isPolyline,description,color,hidden',
    ..._jsonEditionFilter(edition),
  };
  final raw = await Directus.items('locations', query: query) as List;

  return raw.cast<Map<String, dynamic>>().map((j) {
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
    return MapPoint(
      id: j['id'].toString(),
      name: (j['name'] as String?) ?? '',
      type: 'info',
      description: j['description'] as String?,
      lat: lat,
      lng: lng,
      color: j['color'] as String?,
      hidden: (j['hidden'] as bool?) ?? false,
    );
  }).toList();
}

/// Pulls the `organisations.role` field's dropdown choices so editors can
/// rename/reorder partner tiers without an app release. Falls back to an
/// empty list on any error — the UI then synthesises tiers from whatever
/// values the partners themselves carry.
Future<List<PartnerTier>> _fetchPartnerTiers() async {
  try {
    final meta = await Directus.field('organisations', 'role');
    if (meta == null) return const [];
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
  } catch (_) {
    return const [];
  }
}

Future<List<Partner>> _fetchPartners(String edition) async {
  final query = <String, String>{
    'fields': 'id,name,url,logo,logoScale,role,sort,edition',
    'sort': 'sort',
    ..._stringEditionFilter(edition),
  };
  final raw = await Directus.items('organisations', query: query) as List;

  return raw.cast<Map<String, dynamic>>().map((j) {
    return Partner(
      id: j['id'].toString(),
      name: (j['name'] as String?) ?? '',
      tier: (j['role']?.toString()) ?? '4',
      logoUrl: Directus.assetUrl(j['logo'] as String?),
      url: j['url'] as String?,
      logoScale: double.tryParse((j['logoScale']?.toString()) ?? ''),
    );
  }).toList();
}

/// For collections whose `edition` column is a JSON array of values
/// (multi-select dropdown in Directus — checkpoints, faqs, important_info,
/// locations), match either the target edition or rows with no edition set.
/// That way CMS editors don't have to tag every shared row.
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

/// For collections whose `edition` column is a single-select string
/// (events, news, organisations, artists), match either the target edition
/// or rows with no edition set. Same motivation as [_jsonEditionFilter].
Map<String, String> _stringEditionFilter(String edition) {
  final target = edition.trim();
  if (target.isEmpty) return const {};
  return {
    'filter': jsonEncode({
      '_or': [
        {
          'edition': {'_eq': target},
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

Future<List<FaqItem>> _fetchFaqs(String edition) async {
  try {
    final query = <String, String>{
      'sort': 'sort',
      ..._jsonEditionFilter(edition),
    };
    final raw = await Directus.items('faqs', query: query) as List;
    return raw.cast<Map<String, dynamic>>().map((j) {
      return FaqItem(
        id: j['id'].toString(),
        question: (j['question'] as String?) ?? '',
        answer: (j['answer'] as String?) ?? '',
      );
    }).toList();
  } catch (_) {
    return const [];
  }
}

// ── Image precache (staged) ──────────────────────────────────────────────────

/// Monotonic counter — each call to [precacheAppImages] claims a fresh id
/// and workers abort as soon as a newer call supersedes them. Without this,
/// two overlapping refreshes would race to write [_kLastFetchedImageSet].
int _precacheGeneration = 0;

/// Pre-caches every image referenced in [data]. The previous generation
/// of images stays in the [CachedNetworkImage] disk cache until each new
/// URL resolves, so a mid-fetch offline drop doesn't lose imagery.
///
/// Safe to call repeatedly: a new invocation cancels any in-flight workers
/// from the previous call.
Future<void> precacheAppImages(AppData data, {BuildContext? context}) async {
  final myGen = ++_precacheGeneration;
  final urls = data.allImageUrls.toSet();
  if (urls.isEmpty) return;

  const concurrency = 4;
  final iterator = urls.iterator;

  Future<void> worker() async {
    while (true) {
      if (_precacheGeneration != myGen) return;
      if (!iterator.moveNext()) return;
      final url = iterator.current;
      try {
        final provider = CachedNetworkImageProvider(url);
        if (context != null && context.mounted) {
          await precacheImage(provider, context);
        } else {
          final completer = Completer<void>();
          final stream = provider.resolve(ImageConfiguration.empty);
          late final ImageStreamListener listener;
          listener = ImageStreamListener(
            (info, _) {
              if (!completer.isCompleted) completer.complete();
              stream.removeListener(listener);
            },
            onError: (e, _) {
              if (!completer.isCompleted) completer.complete();
              stream.removeListener(listener);
            },
          );
          stream.addListener(listener);
          await completer.future.timeout(
            const Duration(seconds: 10),
            onTimeout: () {},
          );
        }
      } catch (_) {
        // Best-effort — skip failures silently.
      }
    }
  }

  await Future.wait(List.generate(concurrency, (_) => worker()));

  // If a newer precache pass is already running, don't overwrite the tracked
  // image set with this (now-stale) generation's URLs.
  if (_precacheGeneration != myGen) return;
  final prefs = await SharedPreferences.getInstance();
  await prefs.setStringList(_kLastFetchedImageSet, urls.toList());
}

Future<DateTime?> lastSyncTime() async {
  final prefs = await SharedPreferences.getInstance();
  final ms = prefs.getInt(_kCacheTimestamp);
  if (ms == null) return null;
  return DateTime.fromMillisecondsSinceEpoch(ms);
}

/// True when the last successful fetch is older than [_kForceRefetchAfter]
/// regardless of whether the CMS has bumped data_version. Callers use
/// this to decide whether to show a "recently synced" badge or retry.
Future<bool> shouldForceRefetch() async {
  final last = await lastSyncTime();
  if (last == null) return true;
  return DateTime.now().difference(last) > _kForceRefetchAfter;
}
