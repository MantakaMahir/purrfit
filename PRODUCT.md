# Purrfit product notes

Purrfit is an offline-first workout companion for beginners and people returning to movement. The primary experience is calm, safe, and non-punitive.

## Core behavior

- Navigation: Journey, Workout, Report, Profile. Report contains Overview, History, and Body sections.
- Journey chapters contain six checkpoints, with no fixed launch-era progress ceiling.
- Each checkpoint has one frozen, resumable prescription. Save it before Start.
- Qualification requires half of the main movements, rounded up. Partial attempts and replays never advance the path or award checkpoint points.
- Progression follows capability, completed work, and feedback. It does not follow elapsed time or checkpoint number.
- Explicit safety review is required for personalized and optional workouts. Preserve equipment, floor, and impact restrictions throughout planning and playback.
- Data and reports remain on the device. History deletion never erases earned journey progress.

## Experience principles

- No streak penalties, assigned workout days, missed-day punishment, or forced pace.
- Prefer built-in icons and native components; optional branded artwork is intentionally excluded from this code distribution.
- Keep the basic workout and report experience useful offline and accessible with reduced motion.
- Keep optional store billing and advertising isolated from core journey progression.

## Monetization

The default source build unlocks all workouts and reports. In builds with monetization enabled, rewarded ads unlock optional workouts and the Overview and Body reports. The one-time `purrfit_ad_free` non-consumable purchase removes those gates. The active store supplies the localized price.
