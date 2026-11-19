# Mobile store test checklist

Complete store-specific steps for each platform that will be distributed. Do not assume a product or ad unit on one storefront is configured on the other.

## Before submitting

- [ ] Run `dart format --output=none --set-exit-if-changed lib test`, `flutter analyze`, and `flutter test`.
- [ ] Build and launch a debug app from a clean checkout on the target device.
- [ ] Confirm onboarding safety review is required and equipment, floor, and impact restrictions are respected in every workout path.
- [ ] Confirm prescriptions persist before Start and active sessions resume after process restart.
- [ ] Confirm partial attempts, skipped movements, and replays do not advance checkpoint progress.
- [ ] Test local data deletion, restoration of the local journey where applicable, and history deletion separately.
- [ ] Test notification opt-in, refusal, later permission changes, local-time scheduling, timezone changes, and reboot behavior.
- [ ] Test dark appearance, screen readers, text scaling, reduced motion, and narrow phone layouts.

## Google Play / Android

- [ ] Create an Android AdMob app and production units; use test units during development.
- [ ] Configure UMP privacy messaging and complete Play data-safety and content disclosures.
- [ ] Create the non-consumable `purrfit_ad_free` product and test buy, pending, cancellation, restore, and refund paths on a Play test track.
- [ ] Configure and protect your own upload key, AdMob app ID, and release ad-unit IDs.
- [ ] Build a signed bundle and test installation, update, reminders, consent, ads, and billing on supported devices.

## App Store / iOS (macOS + Xcode required)

- [ ] Set a unique bundle identifier and configure Apple signing and distribution certificates in Xcode.
- [ ] Create the matching non-consumable `purrfit_ad_free` product in App Store Connect.
- [ ] Configure StoreKit local testing and/or sandbox testers; test localized price, purchase, cancellation, restore, and refund behavior.
- [ ] Configure the iOS AdMob app ID as `ADMOB_APP_ID` in the Xcode Runner target build settings; create separate iOS ad units.
- [ ] Configure UMP, ATT decisions if applicable to your ad policy, privacy disclosures, and app-privacy information.
- [ ] Verify local notification opt-in and repeating reminders on a physical iPhone and a supported iOS simulator.
- [ ] Build, sign, and archive using the Xcode workspace, then validate the archive in App Store Connect.

## Licensing and release

- [ ] Confirm that all included code and assets have suitable licenses.
- [ ] Do not bundle excluded mascot, exercise/model art, store graphics, or sounds unless distribution rights are separately confirmed.
- [ ] Do not include private signing material, production credentials, `.env` files, or local store-test exports in source control.
