// Build-time helper: pulls the latest data.json from the canonical remote
// source and writes it into assets/data/data.json so the bundled-asset
// fallback (used when the user is offline on first launch) is fresh.
//
// Run before any release build:
//
//     dart run tool/sync_data.dart
//
// Recommended: wire this into your CI / fastlane / `flutter build` script
// so every shipped binary contains a snapshot of the data taken at build
// time. Local builds can be left to fetch on first launch.
//
// This script is intentionally dependency-free (no pub deps) so it works
// from a clean checkout without `pub get`.

import 'dart:convert';
import 'dart:io';

const _remoteUrl =
    'https://raw.githubusercontent.com/Antoni-Czaplicki/web-juwenalia-game/main/data/data.json';
const _outputPath = 'assets/data/data.json';

Future<void> main(List<String> args) async {
  final url = args.isNotEmpty ? args.first : _remoteUrl;

  stdout.writeln('▸ Fetching $url');

  final client = HttpClient();
  client.connectionTimeout = const Duration(seconds: 15);

  try {
    final req = await client.getUrl(Uri.parse(url));
    final res = await req.close();

    if (res.statusCode != 200) {
      stderr.writeln(
        '✖ Remote returned HTTP ${res.statusCode}. '
        'Keeping existing $_outputPath in place.',
      );
      exit(1);
    }

    final body = await res.transform(utf8.decoder).join();

    // Sanity check: must be valid JSON with the expected top-level shape.
    Map<String, dynamic> parsed;
    try {
      parsed = jsonDecode(body) as Map<String, dynamic>;
    } catch (e) {
      stderr.writeln('✖ Remote payload is not valid JSON: $e');
      exit(2);
    }

    if (parsed['checkpoints'] is! List) {
      stderr.writeln(
        '✖ Remote payload is missing required `checkpoints` array — refusing '
        'to overwrite $_outputPath.',
      );
      exit(3);
    }

    final outFile = File(_outputPath);
    await outFile.parent.create(recursive: true);
    // Pretty-print so the diff in source control is readable.
    final encoder = const JsonEncoder.withIndent('  ');
    await outFile.writeAsString('${encoder.convert(parsed)}\n');

    final version = parsed['version'];
    final cpCount = (parsed['checkpoints'] as List).length;
    stdout.writeln(
      '✓ Wrote $_outputPath (version=$version, $cpCount checkpoints).',
    );
  } on SocketException catch (e) {
    stderr.writeln(
      '✖ Network error: ${e.message}. '
      'Keeping existing $_outputPath in place.',
    );
    exit(4);
  } finally {
    client.close(force: true);
  }
}
