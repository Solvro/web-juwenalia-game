import 'package:flutter/material.dart';
import 'package:material_symbols_icons/get.dart';
import 'package:material_symbols_icons/symbols.dart';

/// Resolves a CMS-supplied Material Symbols icon name. Falls back to
/// `info_rounded` when the name is unknown.
///
/// Build release bundles with `--no-tree-shake-icons` since the lookup
/// is dynamic.
IconData iconFromName(String name) {
  final n = name.trim();
  if (n.isEmpty || !SymbolsGet.map.containsKey(n)) {
    return Symbols.info_rounded;
  }
  return SymbolsGet.get(n, SymbolStyle.rounded);
}
