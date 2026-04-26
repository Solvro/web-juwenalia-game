import 'package:flutter/material.dart';

/// One palette per top-level tab.
enum AppElement { wind, fire, earth, water }

class ElementPalette {
  const ElementPalette({
    required this.base,
    required this.accent,
    required this.gradient,
  });

  final Color base;
  final Color accent;
  final List<Color> gradient;

  LinearGradient get linearGradient => LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: gradient,
  );
}

class AppElements {
  AppElements._();

  static const ElementPalette wind = ElementPalette(
    base: Color(0xFF8B5CF6),
    accent: Color(0xFFA78BFA),
    gradient: [Color(0xFFA78BFA), Color(0xFF8B5CF6), Color(0xFF6366F1)],
  );

  static const ElementPalette fire = ElementPalette(
    base: Color(0xFFF97316),
    accent: Color(0xFFFB923C),
    gradient: [Color(0xFFFB923C), Color(0xFFF97316), Color(0xFFEA580C)],
  );

  static const ElementPalette earth = ElementPalette(
    base: Color(0xFF22C55E),
    accent: Color(0xFF4ADE80),
    gradient: [Color(0xFF4ADE80), Color(0xFF22C55E), Color(0xFF16A34A)],
  );

  static const ElementPalette water = ElementPalette(
    base: Color(0xFF0EA5E9),
    accent: Color(0xFF38BDF8),
    gradient: [Color(0xFF38BDF8), Color(0xFF0EA5E9), Color(0xFF0284C7)],
  );

  static ElementPalette of(AppElement element) {
    switch (element) {
      case AppElement.wind:
        return wind;
      case AppElement.fire:
        return fire;
      case AppElement.earth:
        return earth;
      case AppElement.water:
        return water;
    }
  }
}
