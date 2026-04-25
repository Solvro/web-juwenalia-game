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

  /// Optional Material icon name. Overrides [type]'s default icon when set.
  final String? icon;

  /// Pixel coordinates on the festival plan image. Both must be non-null
  /// for the location to render on the plan view; `lat`/`lng` are still
  /// used for the live map. Stored as integers in the CMS.
  final int? planX;
  final int? planY;

  /// When true, the CMS wants this pin excluded from the main map legend
  /// but still reachable via checkpoint mini-maps. Defaults to false for
  /// backwards-compat with pre-migration rows.
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

  /// Whether this location has the pixel coords needed to render on the
  /// plan view.
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

/// Dropdown-choice metadata for the `organisations.role` field. Pulled from
/// Directus so editors can rename/reorder tiers without an app release.
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

  /// Optional external link. When non-empty the card becomes tappable and
  /// opens the URL (e.g. event terms, full article).
  final String? url;

  /// Optional expiry. Items with [expiresAt] in the past are filtered out
  /// in the fetcher so an announcement that ended yesterday doesn't keep
  /// showing up today.
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

  /// URL encoded into the QR shown in the desktop sidebar's download
  /// panel. Empty means "use [appStoreUrlAndroid] as the fallback" so
  /// editors don't have to duplicate the Play link if they don't have a
  /// smart redirector yet.
  final String? downloadQrUrl;

  /// Pitch text shown above the QR in the desktop download panel. Empty
  /// means use the bundled Polish copy so old payloads still render.
  final String? downloadPanelDescription;

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
    this.downloadQrUrl,
    this.downloadPanelDescription,
  });
}
