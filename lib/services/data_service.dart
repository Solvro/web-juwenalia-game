import 'dart:convert';
import 'dart:async';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../checkpoint.dart';
import '../models/models.dart';

/// The remote URL for data. Change this to point at a CMS endpoint later.
const _remoteUrl =
    'https://raw.githubusercontent.com/Antoni-Czaplicki/web-juwenalia-game/main/data/data.json';
const _cacheKey = 'cached_data_json';
const _localAssetPath = 'assets/data/data.json';

class AppData {
  final int version;
  final int goal;
  final String surveyUrl;
  final String rewardDescription;
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
}

/// Fetches data with a three-tier strategy:
///  1. Try network (and cache on success)
///  2. Fall back to SharedPreferences cache
///  3. Fall back to bundled local asset
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
