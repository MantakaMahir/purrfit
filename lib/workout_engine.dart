import 'package:flutter/cupertino.dart';

/// Purrfit deterministic workout engine.
///
/// Pure deterministic checkpoint workout generation and local report models.

enum WorkoutGoal { consistency, fatLoss, strength, mobility }

extension WorkoutGoalX on WorkoutGoal {
  /// Short label for UI surfaces.
  String get title => switch (this) {
    WorkoutGoal.consistency => 'Consistency',
    WorkoutGoal.fatLoss => 'Fat loss & fitness',
    WorkoutGoal.strength => 'Strength',
    WorkoutGoal.mobility => 'Mobility',
  };
}

/// Maps the onboarding goal chips to engine goals.
WorkoutGoal goalFromLabel(String label) => switch (label) {
  'Lose fat / improve fitness' => WorkoutGoal.fatLoss,
  'Build strength' => WorkoutGoal.strength,
  'Improve mobility' => WorkoutGoal.mobility,
  _ => WorkoutGoal.consistency,
};

/// One concrete exercise inside a frozen workout snapshot.
class PlannedExercise {
  const PlannedExercise(this.name, this.target, this.detail, this.icon);
  final String name;
  final String target;
  final String detail;
  final IconData icon;
  String get id => _exerciseCatalog[name]?.id ?? _stableId(name);
  bool get isMain =>
      !_warmupNames.contains(name) && !_cooldownNames.contains(name);
}

/// One frozen checkpoint workout. seq is the 1-based checkpoint ordinal.
class PlannedWorkout {
  const PlannedWorkout({
    required this.seq,
    required this.title,
    required this.estMinutes,
    required this.exercises,
  });
  final int seq;
  final String title;
  final int estMinutes;
  final List<PlannedExercise> exercises;
  Map<String, dynamic> toJson() => {
    'seq': seq,
    'title': title,
    'estMinutes': estMinutes,
    'exercises': exercises
        .map(
          (e) => {
            'id': e.id,
            'name': e.name,
            'target': e.target,
            'detail': e.detail,
          },
        )
        .toList(),
  };
  static PlannedWorkout fromJson(Map<String, dynamic> json) => PlannedWorkout(
    seq: (json['seq'] as num?)?.toInt() ?? 1,
    title: json['title'] as String? ?? 'Workout',
    estMinutes: (json['estMinutes'] as num?)?.toInt() ?? 0,
    exercises: (json['exercises'] as List? ?? const [])
        .whereType<Map>()
        .map((raw) {
          final e = raw.cast<String, dynamic>();
          final name = e['name'] as String? ?? e['id'] as String? ?? 'Exercise';
          return PlannedExercise(
            name,
            e['target'] as String? ?? '',
            e['detail'] as String? ?? '',
            _exerciseIcon(name),
          );
        })
        .toList(growable: false),
  );
}

const _warmupNames = {'Warm-up flow', 'Standing warm-up flow'};
const _cooldownNames = {'Cool-down stretch', 'Standing cool-down stretch'};

// ---------------------------------------------------------------------------
// Each movement pattern is ordered from easiest to hardest.
// ---------------------------------------------------------------------------

enum _Kind { reps, hold, duration }

enum _Pattern { squat, hinge, lunge, push, pull, core, conditioning }

class _Move {
  const _Move(
    this.name,
    this.detail,
    this.icon, {
    this.kind = _Kind.reps,
    this.holdSec = 30,
  });

  final String name;
  final String detail;
  final IconData icon;
  final _Kind kind;
  final int holdSec;
}

const _squatIcon = CupertinoIcons.rectangle_stack_person_crop;
const _pushIcon = CupertinoIcons.arrow_up_circle;
const _pullIcon = CupertinoIcons.arrow_down_left_circle;
const _hingeIcon = CupertinoIcons.arrow_up_right_circle;
const _lungeIcon = CupertinoIcons.person_2;
const _coreIcon = CupertinoIcons.circle_grid_hex;
const _condIcon = CupertinoIcons.flame;

const Map<_Pattern, List<_Move>> _library = {
  _Pattern.squat: [
    _Move('Chair squat', 'Sit-to-stand, controlled', _squatIcon),
    _Move('Bodyweight squat', 'Full range, chest tall', _squatIcon),
    _Move('Tempo squat', '3s down, 1s up', _squatIcon),
    _Move('Squat pulse', 'Hold low, small pulses', _squatIcon),
    _Move('Split squat', 'Staggered stance, deep', _squatIcon),
  ],
  _Pattern.hinge: [
    _Move('Glute bridge', 'Squeeze at the top', _hingeIcon),
    _Move('Single-leg bridge march', 'Alternate legs, level hips', _hingeIcon),
    _Move('Hip hinge reach', 'Flat back, push hips back', _hingeIcon),
    _Move('Single-leg RDL', 'Balance and control', _hingeIcon),
    _Move('Good morning', 'Hands at head, hinge slow', _hingeIcon),
  ],
  _Pattern.lunge: [
    _Move('Assisted reverse lunge', 'Hold support for balance', _lungeIcon),
    _Move('Reverse lunge', 'Step back, control down', _lungeIcon),
    _Move('Forward lunge', 'Step and drive up', _lungeIcon),
    _Move('Walking lunge', 'Continuous steps', _lungeIcon),
    _Move('Bulgarian split squat', 'Rear foot on a chair', _lungeIcon),
  ],
  _Pattern.push: [
    _Move('Wall push-up', 'Stand tall, press away', _pushIcon),
    _Move('Incline push-up', 'Hands on couch or table', _pushIcon),
    _Move('Knee push-up', 'Knees down, tall body line', _pushIcon),
    _Move('Push-up', 'Full plank, chest to floor', _pushIcon),
    _Move('Tempo push-up', '3s lower, steady press', _pushIcon),
  ],
  _Pattern.pull: [
    _Move(
      'Superman hold',
      'Lift chest and legs',
      _pullIcon,
      kind: _Kind.hold,
      holdSec: 20,
    ),
    _Move('Superman pulls', 'Pull elbows back and down', _pullIcon),
    _Move('Doorway row', 'Lean back, pull chest in', _pullIcon),
    _Move('Towel row', 'Towel round a door, row in', _pullIcon),
    _Move('Feet-forward towel row', 'Lower angle, harder pull', _pullIcon),
  ],
  _Pattern.core: [
    _Move('Dead bug', 'Opposite arm and leg, slow', _coreIcon),
    _Move('Bird dog', 'Reach long, stay level', _coreIcon),
    _Move(
      'Knee plank',
      'Strong straight line',
      _coreIcon,
      kind: _Kind.hold,
      holdSec: 20,
    ),
    _Move(
      'Plank',
      'Brace, breathe, hold',
      _coreIcon,
      kind: _Kind.hold,
      holdSec: 30,
    ),
    _Move(
      'Hollow hold',
      'Low back pressed down',
      _coreIcon,
      kind: _Kind.hold,
      holdSec: 20,
    ),
  ],
  _Pattern.conditioning: [
    _Move(
      'March in place',
      'Easy steady pace',
      _condIcon,
      kind: _Kind.duration,
    ),
    _Move(
      'Step touch',
      'Side to side, arms move',
      _condIcon,
      kind: _Kind.duration,
    ),
    _Move(
      'Low-impact jacks',
      'Step out, arms overhead',
      _condIcon,
      kind: _Kind.duration,
    ),
    _Move('Fast feet', 'Quick light steps', _condIcon, kind: _Kind.duration),
    _Move(
      'Jumping jacks',
      'Full jacks, find a rhythm',
      _condIcon,
      kind: _Kind.duration,
    ),
  ],
};

const _warmup = _Move(
  'Warm-up flow',
  'Marches, arm circles, hip openers',
  CupertinoIcons.arrow_up_right_circle,
  kind: _Kind.duration,
);
const _standingWarmup = _Move(
  'Standing warm-up flow',
  'Marches, arm circles, hip openers',
  CupertinoIcons.arrow_up_right_circle,
  kind: _Kind.duration,
);
const _cooldown = _Move(
  'Cool-down stretch',
  'Cat-cow, hamstrings, chest opener',
  CupertinoIcons.leaf_arrow_circlepath,
  kind: _Kind.duration,
);
const _standingCooldown = _Move(
  'Standing cool-down stretch',
  'Standing hamstrings, chest opener, easy breathing',
  CupertinoIcons.leaf_arrow_circlepath,
  kind: _Kind.duration,
);

/// Full-body session templates. The plan rotates A → B → C across the sequence.
const List<(String, List<_Pattern>)> _templates = [
  (
    'Full Body A',
    [_Pattern.squat, _Pattern.push, _Pattern.core, _Pattern.conditioning],
  ),
  (
    'Full Body B',
    [_Pattern.hinge, _Pattern.pull, _Pattern.core, _Pattern.conditioning],
  ),
  (
    'Full Body C',
    [_Pattern.lunge, _Pattern.push, _Pattern.hinge, _Pattern.conditioning],
  ),
];

class _GoalParams {
  const _GoalParams({
    required this.baseSets,
    required this.baseReps,
    required this.maxTier,
    required this.condSec,
  });

  final int baseSets;
  final int baseReps;
  final int maxTier; // cap on progression-chain difficulty
  final int condSec; // conditioning duration seconds
}

String _targetFor(_Move move, int sets, int reps, int condSec) =>
    switch (move.kind) {
      _Kind.reps => '$sets × $reps',
      _Kind.hold => '$sets × ${move.holdSec}s',
      _Kind.duration => '$condSec sec',
    };

/// yyyy-mm-dd key for a local calendar date.
String dateKey(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
Duration durationUntilNextLocalMidnight(DateTime now) => DateTime(
  now.year,
  now.month,
  now.day + 1,
).add(const Duration(seconds: 1)).difference(now);
bool isDateOnOrAfter(String date, String threshold) =>
    date.compareTo(threshold) >= 0;
DateTime? parseDateKey(String? key) {
  if (key == null || !RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(key)) return null;
  final parts = key.split('-');
  final date = DateTime(
    int.parse(parts[0]),
    int.parse(parts[1]),
    int.parse(parts[2]),
  );
  return dateKey(date) == key ? date : null;
}

int daysBetweenKey(String a, DateTime b) {
  final date = parseDateKey(a);
  if (date == null) return 0;
  return DateTime(b.year, b.month, b.day).difference(date).inDays;
}

bool qualifiesCheckpoint(PlannedWorkout workout, Set<int> skipped) {
  final mains = [
    for (var i = 0; i < workout.exercises.length; i++)
      if (workout.exercises[i].isMain) i,
  ];
  return mains.isNotEmpty &&
      mains.where((i) => !skipped.contains(i)).length >=
          (mains.length / 2).ceil();
}

/// An optional activity independent of journey progress and calendar dates.
class QuickActivity {
  const QuickActivity(this.id, this.title, this.detail, this.icon, this.points);
  final String id;
  final String title;
  final String detail;
  final IconData icon;
  final int points;
}

const List<QuickActivity> quickActivities = [
  QuickActivity(
    'sit_to_stand',
    '10 sit-to-stands',
    'Use a sturdy chair',
    CupertinoIcons.rectangle_stack_person_crop,
    40,
  ),
  QuickActivity(
    'march',
    '2-minute march',
    'Move at an easy pace',
    CupertinoIcons.flame,
    40,
  ),
  QuickActivity(
    'bridge',
    '20 glute bridges',
    'Squeeze gently at the top',
    CupertinoIcons.arrow_up_right_circle,
    50,
  ),
  QuickActivity(
    'stretch',
    '40-second chest stretch',
    'Open the chest and breathe',
    CupertinoIcons.leaf_arrow_circlepath,
    30,
  ),
  QuickActivity(
    'calf_raises',
    '15 calf raises',
    'Slow and controlled',
    CupertinoIcons.arrow_up_circle,
    40,
  ),
];

// ---------------------------------------------------------------------------
// Energy adjustment and deterministic workout rewards.
// ---------------------------------------------------------------------------

PlannedExercise _scaleSets(PlannedExercise e, int delta) {
  final m = RegExp(r'^(\d+) × (.+)$').firstMatch(e.target);
  if (m == null) return e; // durations/holds like "30 sec" stay as-is
  final sets = (int.parse(m.group(1)!) + delta).clamp(1, 6);
  return PlannedExercise(e.name, '$sets × ${m.group(2)}', e.detail, e.icon);
}

/// Applies a small deterministic set adjustment to a frozen workout.
PlannedWorkout adjustWorkoutForEnergy(PlannedWorkout w, String energy) {
  if (energy == 'Medium') return w;
  final delta = energy == 'Low' ? -1 : 1;
  final exercises = w.exercises.map((e) => _scaleSets(e, delta)).toList();
  return PlannedWorkout(
    seq: w.seq,
    title: w.title,
    estMinutes: (w.estMinutes + delta * 2).clamp(8, 60),
    exercises: exercises,
  );
}

/// A deterministic variable point bonus (20-80 in steps of 5).
int workoutBonusPoints(String seed) {
  final h = seed.hashCode & 0x7fffffff;
  return 20 + (h % 13) * 5;
}

// ---------------------------------------------------------------------------
// Optional extra workouts do not affect journey progress.
// ---------------------------------------------------------------------------

class SpecializedWorkout {
  const SpecializedWorkout({
    required this.name,
    required this.focus,
    required this.icon,
    required this.estMinutes,
    required this.exercises,
  });

  final String name;
  final String focus;
  final IconData icon;
  final int estMinutes;
  final List<PlannedExercise> exercises;
}

const int bonusWorkoutPoints = 60;

const List<SpecializedWorkout> _specialized = [
  SpecializedWorkout(
    name: 'Legs',
    focus: 'Quads, glutes, calves',
    icon: CupertinoIcons.rectangle_stack_person_crop,
    estMinutes: 14,
    exercises: [
      PlannedExercise(
        'Bodyweight squat',
        '3 × 12',
        'Full range, chest tall',
        _squatIcon,
      ),
      PlannedExercise(
        'Reverse lunge',
        '3 × 10',
        '5 each side, controlled',
        _lungeIcon,
      ),
      PlannedExercise(
        'Glute bridge',
        '3 × 15',
        'Squeeze at the top',
        _hingeIcon,
      ),
      PlannedExercise(
        'Calf raises',
        '3 × 15',
        'Slow up, slow down',
        _squatIcon,
      ),
    ],
  ),
  SpecializedWorkout(
    name: 'Chest',
    focus: 'Chest and triceps push',
    icon: CupertinoIcons.arrow_up_circle,
    estMinutes: 12,
    exercises: [
      PlannedExercise(
        'Incline push-up',
        '3 × 10',
        'Hands on couch or table',
        _pushIcon,
      ),
      PlannedExercise(
        'Knee push-up',
        '3 × 10',
        'Knees down, tall body line',
        _pushIcon,
      ),
      PlannedExercise(
        'Push-up',
        '3 × 8',
        'Full plank, chest to floor',
        _pushIcon,
      ),
      PlannedExercise('Plank', '3 × 30s', 'Brace and breathe', _coreIcon),
    ],
  ),
  SpecializedWorkout(
    name: 'Back',
    focus: 'Upper back and posture',
    icon: CupertinoIcons.arrow_down_left_circle,
    estMinutes: 12,
    exercises: [
      PlannedExercise(
        'Superman pulls',
        '3 × 12',
        'Pull elbows back and down',
        _pullIcon,
      ),
      PlannedExercise(
        'Doorway row',
        '3 × 12',
        'Lean back, pull chest in',
        _pullIcon,
      ),
      PlannedExercise(
        'Superman hold',
        '3 × 20s',
        'Lift chest and legs',
        _pullIcon,
      ),
      PlannedExercise(
        'Bird dog',
        '3 × 10',
        'Reach long, stay level',
        _coreIcon,
      ),
    ],
  ),
  SpecializedWorkout(
    name: 'Arms',
    focus: 'Biceps and triceps',
    icon: CupertinoIcons.bolt_fill,
    estMinutes: 11,
    exercises: [
      PlannedExercise(
        'Chair dips',
        '3 × 10',
        'Elbows back, chest tall',
        _pushIcon,
      ),
      PlannedExercise(
        'Diamond push-up',
        '3 × 8',
        'Hands close, triceps focus',
        _pushIcon,
      ),
      PlannedExercise(
        'Towel row',
        '3 × 12',
        'Towel round a door, curl in',
        _pullIcon,
      ),
      PlannedExercise('Incline push-up', '2 × 12', 'Steady tempo', _pushIcon),
    ],
  ),
  SpecializedWorkout(
    name: 'Core',
    focus: 'Abs and stability',
    icon: CupertinoIcons.circle_grid_hex,
    estMinutes: 10,
    exercises: [
      PlannedExercise(
        'Dead bug',
        '3 × 10',
        'Opposite arm and leg, slow',
        _coreIcon,
      ),
      PlannedExercise('Plank', '3 × 30s', 'Strong straight line', _coreIcon),
      PlannedExercise(
        'Bird dog',
        '3 × 10',
        'Reach long, stay level',
        _coreIcon,
      ),
      PlannedExercise(
        'Hollow hold',
        '3 × 20s',
        'Low back pressed down',
        _coreIcon,
      ),
    ],
  ),
  SpecializedWorkout(
    name: 'Cardio',
    focus: 'Heart and conditioning',
    icon: CupertinoIcons.flame_fill,
    estMinutes: 12,
    exercises: [
      PlannedExercise(
        'March in place',
        '60 sec',
        'Easy steady pace',
        _condIcon,
      ),
      PlannedExercise(
        'Low-impact jacks',
        '45 sec',
        'Step out, arms overhead',
        _condIcon,
      ),
      PlannedExercise('Fast feet', '45 sec', 'Quick light steps', _condIcon),
      PlannedExercise(
        'Step touch',
        '60 sec',
        'Side to side, arms move',
        _condIcon,
      ),
    ],
  ),
];

List<SpecializedWorkout> specializedWorkouts([OnboardingProfile? profile]) {
  if (profile == null) return _specialized;
  if (!profile.safetyReviewed || profile.blockedByRedFlag) return const [];
  return [
    for (final workout in _specialized)
      () {
        final exercises = workout.exercises
            .where((e) => _exerciseAllowed(e.name, profile))
            .toList();
        return exercises.isEmpty
            ? null
            : SpecializedWorkout(
                name: workout.name,
                focus: workout.focus,
                icon: workout.icon,
                estMinutes: workout.estMinutes,
                exercises: exercises,
              );
      }(),
  ].whereType<SpecializedWorkout>().toList();
}

// ---------------------------------------------------------------------------
// Purr levels - give accumulated points a purpose. Deterministic tiers unlock a
// title shown under the avatar. No backend, no randomness.
// ---------------------------------------------------------------------------

class PurrLevel {
  const PurrLevel(this.index, this.title, this.floor, this.ceil);

  final int index; // 1-based level number
  final String title;
  final int floor; // points at which this level starts
  final int ceil; // points at which the next level starts; -1 = max level

  bool get isMax => ceil < 0;

  /// Progress (0..1) through the current level toward the next one.
  double progress(int points) {
    if (isMax) return 1;
    final span = ceil - floor;
    if (span <= 0) return 1;
    return ((points - floor) / span).clamp(0.0, 1.0);
  }

  /// Points needed to reach the next level, or null at max.
  int? get nextAt => isMax ? null : ceil;
}

const List<(String, int)> _levelTable = [
  ('New Friend', 0),
  ('Warm-Up Buddy', 300),
  ('Training Partner', 800),
  ('Consistency Cat', 1600),
  ('Gym Cat', 3000),
  ('Purrfit Legend', 5000),
];

// ---------------------------------------------------------------------------
// Fitness fun facts - shown when the user taps the light-bulb next to Purr.
// ---------------------------------------------------------------------------

const List<String> funFacts = [
  'Muscle is metabolically active - building a little raises the calories you burn even at rest.',
  'Your heart is a muscle too. Regular movement makes each beat pump more blood with less effort.',
  'It takes about 3-4 weeks of consistency for a new habit to start feeling automatic.',
  'A 10-minute walk can boost your mood for up to two hours afterwards.',
  'Soreness usually peaks 24-48 hours after a workout - that is normal and fades as you adapt.',
  'You breathe out most of the fat you lose - it literally leaves as carbon dioxide.',
  'Strength gains in the first weeks are mostly your brain recruiting muscle better, not new muscle yet.',
  'Sleep is when muscle actually repairs and grows - rest days are part of the training.',
  'Standing up and stretching every 30 minutes counteracts a lot of sitting all day.',
  'Drinking water before meals and workouts helps energy, focus and recovery.',
  'Consistency beats intensity: three easy sessions a week outperform one brutal one you dread.',
  'Your body keeps burning extra calories for hours after a harder session - the afterburn effect.',
];

/// A fun fact by index (wraps around).
String funFactAt(int index) => funFacts[index % funFacts.length];

/// The Purr level for a given lifetime points total.
PurrLevel purrLevelFor(int points) {
  var idx = 0;
  for (var i = 0; i < _levelTable.length; i++) {
    if (points >= _levelTable[i].$2) idx = i;
  }
  final floor = _levelTable[idx].$2;
  final ceil = idx + 1 < _levelTable.length ? _levelTable[idx + 1].$2 : -1;
  return PurrLevel(idx + 1, _levelTable[idx].$1, floor, ceil);
}

// ===========================================================================
// Onboarding profile, exercise suitability catalog, and checkpoint journey.
// ===========================================================================

enum BodyModel { masculine, feminine, neutral }

enum FocusArea {
  fullBody,
  armsShoulders,
  chest,
  back,
  core,
  glutesLegs,
  cardio,
  mobility,
}

enum DailyActivityLevel { seated, light, moderate, veryActive }

enum EquipmentItem { floorSpace, wall, chair, couchTable, towelDoorway }

enum ImpactPreference { any, lowImpact }

class Capability {
  const Capability({
    this.push = 0,
    this.lower = 0,
    this.core = 0,
    this.conditioning = 0,
  });
  final int push;
  final int lower;
  final int core;
  final int conditioning;
  Capability copyWith({int? push, int? lower, int? core, int? conditioning}) =>
      Capability(
        push: push ?? this.push,
        lower: lower ?? this.lower,
        core: core ?? this.core,
        conditioning: conditioning ?? this.conditioning,
      );
  Map<String, dynamic> toJson() => {
    'push': push,
    'lower': lower,
    'core': core,
    'conditioning': conditioning,
  };
  static Capability fromJson(Map<String, dynamic>? j) => Capability(
    push: (j?['push'] as num?)?.toInt() ?? 0,
    lower: (j?['lower'] as num?)?.toInt() ?? 0,
    core: (j?['core'] as num?)?.toInt() ?? 0,
    conditioning: (j?['conditioning'] as num?)?.toInt() ?? 0,
  );
}

class SafetyProfile {
  const SafetyProfile({
    this.chestPainOrFainting = false,
    this.severeShortnessOfBreath = false,
    this.recentSurgeryNoClearance = false,
    this.pregnancyPostpartumNoClearance = false,
    this.doctorRestriction = false,
    this.injuryToAvoid = false,
  });
  final bool chestPainOrFainting,
      severeShortnessOfBreath,
      recentSurgeryNoClearance;
  final bool pregnancyPostpartumNoClearance, doctorRestriction, injuryToAvoid;
  bool get hasRedFlag =>
      chestPainOrFainting ||
      severeShortnessOfBreath ||
      recentSurgeryNoClearance ||
      pregnancyPostpartumNoClearance ||
      doctorRestriction ||
      injuryToAvoid;
  SafetyProfile copyWith({
    bool? chestPainOrFainting,
    bool? severeShortnessOfBreath,
    bool? recentSurgeryNoClearance,
    bool? pregnancyPostpartumNoClearance,
    bool? doctorRestriction,
    bool? injuryToAvoid,
  }) => SafetyProfile(
    chestPainOrFainting: chestPainOrFainting ?? this.chestPainOrFainting,
    severeShortnessOfBreath:
        severeShortnessOfBreath ?? this.severeShortnessOfBreath,
    recentSurgeryNoClearance:
        recentSurgeryNoClearance ?? this.recentSurgeryNoClearance,
    pregnancyPostpartumNoClearance:
        pregnancyPostpartumNoClearance ?? this.pregnancyPostpartumNoClearance,
    doctorRestriction: doctorRestriction ?? this.doctorRestriction,
    injuryToAvoid: injuryToAvoid ?? this.injuryToAvoid,
  );
  Map<String, dynamic> toJson() => {
    'chestPainOrFainting': chestPainOrFainting,
    'severeShortnessOfBreath': severeShortnessOfBreath,
    'recentSurgeryNoClearance': recentSurgeryNoClearance,
    'pregnancyPostpartumNoClearance': pregnancyPostpartumNoClearance,
    'doctorRestriction': doctorRestriction,
    'injuryToAvoid': injuryToAvoid,
  };
  static SafetyProfile fromJson(Map<String, dynamic>? j) => SafetyProfile(
    chestPainOrFainting: j?['chestPainOrFainting'] == true,
    severeShortnessOfBreath: j?['severeShortnessOfBreath'] == true,
    recentSurgeryNoClearance: j?['recentSurgeryNoClearance'] == true,
    pregnancyPostpartumNoClearance:
        j?['pregnancyPostpartumNoClearance'] == true,
    doctorRestriction: j?['doctorRestriction'] == true,
    injuryToAvoid: j?['injuryToAvoid'] == true,
  );
}

const int kOnboardingVersion = 3;

T _enumByName<T extends Enum>(List<T> values, Object? name, T fallback) {
  for (final value in values) {
    if (value.name == name) return value;
  }
  return fallback;
}

class OnboardingProfile {
  const OnboardingProfile({
    this.primaryGoal = WorkoutGoal.consistency,
    this.bodyModel = BodyModel.neutral,
    this.focusAreas = const {FocusArea.fullBody},
    this.capability = const Capability(),
    this.activityLevel = DailyActivityLevel.light,
    this.equipment = const {
      EquipmentItem.floorSpace,
      EquipmentItem.wall,
      EquipmentItem.chair,
      EquipmentItem.couchTable,
      EquipmentItem.towelDoorway,
    },
    this.impact = ImpactPreference.any,
    this.floorAllowed = true,
    this.sessionMinutes = 20,
    this.preferredTimeMinutes,
    this.heightCm,
    this.weightKg,
    this.safety = const SafetyProfile(),
    this.safetyReviewed = false,
    this.onboardingVersion = kOnboardingVersion,
  });
  final WorkoutGoal primaryGoal;
  final BodyModel bodyModel;
  final Set<FocusArea> focusAreas;
  final Capability capability;
  final DailyActivityLevel activityLevel;
  final Set<EquipmentItem> equipment;
  final ImpactPreference impact;
  final bool floorAllowed;
  final int sessionMinutes;
  final int? preferredTimeMinutes;
  final double? heightCm, weightKg;
  final SafetyProfile safety;
  final bool safetyReviewed;
  final int onboardingVersion;
  bool get blockedByRedFlag => safety.hasRedFlag;

  OnboardingProfile copyWith({
    WorkoutGoal? primaryGoal,
    BodyModel? bodyModel,
    Set<FocusArea>? focusAreas,
    Capability? capability,
    DailyActivityLevel? activityLevel,
    Set<EquipmentItem>? equipment,
    ImpactPreference? impact,
    bool? floorAllowed,
    int? sessionMinutes,
    Object? preferredTimeMinutes = _unset,
    Object? heightCm = _unset,
    Object? weightKg = _unset,
    SafetyProfile? safety,
    bool? safetyReviewed,
    int? onboardingVersion,
  }) => OnboardingProfile(
    primaryGoal: primaryGoal ?? this.primaryGoal,
    bodyModel: bodyModel ?? this.bodyModel,
    focusAreas: focusAreas ?? this.focusAreas,
    capability: capability ?? this.capability,
    activityLevel: activityLevel ?? this.activityLevel,
    equipment: equipment ?? this.equipment,
    impact: impact ?? this.impact,
    floorAllowed: floorAllowed ?? this.floorAllowed,
    sessionMinutes: sessionMinutes ?? this.sessionMinutes,
    preferredTimeMinutes: preferredTimeMinutes == _unset
        ? this.preferredTimeMinutes
        : preferredTimeMinutes as int?,
    heightCm: heightCm == _unset
        ? this.heightCm
        : (heightCm as num?)?.toDouble(),
    weightKg: weightKg == _unset
        ? this.weightKg
        : (weightKg as num?)?.toDouble(),
    safety: safety ?? this.safety,
    safetyReviewed: safetyReviewed ?? this.safetyReviewed,
    onboardingVersion: onboardingVersion ?? this.onboardingVersion,
  );

  Map<String, dynamic> toJson() => {
    'primaryGoal': primaryGoal.name,
    'bodyModel': bodyModel.name,
    'focusAreas': (focusAreas.map((e) => e.name).toList()..sort()),
    'capability': capability.toJson(),
    'activityLevel': activityLevel.name,
    'equipment': (equipment.map((e) => e.name).toList()..sort()),
    'impact': impact.name,
    'floorAllowed': floorAllowed,
    'sessionMinutes': sessionMinutes,
    'preferredTimeMinutes': preferredTimeMinutes,
    'heightCm': heightCm,
    'weightKg': weightKg,
    'safety': safety.toJson(),
    'safetyReviewed': safetyReviewed,
    'onboardingVersion': onboardingVersion,
  };

  static OnboardingProfile fromJson(Map<String, dynamic>? j) {
    if (j == null) return const OnboardingProfile();
    Set<T> parseSet<T extends Enum>(Object? raw, List<T> values) => raw is List
        ? raw.map((x) => _enumByName(values, x, values.first)).toSet()
        : <T>{};
    final focus = parseSet(j['focusAreas'], FocusArea.values);
    final equipment = parseSet(j['equipment'], EquipmentItem.values);
    return OnboardingProfile(
      primaryGoal: _enumByName(
        WorkoutGoal.values,
        j['primaryGoal'],
        WorkoutGoal.consistency,
      ),
      bodyModel: _enumByName(
        BodyModel.values,
        j['bodyModel'],
        BodyModel.neutral,
      ),
      focusAreas: focus.isEmpty ? const {FocusArea.fullBody} : focus,
      capability: Capability.fromJson(
        (j['capability'] as Map?)?.cast<String, dynamic>(),
      ),
      activityLevel: _enumByName(
        DailyActivityLevel.values,
        j['activityLevel'],
        DailyActivityLevel.light,
      ),
      equipment: equipment,
      impact: _enumByName(
        ImpactPreference.values,
        j['impact'],
        ImpactPreference.any,
      ),
      floorAllowed: j['floorAllowed'] is bool
          ? j['floorAllowed'] as bool
          : true,
      sessionMinutes: (j['sessionMinutes'] as num?)?.toInt() ?? 20,
      preferredTimeMinutes: (j['preferredTimeMinutes'] as num?)?.toInt(),
      heightCm: (j['heightCm'] as num?)?.toDouble(),
      weightKg: (j['weightKg'] as num?)?.toDouble(),
      safety: SafetyProfile.fromJson(
        (j['safety'] as Map?)?.cast<String, dynamic>(),
      ),
      safetyReviewed: j['safetyReviewed'] == true,
      onboardingVersion: (j['onboardingVersion'] as num?)?.toInt() ?? 1,
    );
  }
}

const Object _unset = Object();

class _ExerciseMeta {
  const _ExerciseMeta(
    this.id, {
    this.requires = const {},
    this.floor = false,
    this.impact = false,
  });
  final String id;
  final Set<EquipmentItem> requires;
  final bool floor, impact;
}

String _stableId(String name) => name
    .toLowerCase()
    .replaceAll(RegExp(r'[^a-z0-9]+'), '_')
    .replaceAll(RegExp(r'^_|_$'), '');

const Map<String, _ExerciseMeta> _exerciseCatalog = {
  'Chair squat': _ExerciseMeta('chair_squat', requires: {EquipmentItem.chair}),
  'Bodyweight squat': _ExerciseMeta('bodyweight_squat'),
  'Tempo squat': _ExerciseMeta('tempo_squat'),
  'Squat pulse': _ExerciseMeta('squat_pulse'),
  'Split squat': _ExerciseMeta('split_squat'),
  'Glute bridge': _ExerciseMeta('glute_bridge', floor: true),
  'Single-leg bridge march': _ExerciseMeta(
    'single_leg_bridge_march',
    floor: true,
  ),
  'Hip hinge reach': _ExerciseMeta('hip_hinge_reach'),
  'Single-leg RDL': _ExerciseMeta('single_leg_rdl'),
  'Good morning': _ExerciseMeta('good_morning'),
  'Assisted reverse lunge': _ExerciseMeta(
    'assisted_reverse_lunge',
    requires: {EquipmentItem.chair},
  ),
  'Reverse lunge': _ExerciseMeta('reverse_lunge'),
  'Forward lunge': _ExerciseMeta('forward_lunge'),
  'Walking lunge': _ExerciseMeta('walking_lunge'),
  'Bulgarian split squat': _ExerciseMeta(
    'bulgarian_split_squat',
    requires: {EquipmentItem.chair},
  ),
  'Wall push-up': _ExerciseMeta('wall_push_up', requires: {EquipmentItem.wall}),
  'Incline push-up': _ExerciseMeta(
    'incline_push_up',
    requires: {EquipmentItem.couchTable},
  ),
  'Knee push-up': _ExerciseMeta('knee_push_up', floor: true),
  'Push-up': _ExerciseMeta('push_up', floor: true),
  'Tempo push-up': _ExerciseMeta('tempo_push_up', floor: true),
  'Superman hold': _ExerciseMeta('superman_hold', floor: true),
  'Superman pulls': _ExerciseMeta('superman_pulls', floor: true),
  'Doorway row': _ExerciseMeta(
    'doorway_row',
    requires: {EquipmentItem.towelDoorway},
  ),
  'Towel row': _ExerciseMeta(
    'towel_row',
    requires: {EquipmentItem.towelDoorway},
  ),
  'Feet-forward towel row': _ExerciseMeta(
    'feet_forward_towel_row',
    requires: {EquipmentItem.towelDoorway},
  ),
  'Dead bug': _ExerciseMeta('dead_bug', floor: true),
  'Bird dog': _ExerciseMeta('bird_dog', floor: true),
  'Knee plank': _ExerciseMeta('knee_plank', floor: true),
  'Plank': _ExerciseMeta('plank', floor: true),
  'Hollow hold': _ExerciseMeta('hollow_hold', floor: true),
  'March in place': _ExerciseMeta('march_in_place'),
  'Step touch': _ExerciseMeta('step_touch'),
  'Low-impact jacks': _ExerciseMeta('low_impact_jacks'),
  'Fast feet': _ExerciseMeta('fast_feet'),
  'Jumping jacks': _ExerciseMeta('jumping_jacks', impact: true),
  'Warm-up flow': _ExerciseMeta('warmup_flow'),
  'Standing warm-up flow': _ExerciseMeta('standing_warmup_flow'),
  'Cool-down stretch': _ExerciseMeta('cooldown_stretch', floor: true),
  'Standing cool-down stretch': _ExerciseMeta('standing_cooldown_stretch'),
  'Calf raises': _ExerciseMeta('calf_raises'),
  'Chair dips': _ExerciseMeta('chair_dips', requires: {EquipmentItem.chair}),
  'Diamond push-up': _ExerciseMeta(
    'diamond_push_up',
    requires: {EquipmentItem.floorSpace},
    floor: true,
  ),
};

bool _exerciseAllowed(String name, OnboardingProfile p) {
  final meta = _exerciseCatalog[name];
  return meta == null ||
      (meta.requires.every(p.equipment.contains) &&
          (!meta.floor ||
              (p.floorAllowed &&
                  p.equipment.contains(EquipmentItem.floorSpace))) &&
          (!meta.impact || p.impact == ImpactPreference.any));
}

bool exerciseFitsProfile(PlannedExercise exercise, OnboardingProfile profile) =>
    profile.safetyReviewed &&
    !profile.blockedByRedFlag &&
    _exerciseAllowed(exercise.name, profile);

IconData _exerciseIcon(String name) {
  for (final chain in _library.values) {
    for (final m in chain) {
      if (m.name == name) return m.icon;
    }
  }
  for (final w in _specialized) {
    for (final e in w.exercises) {
      if (e.name == name) return e.icon;
    }
  }
  if (name.toLowerCase().contains('push') || name == 'Chair dips') {
    return _pushIcon;
  }
  if (name.toLowerCase().contains('lunge')) return _lungeIcon;
  if (name.toLowerCase().contains('row') ||
      name.toLowerCase().contains('superman')) {
    return _pullIcon;
  }
  if (name.toLowerCase().contains('plank') ||
      name == 'Dead bug' ||
      name == 'Bird dog') {
    return _coreIcon;
  }
  if (name.toLowerCase().contains('march') ||
      name.contains('jacks') ||
      name == 'Fast feet' ||
      name == 'Step touch') {
    return _condIcon;
  }
  if (_warmupNames.contains(name)) return _standingWarmup.icon;
  if (_cooldownNames.contains(name)) return _cooldown.icon;
  return _squatIcon;
}

const int checkpointsPerChapter = 6;
const int launchCheckpointCount = 24;
const List<String> _chapterNames = [
  'A gentle start',
  'Steady foundations',
  'Growing confidence',
  'Your own rhythm',
];
String chapterTitle(int chapter) =>
    'Chapter $chapter · ${_chapterNames[(chapter - 1).clamp(0, _chapterNames.length - 1)]}';
String checkpointTitle(int ordinal) => switch ((ordinal - 1) % 6) {
  0 => 'Full Body A',
  1 => 'Full Body B',
  2 => 'Control',
  3 => 'Full Body C',
  4 => 'Focus',
  _ => 'Finish',
};

class JourneyProgress {
  const JourneyProgress({
    this.journeyId = '',
    this.completedCheckpoints = 0,
    this.points = 0,
    this.difficulty = 0,
    this.comfortableCount = 0,
  });
  final String journeyId;
  final int completedCheckpoints, points, difficulty, comfortableCount;
  int get nextCheckpoint => completedCheckpoints + 1;
  int get chapter => ((nextCheckpoint - 1) ~/ checkpointsPerChapter) + 1;
  int get chapterCompleted => completedCheckpoints % checkpointsPerChapter;
  Map<String, dynamic> toJson() => {
    'journeyId': journeyId,
    'completedCheckpoints': completedCheckpoints,
    'points': points,
    'difficulty': difficulty,
    'comfortableCount': comfortableCount,
  };
  static JourneyProgress fromJson(Map<String, dynamic>? j) => JourneyProgress(
    journeyId: j?['journeyId'] as String? ?? '',
    completedCheckpoints: ((j?['completedCheckpoints'] as num?)?.toInt() ?? 0)
        .clamp(0, 0x7ffffffe),
    points: ((j?['points'] as num?)?.toInt() ?? 0).clamp(0, 0x7fffffff),
    difficulty: ((j?['difficulty'] as num?)?.toInt() ?? 0).clamp(-2, 2),
    comfortableCount: ((j?['comfortableCount'] as num?)?.toInt() ?? 0).clamp(
      0,
      2,
    ),
  );
  JourneyProgress completeCheckpoint({
    required int checkpoint,
    required String feedback,
    required int pointsEarned,
  }) => advanceJourney(
    this,
    checkpoint: checkpoint,
    feedback: feedback,
    pointsEarned: pointsEarned,
  );
}

JourneyProgress advanceJourney(
  JourneyProgress p, {
  required int checkpoint,
  required String feedback,
  required int pointsEarned,
}) {
  if (checkpoint != p.nextCheckpoint) {
    return p;
  }
  var difficulty = p.difficulty.clamp(-2, 2),
      comfortable = p.comfortableCount.clamp(0, 2);
  if (feedback == 'too_hard') {
    difficulty = (difficulty - 1).clamp(-2, 2);
    comfortable = 0;
  }
  if (feedback == 'good_fit' || feedback == 'too_easy') {
    comfortable++;
    if (comfortable >= 3) {
      difficulty = (difficulty + 1).clamp(-2, 2);
      comfortable = 0;
    }
  }
  return JourneyProgress(
    journeyId: p.journeyId,
    completedCheckpoints: checkpoint,
    points: (p.points + pointsEarned.clamp(0, 0x7fffffff)).clamp(0, 0x7fffffff),
    difficulty: difficulty,
    comfortableCount: comfortable,
  );
}

/// A partial hard attempt can reduce load without earning a checkpoint.
JourneyProgress recordJourneyAttempt(
  JourneyProgress progress, {
  required int? checkpoint,
  required bool qualified,
  required String feedback,
}) {
  if (checkpoint != progress.nextCheckpoint) return progress;
  if (qualified && feedback != 'pain') {
    return advanceJourney(
      progress,
      checkpoint: checkpoint!,
      feedback: feedback,
      pointsEarned: 100,
    );
  }
  if (feedback != 'too_hard' && feedback != 'pain') return progress;
  return JourneyProgress(
    journeyId: progress.journeyId,
    completedCheckpoints: progress.completedCheckpoints,
    points: progress.points,
    difficulty: (progress.difficulty - 1).clamp(-2, 2),
  );
}

const Map<WorkoutGoal, _GoalParams> _checkpointParams = {
  WorkoutGoal.consistency: _GoalParams(
    baseSets: 2,
    baseReps: 10,
    maxTier: 4,
    condSec: 30,
  ),
  WorkoutGoal.fatLoss: _GoalParams(
    baseSets: 2,
    baseReps: 12,
    maxTier: 4,
    condSec: 40,
  ),
  WorkoutGoal.strength: _GoalParams(
    baseSets: 3,
    baseReps: 8,
    maxTier: 4,
    condSec: 25,
  ),
  WorkoutGoal.mobility: _GoalParams(
    baseSets: 2,
    baseReps: 8,
    maxTier: 2,
    condSec: 20,
  ),
};
int _pushBase(int c) => const [0, 0, 1, 2, 3, 3, 4][c.clamp(0, 6)];
int _lowerBase(int c) => const [0, 1, 2, 3, 4][c.clamp(0, 4)];
int _coreBase(int c) => const [0, 2, 3, 4][c.clamp(0, 3)];
int _condBase(int c) => const [0, 1, 2, 4][c.clamp(0, 3)];
int _patternBaseTier(_Pattern p, Capability c) => switch (p) {
  _Pattern.push || _Pattern.pull => _pushBase(c.push),
  _Pattern.squat || _Pattern.lunge || _Pattern.hinge => _lowerBase(c.lower),
  _Pattern.core => _coreBase(c.core),
  _Pattern.conditioning => _condBase(c.conditioning),
};
({int mains, int setBonus}) _sessionSpec(int minutes) {
  if (minutes <= 10) return (mains: 2, setBonus: -1);
  if (minutes <= 15) return (mains: 3, setBonus: 0);
  if (minutes <= 20) return (mains: 4, setBonus: 0);
  if (minutes <= 30) return (mains: 5, setBonus: 1);
  return (mains: 6, setBonus: 1);
}

List<_Pattern> _emphasis(Set<FocusArea> areas) {
  final out = <_Pattern>[];
  void add(_Pattern p) {
    if (!out.contains(p)) out.add(p);
  }

  for (final area in areas) {
    switch (area) {
      case FocusArea.chest:
        add(_Pattern.push);
      case FocusArea.armsShoulders:
        add(_Pattern.push);
        add(_Pattern.pull);
      case FocusArea.back:
        add(_Pattern.pull);
        add(_Pattern.hinge);
      case FocusArea.core:
        add(_Pattern.core);
      case FocusArea.glutesLegs:
        add(_Pattern.squat);
        add(_Pattern.hinge);
        add(_Pattern.lunge);
      case FocusArea.cardio:
        add(_Pattern.conditioning);
      case FocusArea.fullBody || FocusArea.mobility:
        break;
    }
  }
  return out;
}

List<_Pattern> _patterns(
  List<_Pattern> template,
  int mains,
  List<_Pattern> emphasis,
) {
  final result = <_Pattern>[
    ...emphasis.where(template.contains),
    ...template.where((p) => !emphasis.contains(p)),
  ];
  if (result.length >= mains) return result.take(mains).toList();
  final counts = <_Pattern, int>{};
  for (final p in result) {
    counts[p] = (counts[p] ?? 0) + 1;
  }
  final pool = [...emphasis, ...template];
  for (var i = 0; result.length < mains && i < pool.length * 2; i++) {
    final p = pool[i % pool.length];
    if ((counts[p] ?? 0) < 2) {
      result.add(p);
      counts[p] = (counts[p] ?? 0) + 1;
    }
  }
  return result;
}

_Move? _pickMove(_Pattern pattern, int maxTier, OnboardingProfile p) {
  final chain = _library[pattern]!;
  for (var i = maxTier.clamp(0, chain.length - 1); i >= 0; i--) {
    if (_exerciseAllowed(chain[i].name, p)) return chain[i];
  }
  return null;
}

PlannedWorkout generateCheckpointWorkout({
  required OnboardingProfile profile,
  required JourneyProgress progress,
  String energy = 'Medium',
  bool gentle = false,
}) {
  if (!profile.safetyReviewed || profile.blockedByRedFlag) {
    throw StateError('Safety review is required before generating a workout.');
  }
  final ordinal = progress.nextCheckpoint;
  final role = (ordinal - 1) % checkpointsPerChapter;
  final template = _templates[role % _templates.length].$2;
  final spec = _sessionSpec(profile.sessionMinutes);
  final focus = _emphasis(profile.focusAreas);
  final patterns = _patterns(
    template,
    spec.mains,
    role == 5 ? const [] : focus,
  );
  final params = _checkpointParams[profile.primaryGoal]!;
  final energyAdj =
      (energy == 'Low' || gentle
          ? -1
          : energy == 'High'
          ? 1
          : 0) +
      (progress.difficulty < 0 ? -1 : 0) +
      (progress.difficulty > 0 ? 1 : 0);
  final floor =
      profile.floorAllowed &&
      profile.equipment.contains(EquipmentItem.floorSpace);
  final warm = floor ? _warmup : _standingWarmup;
  final cool = floor ? _cooldown : _standingCooldown;
  final exercises = <PlannedExercise>[
    PlannedExercise(
      warm.name,
      gentle ? '4 min' : '3 min',
      warm.detail,
      warm.icon,
    ),
  ];
  const fallbacks = [
    _Pattern.conditioning,
    _Pattern.squat,
    _Pattern.hinge,
    _Pattern.lunge,
    _Pattern.core,
    _Pattern.push,
  ];
  for (final pattern in patterns) {
    final ability = _patternBaseTier(pattern, profile.capability);
    final tier = (ability + progress.difficulty - (gentle ? 1 : 0))
        .clamp(0, ability)
        .clamp(0, params.maxTier);
    var move = _pickMove(pattern, tier, profile);
    if (move == null) {
      for (final fallback in fallbacks) {
        move = _pickMove(
          fallback,
          (_patternBaseTier(fallback, profile.capability) +
                  progress.difficulty -
                  (gentle ? 1 : 0))
              .clamp(0, _patternBaseTier(fallback, profile.capability))
              .clamp(0, params.maxTier),
          profile,
        );
        if (move != null) break;
      }
    }
    if (move == null) {
      throw StateError('No safe compatible exercise is available.');
    }
    final sets =
        (params.baseSets +
                spec.setBonus +
                (profile.activityLevel == DailyActivityLevel.seated ? -1 : 0) +
                energyAdj)
            .clamp(1, 5);
    final reps = params.baseReps + (energy == 'High' && !gentle ? 2 : 0);
    exercises.add(
      PlannedExercise(
        move.name,
        _targetFor(move, sets, reps, params.condSec),
        move.detail,
        move.icon,
      ),
    );
  }
  exercises.add(PlannedExercise(cool.name, '2 min', cool.detail, cool.icon));
  final minutes = profile.sessionMinutes.clamp(8, 60);
  final roleTitle = checkpointTitle(ordinal);
  return PlannedWorkout(
    seq: ordinal,
    title: '$roleTitle · Checkpoint $ordinal',
    estMinutes: gentle || energy == 'Low'
        ? (minutes * 0.7).round().clamp(8, minutes)
        : minutes,
    exercises: exercises,
  );
}

String startingLevelLabel(Capability c) {
  final avg = (c.push / 6 + c.lower / 4 + c.core / 3 + c.conditioning / 3) / 4;
  if (avg < 0.28) return 'Gentle start';
  if (avg < 0.55) return 'Building base';
  if (avg < 0.8) return 'Confident start';
  return 'Strong start';
}

// ===========================================================================
// Report data model: typed workout history, active-time tracking, body metrics.
// ===========================================================================

/// Where a completed workout came from.
enum WorkoutSource { plan, bonus, checkpoint, practice }

/// A truthful, typed record of one completed workout. Nullable duration fields
/// represent "unavailable" (e.g. legacy records) - never fabricate them.
class WorkoutHistoryEntry {
  const WorkoutHistoryEntry({
    required this.id,
    this.eventId,
    this.planId,
    this.journeyId,
    this.checkpoint,
    this.sessionId,
    this.planStartDate,
    required this.title,
    required this.source,
    required this.startedAt,
    required this.completedAt,
    this.scheduledDate,
    this.updatedAt,
    this.activeSeconds,
    this.plannedMinutes,
    this.completedExerciseCount = 0,
    this.totalExerciseCount = 0,
    this.skippedExerciseCount = 0,
    this.energy,
    this.focusCategories = const [],
    this.points = 0,
    this.difficultyFeedback,
    this.qualified = true,
    this.synced = false,
    this.legacy = false,
  });

  final String id; // stable local id
  final String? eventId; // canonical analytics/event id for this completion
  final String? planId;
  final String? journeyId;
  final int? checkpoint;
  final String? sessionId;
  final String? planStartDate;
  final String title;
  final WorkoutSource source;
  final DateTime startedAt;
  final DateTime completedAt;
  final String? scheduledDate;
  final DateTime? updatedAt;
  final int? activeSeconds; // null = duration unavailable
  final int? plannedMinutes;
  final int completedExerciseCount;
  final int totalExerciseCount;
  final int skippedExerciseCount;
  final String? energy;
  final List<String> focusCategories;
  final int points;
  final String? difficultyFeedback;
  final bool qualified; // passed the completion rule (all-skip does not count)
  final bool synced; // optional signed-in sync state
  final bool legacy; // migrated from pre-history data (missing detail)

  /// Local calendar date of completion.
  String get localDateKey => dateKey(completedAt);

  /// Logged workout minutes (rounded from active seconds). Null if unavailable.
  int? get activeMinutes =>
      activeSeconds == null ? null : (activeSeconds! / 60).round();

  DateTime get syncUpdatedAt => updatedAt ?? completedAt;

  WorkoutHistoryEntry copyWith({bool? synced, String? difficultyFeedback}) =>
      WorkoutHistoryEntry(
        id: id,
        eventId: eventId,
        planId: planId,
        journeyId: journeyId,
        checkpoint: checkpoint,
        sessionId: sessionId,
        planStartDate: planStartDate,
        title: title,
        source: source,
        startedAt: startedAt,
        completedAt: completedAt,
        scheduledDate: scheduledDate,
        updatedAt: DateTime.now(),
        activeSeconds: activeSeconds,
        plannedMinutes: plannedMinutes,
        completedExerciseCount: completedExerciseCount,
        totalExerciseCount: totalExerciseCount,
        skippedExerciseCount: skippedExerciseCount,
        energy: energy,
        focusCategories: focusCategories,
        points: points,
        difficultyFeedback: difficultyFeedback ?? this.difficultyFeedback,
        qualified: qualified,
        synced: synced ?? this.synced,
        legacy: legacy,
      );

  Map<String, dynamic> toJson() => {
    'id': id,
    'eventId': eventId,
    'planId': planId,
    'journeyId': journeyId,
    'checkpoint': checkpoint,
    'sessionId': sessionId,
    'planStartDate': planStartDate,
    'title': title,
    'source': source.name,
    'startedAt': startedAt.toIso8601String(),
    'completedAt': completedAt.toIso8601String(),
    'scheduledDate': scheduledDate,
    'updatedAt': updatedAt?.toIso8601String(),
    'activeSeconds': activeSeconds,
    'plannedMinutes': plannedMinutes,
    'completedExerciseCount': completedExerciseCount,
    'totalExerciseCount': totalExerciseCount,
    'skippedExerciseCount': skippedExerciseCount,
    'energy': energy,
    'focusCategories': focusCategories,
    'points': points,
    'difficultyFeedback': difficultyFeedback,
    'qualified': qualified,
    'synced': synced,
    'legacy': legacy,
  };

  static WorkoutHistoryEntry? fromJson(Map<String, dynamic> j) {
    final completed = DateTime.tryParse(j['completedAt'] as String? ?? '');
    if (completed == null) return null;
    final started = DateTime.tryParse(j['startedAt'] as String? ?? '');
    return WorkoutHistoryEntry(
      id: (j['id'] as String?) ?? 'entry-${completed.microsecondsSinceEpoch}',
      eventId: j['eventId'] as String?,
      planId: j['planId'] as String?,
      journeyId: j['journeyId'] as String?,
      checkpoint: (j['checkpoint'] as num?)?.toInt(),
      sessionId: j['sessionId'] as String?,
      planStartDate: j['planStartDate'] as String?,
      title: (j['title'] as String?) ?? 'Workout completed',
      source: _enumByName(
        WorkoutSource.values,
        j['source'],
        WorkoutSource.plan,
      ),
      startedAt: started ?? completed,
      completedAt: completed,
      scheduledDate: j['scheduledDate'] as String?,
      updatedAt: DateTime.tryParse(j['updatedAt'] as String? ?? ''),
      activeSeconds: (j['activeSeconds'] as num?)?.toInt(),
      plannedMinutes: (j['plannedMinutes'] as num?)?.toInt(),
      completedExerciseCount:
          (j['completedExerciseCount'] as num?)?.toInt() ?? 0,
      totalExerciseCount: (j['totalExerciseCount'] as num?)?.toInt() ?? 0,
      skippedExerciseCount: (j['skippedExerciseCount'] as num?)?.toInt() ?? 0,
      energy: j['energy'] as String?,
      focusCategories:
          (j['focusCategories'] as List?)?.map((e) => '$e').toList() ??
          const [],
      points: (j['points'] as num?)?.toInt() ?? 0,
      difficultyFeedback: j['difficultyFeedback'] as String?,
      qualified: j['qualified'] is bool ? j['qualified'] as bool : true,
      synced: j['synced'] == true,
      legacy: j['legacy'] == true,
    );
  }

  Map<String, dynamic> toRemote(String userId) => {
    'id': id,
    'user_id': userId,
    'event_id': eventId,
    'plan_id': planId,
    'journey_id': journeyId,
    'checkpoint': checkpoint,
    'session_id': sessionId,
    'plan_start_date': planStartDate,
    'title': title,
    'source': source.name,
    'scheduled_date': scheduledDate,
    'started_at': startedAt.toUtc().toIso8601String(),
    'completed_at': completedAt.toUtc().toIso8601String(),
    'active_seconds': activeSeconds,
    'planned_minutes': plannedMinutes,
    'completed_exercise_count': completedExerciseCount,
    'total_exercise_count': totalExerciseCount,
    'skipped_exercise_count': skippedExerciseCount,
    'energy': energy,
    'focus_categories': focusCategories,
    'points': points,
    'difficulty_feedback': difficultyFeedback,
    'qualified': qualified,
    'updated_at': syncUpdatedAt.toUtc().toIso8601String(),
  };

  static WorkoutHistoryEntry? fromRemote(Map<String, dynamic> j) {
    final completed = DateTime.tryParse(j['completed_at'] as String? ?? '');
    if (completed == null) return null;
    return WorkoutHistoryEntry(
      id: j['id'] as String,
      eventId: j['event_id'] as String?,
      planId: j['plan_id'] as String?,
      journeyId: j['journey_id'] as String?,
      checkpoint: (j['checkpoint'] as num?)?.toInt(),
      sessionId: j['session_id'] as String?,
      planStartDate: j['plan_start_date'] as String?,
      title: j['title'] as String? ?? 'Workout completed',
      source: _enumByName(
        WorkoutSource.values,
        j['source'],
        WorkoutSource.plan,
      ),
      startedAt:
          DateTime.tryParse(j['started_at'] as String? ?? '') ?? completed,
      completedAt: completed,
      scheduledDate: j['scheduled_date'] as String?,
      updatedAt: DateTime.tryParse(j['updated_at'] as String? ?? ''),
      activeSeconds: (j['active_seconds'] as num?)?.toInt(),
      plannedMinutes: (j['planned_minutes'] as num?)?.toInt(),
      completedExerciseCount:
          (j['completed_exercise_count'] as num?)?.toInt() ?? 0,
      totalExerciseCount: (j['total_exercise_count'] as num?)?.toInt() ?? 0,
      skippedExerciseCount: (j['skipped_exercise_count'] as num?)?.toInt() ?? 0,
      energy: j['energy'] as String?,
      focusCategories:
          (j['focus_categories'] as List?)?.map((e) => '$e').toList() ??
          const [],
      points: (j['points'] as num?)?.toInt() ?? 0,
      difficultyFeedback: j['difficulty_feedback'] as String?,
      qualified: j['qualified'] is bool ? j['qualified'] as bool : true,
    );
  }
}

/// Builds truthful history entries from pre-history local state. Legacy records
/// keep a generic title and no duration - we never invent titles, minutes or
/// calories that were not recorded.
List<WorkoutHistoryEntry> migrateLegacyWorkoutHistory({
  required Set<String> workoutDates,
  required Map<String, int> activityMinutesByDate,
}) {
  final dates = workoutDates.toList()..sort();
  return [
    for (final d in dates)
      if (parseDateKey(d) != null)
        WorkoutHistoryEntry(
          id: 'legacy-$d',
          title: 'Workout completed',
          source: WorkoutSource.plan,
          startedAt: parseDateKey(d)!,
          completedAt: parseDateKey(d)!,
          activeSeconds: null, // Duration unavailable
          plannedMinutes: activityMinutesByDate[d],
          qualified: true,
          legacy: true,
        ),
  ];
}

/// Accumulates *active* workout seconds. Time only counts while explicitly
/// running (foreground + on the workout), so a backgrounded or abandoned screen
/// never logs hours of activity. Pure and deterministic for testing.
class WorkoutActiveTimer {
  WorkoutActiveTimer({this.maxSeconds = 4 * 3600});

  /// Safety cap so an edge case can never log an absurd duration.
  final int maxSeconds;

  int _accumulated = 0;
  DateTime? _runningSince;

  bool get isRunning => _runningSince != null;

  int get accumulatedSeconds => _accumulated.clamp(0, maxSeconds);

  /// Restores only banked foreground time; a restarted app never accrues time
  /// while it was dead or backgrounded.
  void restore(int seconds) {
    _accumulated = seconds.clamp(0, maxSeconds);
    _runningSince = null;
  }

  /// Start counting from [now] (no-op if already running).
  void resume(DateTime now) => _runningSince ??= now;

  /// Stop counting, banking the elapsed active slice.
  void pause(DateTime now) {
    final since = _runningSince;
    if (since == null) return;
    final delta = now.difference(since).inSeconds;
    if (delta > 0) _accumulated += delta;
    _runningSince = null;
  }

  /// Total active seconds so far (including the running slice if [now] is
  /// provided), clamped to [maxSeconds].
  int seconds([DateTime? now]) {
    var total = _accumulated;
    final since = _runningSince;
    if (since != null && now != null) {
      final delta = now.difference(since).inSeconds;
      if (delta > 0) total += delta;
    }
    return total.clamp(0, maxSeconds);
  }

  void reset() {
    _accumulated = 0;
    _runningSince = null;
  }
}

/// A single dated body measurement. Height/weight are always optional.
class BodyMeasurement {
  const BodyMeasurement({
    required this.id,
    required this.measuredAt,
    required this.weightKg,
    this.heightCm,
    this.updatedAt,
    this.journeyId,
  });

  final String id;
  final DateTime measuredAt;
  final double weightKg;
  final double? heightCm;
  final DateTime? updatedAt;
  final String? journeyId;

  DateTime get syncUpdatedAt => updatedAt ?? measuredAt;

  Map<String, dynamic> toJson() => {
    'id': id,
    'measuredAt': measuredAt.toIso8601String(),
    'updatedAt': updatedAt?.toIso8601String(),
    'weightKg': weightKg,
    'heightCm': heightCm,
    'journeyId': journeyId,
  };

  static BodyMeasurement? fromJson(Map<String, dynamic> j) {
    final at = DateTime.tryParse(j['measuredAt'] as String? ?? '');
    final w = (j['weightKg'] as num?)?.toDouble();
    final h = (j['heightCm'] as num?)?.toDouble();
    if (at == null || w == null || !w.isFinite || w <= 0) return null;
    if (h != null && (!h.isFinite || h <= 0)) return null;
    return BodyMeasurement(
      id: (j['id'] as String?) ?? 'm-${at.microsecondsSinceEpoch}',
      measuredAt: at,
      updatedAt: DateTime.tryParse(j['updatedAt'] as String? ?? ''),
      weightKg: w,
      heightCm: h,
      journeyId: j['journeyId'] as String?,
    );
  }

  Map<String, dynamic> toRemote(String userId) => {
    'id': id,
    'user_id': userId,
    'measured_at': measuredAt.toUtc().toIso8601String(),
    'weight_kg': weightKg,
    'height_cm': heightCm,
    'journey_id': journeyId,
    'updated_at': syncUpdatedAt.toUtc().toIso8601String(),
  };

  static BodyMeasurement? fromRemote(Map<String, dynamic> j) {
    final measuredAt = DateTime.tryParse(j['measured_at'] as String? ?? '');
    final weight = (j['weight_kg'] as num?)?.toDouble();
    if (measuredAt == null || weight == null) return null;
    return BodyMeasurement(
      id: j['id'] as String,
      measuredAt: measuredAt,
      weightKg: weight,
      heightCm: (j['height_cm'] as num?)?.toDouble(),
      journeyId: j['journey_id'] as String?,
      updatedAt: DateTime.tryParse(j['updated_at'] as String? ?? ''),
    );
  }
}

/// Adult BMI screening categories (ages 20+). Screening, not diagnosis.
enum BmiCategory { underweight, healthy, overweight, obese }

/// Metric BMI = kg / m^2. Returns null for invalid inputs.
double? computeBmi({required double weightKg, required double heightCm}) {
  if (!weightKg.isFinite ||
      !heightCm.isFinite ||
      weightKg <= 0 ||
      heightCm <= 0) {
    return null;
  }
  final m = heightCm / 100.0;
  return weightKg / (m * m);
}

/// Standard adult screening boundaries: <18.5, 18.5-<25, 25-<30, >=30.
BmiCategory? bmiCategory(double bmi) {
  if (!bmi.isFinite || bmi <= 0) return null;
  if (bmi < 18.5) return BmiCategory.underweight;
  if (bmi < 25) return BmiCategory.healthy;
  if (bmi < 30) return BmiCategory.overweight;
  return BmiCategory.obese;
}

// ===========================================================================
// Report analytics: period ranges, adherence, insights. All local-calendar.
// ===========================================================================

/// Overview date-range selector.
enum ReportPeriod { today, thisWeek, fourWeeks, twelveWeeks }

String reportPeriodLabel(ReportPeriod p) => switch (p) {
  ReportPeriod.today => 'Today',
  ReportPeriod.thisWeek => 'This week',
  ReportPeriod.fourWeeks => '4 weeks',
  ReportPeriod.twelveWeeks => '12 weeks',
};

/// An inclusive local-date range [start, end], both at midnight.
class DateRange {
  DateRange(DateTime start, DateTime end)
    : start = DateTime(start.year, start.month, start.day),
      end = DateTime(end.year, end.month, end.day);

  final DateTime start;
  final DateTime end;

  int get days => end.difference(start).inDays + 1;

  bool contains(DateTime d) {
    final x = DateTime(d.year, d.month, d.day);
    return !x.isBefore(start) && !x.isAfter(end);
  }

  /// The equal-length window immediately preceding this one (for trends).
  DateRange get preceding {
    final n = days;
    final prevEnd = start.subtract(const Duration(days: 1));
    return DateRange(prevEnd.subtract(Duration(days: n - 1)), prevEnd);
  }
}

/// Local date range for a period, ending today. "This week" starts Monday.
DateRange reportPeriodRange(ReportPeriod period, DateTime today) {
  final t = DateTime(today.year, today.month, today.day);
  switch (period) {
    case ReportPeriod.today:
      return DateRange(t, t);
    case ReportPeriod.thisWeek:
      return DateRange(t.subtract(Duration(days: t.weekday - 1)), t);
    case ReportPeriod.fourWeeks:
      return DateRange(t.subtract(const Duration(days: 27)), t);
    case ReportPeriod.twelveWeeks:
      return DateRange(t.subtract(const Duration(days: 83)), t);
  }
}

/// A completed-work insight without a planned-session denominator.
String? reportInsight({
  required ReportPeriod period,
  required int completedInPeriod,
  required List<int> completedMinutes,
  required String? mostConsistentWeekday,
}) {
  if (completedInPeriod == 0) return null;
  if (mostConsistentWeekday != null && completedInPeriod >= 3) {
    return '$mostConsistentWeekday has been your most consistent workout day.';
  }
  if (completedMinutes.length >= 2) {
    final avg =
        completedMinutes.reduce((a, b) => a + b) ~/ completedMinutes.length;
    if (avg > 0) return 'Your average completed session was $avg minutes.';
  }
  return completedInPeriod == 1
      ? 'You completed a workout in this period.'
      : 'You completed $completedInPeriod workouts in this period.';
}

/// Full-name weekday for insight copy.
String weekdayLongName(int weekday) => switch (weekday.clamp(1, 7)) {
  1 => 'Monday',
  2 => 'Tuesday',
  3 => 'Wednesday',
  4 => 'Thursday',
  5 => 'Friday',
  6 => 'Saturday',
  _ => 'Sunday',
};
