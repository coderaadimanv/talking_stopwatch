import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Guards the two house rules that are easy to break by accident and hard to
/// spot in review: a colour named in a widget, and a screen inventing its own
/// sizes. Both are the kind of thing that makes an app look assembled rather
/// than designed.
void main() {
  final sources = Directory('lib')
      .listSync(recursive: true)
      .whereType<File>()
      .where((f) => f.path.endsWith('.dart'))
      .toList();

  test('lib has sources to check', () {
    expect(sources, isNotEmpty);
  });

  test('colours are named only in palette.dart', () {
    final offenders = <String>[];
    for (final file in sources) {
      if (file.path.endsWith('app/palette.dart')) continue;
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

  test('sizes are named only in sizes.dart and the theme', () {
    const allowed = ['app/sizes.dart', 'app/app.dart'];
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
