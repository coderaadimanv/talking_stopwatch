import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../core/timeline/workout.dart';

/// **Everything about how this app looks lives in this file.**
///
/// Colours, sizes, shapes, type and the theme itself. Change a value here and
/// it changes everywhere; no screen names a colour or a size of its own, and
/// `test/app/conventions_test.dart` fails the build if one starts to.
///
/// The palette is Anvil Lab Studio's: ink and ivory, a terracotta accent, taupe
/// for everything quiet, and a 2px radius that is almost but not quite square.

// ---------------------------------------------------------------------------
// The brand
// ---------------------------------------------------------------------------

/// The five colours everything else is mixed from.
abstract final class Brand {
  static const ink = Color(0xFF171513);
  static const ivory = Color(0xFFF4EFE7);
  static const rust = Color(0xFFA8431E);
  static const terracotta = Color(0xFFD97745);
  static const taupe = Color(0xFF8C7A6B);

  /// Taupe laid over ink at the proportions the brand's dark surface uses.
  static const surface = Color(0xFF25211E); // 12% taupe
  static const raised = Color(0xFF3F3731); //  34% taupe
  static const line = Color(0xFF544A41); //   52% taupe
}

/// The colour of each phase on the run screen.
///
/// This is the one place the brand could not simply be copied. A run screen has
/// to say which phase you are in from across a room, at a glance, while out of
/// breath — so the five phases have to be told apart instantly. The brand is
/// essentially one warm hue, and terracotta against rust against taupe is not
/// enough separation for that job.
///
/// So four of the five are the brand's own, and [rest] is a single muted teal,
/// chosen as terracotta's complement so it still belongs to the palette. If it
/// ever looks wrong, it is one line, here.
abstract final class Phases {
  /// Pale sand: get ready, not yet.
  static const prepare = Color(0xFFE8C9A0);

  /// Terracotta: the brand's accent, and the phase that matters.
  static const work = Brand.terracotta;

  /// The one colour not from the brand, and the reason is legibility.
  static const rest = Color(0xFF6E9A91);

  /// Rust: a longer pause than rest, and visibly deeper.
  static const breakBetween = Brand.rust;

  static const cooldown = Brand.taupe;
}

// ---------------------------------------------------------------------------
// Sizes and shapes
// ---------------------------------------------------------------------------

/// Every named size in the app.
///
/// This screen is read at arm's length, mid-set, by someone out of breath, and
/// tapped with a thumb rather than a fingertip. So the numbers are larger than
/// a normal app's, and they are kept together where they can be judged as a set
/// instead of being invented one screen at a time.
abstract final class Sizes {
  /// Minimum tap target. Larger than Material's 48 on purpose: these controls
  /// get hit while moving.
  static const control = 56.0;

  /// The primary action — start, pause — sized to be hit without looking.
  static const bigControl = 96.0;

  /// A row in a list of presets or rounds.
  static const row = 64.0;

  static const gutter = 16.0;
  static const gap = 12.0;
  static const bigGap = 24.0;

  /// The remaining-seconds display: the one thing readable across a gym.
  static const countdownText = 140.0;

  /// The phase name above the countdown.
  static const phaseText = 32.0;

  static const icon = 24.0;
  static const bigIcon = 32.0;

  /// Almost square. The brand's radius is 2px and it is most of its character:
  /// rounder corners make this a different app.
  static const radius = 2.0;

  static const hairline = 1.0;
}

/// Letter-spacing, from the brand's own type rules: headings pulled tight,
/// small labels opened right up.
abstract final class Tracking {
  static const tight = -0.5;
  static const display = -4.0;
  static const normal = 0.0;

  /// Wide-tracked uppercase, the brand's signature for anything small.
  static const wide = 1.6;
  static const wider = 2.4;
}

// ---------------------------------------------------------------------------
// Semantic colours
// ---------------------------------------------------------------------------

/// What a screen actually asks for: not "terracotta" but "the colour of work".
@immutable
class AppColors extends ThemeExtension<AppColors> {
  const AppColors({
    required this.prepare,
    required this.work,
    required this.rest,
    required this.breakBetween,
    required this.cooldown,
    required this.muted,
    required this.line,
    required this.danger,
  });

  static const dark = AppColors(
    prepare: Phases.prepare,
    work: Phases.work,
    rest: Phases.rest,
    breakBetween: Phases.breakBetween,
    cooldown: Phases.cooldown,
    muted: Brand.taupe,
    line: Brand.line,
    danger: Brand.rust,
  );

  final Color prepare;
  final Color work;
  final Color rest;
  final Color breakBetween;
  final Color cooldown;

  /// Secondary text: readable, but never competing with the number.
  final Color muted;

  /// Hairlines, borders and dividers.
  final Color line;

  final Color danger;

  /// The colour the whole run screen takes while [kind] is running.
  Color phase(SegmentKind kind) => switch (kind) {
    SegmentKind.prepare => prepare,
    SegmentKind.work => work,
    SegmentKind.rest => rest,
    SegmentKind.breakBetween => breakBetween,
    SegmentKind.cooldown => cooldown,
  };

  /// What to draw on top of a phase colour.
  ///
  /// Worked out rather than written down: whichever of ink and ivory has more
  /// contrast against that phase wins. Pale sand takes ink and deep rust takes
  /// ivory without anyone having to remember which, and a change to a phase
  /// colour can never leave unreadable text behind it.
  Color onPhase(SegmentKind kind) => _readableOn(phase(kind));

  @override
  AppColors copyWith({
    Color? prepare,
    Color? work,
    Color? rest,
    Color? breakBetween,
    Color? cooldown,
    Color? muted,
    Color? line,
    Color? danger,
  }) => AppColors(
    prepare: prepare ?? this.prepare,
    work: work ?? this.work,
    rest: rest ?? this.rest,
    breakBetween: breakBetween ?? this.breakBetween,
    cooldown: cooldown ?? this.cooldown,
    muted: muted ?? this.muted,
    line: line ?? this.line,
    danger: danger ?? this.danger,
  );

  @override
  AppColors lerp(AppColors? other, double t) {
    if (other == null) return this;
    return AppColors(
      prepare: Color.lerp(prepare, other.prepare, t)!,
      work: Color.lerp(work, other.work, t)!,
      rest: Color.lerp(rest, other.rest, t)!,
      breakBetween: Color.lerp(breakBetween, other.breakBetween, t)!,
      cooldown: Color.lerp(cooldown, other.cooldown, t)!,
      muted: Color.lerp(muted, other.muted, t)!,
      line: Color.lerp(line, other.line, t)!,
      danger: Color.lerp(danger, other.danger, t)!,
    );
  }
}

/// Ink or ivory, whichever can actually be read on [background].
Color _readableOn(Color background) =>
    _contrast(background, Brand.ink) >= _contrast(background, Brand.ivory)
    ? Brand.ink
    : Brand.ivory;

/// WCAG contrast ratio, which is the only honest way to make this choice.
double _contrast(Color a, Color b) {
  final first = a.computeLuminance();
  final second = b.computeLuminance();
  return (math.max(first, second) + 0.05) / (math.min(first, second) + 0.05);
}

extension ColorsOf on BuildContext {
  AppColors get colors => Theme.of(this).extension<AppColors>()!;
}

/// A button's label, which shrinks rather than wraps.
///
/// Three buttons across a 320dp phone leave about 62 logical pixels for text,
/// and "Reset" wants 76 — so it wrapped to "Re / set", which is not an
/// overflow and therefore throws nothing and looks like a design choice. The
/// same thing happens on any phone once the owner turns their system font up,
/// which no amount of tuning the type size here would survive.
///
/// So the label is told never to wrap, and scaled down on the rare screen too
/// narrow to hold it. Nothing changes at ordinary sizes.
class ActionLabel extends StatelessWidget {
  const ActionLabel(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) => FittedBox(
    fit: BoxFit.scaleDown,
    child: Text(text, maxLines: 1, softWrap: false),
  );
}

// ---------------------------------------------------------------------------
// The theme
// ---------------------------------------------------------------------------

const _shape = RoundedRectangleBorder(
  borderRadius: BorderRadius.all(Radius.circular(Sizes.radius)),
);

/// The app's theme. Dark, because this screen is looked at in a gym at six in
/// the morning and is mostly one enormous number.
ThemeData appTheme() {
  const scheme = ColorScheme.dark(
    primary: Brand.terracotta,
    onPrimary: Brand.ink,
    secondary: Brand.taupe,
    onSecondary: Brand.ink,
    // The quiet filled surface behind a tonal icon button. Raised enough to
    // find on both the page and a card, far short of competing with them:
    // a row of solid taupe blocks reads as the loudest thing on the screen,
    // which a minus sign should never be.
    secondaryContainer: Brand.raised,
    onSecondaryContainer: Brand.ivory,
    surface: Brand.ink,
    onSurface: Brand.ivory,
    surfaceContainer: Brand.surface,
    surfaceContainerHighest: Brand.raised,
    outline: Brand.line,
    outlineVariant: Brand.surface,
    error: Brand.rust,
    onError: Brand.ivory,
  );

  final base = ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    colorScheme: scheme,
    scaffoldBackgroundColor: Brand.ink,
    extensions: const [AppColors.dark],
  );

  return base.copyWith(
    textTheme: _textTheme(base.textTheme),

    appBarTheme: const AppBarTheme(
      backgroundColor: Brand.ink,
      foregroundColor: Brand.ivory,
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: false,
    ),

    // Flat and square. The brand has no shadows in it, and a drop shadow is
    // the quickest way to make a deliberate design look like a default one.
    filledButtonTheme: FilledButtonThemeData(style: _filled()),
    elevatedButtonTheme: ElevatedButtonThemeData(style: _filled()),
    outlinedButtonTheme: OutlinedButtonThemeData(style: _outlined()),
    textButtonTheme: TextButtonThemeData(style: _text()),
    iconButtonTheme: IconButtonThemeData(style: _icon()),

    cardTheme: const CardThemeData(
      color: Brand.surface,
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.all(Radius.circular(Sizes.radius)),
        side: BorderSide(color: Brand.line, width: Sizes.hairline),
      ),
    ),

    dividerTheme: const DividerThemeData(
      color: Brand.line,
      thickness: Sizes.hairline,
      space: Sizes.bigGap,
    ),

    iconTheme: const IconThemeData(size: Sizes.icon, color: Brand.ivory),

    listTileTheme: const ListTileThemeData(
      minTileHeight: Sizes.row,
      contentPadding: EdgeInsets.symmetric(horizontal: Sizes.gutter),
      titleTextStyle: TextStyle(
        color: Brand.ivory,
        fontSize: 16,
        fontWeight: FontWeight.w500,
      ),
      subtitleTextStyle: TextStyle(color: Brand.taupe, fontSize: 13),
      iconColor: Brand.taupe,
    ),

    inputDecorationTheme: const InputDecorationThemeData(
      border: UnderlineInputBorder(
        borderSide: BorderSide(color: Brand.line, width: Sizes.hairline),
      ),
      enabledBorder: UnderlineInputBorder(
        borderSide: BorderSide(color: Brand.line, width: Sizes.hairline),
      ),
      focusedBorder: UnderlineInputBorder(
        borderSide: BorderSide(color: Brand.terracotta, width: 2),
      ),
      labelStyle: TextStyle(color: Brand.taupe),
      floatingLabelStyle: TextStyle(color: Brand.terracotta),
      hintStyle: TextStyle(color: Brand.taupe),
    ),

    switchTheme: SwitchThemeData(
      thumbColor: WidgetStateProperty.resolveWith(
        (states) => states.contains(WidgetState.selected)
            ? Brand.ink
            : Brand.taupe,
      ),
      trackColor: WidgetStateProperty.resolveWith(
        (states) => states.contains(WidgetState.selected)
            ? Brand.terracotta
            : Brand.surface,
      ),
      trackOutlineColor: const WidgetStatePropertyAll(Brand.line),
    ),

    sliderTheme: const SliderThemeData(
      activeTrackColor: Brand.terracotta,
      inactiveTrackColor: Brand.raised,
      thumbColor: Brand.terracotta,
      overlayColor: Color(0x33D97745),
    ),

    segmentedButtonTheme: SegmentedButtonThemeData(
      style: ButtonStyle(
        backgroundColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected)
              ? Brand.terracotta
              : Colors.transparent,
        ),
        foregroundColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected)
              ? Brand.ink
              : Brand.ivory,
        ),
        side: const WidgetStatePropertyAll(
          BorderSide(color: Brand.line, width: Sizes.hairline),
        ),
        shape: const WidgetStatePropertyAll(_shape),
        textStyle: const WidgetStatePropertyAll(
          TextStyle(fontWeight: FontWeight.w500, letterSpacing: Tracking.wide),
        ),
      ),
    ),

    floatingActionButtonTheme: const FloatingActionButtonThemeData(
      backgroundColor: Brand.terracotta,
      foregroundColor: Brand.ink,
      elevation: 0,
      focusElevation: 0,
      hoverElevation: 0,
      highlightElevation: 0,
      shape: _shape,
      extendedTextStyle: TextStyle(
        fontWeight: FontWeight.w600,
        letterSpacing: Tracking.wide,
      ),
    ),
  );
}

/// The primary action: solid terracotta, ink on top, no shadow, square edges.
ButtonStyle _filled() => ButtonStyle(
  backgroundColor: WidgetStateProperty.resolveWith(
    (states) => states.contains(WidgetState.disabled)
        ? Brand.raised
        : states.contains(WidgetState.pressed)
        ? Brand.rust
        : Brand.terracotta,
  ),
  foregroundColor: WidgetStateProperty.resolveWith(
    (states) =>
        states.contains(WidgetState.disabled) ? Brand.taupe : Brand.ink,
  ),
  overlayColor: const WidgetStatePropertyAll(Color(0x1A171513)),
  elevation: const WidgetStatePropertyAll(0),
  shadowColor: const WidgetStatePropertyAll(Colors.transparent),
  minimumSize: const WidgetStatePropertyAll(
    Size(Sizes.control, Sizes.control),
  ),
  padding: const WidgetStatePropertyAll(
    EdgeInsets.symmetric(horizontal: Sizes.gap),
  ),
  shape: const WidgetStatePropertyAll(_shape),
  textStyle: const WidgetStatePropertyAll(_actionText),
  iconSize: const WidgetStatePropertyAll(Sizes.bigIcon),
);

/// The secondary action: a hairline and nothing else, until you touch it.
ButtonStyle _outlined() => ButtonStyle(
  backgroundColor: WidgetStateProperty.resolveWith(
    (states) => states.contains(WidgetState.pressed)
        ? Brand.surface
        : Colors.transparent,
  ),
  foregroundColor: WidgetStateProperty.resolveWith(
    (states) =>
        states.contains(WidgetState.disabled) ? Brand.raised : Brand.ivory,
  ),
  side: WidgetStateProperty.resolveWith(
    (states) => BorderSide(
      color: states.contains(WidgetState.disabled)
          ? Brand.raised
          : states.contains(WidgetState.pressed)
          ? Brand.terracotta
          : Brand.line,
      width: Sizes.hairline,
    ),
  ),
  overlayColor: const WidgetStatePropertyAll(Color(0x14F4EFE7)),
  minimumSize: const WidgetStatePropertyAll(
    Size(Sizes.control, Sizes.control),
  ),
  padding: const WidgetStatePropertyAll(
    EdgeInsets.symmetric(horizontal: Sizes.gap),
  ),
  shape: const WidgetStatePropertyAll(_shape),
  textStyle: const WidgetStatePropertyAll(_actionText),
  iconSize: const WidgetStatePropertyAll(Sizes.icon),
);

/// The quiet one: terracotta text, no box at all.
ButtonStyle _text() => ButtonStyle(
  foregroundColor: WidgetStateProperty.resolveWith(
    (states) => states.contains(WidgetState.disabled)
        ? Brand.raised
        : Brand.terracotta,
  ),
  overlayColor: const WidgetStatePropertyAll(Color(0x1AD97745)),
  minimumSize: const WidgetStatePropertyAll(
    Size(Sizes.control, Sizes.control),
  ),
  shape: const WidgetStatePropertyAll(_shape),
  textStyle: const WidgetStatePropertyAll(_actionText),
);

ButtonStyle _icon() => ButtonStyle(
  foregroundColor: WidgetStateProperty.resolveWith(
    (states) =>
        states.contains(WidgetState.disabled) ? Brand.raised : Brand.ivory,
  ),
  overlayColor: const WidgetStatePropertyAll(Color(0x14F4EFE7)),
  shape: const WidgetStatePropertyAll(_shape),
  iconSize: const WidgetStatePropertyAll(Sizes.icon),
);

/// Buttons speak in the brand's small voice: medium weight, opened up.
///
/// 14 rather than 15, and tracked a little less than the headings. Wide
/// tracking costs real width, and three buttons in a row on a 320dp phone do
/// not have it to spare — at 15/1.6 "Reset" wrapped to "Re / set".
const _actionText = TextStyle(
  fontSize: 14,
  fontWeight: FontWeight.w600,
  letterSpacing: 1.2,
);

TextTheme _textTheme(TextTheme base) => base.copyWith(
  // The countdown. Thin and enormous, pulled tight so the digits sit together
  // rather than drifting apart at 140 points.
  displayLarge: base.displayLarge?.copyWith(
    fontSize: Sizes.countdownText,
    fontWeight: FontWeight.w200,
    letterSpacing: Tracking.display,
    height: 1,
    color: Brand.ivory,
  ),
  headlineLarge: base.headlineLarge?.copyWith(
    fontSize: Sizes.phaseText,
    fontWeight: FontWeight.w600,
    letterSpacing: Tracking.wide,
    color: Brand.ivory,
  ),
  headlineSmall: base.headlineSmall?.copyWith(
    fontWeight: FontWeight.w500,
    letterSpacing: Tracking.tight,
    color: Brand.ivory,
  ),
  titleLarge: base.titleLarge?.copyWith(
    fontWeight: FontWeight.w500,
    letterSpacing: Tracking.tight,
    color: Brand.ivory,
  ),
  titleMedium: base.titleMedium?.copyWith(
    fontWeight: FontWeight.w500,
    color: Brand.ivory,
  ),
  bodyLarge: base.bodyLarge?.copyWith(color: Brand.ivory),
  bodyMedium: base.bodyMedium?.copyWith(color: Brand.taupe),
  bodySmall: base.bodySmall?.copyWith(color: Brand.taupe),
  // Section headings, set the way the brand sets them: small, uppercase and
  // widely tracked.
  labelLarge: base.labelLarge?.copyWith(
    fontWeight: FontWeight.w600,
    letterSpacing: Tracking.wider,
    color: Brand.taupe,
  ),
  labelMedium: base.labelMedium?.copyWith(
    fontWeight: FontWeight.w600,
    letterSpacing: Tracking.wide,
    color: Brand.taupe,
  ),
);
