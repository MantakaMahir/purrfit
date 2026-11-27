import 'package:flutter/foundation.dart';

class AdConfig {
  const AdConfig._();

  static const _enabled = bool.fromEnvironment('PURRFIT_ENABLE_MONETIZATION');
  static const _releaseRewarded = String.fromEnvironment('ADMOB_REWARDED_ID');

  static bool get enabled =>
      _enabled &&
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.android ||
          defaultTargetPlatform == TargetPlatform.iOS) &&
      (!kReleaseMode ||
          (RegExp(r'^ca-app-pub-\d{16}/\d{10}$').hasMatch(_releaseRewarded) &&
              !_releaseRewarded.startsWith('ca-app-pub-3940256099942544/')));

  static String get rewardedUnitId => kReleaseMode
      ? _releaseRewarded
      : defaultTargetPlatform == TargetPlatform.iOS
      ? 'ca-app-pub-3940256099942544/1712485313'
      : 'ca-app-pub-3940256099942544/5224354917';
}
