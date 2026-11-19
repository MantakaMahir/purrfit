import 'package:flutter_test/flutter_test.dart';
import 'package:purrfit/workout_engine.dart';

void main() {
  test('a completed checkpoint advances once and awards 100 points', () {
    var progress = const JourneyProgress(journeyId: 'journey');
    for (var attempt = 0; attempt < 3; attempt++) {
      progress = recordJourneyAttempt(
        progress,
        checkpoint: 1,
        qualified: true,
        feedback: 'good_fit',
      );
    }
    expect(progress.completedCheckpoints, 1);
    expect(progress.points, 100);
    expect(progress.comfortableCount, 1);
  });

  test('an already-earned checkpoint never pays out twice', () {
    const earned = JourneyProgress(
      journeyId: 'journey',
      completedCheckpoints: 1,
      points: 100,
    );
    final replay = recordJourneyAttempt(
      earned,
      checkpoint: 1,
      qualified: true,
      feedback: 'good_fit',
    );
    expect(replay.completedCheckpoints, 1);
    expect(replay.points, 100);
  });

  test(
    'partial attempt, optional practice, and pain earn no checkpoint points',
    () {
      const base = JourneyProgress(journeyId: 'journey');
      expect(
        recordJourneyAttempt(
          base,
          checkpoint: 1,
          qualified: false,
          feedback: 'too_hard',
        ).points,
        0,
      );
      expect(
        recordJourneyAttempt(
          base,
          checkpoint: null,
          qualified: true,
          feedback: 'good_fit',
        ),
        same(base),
      );
      final pain = recordJourneyAttempt(
        base,
        checkpoint: 1,
        qualified: true,
        feedback: 'pain',
      );
      expect(pain.completedCheckpoints, 0);
      expect(pain.points, 0);
      expect(pain.difficulty, -1);
    },
  );

  test('a hard attempt lowers difficulty without moving the path', () {
    final progress = recordJourneyAttempt(
      const JourneyProgress(journeyId: 'journey'),
      checkpoint: 1,
      qualified: false,
      feedback: 'too_hard',
    );
    expect(progress.completedCheckpoints, 0);
    expect(progress.difficulty, -1);
  });
}
