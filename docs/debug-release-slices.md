# Android debug release slice register

Use this register with the [release plan](release-plan.md). Each row is a Required work package for the debug release. The separate follow-on table tracks production work. **Planned** means implementation and acceptance evidence are pending. Update a row to **Ready**, **In progress**, **In review**, **Accepted**, or **Blocked** as it moves. Record the actual result and evidence link when it is accepted or blocked.

Each handoff includes the baseline commit, owning agent, scope, dependencies, and acceptance scenario. The reviewer checks the result against the spec on the integrated commit.

## Phase 1 · Initiate and build the foundation

| Slice | Owner | Depends on | Product and acceptance evidence | Specification | Status |
| --- | --- | --- | --- | --- | --- |
| **F1 Flutter scaffold** | Foundation | — | Pin Flutter, Dart dependencies, and Android tooling. Launch the first Flutter and Flame screen from a clean checkout. Record workflow write, runner, emulator, and physical device availability. | [Framework](game-specification.md#framework-and-platform-plan) | Planned |
| **F2 Shared board and save contracts** | Foundation | F1 | Use one versioned puzzle format, stable IDs, Drift migrations, and injectable time, source, and motion input. Test round trips and one save migration without loss. | [Shared code](game-specification.md#shared-code-and-platform-input) | Planned |
| **F3 Debug CI** | Foundation | F1 | Required formatting, analysis, and regression jobs run from the lockfile. **Build APK** defaults to **Debug**, uploads an APK, and installs and launches it on an emulator. | [CI and APK](android-delivery-specification.md) | Planned |

## Phase 2 · First playable build

| Slice | Owner | Depends on | Product and acceptance evidence | Specification | Status |
| --- | --- | --- | --- | --- | --- |
| **P1 Opening and amoeba** | Puzzle and Colony | F2 | Three anchored clues and zero 4s start the board. Reproduce the verified four-slide solve, place the three inline 4s, earn exactly 3 DNA, hatch the amoeba, and collect its offered 4. Resume mid-trip. | [Opening board](game-specification.md#sliding-sudoku) | Planned |
| **P2 Irregular 5×5** | Puzzle | P1 | Move all 16 previous tiles into the new inventory, fill gaps in the verified 5×5, and fetch all five 5s. Validate its regions, unique solution, and resume. | [Grid growth](game-specification.md) | Planned |
| **P3 Starter economy** | Colony | P2 | First clears award their resources once. Upgrade digits to produce DNA and RNA, test capped offline production, and verify the budget funds the first creature and both producers. | [Economy](game-specification.md#dna-and-rna-economy) | Planned |
| **P4 First designed helper and nest** | Colony and UI | P3 | A growth choice changes the preview. Test both starting perks, one favorite offer, one letter trip and nest build, and an interrupted hatch or delivery. Save the resolved identity and appendages. | [Creator](creature-creator-specification.md) · [Construction](game-specification.md#letters-as-building-materials) | Planned |
| **P5 First integrated player flows** | UI and Library | P1, P2, F3 | Play with the Hallmark board, tray, and accessible placement. Start the Sudoku Library before creating a colony, find a bundled variant, solve it offline, and restart both modes with their own saves. | [Design](../design.md) · [Library](library-specification.md) | Planned |

## Phase 3 · Complete campaign and Library

| Slice | Owner | Depends on | Product and acceptance evidence | Specification | Status |
| --- | --- | --- | --- | --- | --- |
| **C1 Growth through 9×9** | Puzzle | P2 | Author and solve 6×6, 7×7, 8×8, and 9×9, including irregular regions where defined. Verify the carried inventory and withheld new digit at each transition. Completes six introductory boards with P1 and P2. | [Grid growth](game-specification.md) | Planned |
| **C2 Colony, projects, and mischief** | Colony | P4 | Run assignments, restocking, favorite-number flocking, offers, theft and recall, one-time salvage, and letter-based village, city, and civilization projects without losing tiles or duplicating materials. | [Creature jobs and colony](game-specification.md#creature-jobs-and-favorite-numbers) | Planned |
| **C3 Full creature growth graph** | Colony and UI | P4, C1 | Exercise all 54 growth choices, joined prerequisites, oddities, all starter recipes, and milestone-gated perks. Verify that random color, favorite, and personality survive save and reload. | [Creator](creature-creator-specification.md) | Planned |
| **C4 Shared variant boards and gravity rules** | Puzzle and UI | C1 | Author and validate Renban, Thermometer, Kropki, German Whispers, Killer, and Arrows boards. The worm removes exactly its planned tiles. All four gravity commands move only loose tiles. | [Variant roster](game-specification.md#variants-after-99) · [Campaign](incremental-campaign-specification.md) | Planned |
| **C5 Fog rules and torch jobs** | Puzzle and Colony | C4, C2 | Author Halo and the optional Trail and Linked torches lessons. Verify the visible logical route, unique reveal events, and that the original amoeba can deliver required torches. | [Fog](game-specification.md#fog-of-war-and-torchbearers) · [Campaign](incremental-campaign-specification.md) | Planned |
| **C6 Finales, expeditions, and ending** | Puzzle and Colony | C4, C5 | Author nine finale-route boards and four expeditions. Verify each finale uses its two rules, reach an ending by a 16-board route, switch routes without losing progress, and finish the Meeting Hall with the original amoeba. The full pack totals 28 boards. | [Finale routes and endgame](incremental-campaign-specification.md#finale-routes) | Planned |
| **C7 Prestige and charters** | Colony | C2, C6 | Preview and commit a reset, grant Legacy and first-time bonuses once, retain the archive, and start a fresh seed or 5×5 quick opening. Test all charter restrictions and settlement policy changes. | [Prestige](incremental-campaign-specification.md#prestige-reset) | Planned |
| **L1 Full Logic Masters catalog** | Library | F2 | Traverse the approved listing through the final page and index by portal ID using the separate payload host. Test overlap, locale fallback, restart from cursor, and representative live pages. Record actual source coverage. | [Source and refresh](library-specification.md#source-and-refresh) | Planned |
| **L2 Rule chips and search** | Library and UI | L1 | Map portal tags, written rules, and supported structured constraints. Test Any/All, requested sorting, and a rule missing from tags. With uncertain coverage, display the supported matches and preserve the original text. | [Rule taxonomy](library-specification.md#rule-taxonomy) | Planned |
| **L3 Offline downloads and formats** | Library | L1, F2 | Test approved playable payloads and diagram and source fallbacks. Automatic downloads start off. Verify that manual and automatic jobs deduplicate, resume, pause, and preserve the last good revision. | [Automatic downloads](library-specification.md#automatic-offline-downloads) · [Formats](library-specification.md#formats-storage-and-content-access) | Planned |
| **L4 Featured on CtC** | Library | L1 | Verify the two named source fixtures with their official video links. Check badge, filter, newest-first ordering, offline metadata, and the different-grid note. | [Featured on CtC](library-specification.md#featured-on-cracking-the-cryptic) | Planned |
| **L5 Complete Sudoku side** | Library and Puzzle | P5, C6, L2, L3, L4 | Bundle standalone editions of every authored board and provide access to the full catalog before campaign play. Resume compatible **Play with Colony** challenges offline with separate progress and one-time rewards. | [Library](library-specification.md) · [Play with Colony](library-specification.md#play-with-colony) | Planned |

## Phase 4 · Companions and device readiness

| Slice | Owner | Depends on | Product and acceptance evidence | Specification | Status |
| --- | --- | --- | --- | --- | --- |
| **D1 Companion identity, learning, and speech** | Colony and UI | C3, C7 | Keep one creature through prestige. Test a retained amoeba and One Helper, shared clears, local phrases, deletion, and in-app visits. Preserve the same identity and memory on reload. | [Companion](companion-specification.md) | Planned |
| **D2 Android portrait and tilt** | Android | C4 | Exercise all four directions with injected sensor input, including upside down without rotating the play surface. Test the on-screen fallback. Record real-handset results when available and list any device observations pending for feedback. | [Renban and gravity](game-specification.md#renban-worm-and-gravity) | Planned |
| **D3 Android companion overlay** | Android | D1 | Verify ask, grant, refusal, revocation, lock, stop, and phrase consent with the Android permission flow. Test launcher and another ordinary app. Mark physical-device observations explicitly. | [Android home screen visits](companion-specification.md#android-home-screen-visits) | Planned |
| **D4 Hallmark and accessibility pass** | UI and Verification | P5, C3, L5, D1 | Capture the required screens at 320, 375, 414, and 768 dp. Check readable rules, text scaling, focus, tap and keyboard placement, reduced motion, and walk, run, slime, and cargo poses. | [Visual design](../design.md) | Planned |
| **D5 Shared platform boundaries** | Foundation | F2, D2, D3 | Test motion fallback, accessible input, and in-app companion visits through the shared interfaces. Run Windows, Linux, and iOS simulator compile checks on available runners. Record any runner gap as evidence pending for the later port. | [Build order](game-specification.md#build-order) | Planned |

## Phase 5 · Verify and hand over the debug release

| Slice | Owner | Depends on | Product and acceptance evidence | Specification | Status |
| --- | --- | --- | --- | --- | --- |
| **R1 Independent acceptance** | Verification | C6, C7, L5, D1–D5, F3 | Review the exact commit. Finish early and late game scenarios, verify all authored board tests, and rerun save, upgrade, offline, and permission regressions. Compare update versions and failure states using fixtures. Record outstanding field checks. | [Campaign acceptance](incremental-campaign-specification.md#what-to-verify-before-release) · [Android acceptance](android-delivery-specification.md#acceptance) | Planned |
| **R2 Debug APK and evidence** | Android and Coordinator | R1 | Build the tested revision, verify the installed package and SHA-256, and hand off the APK and CI evidence. Publish those exact bytes as a GitHub prerelease when authorized. Record installation and any debug-signature limitation for testers. | [Debug preview](android-delivery-specification.md#debug-preview-handoff) | Planned |
| **R3 Feedback handoff** | Coordinator | R2 | Hand over the download, test scenarios, known limits, and the feedback register. Record how feedback goes back to its owning slice and which regression or playtest will confirm the fix. | [Debug handoff and feedback](release-plan.md#debug-handoff-and-feedback) | Planned |

## Stable release follow-on

| Slice | Starts after | Product and acceptance evidence | Specification | Status |
| --- | --- | --- | --- | --- |
| **S1 Feedback and field verification** | Debug handoff | Resolve accepted blocker reports, verify tilt and overlay on physical devices, and review content and economy changes using new regression cases. Use feedback to decide whether to prototype the optional companion mosaic. | [Debug handoff](release-plan.md#debug-handoff-and-feedback) · [Mosaic idea](incremental-campaign-specification.md#additional-mechanic-to-prototype) | Follow-on |
| **S2 Production signing and stable publish** | S1 and stable release authorization | Recover or provision the persistent production key in authorized storage. Verify an upgrade with the same package identity, publish the signed stable APK and Android update manifest, and check the published checksum. | [Android delivery](android-delivery-specification.md) | Follow-on |
| **S3 Live update verification** | S2 | Verify the deployed latest-release response and a compatible newer-release notice from the Android app. | [App updates](android-delivery-specification.md#detecting-an-app-update) | Follow-on |
