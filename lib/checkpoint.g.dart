// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'checkpoint.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

Checkpoint _$CheckpointFromJson(Map<String, dynamic> json) => Checkpoint(
  id: (json['id'] as num).toInt(),
  title: json['title'] as String,
  subtitle: json['subtitle'] as String,
  time: json['time'] as String,
  location: json['location'] as String,
  description: json['description'] as String,
  image: json['image'] as String,
  category: json['category'] as String? ?? 'other',
);

Map<String, dynamic> _$CheckpointToJson(Checkpoint instance) =>
    <String, dynamic>{
      'id': instance.id,
      'title': instance.title,
      'subtitle': instance.subtitle,
      'time': instance.time,
      'location': instance.location,
      'description': instance.description,
      'image': instance.image,
      'category': instance.category,
    };
