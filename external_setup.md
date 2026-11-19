# Store setup and release checklist

This file lists account-specific configuration that app contributors must supply themselves. Keep passwords, signing keys, financial details, production ad IDs, and private account information out of source control.

## Google Play

- Create the Android app with the intended package name and complete Play Console identity, content, target-audience, privacy, and data-safety forms.
- Create a non-consumable in-app product with ID `purrfit_ad_free`.
- Create separate Android AdMob app and ad-unit IDs. Configure UMP consent and `app-ads.txt` as required for your region and monetization policy.
- Set the production IDs through the Android Gradle property `ADMOB_APP_ID` and Dart defines `ADMOB_BANNER_ID`, `ADMOB_INTERSTITIAL_ID`, and `ADMOB_REWARDED_ID`.
- Generate and protect your own upload key. Supply the signing values through local ignored `android/key.properties` or environment variables; see `README.md`.
- Test purchase, pending, cancellation, restore, refund, ads, consent, reminders, installation, and update behavior using a Play testing track.

## Apple App Store (macOS and Xcode)

- Set a unique bundle ID and configure signing, provisioning, and distribution in Xcode.
- Create a matching non-consumable `purrfit_ad_free` item in App Store Connect, then test localized price, purchase, pending/cancel, restore, and refund using StoreKit or sandbox testers.
- Create separate iOS AdMob app and ad-unit IDs; the Debug build uses Google's official test app ID. Set the production `ADMOB_APP_ID` in the Xcode Runner target's build settings and use the three ad-unit Dart defines listed above.
- Configure UMP consent, store privacy disclosures, and any applicable ad tracking decisions.
- Verify notification permission and local reminders on simulator and physical devices.
- Replace the generated iOS placeholder app icon with artwork you have rights to distribute, then archive, sign, and validate in App Store Connect.

## General

- Review current store policies for billing, advertising, privacy, and health/fitness claims before submission.
- Core workouts and reports must remain usable without creating an account or connecting to a backend.
- Avoid committing real store credentials, production ad IDs, signing files, or proprietary artwork and sounds.
