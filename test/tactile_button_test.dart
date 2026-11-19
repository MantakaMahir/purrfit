import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:purrfit/shared/ui/app_buttons.dart';

void main() {
  testWidgets(
    'press lowers the face without shifting layout and activates once',
    (tester) async {
      var taps = 0;
      await tester.pumpWidget(
        CupertinoApp(
          home: Center(
            child: AppPrimaryButton(label: 'Go', onPressed: () => taps++),
          ),
        ),
      );
      final button = find.byType(AppPrimaryButton);
      final size = tester.getSize(button);
      final labelY = tester.getTopLeft(find.text('Go')).dy;
      final gesture = await tester.startGesture(tester.getCenter(button));
      await tester.pumpAndSettle();
      expect(tester.getTopLeft(find.text('Go')).dy, greaterThan(labelY));
      expect(tester.getSize(button), size);
      expect(taps, 0);
      await gesture.up();
      await tester.pumpAndSettle();
      expect(taps, 1);
      expect(tester.getTopLeft(find.text('Go')).dy, labelY);
    },
  );

  testWidgets('cancelled press restores face without activating', (
    tester,
  ) async {
    var taps = 0;
    await tester.pumpWidget(
      CupertinoApp(
        home: Center(
          child: AppSecondaryButton(label: 'Later', onPressed: () => taps++),
        ),
      ),
    );
    final labelY = tester.getTopLeft(find.text('Later')).dy;
    final gesture = await tester.startGesture(
      tester.getCenter(find.text('Later')),
    );
    await tester.pumpAndSettle();
    await gesture.cancel();
    await tester.pumpAndSettle();
    expect(taps, 0);
    expect(tester.getTopLeft(find.text('Later')).dy, labelY);
  });

  testWidgets('disabled and loading buttons do not activate', (tester) async {
    var taps = 0;
    await tester.pumpWidget(
      CupertinoApp(
        home: Column(
          children: [
            const AppPrimaryButton(label: 'Disabled', onPressed: null),
            AppPrimaryButton(
              label: 'Loading',
              loading: true,
              onPressed: () => taps++,
            ),
          ],
        ),
      ),
    );
    await tester.tap(find.text('Disabled'));
    await tester.tap(find.byType(CupertinoActivityIndicator));
    await tester.pump();
    expect(taps, 0);
    expect(tester.takeException(), isNull);
  });
}
