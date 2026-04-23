import 'dart:async';
import 'dart:convert';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../checkpoint.dart';
import '../models/models.dart';

/// The remote URL for data. Change this to point at a CMS endpoint later.
const _remoteUrl =
    'https://raw.githubusercontent.com/Solvro/web-juwenalia-game/main/assets/data/data.json';
const _cacheKey = 'cached_data_json';
const _cacheTimestampKey = 'cached_data_timestamp';
const _localAssetPath = 'assets/data/data.json';

class AppData {
  final int version;
  final int goal;
  final String surveyUrl;
  final String rewardDescription;
  final String? rewardPin;
  final List<Checkpoint> checkpoints;
  final List<NewsItem> news;
  final List<ScheduleDay> schedule;
  final List<MapPoint> mapPoints;
  final List<Partner> partners;
  final bool isFromCache;

  const AppData({
    required this.version,
    required this.goal,
    required this.surveyUrl,
    required this.rewardDescription,
    this.rewardPin,
    required this.checkpoints,
    this.news = const [],
    this.schedule = const [],
    this.mapPoints = const [],
    this.partners = const [],
    this.isFromCache = false,
  });

  factory AppData.fromJson(
    Map<String, dynamic> json, {
    bool isFromCache = false,
  }) {
    return AppData(
      version: json['version'] as int,
      goal: json['goal'] as int,
      surveyUrl: json['survey_url'] as String,
      rewardDescription: json['reward_description'] as String,
      rewardPin: (json['reward_pin'] as String?)?.trim(),
      checkpoints: (json['checkpoints'] as List)
          .cast<Map<String, dynamic>>()
          .map((j) => Checkpoint.fromJson(j))
          .toList(),
      news:
          (json['news'] as List?)
              ?.cast<Map<String, dynamic>>()
              .map(NewsItem.fromJson)
              .toList() ??
          [],
      schedule:
          (json['schedule'] as List?)
              ?.cast<Map<String, dynamic>>()
              .map(ScheduleDay.fromJson)
              .toList() ??
          [],
      mapPoints:
          (json['map_points'] as List?)
              ?.cast<Map<String, dynamic>>()
              .map(MapPoint.fromJson)
              .toList() ??
          [],
      partners:
          (json['partners'] as List?)
              ?.cast<Map<String, dynamic>>()
              .map(Partner.fromJson)
              .toList() ??
          [],
      isFromCache: isFromCache,
    );
  }

  /// Every image URL referenced anywhere in this payload — used for
  /// pre-caching so the app stays usable offline.
  Iterable<String> get allImageUrls sync* {
    for (final c in checkpoints) {
      if (c.image.trim().isNotEmpty) yield c.image.trim();
    }
    for (final day in schedule) {
      for (final ev in day.events) {
        if (ev.imageUrl.trim().isNotEmpty) yield ev.imageUrl.trim();
      }
    }
    for (final p in partners) {
      final url = p.logoUrl?.trim();
      if (url != null && url.isNotEmpty) yield url;
    }
  }
}

/// Fetches data with an "always-online-when-possible" strategy:
///   1. Try network. On success, cache the JSON to SharedPreferences and
///      return the fresh payload (`isFromCache = false`).
///   2. Fall back to SharedPreferences cache.
///   3. Fall back to the bundled asset (`assets/data/data.json` is kept
///      fresh by the build-time `tool/sync_data.dart` script).
Future<AppData> fetchData(http.Client client) async {
  // 1. Try network
  try {
    final response = await client
        .get(Uri.parse(_remoteUrl))
        .timeout(const Duration(seconds: 8));
    if (response.statusCode == 200) {
      final body = response.body;
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_cacheKey, body);
      await prefs.setInt(
        _cacheTimestampKey,
        DateTime.now().millisecondsSinceEpoch,
      );
      return AppData.fromJson(jsonDecode(body) as Map<String, dynamic>);
    }
  } catch (_) {
    // Network unavailable – fall through to cache
  }

  // 2. Try SharedPreferences cache
  final prefs = await SharedPreferences.getInstance();
  final cached = prefs.getString(_cacheKey);
  if (cached != null) {
    return AppData.fromJson(
      jsonDecode(cached) as Map<String, dynamic>,
      isFromCache: true,
    );
  }

  // 3. Fall back to bundled asset
  final assetBody = await rootBundle.loadString(_localAssetPath);
  return AppData.fromJson(
    jsonDecode(assetBody) as Map<String, dynamic>,
    isFromCache: true,
  );
}

/// Pre-caches every image referenced in [data] into the
/// [CachedNetworkImage] disk cache so they're available offline. Runs in
/// the background and returns when the warm-up has been kicked off — does
/// not block the UI.
///
/// Pass a [BuildContext] to also warm Flutter's in-memory image cache via
/// [precacheImage]; otherwise we just rely on the disk cache.
Future<void> precacheAppImages(AppData data, {BuildContext? context}) async {
  final urls = data.allImageUrls.toSet();
  if (urls.isEmpty) return;

  // Cap concurrency so we don't slam the network on a 30+ image payload.
  const concurrency = 4;
  final iterator = urls.iterator;

  Future<void> worker() async {
    while (true) {
      String url;
      if (!iterator.moveNext()) return;
      url = iterator.current;
      try {
        final provider = CachedNetworkImageProvider(url);
        if (context != null && context.mounted) {
          // Warms the in-memory cache and (transitively) the disk cache.
          await precacheImage(provider, context);
        } else {
          // No context: still trigger a fetch via the underlying cache
          // manager so the disk cache populates. We resolve the stream and
          // wait for the first frame to settle.
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
}

/// Returns the timestamp of the last successful network sync, or null if
/// the app has never reached the network.
Future<DateTime?> lastSyncTime() async {
  final prefs = await SharedPreferences.getInstance();
  final ms = prefs.getInt(_cacheTimestampKey);
  if (ms == null) return null;
  return DateTime.fromMillisecondsSinceEpoch(ms);
}
