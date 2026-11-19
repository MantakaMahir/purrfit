import 'package:flutter_test/flutter_test.dart';
import 'package:purrfit/ads/ad_config.dart';
import 'package:purrfit/ads/ad_eligibility_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  test(
    'interstitial eligibility respects workout cadence and daily cap',
    () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final eligibility = AdEligibilityService(prefs);

      expect(eligibility.canShowInterstitial(1), isFalse);

      for (var i = 0; i < AdConfig.interstitialEveryWorkouts; i++) {
        await eligibility.recordWorkoutCompleted();
      }
      expect(
        eligibility.canShowInterstitial(
          AdConfig.minCompletedWorkoutsBeforeInterstitial,
        ),
        isTrue,
      );

      await eligibility.recordInterstitialShown();
      expect(
        eligibility.canShowInterstitial(
          AdConfig.minCompletedWorkoutsBeforeInterstitial + 1,
        ),
        isFalse,
      );

      for (var i = 0; i < AdConfig.interstitialEveryWorkouts; i++) {
        await eligibility.recordWorkoutCompleted();
      }
      await prefs.setString(
        'ads.lastInterstitialAt',
        DateTime.now()
            .subtract(AdConfig.interstitialCooldown)
            .subtract(const Duration(seconds: 1))
            .toIso8601String(),
      );
      expect(
        eligibility.canShowInterstitial(
          AdConfig.minCompletedWorkoutsBeforeInterstitial + 3,
        ),
        isTrue,
      );

      await eligibility.recordInterstitialShown();
      for (var i = 0; i < AdConfig.interstitialEveryWorkouts; i++) {
        await eligibility.recordWorkoutCompleted();
      }
      await prefs.setString(
        'ads.lastInterstitialAt',
        DateTime.now()
            .subtract(AdConfig.interstitialCooldown)
            .subtract(const Duration(seconds: 1))
            .toIso8601String(),
      );
      expect(
        eligibility.canShowInterstitial(
          AdConfig.minCompletedWorkoutsBeforeInterstitial + 6,
        ),
        isFalse,
      );
    },
  );
}
