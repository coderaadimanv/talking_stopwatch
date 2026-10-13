import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Guards the rule that keeps the look in one place: every colour and every
/// size lives in `lib/app/style.dart`, and a screen that names one of its own
/// fails the build. Both are the kind of thing that makes an app look
/// assembled rather than designed, and both are easy to do by accident and
/// hard to spot in review.
///
/// Since the app gained themes the colour half of this rule carries real
/// weight: a hard-coded colour is no longer merely off-brand, it is a screen
/// that quietly ignores the theme the user chose.
void main() {
  final sources = Directory('lib')
      .listSync(recursive: true)
      .whereType<File>()
      .where((f) => f.path.endsWith('.dart'))
      .toList();

  test('lib has sources to check', () {
    expect(sources, isNotEmpty);
  });

  test('colours are named only in style.dart', () {
    final offenders = <String>[];
    for (final file in sources) {
      if (file.path.endsWith('app/style.dart')) continue;
      final lines = file.readAsLinesSync();
      for (var i = 0; i < lines.length; i++) {
        final line = lines[i];
        if (line.trimLeft().startsWith('//')) continue;
        if (RegExp(r'\bColors\.|\bColor\(0x').hasMatch(line)) {
          offenders.add('${file.path}:${i + 1}  ${line.trim()}');
        }
        // `Brand` is one theme's raw values. A screen that reads it directly
        // looks right in rust and wrong in the other three, silently — which
        // is exactly the bug this rule exists to make impossible. The one
        // exception is `transparent`, which is the absence of a colour and
        // the same in every theme.
        if (RegExp(r'\bBrand\.(?!transparent\b)').hasMatch(line)) {
          offenders.add(
            '${file.path}:${i + 1}  ${line.trim()}   '
            '(use context.colors, which follows the theme)',
          );
        }
      }
    }
    expect(
      offenders,
      isEmpty,
      reason: 'use the theme or context.colors:\n${offenders.join('\n')}',
    );
  });

  test('sizes are numbers only in style.dart', () {
    const allowed = ['app/style.dart'];
    final offenders = <String>[];
    for (final file in sources) {
      if (allowed.any(file.path.endsWith)) continue;
      final lines = file.readAsLinesSync();
      for (var i = 0; i < lines.length; i++) {
        final line = lines[i];
        if (line.trimLeft().startsWith('//')) continue;
        // A literal is the offence, not the property. `iconSize: Sizes.icon`
        // is the rule working; `iconSize: 28` is a size invented on the spot.
        if (RegExp(
          r'\b(iconSize|minTileHeight|minimumSize|fontSize|height|width|size)'
          r'\s*:\s*(const\s+)?(Size\s*\(\s*)?[\d.]+',
        ).hasMatch(line)) {
          offenders.add('${file.path}:${i + 1}  ${line.trim()}');
        }
      }
    }
    expect(
      offenders,
      isEmpty,
      reason: 'add a name to Sizes instead:\n${offenders.join('\n')}',
    );
  });
}
