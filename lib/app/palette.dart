import 'package:flutter/material.dart';

import '../core/timeline/workout.dart';

/// Every colour in the app lives here.
///
/// Screens take colours from the theme or from `context.colors`, and never
/// name one themselves. A phase colour is the only thing that tells you at a
/// glance, from across a room, whether you are working or resting — so it is
/// worth keeping all of them side by side where they can be compared.
abstract final class Palette {
  static const ink = Color(0xFF0E1116);
  static const surface = Color(0xFF161B22);
  static const surfaceLight = Color(0xFFF6F7F9);
  static const paper = Color(0xFFFFFFFF);

  static const work = Color(0xFF1DB954);
  static const rest = Color(0xFF2E86DE);
  static const prepare = Color(0xFFF2A33C);
  static const breakBetween = Color(0xFF7C5CD6);
  static const cooldown = Color(0xFF18A999);
  static const idle = Color(0xFF6B7682);

  static const danger = Color(0xFFD64545);
}

/// The colours a screen asks for by meaning rather than by name.
@immutable
class AppColors extends ThemeExtension<AppColors> {
  const AppColors({
    required this.work,
    required this.rest,
    required this.prepare,
    required this.breakBetween,
    required this.cooldown,
    required this.idle,
    required this.danger,
  });

  static const dark = AppColors(
    work: Palette.work,
    rest: Palette.rest,
    prepare: Palette.prepare,
    breakBetween: Palette.breakBetween,
    cooldown: Palette.cooldown,
    idle: Palette.idle,
    danger: Palette.danger,
  );

  final Color work;
  final Color rest;
  final Color prepare;
  final Color breakBetween;
  final Color cooldown;
  final Color idle;
  final Color danger;

  /// The colour the whole run screen takes while [kind] is running.
  Color phase(SegmentKind kind) => switch (kind) {
    SegmentKind.prepare => prepare,
    SegmentKind.work => work,
    SegmentKind.rest => rest,
    SegmentKind.breakBetween => breakBetween,
    SegmentKind.cooldown => cooldown,
  };

  @override
  AppColors copyWith({
    Color? work,
    Color? rest,
    Color? prepare,
    Color? breakBetween,
    Color? cooldown,
    Color? idle,
    Color? danger,
  }) => AppColors(
    work: work ?? this.work,
    rest: rest ?? this.rest,
    prepare: prepare ?? this.prepare,
    breakBetween: breakBetween ?? this.breakBetween,
    cooldown: cooldown ?? this.cooldown,
    idle: idle ?? this.idle,
    danger: danger ?? this.danger,
  );

  @override
  AppColors lerp(AppColors? other, double t) {
    if (other == null) return this;
    return AppColors(
      work: Color.lerp(work, other.work, t)!,
      rest: Color.lerp(rest, other.rest, t)!,
      prepare: Color.lerp(prepare, other.prepare, t)!,
      breakBetween: Color.lerp(breakBetween, other.breakBetween, t)!,
      cooldown: Color.lerp(cooldown, other.cooldown, t)!,
      idle: Color.lerp(idle, other.idle, t)!,
      danger: Color.lerp(danger, other.danger, t)!,
    );
  }
}

extension ColorsOf on BuildContext {
  AppColors get colors => Theme.of(this).extension<AppColors>()!;
}
