import 'package:flutter_test/flutter_test.dart';
import 'package:purrfit/workout_engine.dart';

final _reviewed = OnboardingProfile(
  safetyReviewed: true,
  capability: const Capability(push: 3, lower: 2, core: 2, conditioning: 2),
);

void main() {
  test('safety review and red flags gate generation', () {
    expect(
      () => generateCheckpointWorkout(
        profile: const OnboardingProfile(),
        progress: const JourneyProgress(),
      ),
      throwsStateError,
    );
    expect(
      () => generateCheckpointWorkout(
        profile: _reviewed.copyWith(
          safety: const SafetyProfile(chestPainOrFainting: true),
        ),
        progress: const JourneyProgress(),
      ),
      throwsStateError,
    );
    expect(
      OnboardingProfile.fromJson({'onboardingVersion': 2}).safetyReviewed,
      isFalse,
    );
  });

  test('profile JSON retains onboarding facts and safety review', () {
    final profile = _reviewed.copyWith(
      bodyModel: BodyModel.feminine,
      focusAreas: {FocusArea.core, FocusArea.chest},
      equipment: {EquipmentItem.floorSpace},
      heightCm: 170,
      weightKg: 68,
      preferredTimeMinutes: 1140,
    );
    final back = OnboardingProfile.fromJson(profile.toJson());
    expect(back.bodyModel, BodyModel.feminine);
    expect(back.focusAreas, profile.focusAreas);
    expect(back.equipment, profile.equipment);
    expect(back.heightCm, 170);
    expect(back.weightKg, 68);
    expect(back.preferredTimeMinutes, 1140);
    expect(back.safetyReviewed, isTrue);
    expect(back.onboardingVersion, kOnboardingVersion);
  });

  test(
    'equipment, impact, and floor constraints apply across all 24 checkpoints',
    () {
      final constrained = _reviewed.copyWith(
        floorAllowed: false,
        impact: ImpactPreference.lowImpact,
        equipment: const {EquipmentItem.floorSpace},
        capability: const Capability(
          push: 6,
          lower: 4,
          core: 3,
          conditioning: 3,
        ),
      );
      for (var n = 1; n <= launchCheckpointCount; n++) {
        final w = generateCheckpointWorkout(
          profile: constrained,
          progress: JourneyProgress(completedCheckpoints: n - 1),
        );
        expect(w.seq, n);
        expect(w.exercises.first.name, 'Standing warm-up flow');
        for (final e in w.exercises.where((e) => e.isMain)) {
          expect(
            {
              'Plank',
              'Dead bug',
              'Bird dog',
              'Glute bridge',
              'Push-up',
              'Knee push-up',
              'Jumping jacks',
              'Chair squat',
              'Wall push-up',
              'Incline push-up',
              'Towel row',
              'Doorway row',
            },
            isNot(contains(e.name)),
            reason: 'checkpoint $n: ${e.name}',
          );
        }
      }
    },
  );

  test(
    'checkpoint ordinal does not automatically advance exercise difficulty',
    () {
      final profile = _reviewed.copyWith(
        capability: const Capability(
          push: 2,
          lower: 2,
          core: 1,
          conditioning: 1,
        ),
      );
      List<String> mains(int ordinal) => generateCheckpointWorkout(
        profile: profile,
        progress: JourneyProgress(completedCheckpoints: ordinal - 1),
      ).exercises.where((e) => e.isMain).map((e) => e.name).toList();
      expect(mains(1), mains(7));
      expect(mains(1), mains(13));
    },
  );

  test(
    'generation safely falls back when preferred equipment is unavailable',
    () {
      final profile = _reviewed.copyWith(
        floorAllowed: false,
        equipment: const {EquipmentItem.floorSpace},
        focusAreas: {FocusArea.back},
        capability: const Capability(push: 0, lower: 0),
      );
      final workout = generateCheckpointWorkout(
        profile: profile,
        progress: const JourneyProgress(),
      );
      expect(workout.exercises.where((e) => e.isMain), isNotEmpty);
      expect(
        workout.exercises
            .where((e) => e.isMain)
            .every((e) => !e.name.contains('row')),
        isTrue,
      );
    },
  );
}
