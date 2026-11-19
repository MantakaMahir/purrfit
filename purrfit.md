# Purrfit project summary

Purrfit is an offline-first Flutter workout companion. It builds adjustable home workouts, saves resumable sessions, and records progress through a non-punitive checkpoint journey.

## Project facts

- Flutter and Dart app with Cupertino-style UI.
- Android and iOS host projects are included. Android can be built on a configured development machine; iOS requires macOS, Xcode, and App Store Connect for storefront testing and distribution.
- Journey state, workout history, manual body measurements, and reports are stored locally; journey state is encrypted.
- No sign-in, cloud backend, account system, AI API, or health-data integration.
- Optional daily reminders are local notifications.
- Ads use Google Mobile Ads with User Messaging Platform consent.
- `purrfit_ad_free` is a non-consumable product queried from the current Apple App Store or Google Play storefront.
- Production ad identifiers and release signing must be supplied by each operator. Never commit them.
- The public source distribution omits Purrfit mascot, model, and exercise art and bundled sound effects. It keeps an open-source Manrope font with its separate SIL Open Font License.

Read `README.md` for build steps, store configuration, licensing, and project structure.
