# Store distribution

The standard source build leaves ad and billing services inactive and unlocks all workouts and reports. The native SDKs are linked so the same project can support the integration when enabled. You can sign and distribute the default build without adding a storefront product.

## Signing and app identity

- **Android:** Set your own `applicationId` in `android/app/build.gradle.kts`. Add these four local properties to the ignored `android/key.properties`, or supply the same names as environment variables. The key path is absolute or relative to `android/`. With all four values set, `flutter build appbundle --release` produces a signed bundle. With no values, release builds are unsigned.

  ```properties
  PURRFIT_UPLOAD_STORE_FILE=
  PURRFIT_UPLOAD_STORE_PASSWORD=
  PURRFIT_UPLOAD_KEY_ALIAS=
  PURRFIT_UPLOAD_KEY_PASSWORD=
  ```

- **iOS:** Set your own Runner bundle ID and development team in `ios/Runner.xcworkspace`. Configure signing for Keychain access. Build an archive with `flutter build ipa` on macOS after setting up signing.
- For store listings, use your own icon, privacy policy, support contact, and disclosures. Supply HTTPS links with `--dart-define=PURRFIT_PRIVACY_URL=…`, `--dart-define=PURRFIT_TERMS_URL=…`, and `--dart-define=PURRFIT_SUPPORT_URL=…`. Profile shows only the links you supply.

## Optional rewarded ads and purchase

1. Create a non-consumable item with ID `purrfit_ad_free` in each storefront you use. The app reads the localized price from that storefront.
2. Create an AdMob app and one rewarded ad unit for each platform. Configure UMP privacy messaging and the disclosures that apply to your build.
3. On Android, set `ADMOB_APP_ID` in `android/key.properties`, as an environment variable, or as a Gradle property. On iOS, set `ADMOB_APP_ID` in the ignored `ios/Flutter/Local.xcconfig` or in the Runner target's build settings. The AdMob application ID contains `~`; a rewarded ad unit ID contains `/`.
4. Enable the integration with `--dart-define=PURRFIT_ENABLE_MONETIZATION=true`. For a monetized release, configure release signing and pass `--dart-define=ADMOB_REWARDED_ID=…` with the matching platform's production rewarded unit. Debug builds use Google's test rewarded units. Replace the default sample app ID for any monetized release.
5. Use a testing track or StoreKit sandbox to test the ad and purchase flow before distribution. See the [store test checklist](play_testing_checklist.md).

The purchase cache provides offline access after a purchase or restore. There is no server-side receipt verification or refund reconciliation. Verify payment, pending approval, cancellation, restoration, and refund behavior with the target storefront before enabling paid distribution.
