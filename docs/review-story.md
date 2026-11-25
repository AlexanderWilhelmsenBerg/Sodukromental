# Player experience review for the Android debug release

The scenarios below track all 28 required slices. Creature-model and widget tests live in [creatures_test.dart](../test/creatures_test.dart). Integrated campaign, source, and device checks still belong to their owning slices and need evidence from the exact revision under review.

The starter review can exercise both work perks without grinding for DNA or RNA. Joined growth choices stay visible as saved recipe selections when a prerequisite changes, and the preview omits those parts until the prerequisite returns. Companion testing can use an invitation after prestige to hear local speech before four shared clears. Six shared clears and retention are required for the Android system permission prompt.

| Slice | Player experience to check |
| --- | --- |
| F1 | Open a clean install and find Sudoku and Colony without setup. On a narrow handset, the first puzzle prompt and its anchored tiles should appear before the player needs to scroll. |
| F2 | Resume immediately after placing a prompt digit, while the amoeba is away, and after teaching a phrase. The board, inventory, and companion should each return in a recognizable state. |
| F3 | Launch a CI-built debug APK from a fresh install and proceed from the opening prompt to a placed token. Capture the first visible screen and any handheld startup discrepancy. |
| P1 | Try placing a 4 too soon, solve the four slides, then consume each inline token once. Replay the acceptance scenario using taps only. Read the three lock marks and see why the fourth 4 calls for the amoeba. |
| P2 | Show one outlined irregular region first. Watch retained tiles transfer to the 5×5 board and tray, then check that the missing 5s are the amoeba’s first new assignment. |
| P3 | Buy both producers and the first designed creature from the tutorial and 5×5 budget. Point to the production interval and current balance, then reopen after an absence and check the payout once. |
| P4 | Change the starter silhouette, review the hatch price and housing, and hatch. See the favorite digit and generated coloring at first reveal. Carry a letter from the flavor sentence into a nest and return mid-trip. |
| P5 | Open the bundled Library before creating a colony, select a variant, and solve an authored clue with no network. Change destinations midway and verify that focus, rule context, and each save remain intelligible. |
| C1 | Track what happens to old digits on each expansion and identify the new withheld numeral. Compare the new shape against the tray and the completed board record. |
| C2 | Distinguish a tray digit from the same creature’s favorite offer. Recover the same stolen tile, see a tinkerer’s replacement, and build with the original letter silhouettes. Try reactions and full antics with the same deductions. |
| C3 | Open each path as it becomes relevant. Change a prerequisite and check that the oddity disappears from the preview and returns when restored. Compare idle, travel, and cargo poses. The creature tests cover all starter bodies and the four prerequisite joins. |
| C4 | At 9×9, watch the worm’s Renban event and identify the loose tiles it took. Follow the gravity rules using each on-screen direction control and compare the result with physical tilt. |
| C5 | Request a torch from the original amoeba, see it arrive where the rules led the player to expect, and verify that a wrong placement reveals nothing. Resume with a torch still en route. |
| C6 | Understand which routes remain available and what the Meeting Hall still needs. Try switching routes, then finish the ending with the original amoeba and review the expedition choices. |
| C7 | Preview earned Legacy, the archive, and the selected companion before resetting. Find the selected companion with the same name and coloration afterward. Under One Helper, distinguish a visit from a work assignment. |
| L1 | Search for a known puzzle after a partial source pass, close the app, and resume the source refresh. Record a visible catalog status during incomplete coverage and when the last source page is reached. |
| L2 | Apply two rule filters using Any and All. Compare a result with its original authored text so that unsupported rule matches stay understandable. |
| L3 | Find the difference between a downloaded playable puzzle, a diagram with a source link, and an item waiting for download. Retry offline and verify a previous good revision remains available. |
| L4 | Open a CtC spotlight badge and compare it with its source and grid. The two fixture entries should identify their verified video and explain the different-grid case where relevant. |
| L5 | Start both a standalone puzzle and a Play with Colony challenge from the Library before finishing the campaign. Resume each offline and verify the reward feedback only appears for its first qualifying finish. |
| D1 | Teach a local phrase, hear it during a visit, and revoke it. Encourage a completed task once per encounter. Confirm the archived and active companion share an identity while the active companion alone maintains history. |
| D2 | Keep the board readable in portrait while exercising every tilt and each on-screen direction. Check on a handset that players can reach the fallback comfortably and placed tiles stay fixed. |
| D3 | On a physical Android device, try Stay here, deny permission, grant it, then stop from the notification. Verify explicit phrase consent, tiny touch bounds, launcher and supported app visits, and removal on lock or revocation. The Flutter channel test checks the approved payload. |
| D4 | Check readability and 48 dp targets at 320, 375, 414, and 768 dp and large text. Inspect selection/focus, previews and cargo, digit drag and tap parity, and the immediate state change with reduced motion. |
| D5 | Use on-screen gravity and invited visits when the system adapter is unavailable. In-app work, speech, call back, and focus should stay discoverable on each available target. |
| R1 | Ask a reviewer unfamiliar with the script to complete the tutorial with taps, review a hatch and nest, finish a fog reveal, and reach prestige from an advanced fixture. Record where they relied on out-of-game instructions. |
| R2 | Have a tester install the exact debug APK being handed over. Confirm the fresh opening matches the screenshots and provide the checksum and update/install context with the download. |
| R3 | Give testers a short path to first creature and separate starting points for fog, prestige, and notification-based roaming if those fixtures are available. Route reports by save stage and slice, including expected result, observed result, and revision. |

For follow-on S1, collect physical-device observations and pacing reports before changing the economy or prototyping the mosaic. S2 requires an in-place upgrade check with a saved colony and companion. S3 requires live update availability, failure, and offline checks while normal puzzle access remains usable.
