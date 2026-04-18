// Additional data models for the Juwenalia PWR app.
// Checkpoint model remains in checkpoint.dart (uses json_annotation).

class NewsItem {
  final String id;
  final String title;
  final String body;
  final String category;
  final DateTime date;

  const NewsItem({
    required this.id,
    required this.title,
    required this.body,
    required this.category,
    required this.date,
  });

  factory NewsItem.fromJson(Map<String, dynamic> json) => NewsItem(
    id: json['id'] as String,
    title: json['title'] as String,
    body: json['body'] as String,
    category: (json['category'] as String?) ?? 'general',
    date: DateTime.parse(json['date'] as String),
  );
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

  factory ScheduleDay.fromJson(Map<String, dynamic> json) => ScheduleDay(
    label: json['label'] as String,
    venue: json['venue'] as String,
    events: (json['events'] as List)
        .cast<Map<String, dynamic>>()
        .map(ScheduleEvent.fromJson)
        .toList(),
  );
}

class ScheduleEvent {
  final String id;
  final String artist;
  final String genre;
  final String stage;
  final String time;
  final String imageUrl;

  const ScheduleEvent({
    required this.id,
    required this.artist,
    required this.genre,
    required this.stage,
    required this.time,
    required this.imageUrl,
  });

  factory ScheduleEvent.fromJson(Map<String, dynamic> json) => ScheduleEvent(
    id: json['id'] as String,
    artist: json['artist'] as String,
    genre: (json['genre'] as String?) ?? '',
    stage: (json['stage'] as String?) ?? '',
    time: (json['time'] as String?) ?? '',
    imageUrl: (json['image_url'] as String?) ?? '',
  );
}

class MapPoint {
  final String id;
  final String name;
  final String type;
  final String? description;
  final double? lat;
  final double? lng;

  const MapPoint({
    required this.id,
    required this.name,
    required this.type,
    this.description,
    this.lat,
    this.lng,
  });

  factory MapPoint.fromJson(Map<String, dynamic> json) => MapPoint(
    id: json['id'] as String,
    name: json['name'] as String,
    type: json['type'] as String,
    description: json['description'] as String?,
    lat: (json['lat'] as num?)?.toDouble(),
    lng: (json['lng'] as num?)?.toDouble(),
  );
}

class Partner {
  final String id;
  final String name;
  final String tier; // 'main', 'media'
  final String? logoUrl;

  const Partner({
    required this.id,
    required this.name,
    required this.tier,
    this.logoUrl,
  });

  factory Partner.fromJson(Map<String, dynamic> json) => Partner(
    id: json['id'] as String,
    name: json['name'] as String,
    tier: (json['tier'] as String?) ?? 'media',
    logoUrl: json['logo_url'] as String?,
  );
}
