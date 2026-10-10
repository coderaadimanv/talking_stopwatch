/// Every named size in the app lives here.
///
/// This screen is read at arm's length, mid-set, by someone out of breath, and
/// tapped with a thumb rather than a fingertip. So the numbers are larger than
/// a normal app's, and they are kept together where they can be judged as a
/// set instead of being invented one screen at a time.
abstract final class Sizes {
  /// Minimum tap target. Larger than Material's 48 on purpose: the controls
  /// here get hit while moving.
  static const control = 56.0;

  /// The primary action — start, pause — sized to be hit without looking.
  static const bigControl = 96.0;

  /// A row in a list of presets or rounds.
  static const row = 64.0;

  /// Page margin.
  static const gutter = 16.0;

  /// Space between stacked blocks of content.
  static const gap = 12.0;
  static const bigGap = 24.0;

  /// The remaining-seconds display: the one thing readable across a gym.
  static const countdownText = 140.0;

  /// The phase name above the countdown.
  static const phaseText = 32.0;

  static const icon = 28.0;
  static const bigIcon = 40.0;

  static const radius = 16.0;
}
