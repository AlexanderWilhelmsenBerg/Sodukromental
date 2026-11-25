# Sodukromental Android debug tester guide

## Candidate

**Download the Android debug build, version 0.1.0 (build 1).** Open the Actions artifact while signed in to GitHub, extract the ZIP and install `sodukromental-0.1.0-debug-android.apk`. Android 7.0 or newer can run the game. Optional visits over other apps require Android 8.0 or newer. [Download the debug build](https://github.com/AlexanderWilhelmsenBerg/Sodukromental/actions/runs/45614087897/artifacts/15022054322)

| Item | Verified value |
| --- | --- |
| Built source | [5083583983c2ab23a49a6577f6fef170e308487a](https://github.com/AlexanderWilhelmsenBerg/Sodukromental/commit/5083583983c2ab23a49a6577f6fef170e308487a) |
| Android identity | `org.sodukromental.debug` · `0.1.0+1` · minimum API 24 · target API 36 |
| APK size | 165,081,214 bytes, with ARM64, ARMv7 and x86-64 builds |
| APK SHA-256 | `3e4645771f74c13f8070c9b1de17d4b38fa5a3303950bd7f8f6978700899f9af` |
| Debug signer SHA-256 | `ed0a1a3c6662739ed2688a66b673790fba8fd536c5afbdf54f07a8e46a73caa9` |

The ZIP includes the checksum, signing receipt, source commit and a launch screenshot. On Linux, `sha256sum -c sodukromental-0.1.0-debug-android.apk.sha256` verifies the extracted APK. Open it on the phone and follow Android’s installation prompt. Android may ask to allow installs from the app you used to open the file. If using Android platform tools, `adb install -r sodukromental-0.1.0-debug-android.apk` installs it or upgrades a compatible signed preview. Compare signer digests before replacing a valued colony. Uninstalling a differently signed preview erases its local data.

The Android 14 workflow installed these exact bytes, captured the opening, then installed build 2 with the same debug signing key. The campaign reopened with seed `61312`, two placed 4s and 2 DNA. The independent 5×5 Library save kept pencil candidate 5. Sixty regressions passed. The installed UI test finished the opening, resumed a Library puzzle, solved 5×5, and hatched a designed creature. The companion device test checked consent, visited the Android launcher and another app, and stopped via its notification, screen lock and permission revocation. The later companion test revisions change the test harness only. [APK and upgrade run](https://github.com/AlexanderWilhelmsenBerg/Sodukromental/actions/runs/45614087897) · [Android regression run](https://github.com/AlexanderWilhelmsenBerg/Sodukromental/actions/runs/45614047768) · [Companion device run](https://github.com/AlexanderWilhelmsenBerg/Sodukromental/actions/runs/45615700741) · [Android opening](evidence/android-14-opening.png)

Windows, Linux and the iOS simulator compiled from the released source. Physical handset tilt, TalkBack, differences between Android manufacturers’ overlay controls, early puzzle discovery and late-game pacing are the priorities for playtesting. The stable release workflow also needs a configured production signing key and live update verification before publication. [Port builds](https://github.com/AlexanderWilhelmsenBerg/Sodukromental/actions/runs/45614087828) · [Independent review](agent-review.md) · [Slice register](debug-release-slices.md)

The Library contains 28 authored puzzles for offline play and listing metadata for 32,523 Logic Masters puzzles. Additional author rules load when the Library syncs or opens an entry. **Automatically download Logic Masters puzzles** starts off. For a portal puzzle, save its assets while connected before trying an offline solve. The details page shows whether the entry can be played offline, viewed as a diagram or opened on the original site. The 67 verified Cracking the Cryptic badges work offline, with an internet connection required to play the linked video. [Library requirements](library-specification.md)

## Playtest scenarios

Try the opening once before reading the coordinates. Record what you thought could be touched after each action and where you needed a hint.

| Route | What to try and record | Slice |
| --- | --- | --- |
| Start in Colony | Find the three 4s in the sentence, use both drag and select-then-place, and hatch at 3 DNA. Close the app while the amoeba is out and reopen. Record if the same trip resumes and its last 4 can be placed. | P1, P5 |
| Expand and settle | On 5×5, use carried digits and fetch the five 5s. Review a starter creature's appearance before and after a growth choice, try each starting work perk, and interrupt a letter delivery. Record what persists and whether each reward arrives once. | P2–P4, C2, C3 |
| Start in Sudoku | On a fresh profile in airplane mode, find a bundled variant with two matching rules. Finish it, close the app and reopen. Then start Colony and switch back to Sudoku to confirm the Library solve is still present. | P5, L2, L5 |
| Browse and download | Online, inspect a portal entry's rules and author credit. Use the CtC sort and find *The Most Beautiful Mathematical Equation* and *The Magic Column*. Save a playable puzzle and a diagram, then reopen them in airplane mode. On a compatible download, compare ordinary play with Colony progress after 5×5. | L1–L5 |
| Follow the variants | Compare the worm's removed digits with the tray, use all four gravity directions, and ask the original amoeba for torches. Switch finale routes, return to the first route and check its progress. Complete a finale and build the Meeting Hall. | C4–C6, D2 |
| Retain a companion | Teach a phrase, select a creature in the prestige preview and confirm the reset. Reopen, check the retained identity and phrase, delete the phrase, and check a visit. Exercise a returning amoeba or One Helper in the next run. | C7, D1 |
| Test on a physical phone | On a gravity board, try right, left, upright and upside down and compare with direction controls. In companion settings, refuse an outing, grant one, lock the screen, revoke the system grant and try **Stop roaming**. Check the launcher and an ordinary app. Use a test phrase and verify that permission begins off for each phrase. Record Android version and phone model. | D2, D3 |
| Read and navigate | Use the smallest display available and increase Android font size. Check the rule panel, board, creature preview and Library filters. Try reduced motion and, with a keyboard or screen reader, select a cell and place a digit. | D4, D5 |

The documented opening path moves R2C2 → R1C2, R3C2 → R2C2, R3C3 → R3C2, and R2C2 → R2C1. Then place the sentence's 4s in any three of R1C4, R2C2, R3C3 and R4C1. The amoeba supplies the fourth. [Verified opening board](game-specification.md#verified-opening-board)

## Feedback register

Open a repository issue and include the build, phone, steps, and expected and observed result. The coordinator routes each report to the slice owner, assigns a regression or playtest, and records the retest. A repeatable crash, lost save, unsolvable board or outing without consent takes priority. [Report feedback](https://github.com/AlexanderWilhelmsenBerg/Sodukromental/issues/new) · [Slice owners](debug-release-slices.md)

| ID | Build, device and OS | Slice | Starting state and reproduction | Expected and actual result | Severity | Owner and next action | Regression or playtest | Retest and status |
| --- | --- | --- | --- | --- | --- | --- | --- | --- |
| | | | | | | | | |

Include network state, puzzle or route and action sequence when they matter. Attach screenshots or a recording if they help reproduce the result. The owning slice should reproduce the report, make the fix and identify the check that detects the failure. Record the retest on the fixed candidate and link it in the report. Use the physical-device scenarios above to collect remaining tilt and overlay observations. [Release plan](release-plan.md#debug-handoff-and-feedback)
