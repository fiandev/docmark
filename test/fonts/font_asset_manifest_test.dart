import 'dart:convert';
import 'dart:io';

import 'package:docmark/src/domain/services/font_registry.dart';
import 'package:flutter_test/flutter_test.dart';

/// The committed manifest that pairs every bundled font path with its licence,
/// upstream source and (once fetched) its SHA-256.
const _manifestAsset = 'assets/fonts/FONT_MANIFEST.json';

Map<String, Object?> _readManifest() {
  final file = File(_manifestAsset);
  expect(
    file.existsSync(),
    isTrue,
    reason: '$_manifestAsset ships with the app',
  );

  return jsonDecode(file.readAsStringSync()) as Map<String, Object?>;
}

List<Map<String, Object?>> _families(Map<String, Object?> manifest) {
  final families = manifest['families']! as List<Object?>;

  return [for (final family in families) family! as Map<String, Object?>];
}

List<Map<String, Object?>> _files(Map<String, Object?> family) {
  final files = family['files']! as List<Object?>;

  return [for (final file in files) file! as Map<String, Object?>];
}

/// Every asset path the app can ask for, straight from the registry.
Set<String> _catalogPaths() => {
  for (final spec in FontRegistry.catalog.values) ...spec.styleFiles.values,
};

Set<String> _manifestPaths(List<Map<String, Object?>> families) => {
  for (final family in families)
    for (final file in _files(family)) file['path']! as String,
};

void main() {
  test('manifest and FontRegistry.catalog declare the same asset paths', () {
    final declared = _manifestPaths(_families(_readManifest()));

    expect(declared, isNotEmpty);
    expect(
      declared,
      _catalogPaths(),
      reason: 'the registry is the contract; the manifest mirrors it',
    );
  });

  test('every manifest family has a licence text and an https upstream', () {
    for (final family in _families(_readManifest())) {
      final token = family['token'];
      final licence = family['license'];
      final licenceFile = family['licenseFile']! as String;
      final project = family['upstreamProject']! as String;
      final notice = family['noticeFile']! as String;

      expect(token, isA<String>());
      expect(
        licence,
        anyOf('OFL-1.1', 'Apache-2.0'),
        reason: '$token must name the licence the shipped text implements',
      );
      expect(
        File(licenceFile).existsSync(),
        isTrue,
        reason: '$token points at a licence file that must exist',
      );
      expect(
        File(notice).existsSync(),
        isTrue,
        reason: '$token points at a per-family notice that must exist',
      );
      expect(
        Uri.parse(project).isScheme('https'),
        isTrue,
        reason: '$token must name an https upstream project',
      );
    }
  });

  test('every manifest file entry is complete', () {
    var entries = 0;

    for (final family in _families(_readManifest())) {
      for (final file in _files(family)) {
        entries++;
        final path = file['path']! as String;
        final face = file['face']! as String;
        final upstreamUrl = file['upstreamUrl']! as String;

        expect(face, isNotEmpty, reason: '$path names its face');
        expect(
          Uri.parse(upstreamUrl).isScheme('https'),
          isTrue,
          reason: '$path must name an https upstream file or archive',
        );
        expect(
          file.containsKey('sha256'),
          isTrue,
          reason: '$path needs the key, null until the fetch pins it',
        );
        final sha = file['sha256'];
        if (sha != null) {
          expect(
            sha,
            matches(RegExp(r'^[0-9a-f]{64}$')),
            reason: '$path carries a lowercase hex SHA-256 or null',
          );
        }
      }
    }

    expect(entries, equals(_catalogPaths().length));
  });

  test('every declared path exists and every bundled face is listed once', () {
    final families = _families(_readManifest());
    final seen = <String>{};

    for (final family in families) {
      final paths = [
        for (final file in _files(family)) file['path']! as String,
      ];

      expect(
        paths.toSet(),
        hasLength(paths.length),
        reason: '${family['token']} lists each face once',
      );

      for (final path in paths) {
        seen.add(path);
        final asset = File(path);
        expect(asset.existsSync(), isTrue, reason: '$path must be committed');
        expect(
          asset.lengthSync(),
          greaterThan(0),
          reason: '$path must not be empty',
        );
      }
    }

    for (final spec in FontRegistry.catalog.values) {
      final family = spec.family;
      if (family == null) {
        expect(
          spec.styleFiles,
          isEmpty,
          reason: 'the system font declares no asset',
        );

        continue;
      }

      final entry = families.where((e) => e['token'] == spec.token.name);

      expect(entry, hasLength(1), reason: '${spec.token.name} appears once');
      expect(
        entry.single['family'],
        family,
        reason: 'the Flutter family name must match the registry',
      );
      expect(
        seen.containsAll(spec.styleFiles.values),
        isTrue,
        reason: '${spec.token.name} declares no path the manifest forgets',
      );
    }
  });

  test(
    'every declared file is a real TrueType/OpenType binary',
    () {
      // TrueType (sfnt 1.0), CFF-flavoured OpenType, and Apple's 'true'.
      const signatures = <List<int>>[
        [0x00, 0x01, 0x00, 0x00],
        [0x4F, 0x54, 0x54, 0x4F],
        [0x74, 0x72, 0x75, 0x65],
      ];

      for (final path in _catalogPaths()) {
        final bytes = File(path).readAsBytesSync();
        expect(
          bytes.length,
          greaterThan(1024),
          reason: '$path is still the committed placeholder text',
        );
        expect(
          signatures.any((s) => _startsWith(bytes, s)),
          isTrue,
          reason: '$path does not start with a font signature',
        );
      }
    },
    skip: 'Placeholder bytes are committed by design. Run '
        '`sh tool/fetch_fonts.sh`, then `sh tool/verify_fonts.sh`, on a '
        'machine with network before shipping. See assets/fonts/README.md.',
  );
}

bool _startsWith(List<int> bytes, List<int> prefix) {
  if (bytes.length < prefix.length) return false;
  for (var i = 0; i < prefix.length; i++) {
    if (bytes[i] != prefix[i]) return false;
  }

  return true;
}
