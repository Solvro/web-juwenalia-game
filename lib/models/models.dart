// Data models for the Juwenalia #WrocławRazem app.
// Shapes mirror the Directus CMS collections.

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

  const MapPoint({
    required this.id,
    required this.name,
    required this.type,
    this.description,
    this.lat,
    this.lng,
    this.color,
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

/// Dropdown-choice metadata for the `organisations.role` field. Pulled from
/// Directus so editors can rename/reorder tiers without an app release.
class PartnerTier {
  final String value;
  final String label;
  final String? icon;

  const PartnerTier({
    required this.value,
    required this.label,
    this.icon,
  });
}

class ImportantInfo {
  final String id;
  final String icon;
  final String title;
  final String body;
  final String color;

  const ImportantInfo({
    required this.id,
    required this.icon,
    required this.title,
    required this.body,
    required this.color,
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

class PlanBounds {
  final double north;
  final double south;
  final double east;
  final double west;

  const PlanBounds({
    required this.north,
    required this.south,
    required this.east,
    required this.west,
  });

  /// Default bounds for legacy clients without CMS config.
  static const fallback = PlanBounds(
    north: 51.1098,
    south: 51.1062,
    east: 17.0624,
    west: 17.0562,
  );
}

class AppConfig {
  final String edition;
  final DateTime? eventStartsAt;
  final DateTime? eventEndsAt;
  final bool? gameEnabledOverride;
  final int gameGoal;
  final String rewardDescription;
  final String? rewardPin;
  final String gameTerms;
  final String festivalPlanUrl;
  final String dataVersion;
  final String minAppVersionIos;
  final String minAppVersionAndroid;
  final String minAppVersionWeb;
  final String? appStoreUrlIos;
  final String? appStoreUrlAndroid;
  final PlanBounds planBounds;

  const AppConfig({
    required this.edition,
    this.eventStartsAt,
    this.eventEndsAt,
    this.gameEnabledOverride,
    this.gameGoal = 0,
    this.rewardDescription = '',
    this.rewardPin,
    this.gameTerms = '',
    this.festivalPlanUrl = '',
    this.dataVersion = '',
    this.minAppVersionIos = '',
    this.minAppVersionAndroid = '',
    this.minAppVersionWeb = '',
    this.appStoreUrlIos,
    this.appStoreUrlAndroid,
    this.planBounds = PlanBounds.fallback,
  });
}
