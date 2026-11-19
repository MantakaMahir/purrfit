import 'package:shared_preferences/shared_preferences.dart';

import 'ad_config.dart';

class AdEligibilityService {
  AdEligibilityService(this._prefs);

  final SharedPreferences _prefs;

  static const _completedSinceInterstitial = 'ads.completedSinceInterstitial';
  static const _lastInterstitialAt = 'ads.lastInterstitialAt';
  static const _interstitialDay = 'ads.interstitialDay';
  static const _interstitialsToday = 'ads.interstitialsToday';

  bool canShowInterstitial(int completedWorkouts) {
    if (completedWorkouts < AdConfig.minCompletedWorkoutsBeforeInterstitial) {
      return false;
    }
    if ((_prefs.getInt(_completedSinceInterstitial) ?? 0) <
        AdConfig.interstitialEveryWorkouts) {
      return false;
    }
    final last = _prefs.getString(_lastInterstitialAt);
    if (last != null) {
      final lastAt = DateTime.tryParse(last);
      if (lastAt != null &&
          DateTime.now().difference(lastAt) < AdConfig.interstitialCooldown) {
        return false;
      }
    }
    _resetDailyIfNeeded();
    return (_prefs.getInt(_interstitialsToday) ?? 0) <
        AdConfig.interstitialDailyCap;
  }

  Future<void> recordWorkoutCompleted() async {
    await _prefs.setInt(
      _completedSinceInterstitial,
      (_prefs.getInt(_completedSinceInterstitial) ?? 0) + 1,
    );
  }

  Future<void> recordInterstitialShown() async {
    _resetDailyIfNeeded();
    await _prefs.setInt(_completedSinceInterstitial, 0);
    await _prefs.setString(
      _lastInterstitialAt,
      DateTime.now().toIso8601String(),
    );
    await _prefs.setInt(
      _interstitialsToday,
      (_prefs.getInt(_interstitialsToday) ?? 0) + 1,
    );
  }

  void _resetDailyIfNeeded() {
    final today = DateTime.now().toIso8601String().split('T').first;
    if (_prefs.getString(_interstitialDay) == today) return;
    _prefs.setString(_interstitialDay, today);
    _prefs.setInt(_interstitialsToday, 0);
  }
}
