# Sodukromental

A portrait Sudoku game for Android. Slide tiles to free three missing 4s, hatch an amoeba with the DNA you earn, and send it to find the fourth. Grow the grid from 4×4 to 9×9, design helpers, learn variant rules, build a settlement, and choose a companion to keep through prestige.

The **Sudoku** tab opens independently of the colony. Browse the Logic Masters Deutschland catalog and the 28 original game boards, filter by rule, or look for a verified Cracking the Cryptic solve. Automatic puzzle-content downloads are off by default. The Library displays each puzzle’s available play, diagram, or source options.

The Phase 2 debug build adds branching ecology hatches, living pixel villages and native offline solving tools. Residents fetch digits, carry torches along earned paths and build with letters from the screen. After classic 9×9, a Renban worm introduces the first variant with a practice example. [Phase 2 playtest guide](docs/phase-2-debug-handoff.md)

The [Phase 3 colony specification](docs/phase-3-living-colony.md) covers screen-wide settlements, relationships, survival and the five-step hatch. The [Library repair notes](docs/phase-3-library.md) track setter-page recovery and offline play.

## Run locally

Use Flutter 3.44.4 with Dart 3.12.2 and JDK 21. The Android build uses SDK 36. On a configured Android host, run the following from the repository root.

```sh
flutter pub get --enforce-lockfile
flutter test
flutter run
```

Build an installable tester APK with `flutter build apk --debug`. The GitHub Actions **Build APK** workflow offers Debug and Release. Use Debug for feedback. The separate **Desktop and iOS compile checks** workflow is available for port verification.

## Debug testing

Use the [Phase 2 debug handoff](docs/phase-2-debug-handoff.md) for installation and playtest scenarios. The [Phase 1 handoff](docs/debug-handoff.md) documents the earlier build. The [slice register](docs/debug-release-slices.md) tracks the implementation against the [release plan](docs/release-plan.md) and [game specification](docs/game-specification.md). Story, mechanics and UI/UX findings feed the [independent review](docs/agent-review.md).

Logic Masters puzzles credit their setters and link to their original pages. The bundled fonts include their licenses in `assets/fonts`.
