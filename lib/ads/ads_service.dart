import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

import 'ad_config.dart';
import 'consent_service.dart';

class AdsService {
  AdsService({required this.consent, required this._adFree});

  final ConsentService consent;
  RewardedAd? _rewarded;
  bool _loading = false;
  bool _initialized = false;
  bool _disposed = false;
  bool _adFree;

  bool get _canLoad => !_disposed && !_adFree && consent.canRequestAds;

  void initialize() {
    consent.addListener(_onConsentChanged);
    _onConsentChanged();
  }

  void setAdFree(bool value) {
    if (_adFree == value) return;
    _adFree = value;
    _onConsentChanged();
  }

  void _onConsentChanged() {
    if (_canLoad) {
      unawaited(_loadRewarded());
    } else {
      unawaited(_rewarded?.dispose());
      _rewarded = null;
    }
  }

  Future<void> _loadRewarded() async {
    if (!_canLoad || _rewarded != null || _loading) return;
    _loading = true;
    try {
      if (!_initialized) {
        await MobileAds.instance.initialize();
        _initialized = true;
      }
      if (!_canLoad) {
        _loading = false;
        return;
      }
      await RewardedAd.load(
        adUnitId: AdConfig.rewardedUnitId,
        request: const AdRequest(),
        rewardedAdLoadCallback: RewardedAdLoadCallback(
          onAdLoaded: (ad) {
            _loading = false;
            if (_canLoad) {
              _rewarded = ad;
            } else {
              unawaited(ad.dispose());
            }
          },
          onAdFailedToLoad: (error) {
            _loading = false;
            if (kDebugMode) debugPrint('[ads] Rewarded ad failed: $error');
          },
        ),
      );
    } catch (error) {
      _loading = false;
      if (kDebugMode) debugPrint('[ads] Could not load rewarded ad: $error');
    }
  }

  Future<RewardedResult> showRewarded() async {
    if (_adFree) return RewardedResult.earned;
    final ad = _rewarded;
    if (!_canLoad || ad == null) {
      unawaited(_loadRewarded());
      return RewardedResult.notReady;
    }
    _rewarded = null;
    final result = Completer<RewardedResult>();
    var rewarded = false;
    void finish(RewardedResult outcome) {
      if (result.isCompleted) return;
      result.complete(outcome);
      unawaited(ad.dispose());
      unawaited(_loadRewarded());
    }

    ad.fullScreenContentCallback = FullScreenContentCallback(
      onAdDismissedFullScreenContent: (_) => finish(
        rewarded
            ? RewardedResult.earned
            : RewardedResult.dismissedWithoutReward,
      ),
      onAdFailedToShowFullScreenContent: (_, _) =>
          finish(RewardedResult.failedToShow),
    );
    try {
      await ad.show(onUserEarnedReward: (_, _) => rewarded = true);
    } catch (_) {
      finish(RewardedResult.failedToShow);
    }
    return result.future;
  }

  void dispose() {
    _disposed = true;
    consent.removeListener(_onConsentChanged);
    unawaited(_rewarded?.dispose());
    _rewarded = null;
  }
}

enum RewardedResult { earned, dismissedWithoutReward, failedToShow, notReady }
