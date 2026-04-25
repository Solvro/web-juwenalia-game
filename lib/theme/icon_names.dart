import 'package:flutter/material.dart';
import 'package:material_symbols_icons/get.dart';
import 'package:material_symbols_icons/symbols.dart';

/// Resolves a Directus `select-icon` value (Material Symbols icon name)
/// to an [IconData] using the `material_symbols_icons` package — covers
/// every icon in Google's Material Symbols catalog (~4200) so any icon
/// chosen in the CMS renders without code changes.
///
/// Defaults to the rounded style to match the rest of the app's visual
/// language. Falls back to a neutral info icon when the name is unknown.
///
/// **Build note:** because lookup is dynamic, Flutter's icon tree-shaker
/// can't prove which icons are used. Build release bundles with
/// `--no-tree-shake-icons` to keep the full font glyph set.
IconData iconFromName(String name) {
  final n = name.trim();
  if (n.isEmpty || !SymbolsGet.map.containsKey(n)) {
    return Symbols.info_rounded;
  }
  return SymbolsGet.get(n, SymbolStyle.rounded);
}
