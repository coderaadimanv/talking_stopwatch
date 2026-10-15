import 'package:cadent/app/style.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Pages must not move sideways on the way in.
///
/// Reported as "this screen looks wider than the others", which it is not —
/// every screen in the app puts its content between the same two gutters. What
/// was being seen was the default transition sliding a new page in from the
/// right: for a few hundred milliseconds two screens are on screen at once,
/// and because the run and focus screens have no app bar and paint a colour to
/// all four edges, two of them abutting read as one oversized screen.
///
/// So this pins the thing that was actually wrong rather than the thing that
/// looked wrong: during a push, the incoming page never leaves its place.
void main() {
  testWidgets('a page does not slide in from the side', (tester) async {
    tester.view
      ..physicalSize = const Size(360, 800) * 3
      ..devicePixelRatio = 3;
    addTearDown(tester.view.reset);

    final navigator = GlobalKey<NavigatorState>();
    await tester.pumpWidget(
      MaterialApp(
        theme: appTheme(),
        navigatorKey: navigator,
        home: const Scaffold(body: Center(child: Text('home'))),
      ),
    );

    navigator.currentState!.push(
      MaterialPageRoute<void>(
        builder: (_) => const Scaffold(
          body: SizedBox.expand(child: Text('next')),
        ),
      ),
    );

    // Through the whole transition, a frame at a time.
    var seen = 0;
    for (var i = 0; i < 12; i++) {
      await tester.pump(const Duration(milliseconds: 40));
      final found = find.text('next');
      if (found.evaluate().isEmpty) continue;
      seen++;
      final box = tester.getRect(found.first);
      expect(
        box.left,
        moreOrLessEquals(0, epsilon: 0.5),
        reason: 'the page was ${box.left.toStringAsFixed(1)}dp off to the '
            'side part way through the transition, which is what put two '
            'screens on screen at once',
      );
    }
    expect(seen, greaterThan(2), reason: 'the transition was never observed');
  });
}
