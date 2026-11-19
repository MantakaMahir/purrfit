import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

import 'ad_config.dart';
import 'ad_eligibility_service.dart';
import 'consent_service.dart';

class AdsService {
  AdsService({required this.consent, required this.eligibility});

  final ConsentService consent;
  final AdEligibilityService eligibility;
  InterstitialAd? _interstitial;
  RewardedAd? _rewarded;
  var _loadingInterstitial = false;
  var _loadingRewarded = false;
  bool _adsInitialized = false;
  bool _adFree = false;

  /// Suppresses every ad format after the one-time ad-removal purchase.
  void setAdFree(bool value) {
    if (_adFree == value) return;
    _adFree = value;
    if (value) {
      _interstitial?.dispose();
      _rewarded?.dispose();
      _interstitial = null;
      _rewarded = null;
      _loadingInterstitial = false;
      _loadingRewarded = false;
      return;
    }
    loadInterstitial();
    loadRewarded();
  }

  Future<void> initialize() async {
    if (kIsWeb ||
        (defaultTargetPlatform != TargetPlatform.android &&
            defaultTargetPlatform != TargetPlatform.iOS)) {
      return;
    }
    AdConfig.verifyReleaseIds();
    await consent.initialize();
    consent.addListener(_onConsentChanged);
    if (consent.canRequestAds) {
      await _initializeMobileAds();
      loadInterstitial();
      loadRewarded();
    }
  }

  Future<void> _initializeMobileAds() async {
    if (_adsInitialized) return;
    _adsInitialized = true;
    await MobileAds.instance.initialize();
  }

  void _onConsentChanged() {
    if (consent.canRequestAds && !_adFree) {
      _initializeMobileAds().then((_) {
        loadInterstitial();
        loadRewarded();
      });
      return;
    }
    _interstitial?.dispose();
    _rewarded?.dispose();
    _interstitial = null;
    _rewarded = null;
  }

  void loadInterstitial() {
    if (_adFree ||
        !consent.canRequestAds ||
        _interstitial != null ||
        _loadingInterstitial) {
      return;
    }
    _loadingInterstitial = true;
    InterstitialAd.load(
      adUnitId: AdConfig.interstitialUnitId,
      request: const AdRequest(),
      adLoadCallback: InterstitialAdLoadCallback(
        onAdLoaded: (ad) {
          _debug('interstitial loaded');
          _loadingInterstitial = false;
          _interstitial = ad;
        },
        onAdFailedToLoad: (error) {
          _debug('interstitial failed: $error');
          _loadingInterstitial = false;
        },
      ),
    );
  }

  Future<void> showInterstitialIfEligible({
    required int completedWorkouts,
    required VoidCallback onContinue,
  }) async {
    if (_adFree ||
        !consent.canRequestAds ||
        !eligibility.canShowInterstitial(completedWorkouts) ||
        _interstitial == null) {
      onContinue();
      loadInterstitial();
      return;
    }
    final ad = _interstitial!;
    _interstitial = null;
    ad.fullScreenContentCallback = FullScreenContentCallback(
      onAdShowedFullScreenContent: (_) {
        _debug('interstitial shown');
        eligibility.recordInterstitialShown();
      },
      onAdDismissedFullScreenContent: (ad) {
        _debug('interstitial dismissed');
        ad.dispose();
        loadInterstitial();
        onContinue();
      },
      onAdFailedToShowFullScreenContent: (ad, error) {
        _debug('interstitial show failed: $error');
        ad.dispose();
        loadInterstitial();
        onContinue();
      },
    );
    ad.show();
  }

  void loadRewarded() {
    if (_adFree ||
        !consent.canRequestAds ||
        _rewarded != null ||
        _loadingRewarded) {
      return;
    }
    _loadingRewarded = true;
    RewardedAd.load(
      adUnitId: AdConfig.rewardedUnitId,
      request: const AdRequest(),
      rewardedAdLoadCallback: RewardedAdLoadCallback(
        onAdLoaded: (ad) {
          _debug('rewarded loaded');
          _loadingRewarded = false;
          _rewarded = ad;
        },
        onAdFailedToLoad: (error) {
          _debug('rewarded failed: $error');
          _loadingRewarded = false;
        },
      ),
    );
  }

  Future<RewardedResult> showRewarded() async {
    if (_adFree) return RewardedResult.earned;
    if (!consent.canRequestAds || _rewarded == null) {
      loadRewarded();
      return RewardedResult.notReady;
    }
    final result = Completer<RewardedResult>();
    var rewarded = false;
    final ad = _rewarded!;
    _rewarded = null;
    ad.fullScreenContentCallback = FullScreenContentCallback(
      onAdDismissedFullScreenContent: (ad) {
        _debug('rewarded dismissed');
        ad.dispose();
        loadRewarded();
        if (!result.isCompleted) {
          result.complete(
            rewarded
                ? RewardedResult.earned
                : RewardedResult.dismissedWithoutReward,
          );
        }
      },
      onAdFailedToShowFullScreenContent: (ad, error) {
        _debug('rewarded show failed: $error');
        ad.dispose();
        loadRewarded();
        if (!result.isCompleted) result.complete(RewardedResult.failedToShow);
      },
    );
    ad.show(
      onUserEarnedReward: (_, reward) {
        _debug('reward granted: ${reward.amount} ${reward.type}');
        rewarded = true;
      },
    );
    return result.future;
  }

  void dispose() {
    consent.removeListener(_onConsentChanged);
    _interstitial?.dispose();
    _rewarded?.dispose();
  }

  void _debug(String message) {
    if (kDebugMode) debugPrint('[ads] $message');
  }
}

enum RewardedResult { earned, dismissedWithoutReward, failedToShow, notReady }
