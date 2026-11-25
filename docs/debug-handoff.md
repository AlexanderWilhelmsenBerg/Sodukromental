# Sodukromental Android debug tester guide

## Candidate

The APK, checksum, source revision, application ID, version and launch evidence are pending. Track the test results and outstanding checks in the [independent review](agent-review.md) and the [slice register](debug-release-slices.md).

Once the candidate is available, download the APK from its supplied artifact location. Compare its SHA-256 with the value listed for that candidate. Open the APK on Android and follow the installation prompt. If prompted, allow the current download app to install the package. With Android platform tools and a connected test device, `adb install -r <apk>` installs it or replaces a compatible earlier build. A signature mismatch can require uninstalling the earlier debug build, which removes its local saves. Keep an earlier build and its saves when testing an upgrade until the candidate's signing identity is confirmed.

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

Send reports to the project coordinator for routing by [slice owner](debug-release-slices.md). A repeatable crash, save loss, unsolvable required board or overlay consent bypass blocks the debug handoff. Record playability and balance observations for the next iteration.

| ID | Build, device and OS | Slice | Starting state and reproduction | Expected and actual result | Severity | Owner and next action | Regression or playtest | Retest and status |
| --- | --- | --- | --- | --- | --- | --- | --- | --- |
| | | | | | | | | |

Include network state, puzzle or route and action sequence when they matter. Attach screenshots or a recording if they help reproduce the result. The owning slice should reproduce the report, make the fix and identify the check that detects the failure. Record the retest on the fixed candidate and link it in the report. Use the physical-device scenarios above to collect remaining tilt and overlay observations. [Release plan](release-plan.md#debug-handoff-and-feedback)
