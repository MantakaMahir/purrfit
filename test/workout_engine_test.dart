import 'package:flutter/widgets.dart' show IconData;
import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:purrfit/workout_engine.dart';

void main() {
  group('journey metadata', () {
    test('chapter and role labels repeat every six checkpoints', () {
      expect(checkpointsPerChapter, 6);
      expect(launchCheckpointCount, 24);
      expect(checkpointTitle(1), checkpointTitle(7));
      expect(checkpointTitle(6), checkpointTitle(24));
      expect(chapterTitle(1), isNot(chapterTitle(2)));
      expect(const JourneyProgress(completedCheckpoints: 6).chapter, 2);
    });

    test('progression changes only from feedback and remains bounded', () {
      var progress = const JourneyProgress(journeyId: 'j');
      for (var checkpoint = 1; checkpoint <= 3; checkpoint++) {
        progress = progress.completeCheckpoint(
          checkpoint: checkpoint,
          feedback: 'good_fit',
          pointsEarned: 10,
        );
      }
      expect(progress.difficulty, 1);
      expect(progress.points, 30);
      final duplicate = progress.completeCheckpoint(
        checkpoint: 3,
        feedback: 'too_easy',
        pointsEarned: 99,
      );
      expect(duplicate, same(progress));
      expect(
        advanceJourney(
          progress,
          checkpoint: 5,
          feedback: 'too_hard',
          pointsEarned: 1,
        ),
        same(progress),
      );
      progress = progress.completeCheckpoint(
        checkpoint: 4,
        feedback: 'too_hard',
        pointsEarned: 0,
      );
      expect(progress.difficulty, 0);
      expect(progress.comfortableCount, 0);
      expect(
        JourneyProgress.fromJson({
          ...progress.toJson(),
          'difficulty': 50,
        }).difficulty,
        2,
      );
    });

    test('completion counts main exercises only, never warm-up/cool-down', () {
      final workout = PlannedWorkout(
        seq: 1,
        title: 'test',
        estMinutes: 10,
        exercises: const [
          PlannedExercise('Warm-up flow', '3 min', '', IconData(0)),
          PlannedExercise('Move A', '2 x 8', '', IconData(0)),
          PlannedExercise('Move B', '2 x 8', '', IconData(0)),
          PlannedExercise('Cool-down stretch', '2 min', '', IconData(0)),
        ],
      );
      expect(qualifiesCheckpoint(workout, {1, 2}), isFalse);
      expect(qualifiesCheckpoint(workout, {2}), isTrue);
      expect(qualifiesCheckpoint(workout, {0, 3}), isTrue);
    });

    test('frozen workout and journey round-trip through JSON', () {
      final workout = generateCheckpointWorkout(
        profile: const OnboardingProfile(safetyReviewed: true),
        progress: const JourneyProgress(),
      );
      final restored = PlannedWorkout.fromJson(workout.toJson());
      expect(restored.seq, workout.seq);
      expect(restored.title, workout.title);
      expect(restored.estMinutes, workout.estMinutes);
      expect(
        restored.exercises.map((e) => [e.id, e.target, e.detail]).toList(),
        workout.exercises.map((e) => [e.id, e.target, e.detail]).toList(),
      );
      expect(restored.exercises.first.isMain, isFalse);
      expect(restored.exercises[1].isMain, isTrue);
      expect(
        JourneyProgress.fromJson(
          const JourneyProgress(
            journeyId: 'x',
            completedCheckpoints: 2,
          ).toJson(),
        ).journeyId,
        'x',
      );
    });
  });

  group('date utilities', () {
    test('local date keys reject invalid calendar dates', () {
      expect(dateKey(DateTime(2026, 7, 13)), '2026-07-13');
      expect(parseDateKey('2026-02-30'), isNull);
    });
    test('midnight rollover includes the documented one-second buffer', () {
      expect(
        durationUntilNextLocalMidnight(DateTime(2026, 7, 13, 23, 59, 58)),
        const Duration(seconds: 3),
      );
    });
  });
}
