class NewsItem {
  final String id;
  final String title;
  final String body;
  final String category;
  final DateTime date;
  final String imageUrl;

  const NewsItem({
    required this.id,
    required this.title,
    required this.body,
    required this.category,
    required this.date,
    this.imageUrl = '',
  });
}

class ScheduleDay {
  final String label;
  final String venue;
  final List<ScheduleEvent> events;

  const ScheduleDay({
    required this.label,
    required this.venue,
    required this.events,
  });
}

class ScheduleEvent {
  final String id;
  final String artist;
  final String genre;
  final String stage;
  final String time;
  final String imageUrl;
  final DateTime? startTime;
  final DateTime? endTime;
  final String? artistDescription;
  final String? artistInstagramUrl;
  final String? artistSpotifyUrl;

  const ScheduleEvent({
    required this.id,
    required this.artist,
    required this.genre,
    required this.stage,
    required this.time,
    required this.imageUrl,
    this.startTime,
    this.endTime,
    this.artistDescription,
    this.artistInstagramUrl,
    this.artistSpotifyUrl,
  });
}

class MapPoint {
  final String id;
  final String name;
  final String type;
  final String? description;
  final double? lat;
  final double? lng;
  final String? color;

  /// CMS-supplied Material icon name; overrides [type]'s default.
  final String? icon;

  /// Pixel coordinates on the festival plan. Both must be non-null
  /// for the location to render on the plan view.
  final int? planX;
  final int? planY;

  /// Excludes the pin from the main map legend but keeps it reachable
  /// via checkpoint mini-maps.
  final bool hidden;

  const MapPoint({
    required this.id,
    required this.name,
    required this.type,
    this.description,
    this.lat,
    this.lng,
    this.color,
    this.icon,
    this.planX,
    this.planY,
    this.hidden = false,
  });

  bool get hasPlanPosition => planX != null && planY != null;
}

class Artist {
  final String id;
  final String name;
  final String description;
  final String imageUrl;
  final String? instagramUrl;
  final String? spotifyUrl;
  final bool isPopular;

  const Artist({
    required this.id,
    required this.name,
    required this.description,
    required this.imageUrl,
    this.instagramUrl,
    this.spotifyUrl,
    this.isPopular = false,
  });
}

class Partner {
  final String id;
  final String name;
  final String tier;
  final String? logoUrl;
  final String? url;
  final double? logoScale;

  const Partner({
    required this.id,
    required this.name,
    required this.tier,
    this.logoUrl,
    this.url,
    this.logoScale,
  });
}

class PartnerTier {
  final String value;
  final String label;
  final String? icon;

  const PartnerTier({required this.value, required this.label, this.icon});
}

class ImportantInfo {
  final String id;
  final String icon;
  final String title;
  final String body;
  final String color;

  final String? url;
  final DateTime? expiresAt;

  const ImportantInfo({
    required this.id,
    required this.icon,
    required this.title,
    required this.body,
    required this.color,
    this.url,
    this.expiresAt,
  });
}

class FaqItem {
  final String id;
  final String question;
  final String answer;

  const FaqItem({
    required this.id,
    required this.question,
    required this.answer,
  });
}

class AppConfig {
  final String edition;
  final DateTime? eventStartsAt;
  final bool? gameEnabledOverride;
  final int gameGoal;
  final String rewardDescription;
  final String? rewardPin;
  final String gameTerms;
  final String festivalPlanUrl;
  final String minAppVersionIos;
  final String minAppVersionAndroid;
  final String minAppVersionWeb;
  final String? appStoreUrlIos;
  final String? appStoreUrlAndroid;

  /// URL encoded into the desktop sidebar QR. Empty falls back to
  /// [appStoreUrlAndroid].
  final String? downloadQrUrl;
  final String? downloadPanelDescription;

  const AppConfig({
    required this.edition,
    this.eventStartsAt,
    this.gameEnabledOverride,
    this.gameGoal = 0,
    this.rewardDescription = '',
    this.rewardPin,
    this.gameTerms = '',
    this.festivalPlanUrl = '',
    this.minAppVersionIos = '',
    this.minAppVersionAndroid = '',
    this.minAppVersionWeb = '',
    this.appStoreUrlIos,
    this.appStoreUrlAndroid,
    this.downloadQrUrl,
    this.downloadPanelDescription,
  });
}
