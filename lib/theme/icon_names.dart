import 'package:flutter/material.dart';

/// Maps Directus `select-icon` string values (Material icon names) to
/// Flutter [IconData] so CMS-driven `important_info.icon` renders as an
/// actual icon instead of literal text.
///
/// Only entries currently used by the CMS are listed. Unknown names
/// fall back to [Icons.info_outline_rounded] so content keeps rendering
/// instead of crashing. Add new entries as CMS usage grows.
const _iconByName = <String, IconData>{
  'water_drop': Icons.water_drop_rounded,
  'dangerous': Icons.dangerous_rounded,
  'badge': Icons.badge_rounded,
  'info': Icons.info_rounded,
  'warning': Icons.warning_rounded,
  'error': Icons.error_rounded,
  'check_circle': Icons.check_circle_rounded,
  'schedule': Icons.schedule_rounded,
  'place': Icons.place_rounded,
  'favorite': Icons.favorite_rounded,
  'star': Icons.star_rounded,
  'local_hospital': Icons.local_hospital_rounded,
  'security': Icons.security_rounded,
  'event': Icons.event_rounded,
  'map': Icons.map_rounded,
  'restaurant': Icons.restaurant_rounded,
  'directions_bus': Icons.directions_bus_rounded,
  'umbrella': Icons.umbrella_rounded,
};

IconData iconFromName(String name) =>
    _iconByName[name.trim()] ?? Icons.info_outline_rounded;
