import 'package:flutter_test/flutter_test.dart';
import 'package:purrfit/workout_engine.dart';

void main() {
  test(
    'all launch ordinals generate workouts with stable exercise metadata',
    () {
      final profile = const OnboardingProfile(safetyReviewed: true);
      for (var ordinal = 1; ordinal <= launchCheckpointCount; ordinal++) {
        final workout = generateCheckpointWorkout(
          profile: profile,
          progress: JourneyProgress(completedCheckpoints: ordinal - 1),
        );
        expect(workout.seq, ordinal);
        expect(workout.exercises.first.isMain, isFalse);
        expect(workout.exercises.last.isMain, isFalse);
        expect(workout.exercises.where((e) => e.isMain), isNotEmpty);
        expect(
          workout.exercises
              .where((e) => e.isMain)
              .every((e) => e.id.isNotEmpty),
          isTrue,
        );
      }
    },
  );

  test(
    'same checkpoint stays at capability tier unless feedback changes it',
    () {
      final p = const OnboardingProfile(
        safetyReviewed: true,
        capability: Capability(push: 0, lower: 0, core: 0, conditioning: 0),
      );
      final first = generateCheckpointWorkout(
        profile: p,
        progress: const JourneyProgress(),
      );
      final afterOrdinalOnly = generateCheckpointWorkout(
        profile: p,
        progress: const JourneyProgress(completedCheckpoints: 6),
      );
      expect(
        first.exercises.where((e) => e.isMain).map((e) => e.name),
        afterOrdinalOnly.exercises.where((e) => e.isMain).map((e) => e.name),
      );
      final lower = generateCheckpointWorkout(
        profile: p,
        progress: const JourneyProgress(difficulty: -2),
      );
      expect(lower.exercises.where((e) => e.isMain), isNotEmpty);
    },
  );

  test('all-skip main exercises cannot qualify', () {
    final workout = generateCheckpointWorkout(
      profile: const OnboardingProfile(safetyReviewed: true),
      progress: const JourneyProgress(),
    );
    final mainIndices = [
      for (var i = 0; i < workout.exercises.length; i++)
        if (workout.exercises[i].isMain) i,
    ];
    final skipped = mainIndices.toSet();
    expect(qualifiesCheckpoint(workout, skipped), isFalse);
    skipped.removeAll(mainIndices.take((mainIndices.length / 2).ceil()));
    expect(qualifiesCheckpoint(workout, skipped), isTrue);
  });

  test('journey extends and roundtrips beyond the initial 24 checkpoints', () {
    var progress = const JourneyProgress(journeyId: 'extending');
    for (var i = 1; i <= 48; i++) {
      final workout = generateCheckpointWorkout(
        profile: const OnboardingProfile(safetyReviewed: true),
        progress: progress,
      );
      expect(workout.seq, i);
      progress = advanceJourney(
        progress,
        checkpoint: i,
        feedback: 'not_rated',
        pointsEarned: 100,
      );
      progress = JourneyProgress.fromJson(progress.toJson());
    }
    expect(progress.nextCheckpoint, 49);
    expect(progress.chapter, 9);
    expect(progress.points, 4800);
  });

  test('a partial hard attempt reduces load without awarding progress', () {
    final progress = recordJourneyAttempt(
      const JourneyProgress(),
      checkpoint: 1,
      qualified: false,
      feedback: 'too_hard',
    );
    expect(progress.difficulty, -1);
    expect(progress.completedCheckpoints, 0);
    expect(progress.points, 0);
    expect(
      recordJourneyAttempt(
        progress,
        checkpoint: 0,
        qualified: true,
        feedback: 'too_easy',
      ),
      same(progress),
    );
  });
}
