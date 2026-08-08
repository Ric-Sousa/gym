import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gym_app/shared/widgets/image_comparison_slider.dart';

void main() {
  Widget buildTestWidget() {
    return const MaterialApp(
      home: Scaffold(
        body: Center(
          child: SizedBox(
            width: 320,
            child: ImageComparisonSlider(
              beforeImage: 'https://example.com/before.jpg',
              afterImage: 'https://example.com/after.jpg',
              height: 200,
            ),
          ),
        ),
      ),
    );
  }

  testWidgets('mantém o handle centrado no divisor', (tester) async {
    await tester.pumpWidget(buildTestWidget());

    final handle = tester.getRect(
      find.byKey(const ValueKey('image-comparison-handle')),
    );
    final divider = tester.getRect(
      find.byKey(const ValueKey('image-comparison-divider')),
    );

    expect(handle.center.dx, closeTo(divider.center.dx, 0.01));
    expect(find.byIcon(Icons.compare_arrows_rounded), findsOneWidget);
  });

  testWidgets('move o divisor e mostra as etiquetas durante o arrasto', (
    tester,
  ) async {
    await tester.pumpWidget(buildTestWidget());

    final handleFinder =
        find.byKey(const ValueKey('image-comparison-handle'));
    final initialHandle = tester.getRect(handleFinder);
    final sliderRect = tester.getRect(find.byType(ImageComparisonSlider));
    final gesture = await tester.startGesture(
      Offset(sliderRect.center.dx, sliderRect.center.dy),
    );

    await gesture.moveBy(const Offset(80, 0));
    await tester.pump();

    final movedHandle = tester.getRect(handleFinder);
    expect(movedHandle.center.dx, greaterThan(initialHandle.center.dx));

    final beforeOpacity = tester.widget<AnimatedOpacity>(
      find.ancestor(
        of: find.text('Antes'),
        matching: find.byType(AnimatedOpacity),
      ),
    );
    final afterOpacity = tester.widget<AnimatedOpacity>(
      find.ancestor(
        of: find.text('Depois'),
        matching: find.byType(AnimatedOpacity),
      ),
    );

    expect(beforeOpacity.opacity, 1);
    expect(afterOpacity.opacity, 1);

    await gesture.up();
    await tester.pump();
  });
}
