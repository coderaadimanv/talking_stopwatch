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

/// The five colours the app's own palette is mixed from.
///
/// These are the *rust* theme's raw values and nothing more. Screens never
/// read them — they read [AppColors], which is what changes when the user
/// picks another theme, and `test/app/conventions_test.dart` fails the build
/// if one starts to. The only member here that is not a palette colour is
/// [transparent], which is the absence of one.
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

  static const transparent = Color(0x00000000);
}

/// The one place the app is allowed a shadow.
///
/// The brand is flat, and most of this app still is: buttons in a form, cards,
/// list rows. The running screen is the exception. It is read at a glance from
/// a distance, and lifting the dial and the primary control off the ground is
/// what separates them from it at that distance.
abstract final class Shadows {
  /// Under the dial: wide, soft and low-contrast.
  static const dial = [
    BoxShadow(color: Color(0x26000000), blurRadius: 28, offset: Offset(0, 10)),
  ];

  /// Under the primary control: tighter, so it reads as pressable.
  static const control = [
    BoxShadow(color: Color(0x33000000), blurRadius: 14, offset: Offset(0, 6)),
  ];

  /// Light spilling out of something, rather than a shadow falling under it.
  /// Only for the one action a screen is really offering.
  static List<BoxShadow> glow(Color color) => [
    BoxShadow(
      color: color.withValues(alpha: 0.38),
      blurRadius: 26,
      offset: const Offset(0, 8),
    ),
  ];
}

/// Why the phase colours are chosen the way they are, in every theme.
///
/// A run screen has to say which phase you are in from across a room, at a
/// glance, while out of breath — so the five phases have to be told apart
/// instantly. That is a harder constraint than it sounds: the app's own brand
/// is essentially one warm hue, and terracotta against rust against taupe is
/// not enough separation for the job. Every theme in [AppColors] therefore
/// spends its five phase colours on *separation first* and prettiness second,
/// and `test/app/theme_test.dart` fails the build for a theme that does not.
///
/// This is also why the themes are a short list of designed sets rather than a
/// colour picker. A picker would let someone build a run screen they cannot
/// read, which is the one thing this screen may never be.

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

  /// The app's name on home.
  static const wordmarkText = 40.0;

  static const iconSmall = 20.0;
  static const icon = 24.0;
  static const bigIcon = 32.0;

  // --- the running screen -------------------------------------------------

  /// The dial grows with the screen, up to this.
  static const dialMax = 320.0;

  /// How much of the screen's width the dial may take.
  static const dialFraction = 0.80;

  /// The progress arc around the dial.
  static const dialStroke = 14.0;

  /// The countdown inside the dial, as a share of the dial's width. Scaled
  /// rather than fixed, so it stays right on a small phone and a large one.
  static const dialTextFraction = 0.26;

  /// The circular badge above the phase name.
  static const badge = 72.0;

  /// The same badge in a list row.
  static const badgeSmall = 56.0;

  /// And beside a section heading, where it must not outweigh the words.
  static const badgeTiny = 44.0;

  /// The round controls at the foot of the running screen.
  static const circleControl = 64.0;
  static const circleControlBig = 88.0;

  /// The ring on a preset card, and the one on the screen before a session
  /// starts. Thinner than the dial's: it is read at arm's length rather than
  /// across a room, and the dial's weight at this size is a doughnut.
  static const ringStroke = 5.0;

  /// The ring on a card, which has to hold a total like "2:10:00".
  static const ringSmall = 76.0;

  /// A dot in the round tracker.
  static const dot = 10.0;

  /// The marks around the ring on the screen before a workout starts.
  static const tick = 9.0;
  static const tickMajor = 15.0;
  static const tickWidth = 2.0;

  /// A pill-shaped action.
  static const pill = 60.0;

  /// The small icon inside a chip.
  static const chipIcon = 16.0;

  /// Beyond this many rounds the dots become a bar: forty dots say nothing.
  static const maxDots = 12;

  /// The corner on every button, card and control.
  ///
  /// The brand's own radius is 2px, which is right for an editorial website
  /// and read as hard-edged on a phone, where the controls are large and sit
  /// under a thumb. Softened here, and deliberately one number: change this
  /// and the whole app changes with it.
  static const radius = 14.0;

  /// Cards are rounder than the controls inside them, which is what makes
  /// them read as one surface rather than a box drawn around some widgets.
  static const radiusCard = 20.0;

  static const hairline = 1.0;
}

/// Letter-spacing, from the brand's own type rules: headings pulled tight,
/// small labels opened right up.
abstract final class Tracking {
  static const tight = -0.5;

  /// The countdown's own. Negative, so a five-figure clock holds together as
  /// one number instead of drifting apart at 140 points — but only gently:
  /// the digits are set heavy enough to be read across a room, and heavy
  /// digits pulled as tight as light ones touch.
  static const display = -2.0;
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
    required this.id,
    required this.name,
    required this.ground,
    required this.surface,
    required this.raised,
    required this.onGround,
    required this.prepare,
    required this.work,
    required this.rest,
    required this.breakBetween,
    required this.cooldown,
    required this.stopwatch,
    required this.muted,
    required this.line,
    required this.danger,
  });

  /// The app's own, and the default. Ink and ivory, a terracotta accent, taupe
  /// for everything quiet. Four of the five phases are the brand's own and
  /// [rest] is a muted teal, chosen as terracotta's complement so it still
  /// belongs to the palette while being the one thing you can never mistake
  /// for work.
  static const rust = AppColors(
    id: 'rust',
    name: 'Rust',
    ground: Brand.ink,
    surface: Brand.surface,
    raised: Brand.raised,
    onGround: Brand.ivory,
    prepare: Color(0xFFE8C9A0), // pale sand: get ready, not yet
    work: Brand.terracotta,
    rest: Color(0xFF6E9A91),
    breakBetween: Brand.rust, // a longer pause than rest, and visibly deeper
    cooldown: Brand.taupe,
    stopwatch: Color(0xFF6E73B4),
    muted: Brand.taupe,
    line: Brand.line,
    // Not Brand.rust itself: at #A8431E a notice is 2.7:1 on a card, which is
    // too quiet for the small text every warning in the app is set in. This
    // is the same colour carried up until it can be read.
    danger: Color(0xFFCB5A33),
  );

  /// Cool and low-temperature: the furthest thing from the app's own warmth,
  /// and the one most people switching will switch to.
  ///
  /// The accent is an indigo bright enough to carry the dial at a glance, and
  /// the separation comes from running the phases *around* the wheel rather
  /// than along one hue — amber prepare, indigo work, green rest. Break is a
  /// deep violet so that the two long pauses read as one family and the two
  /// working colours as another.
  static const slate = AppColors(
    id: 'slate',
    name: 'Slate',
    ground: Color(0xFF14161B),
    surface: Color(0xFF1F232B),
    raised: Color(0xFF353C49),
    onGround: Color(0xFFE9ECF2),
    prepare: Color(0xFFE5BE7A),
    work: Color(0xFF6F79BE),
    rest: Color(0xFF59B89A),
    breakBetween: Color(0xFFB25E8E),
    cooldown: Color(0xFF7C8699),
    stopwatch: Color(0xFFD9A14E),
    muted: Color(0xFF8E97A8),
    line: Color(0xFF454E5E),
    danger: Color(0xFFD06072),
  );

  /// Green and earthy, and the calmest of the four.
  ///
  /// Work is a moss green and rest a warm clay — the reverse of the usual
  /// arrangement, and deliberate: the phase you are *in* should be the one
  /// that reads as alive, and a green ground with a clay pause separates at
  /// least as far as terracotta against teal does.
  static const moss = AppColors(
    id: 'moss',
    name: 'Moss',
    ground: Color(0xFF14180F),
    surface: Color(0xFF1F2518),
    raised: Color(0xFF353D29),
    onGround: Color(0xFFEFF0E4),
    prepare: Color(0xFFDFCB85),
    work: Color(0xFF8FB861),
    rest: Color(0xFFD08A5E),
    breakBetween: Color(0xFF6E86B0),
    cooldown: Color(0xFF8A907A),
    stopwatch: Color(0xFFA585C4),
    muted: Color(0xFF8F9681),
    line: Color(0xFF4A5240),
    danger: Color(0xFFC75F4B),
  );

  /// Near-black, near-white, and the highest contrast the app can offer.
  ///
  /// For anyone who finds the other three hard to read, and the best of the
  /// four across a gym. The phases are pushed to the brightest, most separated
  /// hues in the set rather than to tasteful ones, because that is the whole
  /// point of it — this theme is allowed to be louder than the brand.
  static const mono = AppColors(
    id: 'mono',
    name: 'Mono',
    ground: Color(0xFF0B0B0C),
    surface: Color(0xFF1C1C1F),
    raised: Color(0xFF34343A),
    onGround: Color(0xFFF7F7F8),
    prepare: Color(0xFFF2D14E),
    work: Color(0xFF2E9FD4),
    rest: Color(0xFF5BE07A),
    breakBetween: Color(0xFF9B8CFF),
    cooldown: Color(0xFFA6A6AE),
    stopwatch: Color(0xFFEE7FC9),
    muted: Color(0xFFA6A6AE),
    line: Color(0xFF55555E),
    danger: Color(0xFFFF6B6B),
  );

  /// Every theme, in the order they are offered. The first is the default.
  static const themes = [rust, slate, moss, mono];

  /// The theme [id] names, or [rust] for an id from a build that had more of
  /// them than this one does.
  static AppColors byId(String? id) =>
      themes.firstWhere((theme) => theme.id == id, orElse: () => rust);

  /// What the stored setting holds, and what the picker shows.
  final String id;
  final String name;

  /// The page itself, and the two steps up from it: a card, and a control on
  /// a card.
  final Color ground;
  final Color surface;
  final Color raised;

  /// Primary text on [ground].
  final Color onGround;

  final Color prepare;
  final Color work;
  final Color rest;
  final Color breakBetween;
  final Color cooldown;

  /// The stopwatch's own. Not a phase — it is the third thing on home, beside
  /// the workouts and the focus sessions, and it needs a colour of its own for
  /// the same reason they do: the three are told apart by colour before they
  /// are read.
  final Color stopwatch;

  /// Secondary text: readable, but never competing with the number.
  final Color muted;

  /// Hairlines, borders and dividers.
  final Color line;

  final Color danger;

  // The three colours any coloured screen needs: a pale face to sit things
  // on, a deeper cut for what should catch the eye, and whatever reads on
  // top. Taken against a colour rather than a phase, because the stopwatch
  // has no phase and wears the brand's accent instead.

  /// The pale face of a dial, a badge or a quiet control. Tinted towards the
  /// colour it sits on rather than plain ivory, so it belongs to that screen.
  Color faceOn(Color ground) => Color.lerp(onGround, ground, 0.12)!;

  /// Whatever reads on [ground]: the theme's dark or its light, whichever has
  /// more contrast.
  Color readableOn(Color background) =>
      _readableOn(background, dark: ground, light: onGround);

  /// The pale face of the dial, the badge and the quiet controls.
  Color phaseFace(SegmentKind kind) => faceOn(phase(kind));

  /// A deeper cut of the phase, for the progress arc and the primary control.
  ///
  /// Darkened and *enriched*, not mixed towards ink. Mixing towards ink drains
  /// the colour out as it darkens and leaves a muddy brown where the arc
  /// should be the liveliest thing on the screen; pulling the lightness down
  /// while pushing the saturation up keeps the hue burning.
  ///
  /// Derived rather than listed, so a phase colour is still changed in one
  /// place and its deeper cut follows.
  Color deepOf(Color ground) {
    final hsl = HSLColor.fromColor(ground);
    return hsl
        .withLightness((hsl.lightness * 0.78).clamp(0.0, 1.0))
        .withSaturation((hsl.saturation + 0.22).clamp(0.0, 1.0))
        .toColor();
  }

  Color phaseDeep(SegmentKind kind) => deepOf(phase(kind));

  /// The colour the whole run screen takes while [kind] is running.
  Color phase(SegmentKind kind) => switch (kind) {
    SegmentKind.prepare => prepare,
    SegmentKind.work => work,
    SegmentKind.rest => rest,
    SegmentKind.breakBetween => breakBetween,
    SegmentKind.cooldown => cooldown,
  };

  /// What to draw on top of the deeper cut — the arc, the primary control.
  Color onPhaseDeep(SegmentKind kind) => readableOn(phaseDeep(kind));

  /// The fill behind a badge or a section icon on a dark screen: the colour,
  /// turned right down. [accentWash] is this for the app's own accent; a mode
  /// with a colour of its own needs the same treatment of it.
  Color washOf(Color background) => background.withValues(alpha: 0.16);

  /// The fill behind a section's icon: the accent, turned right down.
  Color get accentWash => washOf(work);

  /// A card's edge. Tinted with the accent rather than neutral, so the cards
  /// belong to the colour that lights the rest of the screen.
  Color get cardLine => work.withValues(alpha: 0.22);

  /// The soft shapes behind a running phase: the same colour as the ground,
  /// lifted or dropped a little. Kept this faint on purpose — they should
  /// give the screen depth and never be noticed as shapes. The same in every
  /// theme, because they are light and shade rather than colour.
  Color get veilLight => const Color(0x18FFFFFF);
  Color get veilDark => const Color(0x12000000);

  /// Focus wears the rest colour, and that is the point of it: every theme
  /// spends [work] on the phase that wants you to move, and this screen wants
  /// the opposite. It is also never used as a ground here — only as the arc,
  /// the word and the one control that matters.
  Color get focus => rest;

  /// The fill of the one action a screen is really offering. Lit from the
  /// left, so a wide button does not read as a flat slab of colour.
  LinearGradient gradientOn(Color ground) => LinearGradient(
    colors: [ground, deepOf(ground)],
    begin: Alignment.centerLeft,
    end: Alignment.centerRight,
  );

  /// What to draw on top of a phase colour.
  ///
  /// Worked out rather than written down: whichever of ink and ivory has more
  /// contrast against that phase wins. Pale sand takes ink and deep rust takes
  /// ivory without anyone having to remember which, and a change to a phase
  /// colour can never leave unreadable text behind it.
  Color onPhase(SegmentKind kind) => readableOn(phase(kind));

  @override
  AppColors copyWith({
    String? id,
    String? name,
    Color? ground,
    Color? surface,
    Color? raised,
    Color? onGround,
    Color? prepare,
    Color? work,
    Color? rest,
    Color? breakBetween,
    Color? cooldown,
    Color? stopwatch,
    Color? muted,
    Color? line,
    Color? danger,
  }) => AppColors(
    id: id ?? this.id,
    name: name ?? this.name,
    ground: ground ?? this.ground,
    surface: surface ?? this.surface,
    raised: raised ?? this.raised,
    onGround: onGround ?? this.onGround,
    prepare: prepare ?? this.prepare,
    work: work ?? this.work,
    rest: rest ?? this.rest,
    breakBetween: breakBetween ?? this.breakBetween,
    cooldown: cooldown ?? this.cooldown,
    stopwatch: stopwatch ?? this.stopwatch,
    muted: muted ?? this.muted,
    line: line ?? this.line,
    danger: danger ?? this.danger,
  );

  /// Half way between two themes is not a theme, so [id] and [name] take the
  /// side being moved towards rather than being blended into nonsense.
  @override
  AppColors lerp(AppColors? other, double t) {
    if (other == null) return this;
    return AppColors(
      id: t < 0.5 ? id : other.id,
      name: t < 0.5 ? name : other.name,
      ground: Color.lerp(ground, other.ground, t)!,
      surface: Color.lerp(surface, other.surface, t)!,
      raised: Color.lerp(raised, other.raised, t)!,
      onGround: Color.lerp(onGround, other.onGround, t)!,
      prepare: Color.lerp(prepare, other.prepare, t)!,
      work: Color.lerp(work, other.work, t)!,
      rest: Color.lerp(rest, other.rest, t)!,
      breakBetween: Color.lerp(breakBetween, other.breakBetween, t)!,
      cooldown: Color.lerp(cooldown, other.cooldown, t)!,
      stopwatch: Color.lerp(stopwatch, other.stopwatch, t)!,
      muted: Color.lerp(muted, other.muted, t)!,
      line: Color.lerp(line, other.line, t)!,
      danger: Color.lerp(danger, other.danger, t)!,
    );
  }
}

/// The icon on the badge above the phase name.
///
/// Lives here with the phase colours because it is the same job: saying which
/// phase you are in without being read.
IconData phaseIcon(SegmentKind kind) => switch (kind) {
  SegmentKind.prepare => Icons.hourglass_top_rounded,
  SegmentKind.work => Icons.fitness_center_rounded,
  SegmentKind.rest => Icons.self_improvement_rounded,
  SegmentKind.breakBetween => Icons.local_cafe_rounded,
  SegmentKind.cooldown => Icons.spa_rounded,
};

/// Whichever of the theme's [dark] and [light] can actually be read on
/// [background].
Color _readableOn(Color background, {required Color dark, required Color light}) =>
    _contrast(background, dark) >= _contrast(background, light) ? dark : light;

/// The WCAG contrast ratio between two colours, 1 (identical) to 21.
///
/// Public because a theme's whole promise is made of these — that its five
/// phases can be told apart and that everything on them can be read — and
/// `test/app/theme_test.dart` has to be able to check it.
double contrastBetween(Color a, Color b) => _contrast(a, b);

/// WCAG contrast ratio, which is the only honest way to make this choice.
double _contrast(Color a, Color b) {
  final first = a.computeLuminance();
  final second = b.computeLuminance();
  return (math.max(first, second) + 0.05) / (math.min(first, second) + 0.05);
}

extension ColorsOf on BuildContext {
  AppColors get colors => Theme.of(this).extension<AppColors>()!;
}

/// A filled disc of [accent] with an icon on it — the "new" on a heading, and
/// the settings gear on home.
///
/// The counterpart to [chipIconButton]: that one is a quiet dark disc for an
/// app bar, this one carries a section's colour and is meant to be found.
ButtonStyle discIconButton(AppColors colors, Color accent) => ButtonStyle(
  backgroundColor: WidgetStatePropertyAll(accent),
  foregroundColor: WidgetStatePropertyAll(colors.readableOn(accent)),
  overlayColor: WidgetStatePropertyAll(
    colors.readableOn(accent).withValues(alpha: 0.12),
  ),
  shape: const WidgetStatePropertyAll(CircleBorder()),
  minimumSize: const WidgetStatePropertyAll(
    Size(Sizes.badgeSmall, Sizes.badgeSmall),
  ),
  iconSize: const WidgetStatePropertyAll(Sizes.icon),
);

/// An icon button sitting in its own dark disc, for app bars.
///
/// A bare arrow on a dark screen is a small grey mark in a large empty corner.
/// The disc gives it an edge to be seen against and a target to be hit.
ButtonStyle chipIconButton(AppColors colors) => ButtonStyle(
  backgroundColor: WidgetStatePropertyAll(colors.surface),
  foregroundColor: WidgetStatePropertyAll(colors.onGround),
  overlayColor: const WidgetStatePropertyAll(Color(0x14F4EFE7)),
  shape: const WidgetStatePropertyAll(CircleBorder()),
  minimumSize: const WidgetStatePropertyAll(
    Size(Sizes.control, Sizes.control),
  ),
  iconSize: const WidgetStatePropertyAll(Sizes.icon),
);

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
  const ActionLabel(this.text, {super.key, this.alignment = Alignment.center});

  final String text;

  /// Where the label sits when it is given more room than it needs. Centre
  /// suits a button; a row of label and chevron wants it at the start.
  final AlignmentGeometry alignment;

  @override
  Widget build(BuildContext context) => FittedBox(
    fit: BoxFit.scaleDown,
    alignment: alignment,
    child: Text(text, maxLines: 1, softWrap: false),
  );
}

// ---------------------------------------------------------------------------
// The theme
// ---------------------------------------------------------------------------

/// Pages cross-fade rather than slide.
///
/// The default slides a new page in from the right over about four hundred
/// milliseconds, and for that moment two screens are on screen side by side.
/// On most apps nothing comes of it. Here the run and focus screens have no
/// app bar and paint a colour to all four edges, so mid-slide you get two
/// full-bleed grounds abutting — which the eye reads as one oversized screen
/// rather than as two pages, and which was reported as exactly that.
///
/// A fade cannot do it: nothing ever moves sideways, so nothing is ever beside
/// anything.
class _FadeThrough extends PageTransitionsBuilder {
  const _FadeThrough();

  @override
  Widget buildTransitions<T>(
    PageRoute<T> route,
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) => FadeTransition(opacity: animation, child: child);
}

const _shape = RoundedRectangleBorder(
  borderRadius: BorderRadius.all(Radius.circular(Sizes.radius)),
);

/// Jost, the brand's typeface, bundled as a single variable file.
const _fontFamily = 'Jost';

extension _VariableWeight on TextStyle {
  /// Sets a weight on a variable font.
  ///
  /// Both halves are needed. `fontWeight` is what Flutter lays out and falls
  /// back on; `fontVariations` is what actually moves Jost's weight axis. Set
  /// only the first and every weight in the app renders as Regular.
  TextStyle weight(int value) => copyWith(
    fontWeight: FontWeight.values.firstWhere(
      (w) => w.value == value,
      orElse: () => FontWeight.normal,
    ),
    fontVariations: [FontVariation.weight(value.toDouble())],
  );
}

/// The app's theme. Dark, because this screen is looked at in a gym at six in
/// the morning and is mostly one enormous number.
ThemeData appTheme([AppColors colors = AppColors.rust]) {
  final scheme = ColorScheme.dark(
    primary: colors.work,
    onPrimary: colors.readableOn(colors.work),
    secondary: colors.muted,
    onSecondary: colors.ground,
    // The quiet filled surface behind a tonal icon button. Raised enough to
    // find on both the page and a card, far short of competing with them:
    // a row of solid taupe blocks reads as the loudest thing on the screen,
    // which a minus sign should never be.
    secondaryContainer: colors.raised,
    onSecondaryContainer: colors.onGround,
    surface: colors.ground,
    onSurface: colors.onGround,
    surfaceContainer: colors.surface,
    surfaceContainerHighest: colors.raised,
    outline: colors.line,
    outlineVariant: colors.surface,
    error: colors.danger,
    onError: colors.onGround,
  );

  final base = ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    colorScheme: scheme,
    fontFamily: _fontFamily,
    scaffoldBackgroundColor: colors.ground,
    extensions: [colors],
  );

  return base.copyWith(
    textTheme: _textTheme(base.textTheme, colors),

    // Android only, deliberately. iOS keeps its own transition because the
    // swipe from the left edge to go back comes with it, and trading a
    // platform's back gesture for a consistent fade is a bad bargain.
    pageTransitionsTheme: const PageTransitionsTheme(
      builders: {TargetPlatform.android: _FadeThrough()},
    ),

    appBarTheme: AppBarTheme(
      backgroundColor: colors.ground,
      foregroundColor: colors.onGround,
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: false,
    ),

    // Flat and square. The brand has no shadows in it, and a drop shadow is
    // the quickest way to make a deliberate design look like a default one.
    filledButtonTheme: FilledButtonThemeData(style: _filled(colors)),
    elevatedButtonTheme: ElevatedButtonThemeData(style: _filled(colors)),
    outlinedButtonTheme: OutlinedButtonThemeData(style: _outlined(colors)),
    textButtonTheme: TextButtonThemeData(style: _text(colors)),
    iconButtonTheme: IconButtonThemeData(style: _icon(colors)),

    cardTheme: CardThemeData(
      color: colors.surface,
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(Sizes.radiusCard),
        side: BorderSide(color: colors.cardLine, width: Sizes.hairline),
      ),
    ),

    dividerTheme: DividerThemeData(
      color: colors.line,
      thickness: Sizes.hairline,
      space: Sizes.bigGap,
    ),

    iconTheme: IconThemeData(size: Sizes.icon, color: colors.onGround),

    listTileTheme: ListTileThemeData(
      minTileHeight: Sizes.row,
      contentPadding: const EdgeInsets.symmetric(horizontal: Sizes.gutter),
      titleTextStyle: TextStyle(
        color: colors.onGround,
        fontSize: 16,
      ).weight(500),
      subtitleTextStyle: TextStyle(
        color: colors.muted,
        fontSize: 13,
      ).weight(400),
      iconColor: colors.muted,
    ),

    inputDecorationTheme: InputDecorationThemeData(
      border: UnderlineInputBorder(
        borderSide: BorderSide(color: colors.line, width: Sizes.hairline),
      ),
      enabledBorder: UnderlineInputBorder(
        borderSide: BorderSide(color: colors.line, width: Sizes.hairline),
      ),
      focusedBorder: UnderlineInputBorder(
        borderSide: BorderSide(color: colors.work, width: 2),
      ),
      labelStyle: TextStyle(color: colors.muted),
      floatingLabelStyle: TextStyle(color: colors.work),
      hintStyle: TextStyle(color: colors.muted),
    ),

    switchTheme: SwitchThemeData(
      // Ivory on, taupe off. An ink thumb on a terracotta track reads as a
      // hole punched in the switch rather than as the part that moves.
      thumbColor: WidgetStateProperty.resolveWith(
        (states) => states.contains(WidgetState.selected)
            ? colors.onGround
            : colors.muted,
      ),
      trackColor: WidgetStateProperty.resolveWith(
        (states) => states.contains(WidgetState.selected)
            ? colors.work
            : colors.surface,
      ),
      trackOutlineColor: WidgetStatePropertyAll(colors.line),
    ),

    sliderTheme: SliderThemeData(
      activeTrackColor: colors.work,
      inactiveTrackColor: colors.raised,
      thumbColor: colors.work,
      overlayColor: Color(0x33D97745),
      // A little lift under the thumb, so the one thing being dragged is the
      // one thing standing off the track.
      thumbShape: RoundSliderThumbShape(enabledThumbRadius: 11, elevation: 4),
    ),

    segmentedButtonTheme: SegmentedButtonThemeData(
      style: ButtonStyle(
        backgroundColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected)
              ? colors.work
              : Colors.transparent,
        ),
        foregroundColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected)
              ? colors.ground
              : colors.onGround,
        ),
        side: WidgetStatePropertyAll(
          BorderSide(color: colors.line, width: Sizes.hairline),
        ),
        shape: const WidgetStatePropertyAll(_shape),
        textStyle: WidgetStatePropertyAll(
          const TextStyle(letterSpacing: Tracking.wide).weight(500),
        ),
      ),
    ),

    floatingActionButtonTheme: FloatingActionButtonThemeData(
      backgroundColor: colors.work,
      foregroundColor: colors.ground,
      elevation: 0,
      focusElevation: 0,
      hoverElevation: 0,
      highlightElevation: 0,
      shape: _shape,
      extendedTextStyle: const TextStyle(
        letterSpacing: Tracking.wide,
      ).weight(600),
    ),
  );
}

/// The primary action: solid terracotta, ink on top, no shadow, square edges.
ButtonStyle _filled(AppColors colors) => ButtonStyle(
  backgroundColor: WidgetStateProperty.resolveWith(
    (states) => states.contains(WidgetState.disabled)
        ? colors.raised
        : states.contains(WidgetState.pressed)
        ? colors.danger
        : colors.work,
  ),
  foregroundColor: WidgetStateProperty.resolveWith(
    (states) =>
        states.contains(WidgetState.disabled) ? colors.muted : colors.ground,
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
  textStyle: WidgetStatePropertyAll(_actionText),
  iconSize: const WidgetStatePropertyAll(Sizes.bigIcon),
);

/// The secondary action: a hairline and nothing else, until you touch it.
ButtonStyle _outlined(AppColors colors) => ButtonStyle(
  backgroundColor: WidgetStateProperty.resolveWith(
    (states) => states.contains(WidgetState.pressed)
        ? colors.surface
        : Colors.transparent,
  ),
  foregroundColor: WidgetStateProperty.resolveWith(
    (states) =>
        states.contains(WidgetState.disabled) ? colors.raised : colors.onGround,
  ),
  side: WidgetStateProperty.resolveWith(
    (states) => BorderSide(
      color: states.contains(WidgetState.disabled)
          ? colors.raised
          : states.contains(WidgetState.pressed)
          ? colors.work
          : colors.line,
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
  textStyle: WidgetStatePropertyAll(_actionText),
  iconSize: const WidgetStatePropertyAll(Sizes.icon),
);

/// The quiet one: terracotta text, no box at all.
ButtonStyle _text(AppColors colors) => ButtonStyle(
  foregroundColor: WidgetStateProperty.resolveWith(
    (states) => states.contains(WidgetState.disabled)
        ? colors.raised
        : colors.work,
  ),
  overlayColor: const WidgetStatePropertyAll(Color(0x1AD97745)),
  minimumSize: const WidgetStatePropertyAll(
    Size(Sizes.control, Sizes.control),
  ),
  shape: const WidgetStatePropertyAll(_shape),
  textStyle: WidgetStatePropertyAll(_actionText),
);

ButtonStyle _icon(AppColors colors) => ButtonStyle(
  foregroundColor: WidgetStateProperty.resolveWith(
    (states) =>
        states.contains(WidgetState.disabled) ? colors.raised : colors.onGround,
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
final _actionText = const TextStyle(
  fontSize: 14,
  letterSpacing: 1.2,
).weight(600);

TextTheme _textTheme(TextTheme base, AppColors colors) => base.copyWith(
  // The countdown, and the only thing on the screen that is read from a
  // distance.
  //
  // Weight is what makes that work, not size. The dial is capped at 320
  // logical pixels and the number is fitted inside it, so on a phone propped
  // up across a room the digits land around 100 — about a centimetre of
  // actual glass, where a hairline stroke is under half a millimetre and
  // simply disappears. Medium doubles the stroke and costs nothing else.
  displayLarge: base.displayLarge
      ?.copyWith(
        fontSize: Sizes.countdownText,
        letterSpacing: Tracking.display,
        height: 1,
        color: colors.onGround,
      )
      .weight(500),
  // The wordmark on home. Not the countdown's weight — this is read once, at
  // arm's length, and at 200 it would look like the number without being one.
  displaySmall: base.displaySmall
      ?.copyWith(
        fontSize: Sizes.wordmarkText,
        letterSpacing: Tracking.tight,
        height: 1.1,
        color: colors.onGround,
      )
      .weight(600),
  headlineLarge: base.headlineLarge
      ?.copyWith(
        fontSize: Sizes.phaseText,
        letterSpacing: Tracking.wide,
        color: colors.onGround,
      )
      .weight(600),
  headlineSmall: base.headlineSmall
      ?.copyWith(letterSpacing: Tracking.tight, color: colors.onGround)
      .weight(500),
  titleLarge: base.titleLarge
      ?.copyWith(letterSpacing: Tracking.tight, color: colors.onGround)
      .weight(500),
  titleMedium: base.titleMedium?.copyWith(color: colors.onGround).weight(500),
  bodyLarge: base.bodyLarge?.copyWith(color: colors.onGround).weight(400),
  bodyMedium: base.bodyMedium?.copyWith(color: colors.muted).weight(400),
  bodySmall: base.bodySmall?.copyWith(color: colors.muted).weight(400),
  // Section headings, set the way the brand sets them: small, uppercase and
  // widely tracked.
  labelLarge: base.labelLarge
      ?.copyWith(letterSpacing: Tracking.wider, color: colors.muted)
      .weight(600),
  labelMedium: base.labelMedium
      ?.copyWith(letterSpacing: Tracking.wide, color: colors.muted)
      .weight(600),
);
