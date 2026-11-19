import 'dart:convert';

import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:purrfit/app/theme/app_colors.dart';
import 'package:purrfit/app/theme/app_cupertino_theme.dart';
import 'package:purrfit/main.dart';
import 'package:purrfit/shared/ui/app_buttons.dart';
import 'package:purrfit/shared/ui/app_chip.dart';
import 'package:purrfit/storage/sensitive_local_store.dart';
import 'package:purrfit/workout_engine.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _profile = OnboardingProfile(safetyReviewed: true, sessionMinutes: 10);
const _journey = JourneyProgress(journeyId: 'dark-journey');

double _contrast(Color a, Color b) {
  final first = a.computeLuminance();
  final second = b.computeLuminance();
  final lighter = first > second ? first : second;
  final darker = first > second ? second : first;
  return (lighter + .05) / (darker + .05);
}

void _seedDarkApp() {
  SharedPreferences.setMockInitialValues({
    'darkMode': true,
    SensitiveLocalStore.secureStateKey: jsonEncode({
      'schemaVersion': 3,
      'ownerUserId': null,
      'onboarded': true,
      'journey': _journey.toJson(),
      'profile': _profile.toJson(),
      'active': null,
      'history': <Object>[],
    }),
  });
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    debugUsePlaintextLocalState = true;
  });
  tearDown(() {
    debugUsePlaintextLocalState = false;
    appIsDark.value = null;
  });

  test('filled brand colors get readable ink in both palettes', () {
    for (final fill in [
      AppColors.lightAccent,
      AppColors.darkAccent,
      AppColors.lightSuccess,
      AppColors.darkSuccess,
    ]) {
      expect(
        _contrast(AppColors.inkOn(fill), fill),
        greaterThanOrEqualTo(4.5),
        reason: 'ink on $fill must reach WCAG AA',
      );
    }
    expect(AppColors.inkOn(AppColors.lightPrimaryText), CupertinoColors.white);
  });

  testWidgets('dark primary button and selected chip use dark ink', (
    tester,
  ) async {
    await tester.pumpWidget(
      CupertinoApp(
        theme: AppCupertinoTheme.theme(Brightness.dark),
        home: CupertinoPageScaffold(
          child: Column(
            children: [
              AppPrimaryButton(label: 'Continue', onPressed: () {}),
              AppChip('Low', selected: true, onTap: () {}),
            ],
          ),
        ),
      ),
    );

    final buttonColor = tester
        .widget<Text>(find.text('Continue'))
        .style!
        .color!;
    expect(buttonColor, AppColors.lightPrimaryText);
    expect(
      _contrast(buttonColor, AppColors.darkAccent),
      greaterThanOrEqualTo(4.5),
    );

    final chipColor = tester.widget<Text>(find.text('Low')).style!.color!;
    expect(chipColor, AppColors.lightPrimaryText);
    expect(
      _contrast(chipColor, AppColors.darkAccent),
      greaterThanOrEqualTo(4.5),
    );
  });

  testWidgets('bare text inherits dark ink from the app theme', (tester) async {
    _seedDarkApp();
    appIsDark.value = true;
    await tester.pumpWidget(const PurrfitApp());
    for (var i = 0; i < 5; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    await tester.tap(find.text('Report').last);
    for (var i = 0; i < 5; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }

    final context = tester.element(find.text('History'));
    expect(DefaultTextStyle.of(context).style.color, AppColors.darkPrimaryText);
  });
}
