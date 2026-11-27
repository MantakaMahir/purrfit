# Purrfit

Purrfit is an offline-first workout companion for beginners and people getting back into regular movement. It builds short home workouts around your goals, experience, equipment and movement restrictions. Your progress follows completed workouts and feedback, with no assigned days or streak penalties.

[Official Android app on Google Play](https://play.google.com/store/apps/details?id=com.purrfit.purrfit) · [Website](https://mantakamahir.github.io/purrfit/) · [Purrfit on LinkedIn](https://www.linkedin.com/company/purrfit/)

- Review safety and movement preferences before starting personalized workouts.
- Pause and resume the same workout, including its movements, sets and rest timer.
- Follow a checkpoint journey, review workout history and optionally log adult body measurements.
- Keep workout and profile data on the device, with dark mode, reduced motion and optional mobile reminders.

**The default build includes all workouts and reports without ads, purchases or an account.** It has no fitness-data backend or cloud sync. Store operators can opt into rewarded ads and a one-time ad-removal purchase.

## Run from source

Use [Flutter 3.44.4](https://docs.flutter.dev/install/archive) (Dart 3.12.2), the version pinned in CI. Run `flutter doctor` to check your platform setup, then:

```sh
flutter pub get --enforce-lockfile
flutter run -d <device-id>
```

Run `flutter devices` to find a device ID. For a browser preview, use `flutter run -d chrome`.

| Platform | Build from a clean checkout |
| --- | --- |
| Android | Install Android SDK Platform 36 and JDK 17. Run `flutter build apk --debug`. The installable APK is `build/app/outputs/flutter-apk/app-debug.apk`. `flutter build apk --release` produces an **unsigned** optimized APK unless you configure your own release key. |
| iOS | Use macOS and Xcode with an iOS simulator installed. After `flutter pub get`, run `flutter build ios --simulator --debug`. For Xcode, open `ios/Runner.xcworkspace` after Flutter generates the local Swift package and build configuration. Physical devices require Apple signing. |
| Web preview | Run `flutter build web --release --no-web-resources-cdn` and serve `build/web/` over HTTPS or localhost. Browser storage is specific to that browser and origin. Mobile reminders, ads and purchases are unavailable in the preview. The preview needs its host to load; Flutter may also request fallback fonts. |

### Verification

```sh
dart format --output=none --set-exit-if-changed lib test
flutter analyze --no-pub
flutter test --no-pub
```

The workflows in [`.github/workflows`](.github/workflows) cover Flutter verification, Android debug and unsigned release builds, and the iOS simulator build. The simulator workflow can be run manually for a clean checkout.

## Distributing your build

See [store setup](external_setup.md) for release signing, production identifiers, privacy and support links, and optional AdMob and storefront configuration. Use your own package identifiers and store accounts. The included app name, signing setup, and store configuration are not a turnkey official Purrfit release.

## Project layout

- `lib/main.dart`: app navigation, workout flow, and local journey state.
- `lib/workout_engine.dart`: workout prescriptions, movement restrictions, checkpoints, and report data.
- `lib/storage/`: protected device-local storage.
- `lib/ads/` and `lib/purchases/`: opt-in rewarded ads, consent, purchases, and restores.
- `lib/app/theme/` and `lib/shared/ui/`: themes and reusable Cupertino components.
- `android/`, `ios/`, `web/`, and `test/`: platform hosts and tests.

## Contributing

Open an issue for a reproducible bug or a proposed change. Include the Flutter version and platform where relevant. Run the verification commands before submitting a pull request. Keep workout data local, preserve safety and movement restrictions across all workout entry points, and keep credentials and excluded media out of patches.

## License

The complete first-party project, including its source code, tests, documentation, build configuration, and original placeholder artwork, is licensed under the [MIT License](LICENSE).

[Third-party notices](LICENSES/README.md) cover the Flutter template, Gradle Wrapper, and Manrope, whose [SIL Open Font License](assets/fonts/OFL.txt) also ships with the app. Dependencies retain their own licenses. The original Purrfit mascot, exercise demonstrations, body-model artwork, sounds and store artwork are not included or licensed here. This repository uses neutral launcher icons and built-in UI icons instead.
