import 'package:json_annotation/json_annotation.dart';

part 'checkpoint.g.dart';

@JsonSerializable()
class Checkpoint {
  final int id;
  final String title, subtitle, time, location, description, image;
  @JsonKey(defaultValue: 'other')
  final String category;

  Checkpoint({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.time,
    required this.location,
    required this.description,
    required this.image,
    this.category = 'other',
  });

  factory Checkpoint.fromJson(Map<String, dynamic> json) =>
      _$CheckpointFromJson(json);

  Map<String, dynamic> toJson() => _$CheckpointToJson(this);
}
