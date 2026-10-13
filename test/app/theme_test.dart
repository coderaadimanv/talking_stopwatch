import 'dart:math' as math;

import 'package:cadent/app/style.dart';
import 'package:cadent/core/timeline/workout.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// What a theme promises, checked for every theme.
///
/// A theme in this app is not an accent colour. The run screen has to say
/// which phase you are in from across a room, at a glance, while out of
/// breath, and everything written on it has to be readable — so a palette is
/// only allowed to ship if it still does both. Those are measurable, and a
/// pretty set of colours that fails them is a bug, not a taste.
///
/// Two different measures, because they answer two different questions:
///
/// - **Can these two phases be told apart?** That is perceptual colour
///   difference, and the WCAG ratio is the wrong tool for it — two colours
///   can have an identical luminance and still be obviously different hues.
///   So this uses ΔE in CIE L\*a\*b\*, where distance means roughly what the
///   eye means by it.
/// - **Can this text be read on that colour?** That is luminance contrast,
///   and the WCAG ratio is exactly the right tool.
void main() {
  /// Work and rest alternate dozens of times in a session and are the one
  /// pair that is read without being looked at, so they get the high bar.
  /// Mistaking one for the other means carrying on through a rest.
  const minAlternating = 40.0;

  /// Every other pair only has to be visibly a different colour. ΔE 2.3 is the
  /// textbook "just noticeable difference" side by side in good light; this is
  /// eight times it.
  ///
  /// Calibrated against rust, whose closest pair — terracotta work against
  /// rust break, at 19.2 — is the one that has actually been used in a gym and
  /// is distinguished by its badge and its word as much as by its colour. A
  /// new theme has to be at least as separated as the one that works.
  const minDifference = 18.0;

  /// WCAG AA for small text. The dial's face carries "Round 1 of 8" and the
  /// chip under it, which are not large by anybody's definition.
  const minReadableSmall = 4.5;

  /// WCAG AA for large text, which is what a phase colour ever carries: the
  /// countdown, a badge icon, and three short bold control labels.
  const minReadableLarge = 3.0;

  const kinds = SegmentKind.values;

  test('there are themes to check, and rust is the default', () {
    expect(AppColors.themes, isNotEmpty);
    expect(AppColors.themes.first, same(AppColors.rust));
    expect(AppColors.byId(null), same(AppColors.rust));
    expect(AppColors.byId('nothing-like-it'), same(AppColors.rust));
    expect(
      AppColors.themes.map((t) => t.id).toSet(),
      hasLength(AppColors.themes.length),
      reason: 'two themes share an id, so one of them can never be chosen',
    );
  });

  for (final theme in AppColors.themes) {
    group(theme.name, () {
      test('work and rest are never mistaken for each other', () {
        expect(
          _difference(theme.work, theme.rest),
          greaterThanOrEqualTo(minAlternating),
          reason: 'the two phases that alternate all session look alike',
        );
      });

      test('every pair of phases is visibly a different colour', () {
        final tooClose = <String>[];
        for (var i = 0; i < kinds.length; i++) {
          for (var j = i + 1; j < kinds.length; j++) {
            final difference = _difference(
              theme.phase(kinds[i]),
              theme.phase(kinds[j]),
            );
            if (difference < minDifference) {
              tooClose.add(
                '${kinds[i].name} vs ${kinds[j].name}: '
                'ΔE ${difference.toStringAsFixed(1)}',
              );
            }
          }
        }
        expect(
          tooClose,
          isEmpty,
          reason:
              'these phases look alike at a glance, which is the one thing '
              'the run screen may not do:\n${tooClose.join('\n')}',
        );
      });

      test('everything written on a phase can be read', () {
        for (final kind in kinds) {
          final ground = theme.phase(kind);
          expect(
            contrastBetween(ground, theme.onPhase(kind)),
            greaterThanOrEqualTo(minReadableLarge),
            reason: 'text on ${kind.name}',
          );
          // The arc and the primary control, which carry an icon and a label.
          expect(
            contrastBetween(theme.phaseDeep(kind), theme.onPhaseDeep(kind)),
            greaterThanOrEqualTo(minReadableLarge),
            reason: 'the deeper cut of ${kind.name}',
          );
          // The dial's face is the one place small text sits on a phase.
          expect(
            contrastBetween(
              theme.phaseFace(kind),
              theme.readableOn(theme.phaseFace(kind)),
            ),
            greaterThanOrEqualTo(minReadableSmall),
            reason: 'the dial face on ${kind.name}',
          );
        }
      });

      test('everything written on the dark screens can be read', () {
        // Primary text goes everywhere, including on a raised control.
        for (final surface in [theme.ground, theme.surface, theme.raised]) {
          expect(
            contrastBetween(surface, theme.onGround),
            greaterThanOrEqualTo(minReadableSmall),
            reason: 'primary text',
          );
        }
        // Secondary text and warnings only ever sit on the page or on a card.
        for (final surface in [theme.ground, theme.surface]) {
          expect(
            contrastBetween(surface, theme.muted),
            greaterThanOrEqualTo(minReadableLarge),
            reason:
                'secondary text, which is allowed to be quieter but not '
                'invisible',
          );
          expect(
            contrastBetween(surface, theme.danger),
            greaterThanOrEqualTo(minReadableLarge),
            reason: 'a warning nobody can see is not a warning',
          );
        }
      });

      test('the arc is visible on the dial it is drawn around', () {
        // Not the dial against its ground: on a pale phase like prepare those
        // are deliberately close, and what separates them is the shadow under
        // the disc rather than any difference in colour. The arc has no
        // shadow, so it has only its colour to be seen by.
        for (final kind in kinds) {
          expect(
            _difference(theme.phaseFace(kind), theme.phaseDeep(kind)),
            greaterThanOrEqualTo(minDifference),
            reason: 'the arc disappears into the dial on ${kind.name}',
          );
        }
      });

      test('a hairline and a wash are still visible on the ground', () {
        // The quietest marks in the app, and the first casualties of a new
        // palette: a border that has become invisible breaks no test that
        // only looks at text.
        expect(
          contrastBetween(theme.ground, theme.line),
          greaterThanOrEqualTo(1.4),
          reason: 'hairlines have vanished into the page',
        );
        expect(
          _difference(
            theme.surface,
            Color.alphaBlend(theme.accentWash, theme.surface),
          ),
          greaterThanOrEqualTo(3.0),
          reason: 'the wash behind a section icon has vanished into its card',
        );
      });
    });
  }
}

/// Perceptual distance between two colours: ΔE in CIE L\*a\*b\* (CIE76).
///
/// Plain Euclidean distance in Lab. The later ΔE formulas are more accurate
/// about small differences, and small differences are exactly what this test
/// does not care about — the threshold here is ten times the size at which
/// they start to disagree.
double _difference(Color a, Color b) {
  final first = _lab(a);
  final second = _lab(b);
  return math.sqrt(
    math.pow(first.$1 - second.$1, 2) +
        math.pow(first.$2 - second.$2, 2) +
        math.pow(first.$3 - second.$3, 2),
  );
}

/// sRGB to CIE L\*a\*b\*, through linear RGB and XYZ, against D65.
(double, double, double) _lab(Color color) {
  double linear(double channel) => channel <= 0.04045
      ? channel / 12.92
      : math.pow((channel + 0.055) / 1.055, 2.4).toDouble();

  final r = linear(color.r);
  final g = linear(color.g);
  final b = linear(color.b);

  // D65 white point, normalised so white lands on (100, 0, 0).
  final x = (r * 0.4124 + g * 0.3576 + b * 0.1805) / 0.95047;
  final y = (r * 0.2126 + g * 0.7152 + b * 0.0722) / 1.00000;
  final z = (r * 0.0193 + g * 0.1192 + b * 0.9505) / 1.08883;

  double f(double t) => t > 0.008856
      ? math.pow(t, 1 / 3).toDouble()
      : (7.787 * t) + (16 / 116);

  final fx = f(x);
  final fy = f(y);
  final fz = f(z);

  return (116 * fy - 16, 500 * (fx - fy), 200 * (fy - fz));
}
