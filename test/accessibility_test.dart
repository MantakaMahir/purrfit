import 'dart:ui' show Tristate;

import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:purrfit/main.dart';
import 'package:purrfit/shared/ui/app_buttons.dart';
import 'package:purrfit/shared/ui/app_chip.dart';
import 'package:purrfit/shared/ui/app_progress.dart';
import 'package:purrfit/shared/ui/app_text_field.dart';

void main() {
  testWidgets('primary button grows for large text without overflowing', (
    tester,
  ) async {
    await tester.pumpWidget(
      CupertinoApp(
        home: MediaQuery(
          data: const MediaQueryData(
            size: Size(320, 640),
            textScaler: TextScaler.linear(2),
          ),
          child: CupertinoPageScaffold(
            child: Center(
              child: AppPrimaryButton(
                label: 'Permanently delete account',
                onPressed: () {},
              ),
            ),
          ),
        ),
      ),
    );

    expect(tester.takeException(), isNull);
    expect(
      tester.getSize(find.byType(AppPrimaryButton)).height,
      greaterThan(54),
    );
  });

  testWidgets('progress exposes a spoken label and percentage', (tester) async {
    final semantics = tester.ensureSemantics();
    await tester.pumpWidget(
      const CupertinoApp(
        home: Center(child: AppProgressBar(value: .42, label: 'Plan progress')),
      ),
    );

    final node = tester.getSemantics(find.bySemanticsLabel('Plan progress'));
    expect(node.value, '42 percent');
    semantics.dispose();
  });

  testWidgets('selectable chips expose their selected state', (tester) async {
    final semantics = tester.ensureSemantics();
    await tester.pumpWidget(
      CupertinoApp(
        home: Center(child: AppChip('Medium', selected: true, onTap: () {})),
      ),
    );

    final node = tester.getSemantics(find.bySemanticsLabel('Medium'));
    expect(node.flagsCollection.isSelected, Tristate.isTrue);
    expect(node.flagsCollection.isButton, isTrue);
    semantics.dispose();
  });

  testWidgets('text fields are single-line by default and expose a label', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    final controller = TextEditingController();
    await tester.pumpWidget(
      CupertinoApp(
        home: Center(
          child: AppTextField(
            controller: controller,
            placeholder: 'Your name',
            semanticLabel: 'Profile name',
            maxLength: 40,
          ),
        ),
      ),
    );

    final field = tester.widget<CupertinoTextField>(
      find.byType(CupertinoTextField),
    );
    expect(field.maxLines, 1);
    expect(field.maxLength, 40);
    expect(find.bySemanticsLabel('Profile name'), findsOneWidget);
    controller.dispose();
    semantics.dispose();
  });

  testWidgets('onboarding actions remain reachable at large text sizes', (
    tester,
  ) async {
    await tester.pumpWidget(
      CupertinoApp(
        home: MediaQuery(
          data: const MediaQueryData(
            size: Size(320, 480),
            textScaler: TextScaler.linear(2),
          ),
          child: OnboardingScreen(onFinish: (_) async {}),
        ),
      ),
    );

    await tester.scrollUntilVisible(
      find.text('Meet my journey'),
      120,
      scrollable: find.byType(Scrollable).last,
    );
    await tester.pump(const Duration(milliseconds: 300));
    await tester.tap(find.text('Meet my journey'));
    await tester.pump();
    await tester.scrollUntilVisible(
      find.text('Continue'),
      120,
      scrollable: find.byType(Scrollable).last,
    );

    expect(tester.takeException(), isNull);
    expect(find.text('Continue'), findsOneWidget);
  });
}
