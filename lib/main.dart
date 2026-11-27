import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart'
    show LicenseEntryWithLineBreaks, LicenseRegistry, kIsWeb, visibleForTesting;
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

import 'ads/ad_config.dart';
import 'ads/ads_service.dart';
import 'ads/consent_service.dart';
import 'app/theme/app_colors.dart';
import 'app/theme/app_cupertino_theme.dart';
import 'app/theme/app_motion.dart';
import 'app/theme/app_typography.dart';
import 'notifications.dart';
import 'shared/ui/app_ui.dart';
import 'purchases/ad_removal_service.dart';
import 'storage/sensitive_local_store.dart';
import 'workout_engine.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    final prefs = await SharedPreferences.getInstance();
    final savedTheme = prefs.get('darkMode');
    if (savedTheme is bool) appIsDark.value = savedTheme;
  } on PlatformException {
    // Keep the system theme. The journey handles storage errors separately.
  }
  LicenseRegistry.addLicense(() async* {
    yield LicenseEntryWithLineBreaks([
      'Manrope',
    ], await rootBundle.loadString('assets/fonts/OFL.txt'));
  });
  runApp(const PurrfitApp());
}

final appIsDark = ValueNotifier<bool?>(null);
@visibleForTesting
bool debugUsePlaintextLocalState = false;
@visibleForTesting
bool debugDisableExternalServices = false;
const _privacyUrl = String.fromEnvironment('PURRFIT_PRIVACY_URL');
const _termsUrl = String.fromEnvironment('PURRFIT_TERMS_URL');
const _supportUrl = String.fromEnvironment('PURRFIT_SUPPORT_URL');
String _newId() {
  final random = math.Random.secure();
  return '${DateTime.now().microsecondsSinceEpoch.toRadixString(36)}-'
      '${List.generate(16, (_) => random.nextInt(256).toRadixString(16).padLeft(2, '0')).join()}';
}

Map<String, dynamic> _map(Object? value) =>
    value is Map ? value.cast<String, dynamic>() : <String, dynamic>{};

List<Map<String, dynamic>> _maps(Object? value) => value is List
    ? value.whereType<Map>().map((e) => e.cast<String, dynamic>()).toList()
    : [];

class PurrfitApp extends StatelessWidget {
  const PurrfitApp({super.key});

  @override
  Widget build(BuildContext context) => CupertinoApp(
    title: 'Purrfit',
    debugShowCheckedModeBanner: false,
    theme: AppCupertinoTheme.theme(Brightness.light),
    builder: (context, child) => ValueListenableBuilder<bool?>(
      valueListenable: appIsDark,
      builder: (context, dark, _) {
        final brightness = dark == null
            ? MediaQuery.platformBrightnessOf(context)
            : dark
            ? Brightness.dark
            : Brightness.light;
        final theme = AppCupertinoTheme.theme(brightness);
        return CupertinoTheme(
          data: theme,
          // CupertinoApp's own DefaultTextStyle is fixed to the light theme.
          // Re-apply it here so bare Text widgets follow the active brightness.
          child: DefaultTextStyle(
            style: theme.textTheme.textStyle,
            child: MediaQuery(
              data: MediaQuery.of(
                context,
              ).copyWith(platformBrightness: brightness),
              child: child ?? const SizedBox(),
            ),
          ),
        );
      },
    ),
    home: const PurrfitShell(),
  );
}

class SplashScreen extends StatelessWidget {
  const SplashScreen({super.key});
  @override
  Widget build(BuildContext context) => CupertinoPageScaffold(
    backgroundColor: AppColors.appBackground(context),
    child: SafeArea(
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const _BrandArtwork(height: 180),
            const SizedBox(height: 24),
            const CupertinoActivityIndicator(),
            const SizedBox(height: 16),
            const Text('Progress, at your pace.'),
          ],
        ),
      ),
    ),
  );
}

class _BrandArtwork extends StatelessWidget {
  const _BrandArtwork({required this.height});

  final double height;

  @override
  Widget build(BuildContext context) => SizedBox(
    height: height,
    child: Icon(
      CupertinoIcons.heart_fill,
      size: height * .45,
      color: AppColors.accent(context),
    ),
  );
}

Future<void> showBrandedInfoSheet(
  BuildContext context, {
  required String title,
  required String message,
}) => showCupertinoDialog<void>(
  context: context,
  builder: (dialog) => CupertinoAlertDialog(
    title: Text(title),
    content: Text(message),
    actions: [
      CupertinoDialogAction(
        onPressed: () => Navigator.pop(dialog),
        child: const Text('OK'),
      ),
    ],
  ),
);

Future<bool> _confirm(
  BuildContext context,
  String title,
  String message, {
  String action = 'Continue',
  bool destructive = false,
}) async =>
    await showCupertinoDialog<bool>(
      context: context,
      builder: (dialog) => CupertinoAlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          CupertinoDialogAction(
            onPressed: () => Navigator.pop(dialog, false),
            child: const Text('Cancel'),
          ),
          CupertinoDialogAction(
            isDestructiveAction: destructive,
            onPressed: () => Navigator.pop(dialog, true),
            child: Text(action),
          ),
        ],
      ),
    ) ??
    false;

class _BuddyNote extends StatelessWidget {
  const _BuddyNote(this.message);
  final String message;
  @override
  Widget build(BuildContext context) =>
      AppMascotMessage(message: message, mood: MascotMood.guidance);
}

class _SettingsTile extends StatelessWidget {
  const _SettingsTile(
    this.title,
    this.value, {
    this.onTap,
    this.icon = CupertinoIcons.chevron_forward,
  });
  final String title, value;
  final VoidCallback? onTap;
  final IconData icon;
  @override
  Widget build(BuildContext context) => CupertinoButton(
    padding: const EdgeInsets.symmetric(vertical: 14),
    onPressed: onTap,
    child: Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: AppTypography.headline(context)),
              const SizedBox(height: 4),
              Text(
                value,
                style: AppTypography.subheadline(
                  context,
                ).copyWith(color: AppColors.secondaryText(context)),
              ),
            ],
          ),
        ),
        const SizedBox(width: 12),
        Icon(icon, size: 22),
      ],
    ),
  );
}

/// Exact prescription and player position. Restoring never regenerates a workout.
class FrozenWorkout {
  FrozenWorkout({
    required this.eventId,
    required this.workout,
    required this.startedAt,
    required this.energy,
    this.checkpoint,
    this.current = 0,
    this.setIndex = 0,
    this.restUntil,
    this.activeSeconds = 0,
    this.awaitingFeedback = false,
    Set<int>? completed,
    Set<int>? skipped,
  }) : completed = completed ?? {},
       skipped = skipped ?? {};
  final String eventId, energy;
  final PlannedWorkout workout;
  final DateTime startedAt;
  final int? checkpoint;
  int current, setIndex, activeSeconds;
  DateTime? restUntil;
  bool awaitingFeedback;
  final Set<int> completed, skipped;
  bool get qualified {
    final main = [
      for (var i = 0; i < workout.exercises.length; i++)
        if (workout.exercises[i].isMain) i,
    ];
    return main.isNotEmpty &&
        main.where(completed.contains).length >= (main.length / 2).ceil();
  }

  Map<String, dynamic> toJson() => {
    'eventId': eventId,
    'workout': workout.toJson(),
    'startedAt': startedAt.toIso8601String(),
    'energy': energy,
    'checkpoint': checkpoint,
    'current': current,
    'setIndex': setIndex,
    'restUntil': restUntil?.toIso8601String(),
    'activeSeconds': activeSeconds,
    'awaitingFeedback': awaitingFeedback,
    'completed': completed.toList()..sort(),
    'skipped': skipped.toList()..sort(),
  };
  static FrozenWorkout fromJson(Map<String, dynamic> json) {
    final workout = PlannedWorkout.fromJson(_map(json['workout']));
    if (workout.exercises.isEmpty ||
        json['eventId'] is! String ||
        DateTime.tryParse('${json['startedAt']}') == null) {
      throw const FormatException('Invalid saved workout');
    }
    Set<int> indices(Object? raw) => raw is List
        ? raw
              .whereType<num>()
              .map((e) => e.toInt())
              .where((e) => e >= 0 && e < workout.exercises.length)
              .toSet()
        : {};
    return FrozenWorkout(
      eventId: json['eventId'] as String,
      workout: workout,
      startedAt: DateTime.parse(json['startedAt'] as String),
      energy: json['energy'] as String? ?? 'Medium',
      checkpoint: (json['checkpoint'] as num?)?.toInt(),
      current: ((json['current'] as num?)?.toInt() ?? 0).clamp(
        0,
        workout.exercises.length - 1,
      ),
      setIndex: ((json['setIndex'] as num?)?.toInt() ?? 0).clamp(0, 5),
      restUntil: DateTime.tryParse('${json['restUntil']}'),
      activeSeconds: ((json['activeSeconds'] as num?)?.toInt() ?? 0).clamp(
        0,
        14400,
      ),
      awaitingFeedback: json['awaitingFeedback'] == true,
      completed: indices(json['completed']),
      skipped: indices(json['skipped']),
    );
  }
}

class PurrfitShell extends StatefulWidget {
  const PurrfitShell({super.key, this.demoMode = false, this.localStore});
  final bool demoMode;
  final SensitiveLocalStore? localStore;
  @override
  State<PurrfitShell> createState() => _PurrfitShellState();
}

class _PurrfitShellState extends State<PurrfitShell>
    with WidgetsBindingObserver {
  final _tabs = CupertinoTabController();
  late final _store =
      widget.localStore ??
      SensitiveLocalStore(usePlaintextForTesting: debugUsePlaintextLocalState);
  final _timer = WorkoutActiveTimer();
  Timer? _autosave;
  Future<void> _writes = Future.value();
  int _loadEpoch = 0;
  bool _ready = false, _onboarded = false, _busy = false;
  bool _playerVisible = false, _adult = false;
  bool _storageBlocked = false, _gentle = false;
  bool _deleting = false;
  String? _error;
  var _base = JourneyProgress(journeyId: _newId());
  var _profile = const OnboardingProfile();
  OnboardingProfile? _draft;
  int _draftStep = 0;
  String _energy = 'Medium', _name = '';
  int _avatar = 0;
  FrozenWorkout? _active;
  List<WorkoutHistoryEntry> _history = [];
  List<BodyMeasurement> _measurements = [];
  bool _reminder = false;
  int _reminderMinutes = 18 * 60;
  AdRemovalService? _purchases;
  bool _removeAds = false;
  ConsentService? _consent;
  AdsService? _ads;
  JourneyProgress get _journey => _base;
  bool get _safe => _profile.safetyReviewed && !_profile.blockedByRedFlag;
  bool get _savedWorkoutNeedsReview {
    final active = _active;
    return active != null &&
        !active.awaitingFeedback &&
        active.workout.exercises
            .skip(active.current)
            .any((exercise) => !exerciseFitsProfile(exercise, _profile));
  }

  bool get _monetized =>
      !debugDisableExternalServices && !widget.demoMode && AdConfig.enabled;
  bool get _extraContentUnlocked => !_monetized || _removeAds;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    unawaited(_loadOwner());
    _autosave = Timer.periodic(const Duration(seconds: 15), (_) {
      if (_ready && _active != null) unawaited(_save());
    });
    if (_monetized) {
      unawaited(_initServices());
    }
  }

  Future<void> _initServices() async {
    final purchases = AdRemovalService();
    _purchases = purchases;
    purchases.addListener(_serviceChanged);
    await purchases.initialize();
    if (!mounted) return;
    unawaited(purchases.refresh());
    final consent = ConsentService();
    _consent = consent;
    consent.addListener(_serviceChanged);
    final ads = AdsService(consent: consent, adFree: _removeAds);
    _ads = ads;
    ads.initialize();
    if (!_removeAds) consent.initialize();
  }

  void _serviceChanged() {
    final adFree = _purchases?.hasAdFreeAccess ?? false;
    if (!adFree) _consent?.initialize();
    _ads?.setAdFree(adFree);
    if (mounted) setState(() => _removeAds = adFree);
  }

  Map<String, Object?> _state() {
    final active = _active;
    if (active != null) active.activeSeconds = _timer.seconds(DateTime.now());
    return {
      'experience': 'journey_v1',
      'onboarded': _onboarded,
      'journey': _base.toJson(),
      'profile': _profile.toJson(),
      'draft': _draft?.toJson(),
      'draftStep': _draftStep,
      'energy': _energy,
      'gentle': _gentle,
      'active': active?.toJson(),
      'history': _history.map((e) => e.toJson()).toList(),
      'measurements': _measurements.map((e) => e.toJson()).toList(),
      'name': _name,
      'avatar': _avatar,
      'adultConfirmed': _adult,
      'reminder': _reminder,
      'reminderMinutes': _reminderMinutes,
    };
  }

  Future<bool> _save() {
    if (!_ready || _storageBlocked || _deleting) return Future.value(false);
    // Capture now, before another owner or completion can change mutable state.
    final state = _map(jsonDecode(jsonEncode(_state())));
    final result = Completer<bool>();
    _writes = _writes.catchError((Object _) {}).then((_) async {
      try {
        final ok = await _store.write(
          state,
          await SharedPreferences.getInstance(),
        );
        if (mounted) {
          setState(
            () => _error = ok
                ? null
                : 'Could not save on this device. Free some storage and retry.',
          );
        }
        result.complete(ok);
      } catch (_) {
        if (mounted) {
          setState(
            () => _error = 'Could not save on this device. Please retry.',
          );
        }
        result.complete(false);
      }
    });
    return result.future;
  }

  Future<void> _loadOwner() async {
    if (_deleting) return;
    final epoch = ++_loadEpoch;
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = await _store.readAndMigrate(prefs);
      if (!mounted || epoch != _loadEpoch) return;
      _storageBlocked = false;
      final json = raw.cast<String, dynamic>();
      _base = json['journey'] is Map
          ? JourneyProgress.fromJson(_map(json['journey']))
          : JourneyProgress(journeyId: _newId());
      if (_base.journeyId.isEmpty) _base = JourneyProgress(journeyId: _newId());
      _profile = OnboardingProfile.fromJson(_map(json['profile']));
      _onboarded = json['onboarded'] == true;
      _draft = json['draft'] is Map
          ? OnboardingProfile.fromJson(_map(json['draft']))
          : null;
      _draftStep = (json['draftStep'] as num?)?.toInt() ?? 0;
      _energy = json['energy'] as String? ?? 'Medium';
      _gentle = json['gentle'] == true;
      _active = json['active'] is Map
          ? FrozenWorkout.fromJson(_map(json['active']))
          : null;
      _history = _maps(json['history'])
          .map(WorkoutHistoryEntry.fromJson)
          .whereType<WorkoutHistoryEntry>()
          .where((e) => e.journeyId == _base.journeyId)
          .toList();
      _measurements = _maps(json['measurements'])
          .map(BodyMeasurement.fromJson)
          .whereType<BodyMeasurement>()
          .where((e) => e.journeyId == _base.journeyId)
          .toList();
      _name = json['name'] as String? ?? '';
      _avatar = (json['avatar'] as num?)?.toInt() ?? 0;
      _adult = json['adultConfirmed'] == true;
      _reminder = json['reminder'] == true;
      _reminderMinutes = (json['reminderMinutes'] as num?)?.toInt() ?? 18 * 60;
      _timer.restore(_active?.activeSeconds ?? 0);
      setState(() {
        _ready = true;
        _error = null;
      });
    } catch (_) {
      if (!mounted || epoch != _loadEpoch) return;
      setState(() {
        _storageBlocked = true;
        _ready = true;
        _error =
            'The saved journey could not be read. Your saved copy has been kept. Contact support before continuing.';
      });
      return;
    }
    if (!kIsWeb && !debugDisableExternalServices) {
      await Notifications.instance.init();
      if (_reminder) {
        await Notifications.instance.scheduleDailyReminder(
          hour: _reminderMinutes ~/ 60,
          minute: _reminderMinutes % 60,
        );
      } else {
        await Notifications.instance.cancelDailyReminder();
      }
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (!_ready) return;
    if (state == AppLifecycleState.resumed) {
      if (_safe &&
          !_savedWorkoutNeedsReview &&
          _playerVisible &&
          _active != null &&
          !_active!.awaitingFeedback) {
        _timer.resume(DateTime.now());
      }
      if (_purchases != null) unawaited(_purchases!.refresh());
    } else {
      _timer.pause(DateTime.now());
      unawaited(_save());
    }
  }

  Future<void> _finishOnboarding(OnboardingProfile profile) async {
    if (_storageBlocked) return;
    final epoch = _loadEpoch;
    final previous = _profile;
    final draft = _draft;
    _profile = profile;
    _onboarded = true;
    _draft = null;
    final saved = await _save();
    if (!mounted || epoch != _loadEpoch) return;
    if (!saved) {
      setState(() {
        _profile = previous;
        _onboarded = false;
        _draft = draft;
      });
      throw StateError('Onboarding was not saved');
    }
    if (mounted) setState(() {});
  }

  Future<void> _editPreferences() async {
    final epoch = _loadEpoch;
    await Navigator.of(context, rootNavigator: true).push<void>(
      CupertinoPageRoute(
        builder: (route) => OnboardingScreen(
          initialProfile: _profile,
          editing: true,
          onFinish: (profile) async {
            if (epoch != _loadEpoch) return;
            final previous = _profile;
            _profile = profile;
            final saved = await _save();
            if (!mounted || epoch != _loadEpoch) return;
            if (!saved) {
              setState(() {
                _profile = previous;
              });
              throw StateError('Preferences were not saved');
            }
            if (!_safe || _savedWorkoutNeedsReview) {
              _timer.pause(DateTime.now());
              _playerVisible = false;
            }
            setState(() {});
            if (route.mounted) Navigator.pop(route);
          },
        ),
      ),
    );
  }

  Future<void> _start({PlannedWorkout? optional, int? replayCheckpoint}) async {
    if (_busy || !_ready || _storageBlocked) return;
    final epoch = _loadEpoch;
    if (!_safe) {
      await showBrandedInfoSheet(
        context,
        title: 'Review safety first',
        message:
            'Personalized exercise is paused. Review your safety answers in Workout preferences and seek medical guidance for any flagged symptom or restriction.',
      );
      return;
    }
    final active = _active;
    if (active != null) {
      setState(() {
        _tabs.index = 1;
        _playerVisible = !_savedWorkoutNeedsReview;
      });
      if (!_playerVisible) _timer.pause(DateTime.now());
      if (_playerVisible && !active.awaitingFeedback) {
        _timer.resume(DateTime.now());
      }
      return;
    }
    setState(() => _busy = true);
    try {
      if (optional != null &&
          !optional.exercises.every((e) => exerciseFitsProfile(e, _profile))) {
        throw StateError('Optional movement does not fit these preferences.');
      }
      final workout =
          optional ??
          generateCheckpointWorkout(
            profile: _profile,
            progress: _journey,
            energy: _energy,
            gentle: _gentle,
          );
      _active = FrozenWorkout(
        eventId: _newId(),
        workout: workout,
        checkpoint: optional == null
            ? _journey.nextCheckpoint
            : replayCheckpoint,
        energy: _energy,
        startedAt: DateTime.now(),
      );
      _timer.reset();
      final saved = await _save();
      if (!mounted || epoch != _loadEpoch) return;
      if (!saved) {
        _active = null;
        return;
      }
      if (!mounted) return;
      setState(() {
        _tabs.index = 1;
        _playerVisible = true;
      });
      _timer.resume(DateTime.now());
    } catch (_) {
      if (mounted) {
        setState(
          () => _error =
              'No suitable workout fits these settings. Review your equipment and ability in Profile.',
        );
      }
    } finally {
      if (mounted && epoch == _loadEpoch) setState(() => _busy = false);
    }
  }

  Future<void> _exerciseAction({bool skip = false}) async {
    final active = _active;
    if (active == null || _busy) return;
    final epoch = _loadEpoch;
    final before = FrozenWorkout.fromJson(active.toJson());
    setState(() => _busy = true);
    if (skip) {
      active.skipped.add(active.current);
    } else {
      active.completed.add(active.current);
    }
    active.setIndex = 0;
    active.restUntil = null;
    if (active.current == active.workout.exercises.length - 1) {
      _timer.pause(DateTime.now());
      active.awaitingFeedback = true;
    } else {
      active.current++;
    }
    final saved = await _save();
    if (!mounted || epoch != _loadEpoch) return;
    if (!saved) {
      _active = before;
      if (!before.awaitingFeedback && _playerVisible) {
        _timer.resume(DateTime.now());
      }
    }
    setState(() => _busy = false);
  }

  Future<void> _stop() async {
    if (_active == null || _busy) return;
    final epoch = _loadEpoch;
    final stop = await _confirm(
      context,
      'Finish this attempt?',
      'Your completed movements will be recorded. You can also pause and resume the exact workout later.',
      action: 'Finish attempt',
    );
    if (!stop || !mounted || epoch != _loadEpoch || _busy || _active == null) {
      return;
    }
    _timer.pause(DateTime.now());
    setState(() {
      _busy = true;
      _active!.awaitingFeedback = true;
    });
    final saved = await _save();
    if (!mounted || epoch != _loadEpoch) return;
    setState(() {
      _busy = false;
      if (!saved) _active!.awaitingFeedback = false;
    });
    if (!saved) _timer.resume(DateTime.now());
  }

  Future<void> _discardIncompatibleWorkout() async {
    final active = _active;
    if (active == null || _busy || !_savedWorkoutNeedsReview) return;
    final epoch = _loadEpoch;
    setState(() => _busy = true);
    try {
      final discard = await _confirm(
        context,
        'Discard this saved workout?',
        'The unfinished attempt will be removed. Earned checkpoints and history stay saved.',
        action: 'Discard workout',
        destructive: true,
      );
      if (!discard || !mounted || epoch != _loadEpoch) return;
      _timer.pause(DateTime.now());
      _active = null;
      final saved = await _save();
      if (!mounted || epoch != _loadEpoch) return;
      if (saved) {
        _timer.reset();
      } else {
        _active = active;
      }
    } finally {
      if (mounted && epoch == _loadEpoch) setState(() => _busy = false);
    }
  }

  Future<void> _finish(String feedback) async {
    final active = _active;
    if (active == null || _busy) return;
    final epoch = _loadEpoch;
    setState(() => _busy = true);
    final qualified = active.qualified && feedback != 'pain';
    final advances = qualified && active.checkpoint == _journey.nextCheckpoint;
    final entry = WorkoutHistoryEntry(
      id: active.eventId,
      eventId: active.eventId,
      journeyId: _base.journeyId,
      checkpoint: active.checkpoint,
      title: active.workout.title,
      source: advances ? WorkoutSource.checkpoint : WorkoutSource.practice,
      startedAt: active.startedAt,
      completedAt: DateTime.now(),
      activeSeconds: _timer.seconds(DateTime.now()),
      plannedMinutes: active.workout.estMinutes,
      completedExerciseCount: active.completed.length,
      totalExerciseCount: active.workout.exercises.length,
      skippedExerciseCount:
          active.workout.exercises.length - active.completed.length,
      energy: active.energy,
      points: advances ? 100 : 0,
      difficultyFeedback: feedback,
      qualified: qualified,
      focusCategories: _profile.focusAreas.map((e) => e.name).toList(),
    );
    final nextProgress = recordJourneyAttempt(
      _base,
      checkpoint: active.checkpoint,
      qualified: qualified,
      feedback: feedback,
    );
    final storedEntry = WorkoutHistoryEntry.fromJson({
      ...entry.toJson(),
      'source': advances
          ? WorkoutSource.checkpoint.name
          : WorkoutSource.practice.name,
      'points': advances ? 100 : 0,
    })!;
    final previousProgress = _base;
    _history.add(storedEntry);
    _base = nextProgress;
    _active = null;
    final saved = await _save();
    if (!mounted || epoch != _loadEpoch) return;
    if (!saved) {
      _active = active;
      _history.removeWhere((e) => e.id == entry.id);
      _base = previousProgress;
      if (mounted) setState(() => _busy = false);
      return;
    }
    _timer.reset();
    if (!mounted) return;
    setState(() {
      _busy = false;
      _playerVisible = false;
      _tabs.index = 0;
    });
    await showBrandedInfoSheet(
      context,
      title: advances
          ? 'Checkpoint ${active.checkpoint} complete!'
          : 'Your effort is recorded',
      message: advances
          ? 'Purr moved forward. The next checkpoint is open. Rest and recover; continue whenever you feel ready.'
          : feedback == 'pain'
          ? 'Stopping was the right choice. Do not push through pain, chest discomfort, faintness, or unusual breathlessness. Seek medical help for concerning symptoms. Your place is saved.'
          : 'This attempt stays in History. Your checkpoint is still here, with no penalty. Choose a gentler version when you are ready.',
    );
  }

  @override
  void dispose() {
    _timer.pause(DateTime.now());
    _autosave?.cancel();
    _tabs.dispose();
    _ads?.dispose();
    _consent?.removeListener(_serviceChanged);
    _consent?.dispose();
    _purchases?.removeListener(_serviceChanged);
    _purchases?.dispose();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_ready) return const SplashScreen();
    if (_storageBlocked) {
      return AppPage(
        title: 'Your saved journey is protected',
        children: [
          Text(_error ?? 'Could not read saved progress.'),
          const AppGap(),
          AppPrimaryButton(
            label: 'Retry reading saved journey',
            onPressed: _loadOwner,
          ),
        ],
      );
    }
    if (!_onboarded) {
      return OnboardingScreen(
        initialProfile: _draft,
        initialStep: _draftStep,
        onDraft: (profile, step) {
          _draft = profile;
          _draftStep = step;
          unawaited(_save());
        },
        onFinish: _finishOnboarding,
      );
    }
    return CupertinoTabScaffold(
      controller: _tabs,
      tabBar: CupertinoTabBar(
        onTap: (index) {
          if (index != 1) {
            _timer.pause(DateTime.now());
            _playerVisible = false;
            unawaited(_save());
          }
        },
        items: const [
          BottomNavigationBarItem(
            icon: Icon(CupertinoIcons.map),
            label: 'Journey',
          ),
          BottomNavigationBarItem(
            icon: Icon(CupertinoIcons.bolt),
            label: 'Workout',
          ),
          BottomNavigationBarItem(
            icon: Icon(CupertinoIcons.chart_bar),
            label: 'Report',
          ),
          BottomNavigationBarItem(
            icon: Icon(CupertinoIcons.person),
            label: 'Profile',
          ),
        ],
      ),
      tabBuilder: (context, index) => CupertinoTabView(
        builder: (context) {
          final error = _error;
          return switch (index) {
            0 => JourneyScreen(
              progress: _journey,
              hasActive: _active != null,
              busy: _busy,
              error: error,
              energy: _energy,
              gentle: _gentle,
              onGentle: () {
                setState(() => _gentle = !_gentle);
                unawaited(_save());
              },
              onEnergy: (value) {
                setState(() => _energy = value);
                unawaited(_save());
              },
              onStart: _start,
              onReplay: _replay,
            ),
            1 => _workoutPage(),
            2 => ReportScreen(
              progress: _journey,
              history: _history,
              measurements: _measurements,
              adultConfirmed: _adult,
              error: _error,
              onAdult: (value) {
                setState(() {
                  _adult = value;
                });
                unawaited(_save());
              },
              onAddMeasurement: _addMeasurement,
              onDeleteMeasurement: (id) async {
                final entry = _measurements
                    .where((e) => e.id == id)
                    .firstOrNull;
                if (entry == null) return;
                setState(() {
                  _measurements.removeWhere((e) => e.id == id);
                });
                final saved = await _save();
                if (!mounted) return;
                if (!saved) setState(() => _measurements.add(entry));
              },
              onDeleteHistory: (id) async {
                final entry = _history.where((e) => e.id == id).firstOrNull;
                if (entry == null) return;
                setState(() {
                  _history.removeWhere((e) => e.id == id);
                });
                final saved = await _save();
                if (!mounted) return;
                if (!saved) setState(() => _history.add(entry));
              },
              isAdFree: _extraContentUnlocked,
              onRemoveAds: _openRemoveAds,
              onReward: _watchAd,
            ),
            _ => _profilePage(),
          };
        },
      ),
    );
  }

  Widget _workoutPage() {
    final active = _active;
    final needsReview = _savedWorkoutNeedsReview;
    if (active != null && _playerVisible && _safe && !needsReview) {
      if (active.awaitingFeedback) {
        return WorkoutCompleteScreen(
          qualified: active.qualified,
          busy: _busy,
          error: _error,
          onFeedback: _finish,
        );
      }
      return WorkoutScreen(
        key: ValueKey(active.eventId),
        session: active,
        busy: _busy,
        error: _error,
        onComplete: () => _exerciseAction(),
        onSkip: () => _exerciseAction(skip: true),
        onSave: _save,
        onStop: _stop,
        onPause: () {
          _timer.pause(DateTime.now());
          setState(() => _playerVisible = false);
          unawaited(_save());
        },
      );
    }
    PlannedWorkout? preview;
    if (_safe) {
      try {
        preview =
            active?.workout ??
            generateCheckpointWorkout(
              profile: _profile,
              progress: _journey,
              energy: _energy,
              gentle: _gentle,
            );
      } catch (_) {
        /* Preferences can exclude all suitable movement. */
      }
    }
    return AppPage(
      title: 'Workout',
      children: [
        if (!_safe) ...[
          const _BuddyNote(
            'Personalized workouts are paused until you complete the safety review and clear any red flags.',
          ),
          AppPrimaryButton(
            label: 'Review workout preferences',
            onPressed: _editPreferences,
          ),
        ] else if (needsReview) ...[
          const _BuddyNote(
            'Your saved workout includes movements that no longer fit your equipment, floor, or impact settings.',
          ),
          AppPrimaryButton(
            label: 'Review workout preferences',
            onPressed: _busy ? null : _editPreferences,
          ),
          CupertinoButton(
            onPressed: _busy ? null : _discardIncompatibleWorkout,
            child: const Text('Discard saved workout'),
          ),
        ] else if (preview == null) ...[
          const _BuddyNote(
            'No suitable workout fits your current setup. Review equipment and ability in Profile.',
          ),
          AppPrimaryButton(
            label: 'Review workout preferences',
            onPressed: _editPreferences,
          ),
        ] else ...[
          Text(
            active == null
                ? 'Checkpoint ${_journey.nextCheckpoint}'
                : 'Your saved workout',
            style: AppTypography.title2(context),
          ),
          const AppGap(),
          Text('${preview.title} · about ${preview.estMinutes} min'),
          const AppGap(),
          AppPrimaryButton(
            label: active == null ? 'Start checkpoint' : 'Resume workout',
            loading: _busy,
            onPressed: _busy ? null : _start,
          ),
          const AppGap(),
          for (final exercise in preview.exercises) _ExerciseRow(exercise),
        ],
        if (_error != null) Text(_error!),
        const AppGap(),
        const _BuddyNote(
          'Rest between sessions and whenever you feel sore or tired. Your next checkpoint never expires.',
        ),
        const AppGap(),
        const AppSectionHeader('Optional movement'),
        const Text(
          'Practice and extras record effort without moving Purr or earning checkpoint points.',
        ),
        const AppGap(),
        if (_safe) ...[
          for (final workout in specializedWorkouts(_profile))
            _SettingsTile(
              workout.name,
              '${workout.focus} · about ${workout.estMinutes} min',
              onTap: () => _openBonus(workout),
              icon: workout.icon,
            ),
          for (final activity in quickActivities.where(
            (e) =>
                (e.id != 'bridge' ||
                    (_profile.floorAllowed &&
                        _profile.equipment.contains(
                          EquipmentItem.floorSpace,
                        ))) &&
                (e.id != 'sit_to_stand' ||
                    _profile.equipment.contains(EquipmentItem.chair)),
          ))
            _SettingsTile(
              activity.title,
              activity.detail,
              icon: activity.icon,
              onTap: () => _openQuick(activity),
            ),
        ],
      ],
    );
  }

  Future<void> _replay(int checkpoint) async {
    final entries = _history
        .where(
          (e) =>
              e.checkpoint == checkpoint &&
              e.source == WorkoutSource.checkpoint,
        )
        .toList();
    if (entries.isEmpty) {
      await showBrandedInfoSheet(
        context,
        title: 'Checkpoint $checkpoint complete',
        message:
            'This checkpoint is already earned. Optional workouts are available from Workout.',
      );
      return;
    }
    // Replay uses a fresh suitable prescription; its original checkpoint stays fixed.
    final progress = JourneyProgress(
      journeyId: _base.journeyId,
      completedCheckpoints: checkpoint - 1,
      difficulty: _journey.difficulty,
      points: _journey.points,
    );
    if (!_safe) return;
    try {
      await _start(
        optional: generateCheckpointWorkout(
          profile: _profile,
          progress: progress,
          energy: _energy,
        ),
        replayCheckpoint: checkpoint,
      );
    } catch (_) {
      if (mounted) {
        setState(() => _error = 'No suitable replay fits these preferences.');
      }
    }
  }

  /// Ad-free access also opens optional content, since the ad was the only key.
  Future<RewardedResult> _watchAd() async {
    if (_extraContentUnlocked) return RewardedResult.earned;
    return await _ads?.showRewarded() ?? RewardedResult.notReady;
  }

  Future<void> _openBonus(SpecializedWorkout workout) async {
    if (!_safe || _active != null) {
      await _start();
      return;
    }
    if (!_extraContentUnlocked) {
      if (!await _confirm(
        context,
        'Unlock optional workout?',
        'Watch a short ad to unlock this workout, or remove all ads from Profile.',
        action: 'Watch ad',
      )) {
        return;
      }
      if (!mounted) return;
      final result = await _watchAd();
      if (!mounted) return;
      if (result != RewardedResult.earned) {
        await showBrandedInfoSheet(
          context,
          title: 'Workout not unlocked',
          message: result == RewardedResult.dismissedWithoutReward
              ? 'The ad was closed before the reward. You can try again.'
              : 'No ad is ready. Please try again later.',
        );
        return;
      }
    }
    await _start(
      optional: PlannedWorkout(
        seq: 0,
        title: workout.name,
        estMinutes: workout.estMinutes,
        exercises: workout.exercises,
      ),
    );
  }

  Future<void> _openQuick(QuickActivity activity) async {
    final exercise = switch (activity.id) {
      'sit_to_stand' => const PlannedExercise(
        'Chair squat',
        '1 × 10 reps',
        'Use a sturdy chair. Move slowly.',
        CupertinoIcons.person,
      ),
      'march' => const PlannedExercise(
        'March in place',
        '120 sec',
        'Keep an easy, comfortable pace.',
        CupertinoIcons.flame,
      ),
      'bridge' => const PlannedExercise(
        'Glute bridge',
        '1 × 20 reps',
        'Squeeze gently at the top.',
        CupertinoIcons.person,
      ),
      'calf_raises' => const PlannedExercise(
        'Calf raises',
        '1 × 15 reps',
        'Use a wall for balance if needed.',
        CupertinoIcons.person,
      ),
      _ => const PlannedExercise(
        'Standing cool-down stretch',
        '40 sec',
        'Gently open your chest and breathe. Stay in a comfortable range.',
        CupertinoIcons.leaf_arrow_circlepath,
      ),
    };
    await _start(
      optional: PlannedWorkout(
        seq: 0,
        title: activity.title,
        estMinutes: 2,
        exercises: [exercise],
      ),
    );
  }

  Future<void> _openRemoveAds() async {
    await Navigator.of(context, rootNavigator: true).push(
      CupertinoPageRoute<void>(
        builder: (_) => RemoveAdsScreen(purchases: _purchases),
      ),
    );
  }

  Future<bool> _addMeasurement(double weight, double? height) async {
    if (!weight.isFinite ||
        weight < 20 ||
        weight > 400 ||
        (height != null && (!height.isFinite || height < 80 || height > 250))) {
      return false;
    }
    final epoch = _loadEpoch;
    final entry = BodyMeasurement(
      id: _newId(),
      measuredAt: DateTime.now(),
      weightKg: weight,
      heightCm: height,
      journeyId: _base.journeyId,
    );
    setState(() => _measurements.add(entry));
    final saved = await _save();
    if (!mounted || epoch != _loadEpoch) return false;
    if (!saved) {
      setState(() => _measurements.removeWhere((e) => e.id == entry.id));
      return false;
    }
    return true;
  }

  Future<void> _reminderSettings() async {
    var minutes = _reminderMinutes;
    await showCupertinoModalPopup<void>(
      context: context,
      builder: (sheet) => Container(
        color: AppColors.surface(sheet),
        child: SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('Optional daily reminder'),
                const Text('A nudge, never a deadline.'),
                SizedBox(
                  height: 160,
                  child: CupertinoDatePicker(
                    mode: CupertinoDatePickerMode.time,
                    initialDateTime: DateTime(
                      2026,
                      1,
                      1,
                      minutes ~/ 60,
                      minutes % 60,
                    ),
                    onDateTimeChanged: (date) =>
                        minutes = date.hour * 60 + date.minute,
                  ),
                ),
                AppPrimaryButton(
                  label: 'Enable reminder',
                  onPressed: () async {
                    Navigator.pop(sheet);
                    final granted = await Notifications.instance
                        .requestPermission();
                    final scheduled =
                        granted &&
                        await Notifications.instance.scheduleDailyReminder(
                          hour: minutes ~/ 60,
                          minute: minutes % 60,
                        );
                    if (!mounted) return;
                    setState(() {
                      _reminder = scheduled;
                      _reminderMinutes = minutes;
                    });
                    await _save();
                    if (!scheduled && mounted) {
                      await showBrandedInfoSheet(
                        context,
                        title: 'Reminder not enabled',
                        message:
                            'Allow notifications in your device settings and try again.',
                      );
                    }
                  },
                ),
                CupertinoButton(
                  onPressed: () async {
                    Navigator.pop(sheet);
                    await Notifications.instance.cancelDailyReminder();
                    if (mounted) setState(() => _reminder = false);
                    await _save();
                  },
                  child: const Text('Turn off reminders'),
                ),
                CupertinoButton(
                  onPressed: () => Navigator.pop(sheet),
                  child: const Text('Cancel'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _deleteLocalData() async {
    if (!await _confirm(
      context,
      'Delete local data?',
      'This permanently removes your workout and profile data from this device. Your app-store purchase is managed separately.',
      action: 'Delete',
      destructive: true,
    )) {
      return;
    }
    _deleting = true;
    ++_loadEpoch;
    _timer.pause(DateTime.now());
    setState(() {
      _ready = false;
    });
    String? deletionError;
    try {
      await _writes;
      final ok = await _store.clear(
        await SharedPreferences.getInstance(),
        clearLegacyPreferences: true,
      );
      if (!ok) throw StateError('Local deletion failed');
      if (!kIsWeb && !debugDisableExternalServices) {
        await Notifications.instance.cancelDailyReminder();
      }
    } catch (_) {
      deletionError = 'Your data could not be deleted. Please retry.';
    } finally {
      _deleting = false;
      if (mounted) await _loadOwner();
    }
    if (mounted && deletionError != null) {
      await showBrandedInfoSheet(
        context,
        title: 'Deletion failed',
        message: deletionError,
      );
    }
  }

  Widget _profilePage() => AppPage(
    title: 'Profile',
    trailing: const _ThemeToggle(),
    children: [
      Row(
        children: [
          const _BrandArtwork(height: 64),
          const SizedBox(width: 16),
          Expanded(
            child: Text(
              _name.isNotEmpty ? _name : 'Your Purrfit',
              style: AppTypography.title2(context),
            ),
          ),
        ],
      ),
      const AppGap(),
      if (_error != null) Text(_error!),
      const _BuddyNote('Your journey is saved privately on this device.'),
      const AppGap(),
      const AppSectionHeader('Your preferences'),
      _SettingsTile(
        'Workout preferences',
        '${_profile.primaryGoal.title} · ${_profile.sessionMinutes} min',
        onTap: _editPreferences,
      ),
      const Text(
        'Changes shape future workouts. Your journey and saved workout stay intact.',
      ),
      _SettingsTile(
        'Name & picture',
        'Personalize your profile',
        onTap: () async {
          final epoch = _loadEpoch;
          await Navigator.of(context, rootNavigator: true).push(
            CupertinoPageRoute<void>(
              builder: (_) => EditProfileScreen(
                initialName: _name,
                initialAvatar: _avatar,
                onSave: (name, avatar) async {
                  if (epoch != _loadEpoch) throw StateError('Account changed');
                  final previous = (_name, _avatar);
                  _name = name;
                  _avatar = avatar;
                  final saved = await _save();
                  if (!mounted || epoch != _loadEpoch) return;
                  if (!saved) {
                    setState(() {
                      _name = previous.$1;
                      _avatar = previous.$2;
                    });
                    throw StateError('Profile was not saved');
                  }
                },
              ),
            ),
          );
        },
      ),
      if (!kIsWeb)
        _SettingsTile(
          'Reminders',
          _reminder
              ? 'On · ${(_reminderMinutes ~/ 60).toString().padLeft(2, '0')}:${(_reminderMinutes % 60).toString().padLeft(2, '0')}'
              : 'Off',
          onTap: _reminderSettings,
        ),
      if (_consent?.privacyOptionsRequired ?? false)
        _SettingsTile(
          'Privacy & ads',
          'Manage choices',
          onTap: () => _consent!.showPrivacyOptions(),
        ),
      if (_monetized)
        _SettingsTile(
          'Remove ads · one-time purchase',
          _removeAds
              ? 'Paid · no ads'
              : _purchases?.priceString ?? 'See store price',
          onTap: _openRemoveAds,
        ),
      const AppGap(),
      const AppSectionHeader('About your journey'),
      _BuddyNote(
        _monetized
            ? 'Your journey is stored on this device. Your store account manages your ad-removal purchase separately.'
            : 'Your journey is stored on this device. Use Delete local data to erase it.',
      ),
      for (final link in [
        ('Privacy policy', _privacyUrl),
        ('Terms', _termsUrl),
        ('Support', _supportUrl),
      ])
        if (Uri.tryParse(link.$2) case final Uri url
            when url.scheme == 'https' && url.host.isNotEmpty)
          _SettingsTile(
            link.$1,
            'Open in browser',
            onTap: () async {
              var opened = false;
              try {
                opened = await launchUrl(
                  url,
                  mode: LaunchMode.externalApplication,
                );
              } on PlatformException {
                // The browser may be unavailable on this device.
              }
              if (!opened && mounted) {
                await showBrandedInfoSheet(
                  context,
                  title: 'Could not open ${link.$1.toLowerCase()}',
                  message: 'Open ${url.host} in your browser and try again.',
                );
              }
            },
          ),
      _SettingsTile(
        'Delete local data',
        'Permanently delete your data',
        onTap: _deleteLocalData,
      ),
    ],
  );
}

class _ThemeToggle extends StatelessWidget {
  const _ThemeToggle();
  @override
  Widget build(BuildContext context) => CupertinoButton(
    padding: EdgeInsets.zero,
    onPressed: () async {
      final dark = !AppColors.isDark(context);
      appIsDark.value = dark;
      await (await SharedPreferences.getInstance()).setBool('darkMode', dark);
    },
    child: Semantics(
      label: 'Change appearance',
      button: true,
      child: const Icon(CupertinoIcons.circle_lefthalf_fill, size: 28),
    ),
  );
}

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({
    super.key,
    required this.onFinish,
    this.initialProfile,
    this.initialStep = 0,
    this.onDraft,
    this.editing = false,
  });
  final Future<void> Function(OnboardingProfile) onFinish;
  final OnboardingProfile? initialProfile;
  final int initialStep;
  final void Function(OnboardingProfile, int)? onDraft;
  final bool editing;
  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  late OnboardingProfile _profile =
      widget.initialProfile ??
      const OnboardingProfile(
        equipment: {
          EquipmentItem.floorSpace,
          EquipmentItem.wall,
          EquipmentItem.chair,
        },
      );
  late int _step = widget.editing ? 1 : widget.initialStep.clamp(0, 6);
  late final _height = TextEditingController(
    text: _profile.heightCm?.toStringAsFixed(0),
  );
  late final _weight = TextEditingController(
    text: _profile.weightKg?.toStringAsFixed(1),
  );
  bool _busy = false;
  String? _error;
  void _update(OnboardingProfile value) {
    setState(() => _profile = value);
    widget.onDraft?.call(value, _step);
  }

  Future<void> _next() async {
    if (_busy) return;
    if (_step == 4) {
      final height = double.tryParse(_height.text),
          weight = double.tryParse(_weight.text);
      if ((_height.text.isNotEmpty &&
              (height == null ||
                  !height.isFinite ||
                  height < 80 ||
                  height > 250)) ||
          (_weight.text.isNotEmpty &&
              (weight == null ||
                  !weight.isFinite ||
                  weight < 20 ||
                  weight > 400))) {
        setState(
          () => _error =
              'Use height 80–250 cm and weight 20–400 kg, or leave them blank.',
        );
        return;
      }
      _profile = _profile.copyWith(heightCm: height, weightKg: weight);
    }
    if (_step == 5 && !_profile.safetyReviewed) {
      setState(
        () => _error =
            'Review the safety questions and confirm your answers to continue.',
      );
      return;
    }
    if (_step < 6) {
      setState(() {
        _step++;
        _error = null;
      });
      widget.onDraft?.call(_profile, _step);
    } else {
      setState(() => _busy = true);
      try {
        await widget.onFinish(_profile);
      } catch (_) {
        if (mounted) {
          setState(
            () => _error = 'Your choices could not be saved. Please retry.',
          );
        }
      } finally {
        if (mounted) setState(() => _busy = false);
      }
    }
  }

  @override
  void dispose() {
    _height.dispose();
    _weight.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final titles = [
      'A little movement. A new adventure.',
      'What brings you here?',
      'Start with what feels comfortable',
      'Your workout setup',
      'Make it yours',
      'A quick safety check',
      'Your journey is ready',
    ];
    return AppPage(
      key: ValueKey('onboarding-$_step'),
      title: titles[_step],
      children: [
        if (_step > 0) ...[
          AppProgressBar(value: _step / 6, label: 'Setup step $_step of 6'),
          const AppGap(),
        ],
        ...switch (_step) {
          0 => [
            const Center(child: _BrandArtwork(height: 210)),
            const AppGap(),
            const _BuddyNote(
              'Meet Purr. Finish one workout, move one checkpoint. Your place is always saved, however long your break.',
            ),
            const AppGap(),
            const Text(
              'Six workouts per chapter. No assigned days, deadlines, or missed-day penalties.',
            ),
            const AppGap(),
            const Text(
              'This is a fresh journey. Earlier records stay separate, and everything you do next is saved on this device.',
            ),
          ],
          1 => [
            for (final goal in WorkoutGoal.values)
              _choice(
                goal.title,
                _profile.primaryGoal == goal,
                () => _update(_profile.copyWith(primaryGoal: goal)),
              ),
            const AppGap(),
            const AppSectionHeader('Areas you enjoy'),
            const Text('Choose any. Purr still balances your whole body.'),
            for (final focus in FocusArea.values)
              _choice(
                _focusLabel(focus),
                _profile.focusAreas.contains(focus),
                () {
                  final areas = {..._profile.focusAreas};
                  if (!areas.add(focus)) areas.remove(focus);
                  _update(
                    _profile.copyWith(
                      focusAreas: areas.isEmpty ? {FocusArea.fullBody} : areas,
                    ),
                  );
                },
              ),
          ],
          2 => [
            const Text(
              'Pick a comfortable starting point. These are self-reports, not a fitness test. You can change them later.',
            ),
            const AppGap(),
            _ability(
              'Pushing',
              [
                'Wall support',
                'A few wall push-ups',
                'Incline push-ups',
                'Knee push-ups',
                'A few floor push-ups',
                'Comfortable floor push-ups',
                'Strong floor push-ups',
              ],
              _profile.capability.push,
              (v) => _update(
                _profile.copyWith(
                  capability: _profile.capability.copyWith(push: v),
                ),
              ),
            ),
            _ability(
              'Legs',
              [
                'Chair support',
                'A few squats',
                'Comfortable squats',
                'Comfortable lunges',
                'Strong single-leg control',
              ],
              _profile.capability.lower,
              (v) => _update(
                _profile.copyWith(
                  capability: _profile.capability.copyWith(lower: v),
                ),
              ),
            ),
            _ability(
              'Core',
              [
                'Just starting',
                'Gentle floor movements',
                'Short planks',
                'Comfortable planks',
              ],
              _profile.capability.core,
              (v) => _update(
                _profile.copyWith(
                  capability: _profile.capability.copyWith(core: v),
                ),
              ),
            ),
            _ability(
              'Breathing & stamina',
              [
                'Easy marching',
                'A few minutes of movement',
                'Moderate movement',
                'Comfortable sustained movement',
              ],
              _profile.capability.conditioning,
              (v) => _update(
                _profile.copyWith(
                  capability: _profile.capability.copyWith(conditioning: v),
                ),
              ),
            ),
            const AppSectionHeader('Everyday activity'),
            for (final level in DailyActivityLevel.values)
              _choice(
                switch (level) {
                  DailyActivityLevel.seated => 'Mostly seated',
                  DailyActivityLevel.light => 'Lightly active',
                  DailyActivityLevel.moderate => 'Moderately active',
                  DailyActivityLevel.veryActive => 'Very active',
                },
                _profile.activityLevel == level,
                () => _update(_profile.copyWith(activityLevel: level)),
              ),
          ],
          3 => [
            const Text(
              'Select only what you can safely use. Check household supports are stable before every workout.',
            ),
            for (final item in EquipmentItem.values)
              _choice(
                _equipmentLabel(item),
                _profile.equipment.contains(item),
                () {
                  final equipment = {..._profile.equipment};
                  if (!equipment.add(item)) equipment.remove(item);
                  _update(_profile.copyWith(equipment: equipment));
                },
              ),
            const AppGap(),
            _switch(
              'Floor exercises are comfortable',
              _profile.floorAllowed,
              (v) => _update(_profile.copyWith(floorAllowed: v)),
            ),
            _switch(
              'Keep movement low impact',
              _profile.impact == ImpactPreference.lowImpact,
              (v) => _update(
                _profile.copyWith(
                  impact: v ? ImpactPreference.lowImpact : ImpactPreference.any,
                ),
              ),
            ),
            const AppGap(),
            const AppSectionHeader('Preferred workout length'),
            for (final minutes in [10, 15, 20, 30, 45])
              _choice(
                '$minutes minutes',
                _profile.sessionMinutes == minutes,
                () => _update(_profile.copyWith(sessionMinutes: minutes)),
              ),
            const Text(
              'A preference, not a deadline. Actual length depends on your pace and rests.',
            ),
          ],
          4 => [
            const AppSectionHeader('Optional avatar'),
            const Text(
              'Personalization is based on your comfort, preferences, and safety—not your appearance.',
            ),
            const AppGap(),
            const AppSectionHeader('Optional body information'),
            const Text(
              'Leave these blank if you prefer. No body goals or deadlines are required.',
            ),
            const AppGap(),
            _numberField(_height, 'Height in cm'),
            const SizedBox(height: 12),
            _numberField(_weight, 'Weight in kg'),
          ],
          5 => [
            const Text(
              'Are any of these true for you? These answers help decide whether personalized exercise should pause.',
            ),
            const AppGap(),
            for (var i = 0; i < _safetyLabels.length; i++)
              _switch(_safetyLabels[i], _safetyValues(_profile.safety)[i], (
                value,
              ) {
                final values = _safetyValues(_profile.safety)..[i] = value;
                _update(
                  _profile.copyWith(
                    safety: SafetyProfile(
                      chestPainOrFainting: values[0],
                      severeShortnessOfBreath: values[1],
                      recentSurgeryNoClearance: values[2],
                      pregnancyPostpartumNoClearance: values[3],
                      doctorRestriction: values[4],
                      injuryToAvoid: values[5],
                    ),
                    safetyReviewed: false,
                  ),
                );
              }),
            const AppGap(),
            if (_profile.blockedByRedFlag) ...[
              const _BuddyNote(
                'Personalized exercise will stay paused. Please get appropriate medical guidance before exercising. Purrfit does not provide rehabilitation or medical clearance.',
              ),
              const AppGap(),
            ],
            _switch(
              'I have reviewed these questions and my answers are accurate',
              _profile.safetyReviewed,
              (v) => _update(_profile.copyWith(safetyReviewed: v)),
            ),
            const AppGap(),
            const Text(
              'Stop for pain, chest discomfort, faintness, or unusual shortness of breath. Seek urgent help for severe or ongoing symptoms.',
            ),
          ],
          _ => [
            const Center(child: _BrandArtwork(height: 170)),
            const AppGap(),
            Text(
              _profile.blockedByRedFlag
                  ? 'Your safety comes first'
                  : '${_profile.primaryGoal.title}, at your pace.',
              style: AppTypography.title2(context),
            ),
            const AppGap(),
            Text(
              _profile.blockedByRedFlag
                  ? 'We will save your preferences. Personalized workouts remain paused until your safety review is clear.'
                  : 'Purr starts at checkpoint 1. Complete at least half of the main movements to move forward. Warm-up and cool-down alone do not clear a checkpoint.',
            ),
            const AppGap(),
            const _BuddyNote(
              'Difficulty follows your ability, completed movement, and feedback. Checkpoint numbers and time away never make a workout harder.',
            ),
            if (widget.editing) ...[
              const AppGap(),
              const Text(
                'Your progress, points, and active workout stay exactly where they are.',
              ),
            ],
          ],
        },
        const AppGap(),
        if (_error != null) ...[
          Text(_error!, style: TextStyle(color: AppColors.danger(context))),
          const AppGap(),
        ],
        AppPrimaryButton(
          label: _step == 0
              ? 'Meet my journey'
              : _step == 6
              ? (widget.editing ? 'Save preferences' : 'Begin my journey')
              : 'Continue',
          loading: _busy,
          onPressed: _busy ? null : _next,
        ),
        if (_step > (widget.editing ? 1 : 0))
          CupertinoButton(
            onPressed: _busy
                ? null
                : () {
                    setState(() {
                      _step--;
                      _error = null;
                    });
                    widget.onDraft?.call(_profile, _step);
                  },
            child: const Text('Back'),
          ),
        if (widget.editing)
          CupertinoButton(
            onPressed: () => Navigator.maybePop(context),
            child: const Text('Cancel changes'),
          ),
      ],
    );
  }

  Widget _choice(String label, bool selected, VoidCallback onTap) => Semantics(
    selected: selected,
    child: CupertinoButton(
      padding: const EdgeInsets.symmetric(vertical: 12),
      onPressed: onTap,
      child: Row(
        children: [
          Icon(
            selected
                ? CupertinoIcons.checkmark_circle_fill
                : CupertinoIcons.circle,
            size: 26,
          ),
          const SizedBox(width: 12),
          Expanded(child: Text(label, style: AppTypography.body(context))),
        ],
      ),
    ),
  );
  Widget _switch(String label, bool value, ValueChanged<bool> onChanged) =>
      Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Row(
          children: [
            Expanded(child: Text(label, style: AppTypography.body(context))),
            const SizedBox(width: 12),
            Semantics(
              label: label,
              child: CupertinoSwitch(value: value, onChanged: onChanged),
            ),
          ],
        ),
      );
  Widget _ability(
    String title,
    List<String> labels,
    int value,
    ValueChanged<int> onChanged,
  ) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      AppSectionHeader(title),
      for (var i = 0; i < labels.length; i++)
        _choice(labels[i], value == i, () => onChanged(i)),
      const AppGap(),
    ],
  );
}

const _safetyLabels = [
  'Chest pain, unexplained fainting, or dizziness with activity',
  'Severe or unusual shortness of breath',
  'Recent surgery without exercise clearance',
  'Pregnancy or recent birth without exercise clearance',
  'A doctor has restricted my exercise',
  'An injury or condition I need to avoid aggravating',
];
List<bool> _safetyValues(SafetyProfile p) => [
  p.chestPainOrFainting,
  p.severeShortnessOfBreath,
  p.recentSurgeryNoClearance,
  p.pregnancyPostpartumNoClearance,
  p.doctorRestriction,
  p.injuryToAvoid,
];
String _focusLabel(FocusArea area) => switch (area) {
  FocusArea.fullBody => 'Full body',
  FocusArea.armsShoulders => 'Arms & shoulders',
  FocusArea.chest => 'Chest',
  FocusArea.back => 'Back',
  FocusArea.core => 'Core',
  FocusArea.glutesLegs => 'Glutes & legs',
  FocusArea.cardio => 'Cardio',
  FocusArea.mobility => 'Mobility',
};
String _equipmentLabel(EquipmentItem item) => switch (item) {
  EquipmentItem.floorSpace => 'Clear floor space',
  EquipmentItem.wall => 'A stable wall',
  EquipmentItem.chair => 'A sturdy chair',
  EquipmentItem.couchTable => 'A stable couch or table',
  EquipmentItem.towelDoorway => 'A towel and secure doorway suitable for rows',
};
Widget _numberField(TextEditingController controller, String label) =>
    AppTextField(
      controller: controller,
      placeholder: label,
      semanticLabel: label,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
    );

class JourneyScreen extends StatelessWidget {
  const JourneyScreen({
    super.key,
    required this.progress,
    required this.hasActive,
    required this.busy,
    required this.energy,
    required this.onEnergy,
    required this.onStart,
    required this.onReplay,
    this.gentle = false,
    this.onGentle,
    this.error,
  });
  final JourneyProgress progress;
  final bool hasActive, busy;
  final bool gentle;
  final String energy;
  final String? error;
  final ValueChanged<String> onEnergy;
  final VoidCallback onStart;
  final VoidCallback? onGentle;
  final ValueChanged<int> onReplay;
  @override
  Widget build(BuildContext context) {
    final chapter = progress.chapter;
    final firstChapter = chapter > 1 ? chapter - 1 : 1;
    final lastChapter = math.max(4, chapter + 1);
    final level = purrLevelFor(progress.points);
    return AppPage(
      title: 'Your journey',
      trailing: const _ThemeToggle(),
      children: [
        Text(
          'One workout. One step with Purr.',
          style: AppTypography.body(context),
        ),
        const AppGap(),
        Row(
          children: [
            const _BrandArtwork(height: 60),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Level ${level.index} · ${level.title}',
                    style: AppTypography.headline(context),
                  ),
                  Text(
                    '${progress.points} points · ${progress.completedCheckpoints} checkpoints completed',
                    style: AppTypography.footnote(context),
                  ),
                ],
              ),
            ),
          ],
        ),
        const AppGap(),
        AppPrimaryButton(
          label: hasActive
              ? 'Resume workout'
              : 'Start checkpoint ${progress.nextCheckpoint}',
          loading: busy,
          onPressed: busy ? null : onStart,
        ),
        if (error != null) ...[const AppGap(), Text(error!)],
        const AppGap(),
        if (!hasActive) ...[
          const AppSectionHeader('How is your energy?'),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final value in ['Low', 'Medium', 'High'])
                Semantics(
                  selected: energy == value,
                  child: CupertinoButton(
                    color: energy == value
                        ? AppColors.accentSoft(context)
                        : AppColors.surface(context),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 18,
                      vertical: 12,
                    ),
                    onPressed: () => onEnergy(value),
                    child: Text(value, style: AppTypography.body(context)),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),
          AppSecondaryButton(
            label: gentle
                ? 'Gentler workout selected'
                : 'Choose a gentler workout',
            icon: CupertinoIcons.leaf_arrow_circlepath,
            onPressed: onGentle,
          ),
          const AppGap(),
        ],
        const _BuddyNote(
          'Your place is safe. Rest when you need to; the path will be here.',
        ),
        const AppGap(),
        for (var c = firstChapter; c <= lastChapter; c++) ...[
          AppSectionHeader(chapterTitle(c)),
          if (c == chapter) ...[
            AppProgressBar(
              value: progress.chapterCompleted / checkpointsPerChapter,
              label:
                  '${progress.chapterCompleted} of 6 checkpoints in this chapter',
            ),
            const AppGap(),
          ],
          for (var i = 0; i < checkpointsPerChapter; i++)
            _CheckpointNode(
              checkpoint: (c - 1) * checkpointsPerChapter + i + 1,
              next: progress.nextCheckpoint,
              index: i,
              onTap: (checkpoint) => checkpoint == progress.nextCheckpoint
                  ? onStart()
                  : onReplay(checkpoint),
            ),
          const AppGap(),
        ],
        const Text(
          'The path keeps growing. Difficulty follows you, not the chapter number.',
        ),
        const AppGap(),
        CupertinoButton(
          onPressed: () => showBrandedInfoSheet(
            context,
            title: 'Purr fact',
            message: funFactAt(progress.completedCheckpoints),
          ),
          child: const Text('A little Purr fact'),
        ),
      ],
    );
  }
}

class _CheckpointNode extends StatelessWidget {
  const _CheckpointNode({
    required this.checkpoint,
    required this.next,
    required this.index,
    required this.onTap,
  });
  final int checkpoint, next, index;
  final ValueChanged<int> onTap;
  @override
  Widget build(BuildContext context) {
    final current = checkpoint == next, done = checkpoint < next;
    final alignment = [
      Alignment.centerLeft,
      Alignment.center,
      Alignment.centerRight,
      Alignment.centerRight,
      Alignment.center,
      Alignment.centerLeft,
    ][index];
    final color = done
        ? AppColors.success(context)
        : current
        ? AppColors.accent(context)
        : AppColors.secondaryText(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 9),
      child: Align(
        alignment: alignment,
        child: SizedBox(
          width: 180,
          child: Column(
            children: [
              if (current) ...[
                Semantics(
                  label: 'Purr is at checkpoint $checkpoint',
                  image: true,
                  child: ExcludeSemantics(
                    child: const _BrandArtwork(height: 84),
                  ),
                ),
                const SizedBox(height: 6),
              ],
              Semantics(
                label:
                    'Checkpoint $checkpoint, ${checkpointTitle(checkpoint)}, ${done
                        ? 'completed, replay as practice'
                        : current
                        ? 'ready'
                        : 'complete the earlier checkpoint to unlock'}',
                button: true,
                enabled: current || done,
                child: ExcludeSemantics(
                  child: CupertinoButton(
                    padding: EdgeInsets.zero,
                    onPressed: current || done ? () => onTap(checkpoint) : null,
                    child: AnimatedContainer(
                      duration: AppMotion.duration(
                        context,
                        const Duration(milliseconds: 280),
                      ),
                      width: 76,
                      height: 76,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: current || done
                            ? color
                            : AppColors.elevatedSurface(context),
                        border: Border.all(
                          color: color,
                          width: current ? 4 : 2,
                        ),
                      ),
                      child: Center(
                        child: done
                            ? Icon(
                                CupertinoIcons.checkmark_alt,
                                color: AppColors.inkOn(color),
                                size: 30,
                              )
                            : current
                            ? Icon(
                                CupertinoIcons.play_fill,
                                color: AppColors.inkOn(color),
                                size: 28,
                              )
                            : Icon(CupertinoIcons.lock, color: color, size: 25),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                '$checkpoint · ${checkpointTitle(checkpoint)}',
                textAlign: TextAlign.center,
                style: AppTypography.subheadline(context).copyWith(
                  fontWeight: current ? FontWeight.w800 : FontWeight.w600,
                ),
              ),
              if (index < 5)
                Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: Container(
                    height: 22,
                    width: 3,
                    color: AppColors.separator(context),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class WorkoutScreen extends StatefulWidget {
  const WorkoutScreen({
    super.key,
    required this.session,
    required this.busy,
    required this.onComplete,
    required this.onSkip,
    required this.onSave,
    required this.onPause,
    required this.onStop,
    this.error,
  });
  final FrozenWorkout session;
  final bool busy;
  final String? error;
  final VoidCallback onComplete, onSkip, onPause, onStop;
  final Future<bool> Function() onSave;
  @override
  State<WorkoutScreen> createState() => _WorkoutScreenState();
}

class _WorkoutScreenState extends State<WorkoutScreen>
    with WidgetsBindingObserver {
  Timer? _restTimer;
  bool _saving = false;
  int _remaining = 0;
  FrozenWorkout get session => widget.session;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _checkRest();
    _restTimer = Timer.periodic(
      const Duration(seconds: 1),
      (_) => _checkRest(),
    );
  }

  void _checkRest() {
    if (!mounted) return;
    final until = session.restUntil;
    final remaining = until == null
        ? 0
        : math.max(
            0,
            (until.difference(DateTime.now()).inMilliseconds / 1000).ceil(),
          );
    if (until != null && remaining == 0) {
      session.restUntil = null;
      unawaited(widget.onSave());
    }
    if (_remaining != remaining) setState(() => _remaining = remaining);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _checkRest();
  }

  Future<void> _completeSet(int sets) async {
    if (_saving || widget.busy) return;
    HapticFeedback.selectionClick();
    if (session.setIndex + 1 < sets) {
      final previous = session.setIndex;
      setState(() {
        _saving = true;
        session.setIndex++;
        session.restUntil = DateTime.now().add(const Duration(seconds: 45));
      });
      final saved = await widget.onSave();
      if (!mounted) return;
      if (!saved) {
        session.setIndex = previous;
        session.restUntil = null;
      }
      _checkRest();
      if (mounted) setState(() => _saving = false);
    } else {
      widget.onComplete();
    }
  }

  @override
  void dispose() {
    _restTimer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final exercise = session.workout.exercises[session.current];
    final sets =
        int.tryParse(
          RegExp(r'^(\d+) ×').firstMatch(exercise.target)?.group(1) ?? '',
        ) ??
        1;
    return AppPage(
      title: 'Focus mode',
      children: [
        Text(
          '${session.workout.title} · ${session.energy.toLowerCase()} energy',
          style: AppTypography.subheadline(context),
        ),
        const AppGap(),
        AppProgressBar(
          value: session.current / session.workout.exercises.length,
          label:
              'Exercise ${session.current + 1} of ${session.workout.exercises.length}',
        ),
        const AppGap(),
        Center(child: _ExerciseGlyph(exercise)),
        const AppGap(),
        Text(exercise.name, style: AppTypography.title1(context)),
        const SizedBox(height: 8),
        Text(exercise.detail, style: AppTypography.body(context)),
        const AppGap(),
        AppCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(exercise.target, style: AppTypography.title2(context)),
              const SizedBox(height: 8),
              Text(
                sets > 1
                    ? 'Set ${session.setIndex + 1} of $sets'
                    : 'Move at your own pace',
              ),
              const SizedBox(height: 8),
              const Text(
                'Follow the written target. Mark complete only after doing the movement.',
              ),
            ],
          ),
        ),
        const AppGap(),
        if (widget.error != null) ...[Text(widget.error!), const AppGap()],
        if (session.restUntil != null && _remaining > 0) ...[
          Semantics(
            liveRegion: _remaining <= 3,
            child: Text(
              'Rest · $_remaining seconds',
              style: AppTypography.title2(context),
            ),
          ),
          CupertinoButton(
            onPressed: _saving
                ? null
                : () async {
                    final previous = session.restUntil;
                    setState(() {
                      _saving = true;
                      session.restUntil = null;
                      _remaining = 0;
                    });
                    final saved = await widget.onSave();
                    if (!mounted) return;
                    if (!saved) session.restUntil = previous;
                    _checkRest();
                    setState(() => _saving = false);
                  },
            child: const Text('End rest'),
          ),
        ] else
          AppPrimaryButton(
            label: session.setIndex + 1 < sets
                ? 'Complete set ${session.setIndex + 1} of $sets'
                : session.current == session.workout.exercises.length - 1
                ? 'Finish workout'
                : 'Complete exercise',
            onPressed: widget.busy || _saving ? null : () => _completeSet(sets),
          ),
        const SizedBox(height: 12),
        AppSecondaryButton(
          label: 'Skip this movement',
          icon: CupertinoIcons.forward,
          onPressed: widget.busy || _saving ? null : widget.onSkip,
        ),
        const AppGap(),
        const Text(
          'If a movement feels too hard, skip it and choose “Too hard” in feedback. Never push through pain.',
        ),
        CupertinoButton(
          onPressed: widget.busy || _saving ? null : widget.onStop,
          child: const Text('Stop & record attempt'),
        ),
        CupertinoButton(
          onPressed: widget.busy || _saving ? null : widget.onPause,
          child: const Text('Pause workout'),
        ),
      ],
    );
  }
}

class _ExerciseGlyph extends StatelessWidget {
  const _ExerciseGlyph(this.exercise);
  final PlannedExercise exercise;
  @override
  Widget build(BuildContext context) => ExcludeSemantics(
    child: SizedBox(
      width: 180,
      height: 180,
      child: Icon(exercise.icon, size: 92, color: AppColors.accent(context)),
    ),
  );
}

class _ExerciseRow extends StatelessWidget {
  const _ExerciseRow(this.exercise);
  final PlannedExercise exercise;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 12),
    child: Row(
      children: [
        Icon(exercise.icon, color: AppColors.accent(context)),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(exercise.name, style: AppTypography.headline(context)),
              Text(exercise.target, style: AppTypography.subheadline(context)),
            ],
          ),
        ),
      ],
    ),
  );
}

class WorkoutCompleteScreen extends StatelessWidget {
  const WorkoutCompleteScreen({
    super.key,
    required this.qualified,
    required this.busy,
    required this.onFeedback,
    this.error,
  });
  final bool qualified, busy;
  final String? error;
  final ValueChanged<String> onFeedback;
  @override
  Widget build(BuildContext context) => AppPage(
    title: 'How did that feel?',
    children: [
      const Center(child: _BrandArtwork(height: 180)),
      const AppGap(),
      Text(
        qualified
            ? 'Your movements are complete.'
            : 'Every bit of effort counts.',
        style: AppTypography.title2(context),
      ),
      const AppGap(),
      const Text(
        'Feedback shapes future workouts. Save this attempt to return to your journey.',
      ),
      const AppGap(),
      if (error != null) Text(error!),
      for (final choice in [
        ('too_hard', 'Too hard'),
        ('good_fit', 'Good fit'),
        ('too_easy', 'Too easy'),
        ('pain', 'Pain or unsafe symptoms'),
      ]) ...[
        AppSecondaryButton(
          label: choice.$2,
          icon: CupertinoIcons.check_mark_circled,
          onPressed: busy ? null : () => onFeedback(choice.$1),
        ),
        const SizedBox(height: 12),
      ],
      CupertinoButton(
        onPressed: busy ? null : () => onFeedback('not_rated'),
        child: const Text('Save without rating'),
      ),
    ],
  );
}

enum ReportView { overview, history, body }

class ReportScreen extends StatefulWidget {
  const ReportScreen({
    super.key,
    required this.progress,
    required this.history,
    required this.measurements,
    required this.adultConfirmed,
    required this.onAdult,
    required this.onAddMeasurement,
    required this.onDeleteMeasurement,
    required this.onDeleteHistory,
    required this.isAdFree,
    required this.onRemoveAds,
    this.error,
    this.onReward,
    this.initialView = ReportView.overview,
  });
  final JourneyProgress progress;
  final List<WorkoutHistoryEntry> history;
  final List<BodyMeasurement> measurements;
  final bool adultConfirmed, isAdFree;
  final String? error;
  final ValueChanged<bool> onAdult;
  final Future<bool> Function(double, double?) onAddMeasurement;
  final ValueChanged<String> onDeleteMeasurement, onDeleteHistory;
  final VoidCallback onRemoveAds;
  final Future<RewardedResult> Function()? onReward;
  final ReportView initialView;
  @override
  State<ReportScreen> createState() => _ReportScreenState();
}

class _ReportScreenState extends State<ReportScreen> {
  late ReportView _view = widget.initialView;
  ReportPeriod _period = ReportPeriod.thisWeek;
  final Set<ReportView> _unlocked = {};
  bool _unlocking = false;
  List<WorkoutHistoryEntry> get _history =>
      widget.history
          .where((e) => e.journeyId == widget.progress.journeyId)
          .toList()
        ..sort((a, b) => b.completedAt.compareTo(a.completedAt));
  List<BodyMeasurement> get _measurements =>
      widget.measurements
          .where((e) => e.journeyId == widget.progress.journeyId)
          .toList()
        ..sort((a, b) => b.measuredAt.compareTo(a.measuredAt));
  bool get _canView =>
      _view == ReportView.history ||
      widget.isAdFree ||
      _unlocked.contains(_view);
  @override
  Widget build(BuildContext context) => AppPage(
    title: 'Report',
    children: [
      CupertinoSlidingSegmentedControl<ReportView>(
        groupValue: _view,
        onValueChanged: (view) {
          if (view != null) setState(() => _view = view);
        },
        children: const {
          ReportView.overview: Padding(
            padding: EdgeInsets.symmetric(vertical: 8),
            child: Text('Overview'),
          ),
          ReportView.history: Padding(
            padding: EdgeInsets.symmetric(vertical: 8),
            child: Text('History'),
          ),
          ReportView.body: Padding(
            padding: EdgeInsets.symmetric(vertical: 8),
            child: Text('Body'),
          ),
        },
      ),
      const AppGap(),
      if (widget.error != null) ...[Text(widget.error!), const AppGap()],
      if (!_canView)
        ..._gate()
      else
        ...switch (_view) {
          ReportView.overview => _overview(),
          ReportView.history => _historyView(),
          ReportView.body => _body(),
        },
    ],
  );
  List<Widget> _gate() => [
    const _BuddyNote(
      'History is always free. Watch a short ad to open this report once, or remove ads for good.',
    ),
    const AppGap(),
    AppPrimaryButton(label: 'See no-ads option', onPressed: widget.onRemoveAds),
    if (widget.onReward != null) ...[
      const SizedBox(height: 12),
      AppSecondaryButton(
        label: 'Watch ad to view this report',
        icon: CupertinoIcons.play_circle,
        onPressed: _unlocking
            ? null
            : () async {
                final view = _view;
                setState(() => _unlocking = true);
                final result = await widget.onReward!();
                if (!mounted) return;
                setState(() {
                  _unlocking = false;
                  if (result == RewardedResult.earned) _unlocked.add(view);
                });
                if (result != RewardedResult.earned) {
                  await showBrandedInfoSheet(
                    context,
                    title: 'Report not unlocked',
                    message: result == RewardedResult.dismissedWithoutReward
                        ? 'The ad was closed before the reward. You can try again.'
                        : 'No ad is ready. Please try again later.',
                  );
                }
              },
      ),
    ],
  ];
  List<Widget> _overview() {
    final range = reportPeriodRange(_period, DateTime.now());
    final entries = _history
        .where((e) => range.contains(e.completedAt))
        .toList();
    final seconds = entries.fold<int>(0, (n, e) => n + (e.activeSeconds ?? 0));
    final days = entries.map((e) => e.localDateKey).toSet().length;
    final bars = [
      for (var i = 6; i >= 0; i--)
        () {
          final date = DateTime.now().subtract(Duration(days: i));
          final total = _history
              .where((e) => e.localDateKey == dateKey(date))
              .fold<int>(0, (n, e) => n + (e.activeSeconds ?? 0));
          return (
            label: const [
              'Mon',
              'Tue',
              'Wed',
              'Thu',
              'Fri',
              'Sat',
              'Sun',
            ][date.weekday - 1],
            value: (total / 60).round(),
          );
        }(),
    ];
    return [
      Text(
        '${widget.progress.completedCheckpoints} checkpoints completed',
        style: AppTypography.title2(context),
      ),
      const SizedBox(height: 8),
      Text(
        'Chapter ${widget.progress.chapter} · ${widget.progress.chapterCompleted} of 6 complete',
      ),
      const AppGap(),
      AppProgressBar(
        value: widget.progress.chapterCompleted / 6,
        label: 'Current chapter progress',
      ),
      const SizedBox(height: 8),
      const Text('Training progress, not a measure of weight or health.'),
      const AppGap(),
      Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          for (final period in ReportPeriod.values)
            CupertinoButton(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              color: period == _period
                  ? AppColors.accentSoft(context)
                  : AppColors.surface(context),
              onPressed: () => setState(() => _period = period),
              child: Text(
                reportPeriodLabel(period),
                style: AppTypography.footnote(context),
              ),
            ),
        ],
      ),
      const AppGap(),
      AppSectionHeader('${reportPeriodLabel(_period)} activity'),
      _reportMetric('${entries.length}', 'Workout attempts'),
      _reportMetric(
        '${entries.where((e) => e.source == WorkoutSource.checkpoint).length}',
        'Checkpoint workouts',
      ),
      _reportMetric('${(seconds / 60).round()}', 'Logged active minutes'),
      _reportMetric('$days', 'Active days'),
      const AppGap(),
      const AppSectionHeader('Last 7 days'),
      _AccessibleBarChart(bars: bars),
      const AppGap(),
      const _BuddyNote(
        'Your report reflects actual activity dates. Taking a break never removes progress.',
      ),
    ];
  }

  Widget _reportMetric(String value, String label) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 10),
    child: Row(
      children: [
        Expanded(child: Text(label, style: AppTypography.body(context))),
        Text(value, style: AppTypography.title2(context)),
      ],
    ),
  );

  List<Widget> _historyView() {
    final entries = _history;
    if (entries.isEmpty) {
      return [
        const _BuddyNote(
          'Your new journey history starts here. Complete a workout or record an attempt to see it here.',
        ),
      ];
    }
    return [
      const Text(
        'Actual activity dates. Deleting a record never rewinds your journey.',
      ),
      const AppGap(),
      for (final entry in entries)
        Padding(
          padding: const EdgeInsets.only(bottom: 16),
          child: AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(entry.title, style: AppTypography.title3(context)),
                const SizedBox(height: 8),
                Text(_dateLabel(entry.completedAt)),
                Text(
                  entry.source == WorkoutSource.checkpoint
                      ? 'Checkpoint ${entry.checkpoint} · +${entry.points} points'
                      : 'Practice / partial attempt · no path advancement',
                ),
                const SizedBox(height: 8),
                Text(
                  '${entry.completedExerciseCount} of ${entry.totalExerciseCount} movements · ${entry.activeSeconds == null ? 'Duration unavailable' : '${entry.activeSeconds! ~/ 60}m ${entry.activeSeconds! % 60}s active'}',
                ),
                if (entry.difficultyFeedback != null)
                  Text(
                    'Feedback: ${switch (entry.difficultyFeedback) {
                      'too_hard' => 'Too hard',
                      'too_easy' => 'Too easy',
                      'good_fit' => 'Good fit',
                      'pain' => 'Stopped for safety',
                      _ => 'Not rated',
                    }}',
                  ),
                CupertinoButton(
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  onPressed: () async {
                    if (await _confirm(
                      context,
                      'Delete history entry?',
                      'Your earned checkpoints and points stay saved.',
                      action: 'Delete',
                      destructive: true,
                    )) {
                      widget.onDeleteHistory(entry.id);
                    }
                  },
                  child: const Text('Delete entry'),
                ),
              ],
            ),
          ),
        ),
    ];
  }

  List<Widget> _body() {
    final measurements = _measurements;
    final latest = measurements.isEmpty ? null : measurements.first;
    final height = measurements
        .where((e) => e.heightCm != null)
        .firstOrNull
        ?.heightCm;
    final bmi = latest == null || height == null
        ? null
        : computeBmi(weightKg: latest.weightKg, heightCm: height);
    return [
      const Text(
        'Body information is optional. These measurements are separate from checkpoint progress.',
      ),
      const AppGap(),
      AppPrimaryButton(label: 'Add measurement', onPressed: _addMeasurement),
      const AppGap(),
      if (latest == null)
        const _BuddyNote(
          'No measurements yet. You can enjoy the whole journey without adding one.',
        )
      else ...[
        Text(
          '${latest.weightKg.toStringAsFixed(1)} kg',
          style: AppTypography.title1(context),
        ),
        Text('Latest entry · ${_dateLabel(latest.measuredAt)}'),
        if (measurements.length > 1) ...[
          const AppGap(),
          Text(
            '${(latest.weightKg - measurements.last.weightKg).toStringAsFixed(1)} kg change since first journey entry',
          ),
        ],
      ],
      const AppGap(),
      Row(
        children: [
          const Expanded(child: Text('I am age 20 or older')),
          Semantics(
            label: 'I am age 20 or older',
            child: CupertinoSwitch(
              value: widget.adultConfirmed,
              onChanged: widget.onAdult,
            ),
          ),
        ],
      ),
      const AppGap(),
      if (!widget.adultConfirmed)
        const Text('Adult BMI screening is shown only after age confirmation.')
      else if (bmi == null)
        const Text('Add weight and height to see optional adult BMI screening.')
      else ...[
        Text(
          'BMI ${bmi.toStringAsFixed(1)} · ${_bmiLabel(bmiCategory(bmi))}',
          style: AppTypography.title3(context),
        ),
        const SizedBox(height: 8),
        const Text(
          'A broad screening measure, not a diagnosis or a goal. BMI does not account for muscle, pregnancy, or individual health. Discuss concerns with a qualified clinician.',
        ),
      ],
      const AppGap(),
      for (final measurement in measurements)
        _SettingsTile(
          '${measurement.weightKg.toStringAsFixed(1)} kg${measurement.heightCm == null ? '' : ' · ${measurement.heightCm!.toStringAsFixed(0)} cm'}',
          _dateLabel(measurement.measuredAt),
          icon: CupertinoIcons.delete,
          onTap: () async {
            if (await _confirm(
              context,
              'Delete measurement?',
              'This removes the selected measurement.',
              action: 'Delete',
              destructive: true,
            )) {
              widget.onDeleteMeasurement(measurement.id);
            }
          },
        ),
    ];
  }

  Future<void> _addMeasurement() async {
    final weight = TextEditingController(), height = TextEditingController();
    String? error;
    var busy = false;
    await showCupertinoDialog<void>(
      context: context,
      builder: (dialog) => StatefulBuilder(
        builder: (context, update) => CupertinoAlertDialog(
          title: const Text('Add measurement'),
          content: Column(
            children: [
              const SizedBox(height: 16),
              _numberField(weight, 'Weight in kg'),
              const SizedBox(height: 12),
              _numberField(height, 'Height in cm (optional)'),
              if (error != null) Text(error!),
            ],
          ),
          actions: [
            CupertinoDialogAction(
              onPressed: busy ? null : () => Navigator.pop(dialog),
              child: const Text('Cancel'),
            ),
            CupertinoDialogAction(
              onPressed: busy
                  ? null
                  : () async {
                      final w = double.tryParse(weight.text),
                          h = double.tryParse(height.text);
                      if (w == null ||
                          !w.isFinite ||
                          w < 20 ||
                          w > 400 ||
                          (height.text.isNotEmpty &&
                              (h == null ||
                                  !h.isFinite ||
                                  h < 80 ||
                                  h > 250))) {
                        update(
                          () => error =
                              'Enter weight 20–400 kg and optional height 80–250 cm.',
                        );
                        return;
                      }
                      update(() => busy = true);
                      final saved = await widget.onAddMeasurement(w, h);
                      if (!dialog.mounted) return;
                      if (saved) {
                        Navigator.pop(dialog);
                      } else {
                        update(() {
                          busy = false;
                          error =
                              'Your measurement could not be saved. Please retry.';
                        });
                      }
                    },
              child: busy
                  ? const CupertinoActivityIndicator()
                  : const Text('Save'),
            ),
          ],
        ),
      ),
    );
    // Dialog routes still animate after the result completes.
    await Future<void>.delayed(const Duration(milliseconds: 350));
    weight.dispose();
    height.dispose();
  }
}

String _dateLabel(DateTime date) =>
    '${date.toLocal().day}/${date.toLocal().month}/${date.toLocal().year}';
String _bmiLabel(BmiCategory? category) => switch (category) {
  BmiCategory.underweight => 'Underweight range',
  BmiCategory.healthy => 'Healthy range',
  BmiCategory.overweight => 'Overweight range',
  BmiCategory.obese => 'Obesity range',
  null => 'Unavailable',
};

class _AccessibleBarChart extends StatelessWidget {
  const _AccessibleBarChart({required this.bars});
  final List<({String label, int value})> bars;
  @override
  Widget build(BuildContext context) {
    final max = bars.fold<int>(1, (value, bar) => math.max(value, bar.value));
    return Semantics(
      label:
          'Logged active minutes: ${bars.map((bar) => '${bar.label} ${bar.value}').join(', ')}',
      child: ExcludeSemantics(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            for (final bar in bars)
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 3),
                  child: Column(
                    children: [
                      Text(
                        '${bar.value}',
                        style: AppTypography.footnote(context),
                      ),
                      const SizedBox(height: 6),
                      Container(
                        height: math.max(4.0, 88 * bar.value / max),
                        width: 20,
                        decoration: BoxDecoration(
                          color: AppColors.accent(context),
                          borderRadius: BorderRadius.circular(5),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(bar.label, style: AppTypography.footnote(context)),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class EditProfileScreen extends StatefulWidget {
  const EditProfileScreen({
    super.key,
    required this.initialName,
    required this.initialAvatar,
    required this.onSave,
  });
  final String initialName;
  final int initialAvatar;
  final Future<void> Function(String, int) onSave;
  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  late final _name = TextEditingController(text: widget.initialName);
  late int _avatar = widget.initialAvatar;
  bool _busy = false;
  String? _error;
  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AppPage(
    title: 'Edit profile',
    children: [
      AppTextField(
        controller: _name,
        placeholder: 'Your name',
        semanticLabel: 'Profile name',
        maxLength: 40,
      ),
      const AppGap(),
      Wrap(
        spacing: 10,
        runSpacing: 10,
        children: [
          for (var i = 0; i < 3; i++)
            Semantics(
              label: 'Choose avatar ${i + 1}',
              selected: _avatar == i,
              button: true,
              child: CupertinoButton(
                padding: const EdgeInsets.all(5),
                onPressed: () => setState(() => _avatar = i),
                child: Container(
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: _avatar == i
                          ? AppColors.accent(context)
                          : CupertinoColors.transparent,
                      width: 3,
                    ),
                  ),
                  child: Icon(
                    [
                      CupertinoIcons.person_fill,
                      CupertinoIcons.person_crop_circle,
                      CupertinoIcons.person_2_fill,
                    ][i],
                    size: 44,
                    color: AppColors.accent(context),
                  ),
                ),
              ),
            ),
        ],
      ),
      const AppGap(),
      if (_error != null) Text(_error!),
      AppPrimaryButton(
        label: 'Save profile',
        loading: _busy,
        onPressed: _busy
            ? null
            : () async {
                setState(() => _busy = true);
                try {
                  await widget.onSave(_name.text.trim(), _avatar);
                  if (!mounted) return;
                  Navigator.maybePop(this.context);
                } catch (_) {
                  if (mounted) {
                    setState(
                      () => _error =
                          'Your profile could not be saved. Please retry.',
                    );
                  }
                } finally {
                  if (mounted) setState(() => _busy = false);
                }
              },
      ),
      CupertinoButton(
        onPressed: _busy ? null : () => Navigator.maybePop(context),
        child: const Text('Cancel'),
      ),
    ],
  );
}

class RemoveAdsScreen extends StatefulWidget {
  const RemoveAdsScreen({super.key, required this.purchases});
  final AdRemovalService? purchases;
  @override
  State<RemoveAdsScreen> createState() => _RemoveAdsScreenState();
}

class _RemoveAdsScreenState extends State<RemoveAdsScreen> {
  AdRemovalService? get service => widget.purchases;
  bool get _adFree => service?.hasAdFreeAccess ?? false;
  bool get _hasOffer => service?.storeReady ?? false;
  String get _price => service?.priceString ?? 'See store price';

  @override
  void initState() {
    super.initState();
    final service = widget.purchases;
    if (service != null) {
      service.addListener(_onServiceChanged);
      unawaited(service.refresh());
    }
  }

  void _onServiceChanged() {
    if (!mounted) return;
    setState(() {});
  }

  @override
  void dispose() {
    service?.removeListener(_onServiceChanged);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AppPage(
    title: 'No ads',
    children: [
      const Center(child: _BrandArtwork(height: 150)),
      const AppGap(),
      Text(
        _adFree ? 'Ads are off. Thank you.' : 'A quiet app, once.',
        style: AppTypography.title1(context),
      ),
      const AppGap(),
      Text(
        _adFree
            ? 'Every optional workout and report stays open without watching an ad.'
            : 'Purrfit is free to use. Optional workouts and extra reports open after a short ad. Pay once to skip every ad from now on.',
      ),
      const AppGap(),
      const AppSectionHeader('What changes'),
      for (final line in [
        'No rewarded ads before optional workouts',
        'No ads before Overview or Body reports',
        'One payment, kept on your ${AdRemovalService.storeName} account',
      ])
        Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                CupertinoIcons.checkmark_circle_fill,
                size: 20,
                color: AppColors.success(context),
              ),
              const SizedBox(width: 10),
              Expanded(child: Text(line)),
            ],
          ),
        ),
      const AppGap(),
      if (service == null)
        const _BuddyNote(
          'The store is not available in this build, so ad removal cannot be purchased here.',
        )
      else if (_adFree)
        _BuddyNote(
          'Your purchase is linked to the ${AdRemovalService.storeName} account that bought it. If you reinstall Purrfit, tap Restore purchases.',
        )
      else if (!service!.available)
        const _BuddyNote(
          'The store is not available in this build, so ad removal cannot be purchased here.',
        )
      else if (service!.querying && !_hasOffer)
        const Center(child: CupertinoActivityIndicator())
      else ...[
        if (_hasOffer)
          AppPrimaryButton(
            label: 'Remove ads · $_price',
            loading: service!.loading,
            onPressed: service!.loading || service!.pendingPurchase
                ? null
                : service!.purchase,
          )
        else
          _BuddyNote(
            'Ad removal is not available from ${AdRemovalService.storeName} yet. Please try again later.',
          ),
        const SizedBox(height: 12),
        Text(
          'One-time purchase. Not a subscription, so there is nothing to cancel. ${AdRemovalService.storeName} shows the final price before you confirm.',
        ),
      ],
      if (service?.error != null) ...[const AppGap(), Text(service!.error!)],
      const AppGap(),
      if (service != null && !service!.loading)
        AppSecondaryButton(
          label: 'Restore purchases',
          icon: CupertinoIcons.arrow_clockwise,
          onPressed: () => service!.restore(),
        ),
      CupertinoButton(
        onPressed: () => Navigator.maybePop(context),
        child: const Text('Back'),
      ),
    ],
  );
}
