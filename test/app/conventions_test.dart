import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Guards the rule that keeps the look in one place: every colour and every
/// size lives in `lib/app/style.dart`, and a screen that names one of its own
/// fails the build. Both are the kind of thing that makes an app look
/// assembled rather than designed, and both are easy to do by accident and
/// hard to spot in review.
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
      }
    }
    expect(
      offenders,
      isEmpty,
      reason: 'use the theme or context.colors:\n${offenders.join('\n')}',
    );
  });

  test('sizes are named only in style.dart', () {
    const allowed = ['app/style.dart'];
    final offenders = <String>[];
    for (final file in sources) {
      if (allowed.any(file.path.endsWith)) continue;
      final lines = file.readAsLinesSync();
      for (var i = 0; i < lines.length; i++) {
        final line = lines[i];
        if (line.trimLeft().startsWith('//')) continue;
        if (RegExp(
          r'\b(iconSize|minTileHeight|minimumSize|fontSize)\s*:',
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
