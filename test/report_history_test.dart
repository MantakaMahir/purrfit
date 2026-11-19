import 'package:flutter_test/flutter_test.dart';
import 'package:purrfit/workout_engine.dart';

void main() {
  group('WorkoutActiveTimer', () {
    test('background time is not counted as active workout time', () {
      final t0 = DateTime(2026, 7, 18, 9);
      final timer = WorkoutActiveTimer();
      timer.resume(t0);
      timer.pause(t0.add(const Duration(seconds: 60))); // 60s active
      // App backgrounded for an hour - no resume, so no accrual.
      timer.resume(t0.add(const Duration(minutes: 61)));
      timer.pause(t0.add(const Duration(minutes: 61, seconds: 30))); // +30s
      expect(timer.seconds(), 90); // not 3690
    });

    test('double resume does not double count', () {
      final t0 = DateTime(2026, 7, 18, 9);
      final timer = WorkoutActiveTimer();
      timer.resume(t0);
      timer.resume(t0.add(const Duration(seconds: 30))); // ignored
      timer.pause(t0.add(const Duration(seconds: 60)));
      expect(timer.seconds(), 60);
    });

    test('is clamped to a sane maximum', () {
      final timer = WorkoutActiveTimer(maxSeconds: 100);
      final t0 = DateTime(2026, 7, 18, 9);
      timer.resume(t0);
      timer.pause(t0.add(const Duration(hours: 5)));
      expect(timer.seconds(), 100);
    });
  });

  group('legacy history migration', () {
    test('does not fabricate titles, durations or calories', () {
      final entries = migrateLegacyWorkoutHistory(
        workoutDates: {'2026-07-10', '2026-07-12'},
        activityMinutesByDate: {'2026-07-12': 18}, // only one has minutes
      );
      expect(entries.length, 2);
      final first = entries.first;
      expect(first.title, 'Workout completed');
      expect(first.legacy, isTrue);
      expect(first.activeSeconds, isNull); // duration unavailable
      expect(first.activeMinutes, isNull);
      // Planned minutes only where they actually existed.
      final withMinutes = entries.firstWhere(
        (e) => e.localDateKey == '2026-07-12',
      );
      expect(withMinutes.plannedMinutes, 18);
      final withoutMinutes = entries.firstWhere(
        (e) => e.localDateKey == '2026-07-10',
      );
      expect(withoutMinutes.plannedMinutes, isNull);
    });

    test('legacy records do not claim a current-plan identity', () {
      final entries = migrateLegacyWorkoutHistory(
        workoutDates: {'2026-07-10'},
        activityMinutesByDate: const {},
      );
      expect(entries.single.planId, isNull);
      expect(entries.single.planStartDate, isNull);
    });
  });

  group('WorkoutHistoryEntry JSON', () {
    test('round-trips including nullable durations', () {
      final e = WorkoutHistoryEntry(
        id: 'w-1',
        planId: 'p1',
        sessionId: 's1',
        title: 'Full Body A',
        source: WorkoutSource.checkpoint,
        journeyId: 'journey-1',
        checkpoint: 4,
        startedAt: DateTime(2026, 7, 18, 9),
        completedAt: DateTime(2026, 7, 18, 9, 20),
        activeSeconds: 1080,
        plannedMinutes: 20,
        completedExerciseCount: 6,
        totalExerciseCount: 7,
        skippedExerciseCount: 1,
        energy: 'Medium',
        focusCategories: const ['chest'],
        points: 80,
      );
      final back = WorkoutHistoryEntry.fromJson(e.toJson())!;
      expect(back.id, 'w-1');
      expect(back.source, WorkoutSource.checkpoint);
      expect(back.journeyId, 'journey-1');
      expect(back.checkpoint, 4);
      expect(back.activeSeconds, 1080);
      expect(back.activeMinutes, 18);
      expect(back.skippedExerciseCount, 1);
      expect(back.energy, 'Medium');
      expect(back.focusCategories, ['chest']);
    });

    test('a null-duration entry survives the round-trip', () {
      final e = WorkoutHistoryEntry(
        id: 'legacy-2026-07-10',
        title: 'Workout completed',
        source: WorkoutSource.plan,
        startedAt: DateTime(2026, 7, 10),
        completedAt: DateTime(2026, 7, 10),
        legacy: true,
      );
      final back = WorkoutHistoryEntry.fromJson(e.toJson())!;
      expect(back.activeSeconds, isNull);
      expect(back.legacy, isTrue);
    });
  });

  group('report period ranges (local calendar)', () {
    final wed = DateTime(2026, 7, 15, 14); // a Wednesday afternoon
    test('today is a single day', () {
      final r = reportPeriodRange(ReportPeriod.today, wed);
      expect(r.days, 1);
      expect(r.start, DateTime(2026, 7, 15));
      expect(r.end, DateTime(2026, 7, 15));
    });
    test('this week starts Monday and ends today', () {
      final r = reportPeriodRange(ReportPeriod.thisWeek, wed);
      expect(r.start, DateTime(2026, 7, 13)); // Monday
      expect(r.end, DateTime(2026, 7, 15));
      expect(r.days, 3);
    });
    test('4 and 12 weeks are rolling windows ending today', () {
      expect(reportPeriodRange(ReportPeriod.fourWeeks, wed).days, 28);
      expect(reportPeriodRange(ReportPeriod.twelveWeeks, wed).days, 84);
    });
  });

  group('insights', () {
    test('no insight before a completed workout', () {
      expect(
        reportInsight(
          period: ReportPeriod.thisWeek,
          completedInPeriod: 0,
          completedMinutes: const [],
          mostConsistentWeekday: null,
        ),
        isNull,
      );
    });

    test('reports only completed work, with no planned denominator', () {
      expect(
        reportInsight(
          period: ReportPeriod.thisWeek,
          completedInPeriod: 3,
          completedMinutes: const [18, 20, 16],
          mostConsistentWeekday: 'Tuesday',
        ),
        'Tuesday has been your most consistent workout day.',
      );
      expect(
        reportInsight(
          period: ReportPeriod.fourWeeks,
          completedInPeriod: 1,
          completedMinutes: const [18],
          mostConsistentWeekday: null,
        ),
        'You completed a workout in this period.',
      );
    });
  });

  group('BMI (adult screening)', () {
    test('computes metric BMI', () {
      final bmi = computeBmi(weightKg: 68, heightCm: 170)!;
      expect(bmi, closeTo(23.5, 0.1));
    });

    test('rejects non-positive inputs', () {
      expect(computeBmi(weightKg: 0, heightCm: 170), isNull);
      expect(computeBmi(weightKg: 68, heightCm: 0), isNull);
    });

    test('categories use standard adult boundaries', () {
      expect(bmiCategory(18.4), BmiCategory.underweight);
      expect(bmiCategory(18.5), BmiCategory.healthy);
      expect(bmiCategory(24.9), BmiCategory.healthy);
      expect(bmiCategory(25.0), BmiCategory.overweight);
      expect(bmiCategory(29.9), BmiCategory.overweight);
      expect(bmiCategory(30.0), BmiCategory.obese);
    });
  });
}
