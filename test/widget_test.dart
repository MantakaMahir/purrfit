import 'dart:async';
import 'dart:convert';

import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:purrfit/main.dart';
import 'package:purrfit/storage/sensitive_local_store.dart';
import 'package:purrfit/workout_engine.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _profile = OnboardingProfile(safetyReviewed: true, sessionMinutes: 10);
const _journey = JourneyProgress(journeyId: 'fresh-journey');

Future<void> _pump(WidgetTester tester) async {
  for (var i = 0; i < 5; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

Future<void> _tap(WidgetTester tester, String label) async {
  final target = find.text(label);
  await tester.scrollUntilVisible(
    target,
    250,
    scrollable: find.byType(Scrollable).last,
  );
  await tester.ensureVisible(target);
  await _pump(tester);
  await tester.tap(target);
  await _pump(tester);
}

void _seed({
  JourneyProgress journey = _journey,
  OnboardingProfile profile = _profile,
  FrozenWorkout? active,
  List<WorkoutHistoryEntry> history = const [],
}) {
  SharedPreferences.setMockInitialValues({
    SensitiveLocalStore.secureStateKey: jsonEncode({
      'schemaVersion': 3,
      'ownerUserId': null,
      'onboarded': true,
      'journey': journey.toJson(),
      'profile': profile.toJson(),
      'active': active?.toJson(),
      'history': history.map((e) => e.toJson()).toList(),
    }),
  });
}

Future<Map<String, dynamic>> _saved() async =>
    (jsonDecode(
              (await SharedPreferences.getInstance()).getString(
                SensitiveLocalStore.secureStateKey,
              )!,
            )
            as Map)
        .cast<String, dynamic>();
JourneyProgress _savedJourney(Map<String, dynamic> saved) =>
    JourneyProgress.fromJson((saved['journey'] as Map).cast<String, dynamic>());

Future<void> _restart(WidgetTester tester) async {
  await tester.pumpWidget(const SizedBox());
  await tester.pump();
  await tester.pumpWidget(const PurrfitApp());
  await _pump(tester);
}

class _FailingLocalStore extends SensitiveLocalStore {
  _FailingLocalStore() : super(usePlaintextForTesting: true);
  bool failWrites = true;
  Completer<void>? pendingWrite;

  @override
  Future<bool> write(
    Map<String, Object?> state,
    SharedPreferences preferences, {
    String? ownerUserId,
  }) async {
    await pendingWrite?.future;
    return !failWrites &&
        await super.write(state, preferences, ownerUserId: ownerUserId);
  }
}

void main() {
  setUpAll(() {
    SharedPreferences.setMockInitialValues({});
  });
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    debugUsePlaintextLocalState = true;
    debugDisableExternalServices = true;
  });
  tearDown(() {
    debugUsePlaintextLocalState = false;
    debugDisableExternalServices = false;
    appIsDark.value = null;
  });

  testWidgets(
    'fresh onboarding keeps old records separate and requires safety review',
    (tester) async {
      SharedPreferences.setMockInitialValues({
        'onboarded': true,
        'points': 9999,
        'purrfitLocalState': '{"onboarded":true,"points":9999}',
      });
      await tester.pumpWidget(const PurrfitApp());
      await _pump(tester);
      expect(find.text('A little movement. A new adventure.'), findsOneWidget);
      await _tap(tester, 'Meet my journey');
      for (var i = 0; i < 4; i++) {
        await _tap(tester, 'Continue');
      }
      expect(find.text('A quick safety check'), findsOneWidget);
      await _tap(tester, 'Continue');
      expect(find.textContaining('confirm your answers'), findsOneWidget);
      await tester.ensureVisible(find.byType(CupertinoSwitch).last);
      await tester.tap(find.byType(CupertinoSwitch).last);
      await _pump(tester);
      await _tap(tester, 'Continue');
      await _tap(tester, 'Begin my journey');
      expect(find.text('Journey'), findsOneWidget);
      expect(find.text('Start checkpoint 1'), findsOneWidget);
      expect(_savedJourney(await _saved()).points, 0);
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getInt('points'), 9999);
      expect(prefs.getString('purrfitLocalState'), contains('9999'));
    },
  );

  testWidgets('onboarding draft survives a restart', (tester) async {
    await tester.pumpWidget(const PurrfitApp());
    await _pump(tester);
    await _tap(tester, 'Meet my journey');
    await _tap(tester, 'Strength');
    await _tap(tester, 'Continue');
    await _restart(tester);
    expect(find.text('Start with what feels comfortable'), findsOneWidget);
    expect((await _saved())['draft']['primaryGoal'], 'strength');
  });

  testWidgets('default builds expose reports without a purchase or ad', (
    tester,
  ) async {
    _seed();
    await tester.pumpWidget(const PurrfitApp());
    await _pump(tester);

    await tester.tap(find.text('Report'));
    await _pump(tester);
    expect(find.text('0 checkpoints completed'), findsOneWidget);
    expect(find.text('Watch ad to view this report'), findsNothing);
    await tester.tap(find.text('Body'));
    await _pump(tester);
    expect(find.textContaining('Adult BMI screening'), findsOneWidget);

    await tester.tap(find.text('Profile'));
    await _pump(tester);
    expect(find.textContaining('Remove ads'), findsNothing);
  });

  testWidgets('onboarding ignores double finish taps', (tester) async {
    final done = Completer<void>();
    var calls = 0;
    await tester.pumpWidget(
      CupertinoApp(
        home: OnboardingScreen(
          initialStep: 6,
          initialProfile: _profile,
          onFinish: (_) {
            calls++;
            return done.future;
          },
        ),
      ),
    );
    await _pump(tester);
    await tester.ensureVisible(find.text('Begin my journey'));
    await _pump(tester);
    await tester.tap(find.text('Begin my journey'));
    await tester.tap(find.text('Begin my journey'));
    expect(calls, 1);
    done.complete();
    await _pump(tester);
  });

  testWidgets('failed onboarding save keeps choices and offers a retry', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({
      SensitiveLocalStore.secureStateKey: jsonEncode({
        'schemaVersion': 3,
        'draftStep': 6,
        'draft': _profile.toJson(),
      }),
    });
    final store = _FailingLocalStore();
    await tester.pumpWidget(
      CupertinoApp(home: PurrfitShell(localStore: store)),
    );
    await _pump(tester);
    await _tap(tester, 'Begin my journey');
    expect(
      find.text('Your choices could not be saved. Please retry.'),
      findsOneWidget,
    );
    expect((await _saved())['onboarded'], isNot(true));
    store.failWrites = false;
    await _tap(tester, 'Begin my journey');
    expect(find.text('Start checkpoint 1'), findsOneWidget);
  });

  testWidgets(
    'failed profile save stays open and retries without losing input',
    (tester) async {
      _seed();
      final store = _FailingLocalStore();
      await tester.pumpWidget(
        CupertinoApp(home: PurrfitShell(localStore: store)),
      );
      await _pump(tester);
      await tester.tap(find.text('Profile').last);
      await _pump(tester);
      await _tap(tester, 'Name & picture');
      await tester.enterText(find.byType(CupertinoTextField), 'Purr friend');
      await _tap(tester, 'Save profile');
      expect(
        find.text('Your profile could not be saved. Please retry.'),
        findsOneWidget,
      );
      expect((await _saved())['name'], isNull);
      store.failWrites = false;
      await _tap(tester, 'Save profile');
      expect((await _saved())['name'], 'Purr friend');
    },
  );

  testWidgets('failed measurement save retains the form and retries once', (
    tester,
  ) async {
    _seed();
    final store = _FailingLocalStore();
    await tester.pumpWidget(
      CupertinoApp(home: PurrfitShell(localStore: store)),
    );
    await _pump(tester);
    await tester.tap(find.text('Report').last);
    await _pump(tester);
    await tester.tap(find.text('Body'));
    await _pump(tester);
    await _tap(tester, 'Add measurement');
    await tester.enterText(find.byType(CupertinoTextField).first, '65.5');
    await tester.tap(find.text('Save'));
    await _pump(tester);
    expect(
      find.text('Your measurement could not be saved. Please retry.'),
      findsOneWidget,
    );
    store.failWrites = false;
    await tester.tap(find.text('Save'));
    await _pump(tester);
    expect((await _saved())['measurements'], hasLength(1));
    expect((await _saved())['measurements'][0]['weightKg'], 65.5);
  });

  testWidgets(
    'explicit local deletion survives restart without old state returning',
    (tester) async {
      _seed(
        journey: const JourneyProgress(
          journeyId: 'fresh-journey',
          completedCheckpoints: 3,
          points: 300,
        ),
      );
      await tester.pumpWidget(const PurrfitApp());
      await _pump(tester);
      await tester.tap(find.text('Profile').last);
      await _pump(tester);
      await _tap(tester, 'Delete local data');
      await tester.tap(find.text('Delete'));
      await _pump(tester);
      expect(find.text('Meet my journey'), findsOneWidget);
      await _restart(tester);
      expect(find.text('Meet my journey'), findsOneWidget);
      expect(
        (await SharedPreferences.getInstance()).getString(
          SensitiveLocalStore.secureStateKey,
        ),
        isNull,
      );
    },
  );

  testWidgets(
    'a write in flight keeps the journey readable and saves the latest state',
    (tester) async {
      _seed(
        journey: const JourneyProgress(
          journeyId: 'guest-journey',
          completedCheckpoints: 3,
        ),
      );
      final store = _FailingLocalStore()..failWrites = false;
      await tester.pumpWidget(
        CupertinoApp(home: PurrfitShell(localStore: store)),
      );
      await _pump(tester);
      expect(find.text('Start checkpoint 4'), findsOneWidget);
      final pending = Completer<void>();
      store.pendingWrite = pending;
      await tester.tap(find.text('Workout').last);
      await _pump(tester);
      expect(find.text('Start checkpoint'), findsOneWidget);
      store.pendingWrite = null;
      pending.complete();
      await _pump(tester);
      expect(_savedJourney(await _saved()).journeyId, 'guest-journey');
    },
  );

  testWidgets(
    'half the main movements clears once and immediately unlocks next checkpoint',
    (tester) async {
      _seed();
      await tester.pumpWidget(const PurrfitApp());
      await _pump(tester);
      await _tap(tester, 'Start checkpoint 1');
      expect((await _saved())['active']['workout']['seq'], 1);
      await _tap(tester, 'Complete exercise'); // warm-up
      await _tap(tester, 'Complete exercise'); // first of two mains
      await _tap(tester, 'Skip this movement');
      await _tap(tester, 'Finish workout');
      await _tap(tester, 'Good fit');
      expect(find.text('Checkpoint 1 complete!'), findsOneWidget);
      await tester.tap(find.text('OK'));
      await _pump(tester);
      expect(find.text('Start checkpoint 2'), findsOneWidget);
      final saved = await _saved();
      expect(saved['history'], hasLength(1));
      expect(_savedJourney(saved).completedCheckpoints, 1);
      expect(_savedJourney(saved).points, 100);
      await _restart(tester);
      expect(find.text('Start checkpoint 2'), findsOneWidget);
    },
  );

  testWidgets(
    'warm-up and cool-down alone record practice without progression',
    (tester) async {
      _seed();
      await tester.pumpWidget(const PurrfitApp());
      await _pump(tester);
      await _tap(tester, 'Start checkpoint 1');
      await _tap(tester, 'Complete exercise');
      await _tap(tester, 'Skip this movement');
      await _tap(tester, 'Skip this movement');
      await _tap(tester, 'Finish workout');
      await _tap(tester, 'Too hard');
      await tester.tap(find.text('OK'));
      await _pump(tester);
      expect(find.text('Start checkpoint 1'), findsOneWidget);
      final saved = await _saved();
      expect(saved['history'][0]['points'], 0);
      expect(saved['history'][0]['source'], 'practice');
      expect(_savedJourney(saved).difficulty, -1);
      expect(_savedJourney(saved).completedCheckpoints, 0);
    },
  );

  testWidgets(
    'restart restores exact prescription, exercise, set and rest across a long break',
    (tester) async {
      final workout = generateCheckpointWorkout(
        profile: _profile.copyWith(sessionMinutes: 20),
        progress: _journey,
      );
      final restUntil = DateTime.now().add(const Duration(seconds: 40));
      final active = FrozenWorkout(
        eventId: 'frozen-attempt',
        workout: workout,
        startedAt: DateTime(2026, 1, 1),
        energy: 'Low',
        checkpoint: 1,
        current: 1,
        setIndex: 1,
        restUntil: restUntil,
        activeSeconds: 95,
        completed: {0},
      );
      _seed(
        profile: _profile.copyWith(
          primaryGoal: WorkoutGoal.strength,
          sessionMinutes: 45,
        ),
        active: active,
      );
      await tester.pumpWidget(const PurrfitApp());
      await _pump(tester);
      await _tap(tester, 'Resume workout');
      final player = tester.widget<WorkoutScreen>(find.byType(WorkoutScreen));
      expect(player.session.workout.toJson(), workout.toJson());
      expect(player.session.current, 1);
      expect(player.session.setIndex, 1);
      expect(player.session.restUntil, restUntil);
      expect(player.session.activeSeconds, 95);
      await tester.scrollUntilVisible(
        find.textContaining('Rest ·'),
        200,
        scrollable: find.byType(Scrollable).last,
      );
      await _pump(tester);
      expect(find.textContaining('Rest ·'), findsOneWidget);
      await _tap(tester, 'Pause workout');
      await _restart(tester);
      await _tap(tester, 'Resume workout');
      final restored = tester
          .widget<WorkoutScreen>(find.byType(WorkoutScreen))
          .session;
      expect(restored.eventId, 'frozen-attempt');
      expect(restored.workout.toJson(), workout.toJson());
      expect(restored.setIndex, 1);
      expect(restored.activeSeconds, lessThan(100));
    },
  );

  testWidgets(
    'pending feedback survives restart and pain never clears the checkpoint',
    (tester) async {
      final workout = generateCheckpointWorkout(
        profile: _profile,
        progress: _journey,
      );
      _seed(
        active: FrozenWorkout(
          eventId: 'feedback',
          workout: workout,
          startedAt: DateTime.now(),
          energy: 'Medium',
          checkpoint: 1,
          awaitingFeedback: true,
          completed: {0, 1, 2, 3},
          activeSeconds: 100,
        ),
      );
      await tester.pumpWidget(const PurrfitApp());
      await _pump(tester);
      await _tap(tester, 'Resume workout');
      expect(find.text('How did that feel?'), findsOneWidget);
      await _tap(tester, 'Pain or unsafe symptoms');
      await tester.tap(find.text('OK'));
      await _pump(tester);
      expect(find.text('Start checkpoint 1'), findsOneWidget);
      expect((await _saved())['history'][0]['qualified'], false);
    },
  );

  testWidgets(
    'safety red flag blocks start and optional workout entry points',
    (tester) async {
      _seed(
        profile: _profile.copyWith(
          safety: const SafetyProfile(doctorRestriction: true),
        ),
      );
      await tester.pumpWidget(const PurrfitApp());
      await _pump(tester);
      await _tap(tester, 'Start checkpoint 1');
      expect(find.text('Review safety first'), findsOneWidget);
      await tester.tap(find.text('OK'));
      await _pump(tester);
      await tester.tap(find.text('Workout').last);
      await _pump(tester);
      expect(find.text('Review workout preferences'), findsOneWidget);
      expect(find.text('2-minute march'), findsNothing);
      expect(
        (await SharedPreferences.getInstance()).getString(
          SensitiveLocalStore.secureStateKey,
        ),
        isNot(contains('"eventId"')),
      );
    },
  );

  testWidgets(
    'a saved workout cannot resume if its remaining movements need the floor',
    (tester) async {
      final active = FrozenWorkout(
        eventId: 'saved-floor-attempt',
        workout: const PlannedWorkout(
          seq: 1,
          title: 'Saved floor workout',
          estMinutes: 10,
          exercises: [
            PlannedExercise(
              'Plank',
              '15 sec',
              'Hold on the floor.',
              CupertinoIcons.person,
            ),
          ],
        ),
        startedAt: DateTime.now(),
        energy: 'Medium',
        checkpoint: 2,
      );
      _seed(
        journey: const JourneyProgress(
          journeyId: 'fresh-journey',
          completedCheckpoints: 1,
          points: 100,
        ),
        profile: _profile.copyWith(floorAllowed: false),
        active: active,
      );
      await tester.pumpWidget(const PurrfitApp());
      await _pump(tester);
      await _tap(tester, 'Resume workout');
      expect(find.byType(WorkoutScreen), findsNothing);
      expect(find.text('Review workout preferences'), findsOneWidget);
      expect((await _saved())['active']['eventId'], active.eventId);

      await _tap(tester, 'Discard saved workout');
      await tester.tap(find.text('Discard workout'));
      await _pump(tester);
      final saved = await _saved();
      expect(saved['active'], isNull);
      expect(_savedJourney(saved).completedCheckpoints, 1);
      expect(_savedJourney(saved).points, 100);
    },
  );

  testWidgets(
    'corrupt saved journey is kept and cannot be overwritten by onboarding',
    (tester) async {
      SharedPreferences.setMockInitialValues({
        SensitiveLocalStore.secureStateKey: '{broken',
      });
      await tester.pumpWidget(const PurrfitApp());
      await _pump(tester);
      expect(find.text('Your saved journey is protected'), findsOneWidget);
      expect(find.text('Meet my journey'), findsNothing);
      expect(
        (await SharedPreferences.getInstance()).getString(
          SensitiveLocalStore.secureStateKey,
        ),
        '{broken',
      );
    },
  );

  testWidgets('path extends into chapter five without time locks', (
    tester,
  ) async {
    _seed(
      journey: const JourneyProgress(
        journeyId: 'fresh-journey',
        completedCheckpoints: 24,
        points: 2400,
      ),
    );
    await tester.pumpWidget(const PurrfitApp());
    await _pump(tester);
    expect(find.text('Start checkpoint 25'), findsOneWidget);
    await _tap(tester, 'Start checkpoint 25');
    expect(
      tester
          .widget<WorkoutScreen>(find.byType(WorkoutScreen))
          .session
          .checkpoint,
      25,
    );
  });

  testWidgets('history deletion leaves earned checkpoint intact', (
    tester,
  ) async {
    final entry = WorkoutHistoryEntry(
      id: 'earned',
      journeyId: 'fresh-journey',
      checkpoint: 1,
      title: 'Earned workout',
      source: WorkoutSource.checkpoint,
      startedAt: DateTime.now().subtract(const Duration(minutes: 2)),
      completedAt: DateTime.now(),
      activeSeconds: 120,
      plannedMinutes: 10,
      completedExerciseCount: 3,
      totalExerciseCount: 4,
      skippedExerciseCount: 1,
      energy: 'Medium',
      points: 100,
    );
    _seed(
      journey: const JourneyProgress(
        journeyId: 'fresh-journey',
        completedCheckpoints: 1,
        points: 100,
      ),
      history: [entry],
    );
    await tester.pumpWidget(const PurrfitApp());
    await _pump(tester);
    await tester.tap(find.text('Report').last);
    await _pump(tester);
    await tester.tap(find.text('History'));
    await _pump(tester);
    await _tap(tester, 'Delete entry');
    await tester.tap(find.text('Delete'));
    await _pump(tester);
    expect(_savedJourney(await _saved()).completedCheckpoints, 1);
    expect((await _saved())['history'], isEmpty);
  });
}
