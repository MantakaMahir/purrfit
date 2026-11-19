import 'package:flutter/foundation.dart';

class AdConfig {
  const AdConfig._();

  static const interstitialEveryWorkouts = 3;
  static const interstitialCooldown = Duration(minutes: 10);
  static const interstitialDailyCap = 2;
  static const minCompletedWorkoutsBeforeInterstitial = 2;

  static const _androidTestBanner = 'ca-app-pub-3940256099942544/9214589741';
  static const _androidTestInterstitial =
      'ca-app-pub-3940256099942544/1033173712';
  static const _androidTestRewarded = 'ca-app-pub-3940256099942544/5224354917';
  static const _iosTestBanner = 'ca-app-pub-3940256099942544/2435281174';
  static const _iosTestInterstitial = 'ca-app-pub-3940256099942544/4411468910';
  static const _iosTestRewarded = 'ca-app-pub-3940256099942544/1712485313';

  static const _releaseBanner = String.fromEnvironment('ADMOB_BANNER_ID');
  static const _releaseInterstitial = String.fromEnvironment(
    'ADMOB_INTERSTITIAL_ID',
  );
  static const _releaseRewarded = String.fromEnvironment('ADMOB_REWARDED_ID');

  static bool get _isIOS =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.iOS;

  static String get bannerUnitId => kReleaseMode
      ? _releaseBanner
      : _isIOS
      ? _iosTestBanner
      : _androidTestBanner;

  static String get interstitialUnitId => kReleaseMode
      ? _releaseInterstitial
      : _isIOS
      ? _iosTestInterstitial
      : _androidTestInterstitial;

  static String get rewardedUnitId => kReleaseMode
      ? _releaseRewarded
      : _isIOS
      ? _iosTestRewarded
      : _androidTestRewarded;

  static void verifyReleaseIds() {
    if (!kReleaseMode) return;
    final missing = <String>[
      if (_releaseBanner.isEmpty) 'ADMOB_BANNER_ID',
      if (_releaseInterstitial.isEmpty) 'ADMOB_INTERSTITIAL_ID',
      if (_releaseRewarded.isEmpty) 'ADMOB_REWARDED_ID',
    ];
    if (missing.isNotEmpty) {
      throw StateError('Missing release AdMob unit IDs: ${missing.join(', ')}');
    }
  }
}
