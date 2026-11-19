# Purrfit

**A gentle, offline-first workout companion built with Flutter.** Purrfit helps people get started with short, adaptable home workouts and a checkpoint journey that progresses at their pace.

> This source distribution contains the app code and open-source font, but not the original Purrfit mascot, exercise demonstrations, body artwork, or sound effects. The app uses built-in icons in their place. See [artwork and licensing](#artwork-and-licensing).

## What it does

- Onboarding that considers exercise experience, goals, available equipment, movement preferences, and a required safety review.
- Personalized, deterministic home-workout plans that adapt to ability, feedback, and restrictions.
- A resumable workout player that saves the exact prescription and current progress before you start.
- A forgiving checkpoint journey: missed days carry no penalty, partial attempts do not advance progression, and difficulty does not increase just because time has passed.
- Offline reports for workout history, journey progress, and optional manual body measurements.
- Encrypted, device-local journey storage, optional daily reminders, dark mode, and reduced-motion support.
- Optional rewarded ads for extra workouts and reports, plus a one-time, store-localized purchase to remove ads.

There is no account, backend, cloud sync, AI service, or required network connection for the core experience. Ads and optional app-store purchases require network access.

## Supported platforms

| Platform | Status |
| --- | --- |
| Android | Flutter project included; can be built with Android Studio or the Flutter SDK. |
| iOS | Xcode project included; requires macOS, Xcode, CocoaPods, and Apple developer/store configuration for device distribution. |

The generated iOS host project cannot be built or signed on Windows. This repository has not yet been verified with Xcode. Follow the iOS setup notes below before configuring store integrations.

This repository is currently private while source and licensing review is completed. A future public release will continue to exclude proprietary product icons and character artwork.

## Quick start

Install the [Flutter SDK](https://docs.flutter.dev/get-started/install) and the platform tools you need, clone this repository, then run:

```shell
flutter pub get
flutter run
```

To check the source locally:

```shell
dart format --output=none --set-exit-if-changed lib test
flutter analyze
flutter test
```

The standard debug build uses Google’s sample AdMob app ID and test ad-unit IDs on Android and iOS. It does not need production credentials or store products to launch. Store-specific screens remain unavailable until running on a supported mobile device.

### Build Android

```shell
flutter build apk --debug
```

For local billing and release signing, configure your own Play Console product and upload key. For production ads, provide the AdMob application ID through Gradle and ad-unit IDs through Dart defines; **never commit signing keys or store passwords**. The included release Gradle configuration deliberately fails closed if release AdMob values are missing.

### Build iOS (macOS only)

```shell
flutter build ios --debug --no-codesign
```

Run `flutter pub get` before opening the project so Flutter generates the local plugin package and `ios/Flutter/Generated.xcconfig`. The generated package is intentionally ignored by Git and referenced by the Xcode project; `flutter pub get` must therefore run after every clean checkout. Open `ios/Runner.xcworkspace` in Xcode to select a team and configure code signing. The Debug configuration defaults `ADMOB_APP_ID` to Google's official test app ID; set the production ID in the Xcode Runner target's build settings for release. Supply iOS ad-unit IDs with the `ADMOB_BANNER_ID`, `ADMOB_INTERSTITIAL_ID`, and `ADMOB_REWARDED_ID` Dart defines. The ad-free item uses the shared product identifier `purrfit_ad_free`; create a matching **non-consumable** product in App Store Connect, and use the product’s localized price shown by StoreKit. A Play Console item does not automatically create an App Store product.

Purrfit requests notification permission only when a person enables reminders. Local reminders do not require push notifications, APNs, or background modes. Validate permission prompts, scheduling, and recurring delivery on a real iPhone and simulator with Xcode before release.

## Optional storefront and advertising configuration

- **Google Play:** create a non-consumable in-app product with identifier `purrfit_ad_free` and test it through a Play testing track.
- **Apple App Store:** create a matching non-consumable in-app purchase with identifier `purrfit_ad_free` in App Store Connect; configure StoreKit testing in Xcode for local purchase-flow work.
- **AdMob:** set up separate Android and iOS app IDs and ad units, UMP privacy messaging, and store privacy disclosures. Debug builds use test placements; release builds require the operator’s production IDs.
- **Price:** the UI fetches the current price from the active storefront. Purrfit intentionally does not assume a fixed USD amount; the final price is localized and confirmed by the store.

The current `adFreeOwned` device preference is a convenience cache. The purchase stream and explicit restore action recover non-consumable purchases; this client-only project does not implement server-side receipt validation or refund reconciliation. Review both stores’ current billing requirements before publishing.

## Project layout

- `lib/main.dart` — application flow, workout state, local journey persistence, and screens.
- `lib/workout_engine.dart` — deterministic workout planning, safety restrictions, checkpoint progression, and report models.
- `lib/storage/` — encrypted local state.
- `lib/ads/` — consent, ad configuration, rewarded ads, and eligibility.
- `lib/purchases/` — direct App Store / Google Play non-consumable purchase and restore.
- `lib/notifications.dart` — optional scheduled local reminders.
- `lib/app/theme/` and `lib/shared/ui/` — design tokens and reusable Cupertino widgets.
- `test/` — offline widget, accessibility, progression, purchase-service, and storage tests.
- `android/`, `ios/` — native Flutter app hosts.

## Artwork and licensing

The source repository is licensed under the MIT License; that license applies to the project’s original code. The excluded Purrfit character, exercise and body-model artwork, sound effects, store listings, and related brand assets are **not** granted or relicensed by this repository. They are intentionally not present in this source distribution. Do not add them back unless you hold the rights and have explicitly chosen to distribute them under compatible terms.

The included Manrope font is separately licensed under the SIL Open Font License; its license is retained in `assets/fonts/OFL.txt`. Third-party Flutter packages retain their own licenses.

The Android and iOS launcher icons are neutral placeholders, not Purrfit brand artwork. Replace them with artwork you have rights to distribute before a branded release. The included raster icon source is in `assets/icon/`; regenerate the native icon sizes after replacing it.

## Contributing

Bug fixes, tests, documentation, and platform improvements are welcome. Please keep the core workout and report experience offline-capable, preserve the required safety review and movement restrictions, and do not introduce account or network dependencies without discussing the change first. Run formatting, analysis, and tests before opening a pull request. Avoid including real store credentials, signing materials, private handoff archives, or unlicensed artwork/audio in contributions.

## License

Original application code is available under the [MIT License](LICENSE). That license does not grant rights to omitted artwork or other excluded brand material.
