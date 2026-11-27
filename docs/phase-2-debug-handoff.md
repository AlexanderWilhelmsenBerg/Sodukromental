# Phase 2 Android debug handoff

**0.2.0, build 3** is ready for playtesting on Android 7.0 and newer. Download the artifact while signed in to GitHub, extract the ZIP and open `sodukromental-0.2.0-debug-android.apk` on your phone. The ZIP also contains the checksum, signing receipt, source revision and Android launch screenshot. [Download the verified build](https://github.com/AlexanderWilhelmsenBerg/Sodukromental/actions/runs/45982280414/artifacts/15190039691)

**Returning from the published 0.1.0 preview? Export your saves before removing it.** Android requires matching certificates for an in-place update, and the two published debug builds have different signatures. The transfer guide covers both the colony and the Library, including saved puzzle packages and notes. [Transfer a debug save](android-debug-save-transfer.md)

On a disposable Android 14 emulator, the transfer recovered a Phase 1 campaign, its settings and an in-progress *X-Sums* puzzle into this signed APK. The source database held a pencilled 1, which was also present in the restored Library. The helper checks both databases before replacing them and keeps a separate backup of the destination.

| Build receipt | Verified value |
| --- | --- |
| APK SHA-256 | `2bb2abc180ef8569ffbec44301b7e8dd486982147cf113b416212eb0271b003a` |
| Debug signer SHA-256 | `9ee6aee25335bf4f7d941e710d454ed2ce28db3569ca58933f0e01cf94926fb8` |
| Package and source | `org.sodukromental.debug` · [8a245bc](https://github.com/AlexanderWilhelmsenBerg/Sodukromental/commit/8a245bc7fe5105ecc08ff3b4b43ce5a421237295) |

All 121 regression tests passed. Android 14 exercised the opening through a designed hatch, a wrong fog entry that survived a database reopen and could immediately be corrected, and the companion’s permission and roaming controls. The packaging job installed the exact APK on Android 14 and verified a same-signer test upgrade retained two printed 4s, 2 DNA, the colony seed and a Library pencil mark. Windows, Linux and the iOS simulator compiled from the same source. [Android tests](https://github.com/AlexanderWilhelmsenBerg/Sodukromental/actions/runs/45982247134) · [APK installation and upgrade](https://github.com/AlexanderWilhelmsenBerg/Sodukromental/actions/runs/45982280414) · [Desktop and iOS builds](https://github.com/AlexanderWilhelmsenBerg/Sodukromental/actions/runs/45982280443)

| Slice | Try this in the debug build |
| --- | --- |
| A1 · Opening and inventory | Select a loose tile. Follow its arrows or slide it just under half a square and release. Try an anchor and a diagonal swipe. Free the three printed 4s, hatch the amoeba and accept its fourth 4. On 5×5 select a cell, then its value from the fixed pad. |
| A2, B1 · Creature paths and behavior | After 5×5, choose a lineage, habitat and response, resume a saved draft, then hatch. Compare how a specialist walks with and without cargo. In an established village watch two residents meet. Look up their bond and try working them apart. |
| B2 · Living settlement | Follow one letter from its gray source through a lodge and into a pixel building. Change a worker's priority while a project is underway. Watch rain collect in a closed glyph, enter a bucket and reach the cistern. Reduce motion and check that you can still read the source and the job. |
| B3, C1 · Shatter, lessons and fog | Break a seam after classic 9×9, finish or skip the remaining seams, then place one piece directly and sort another. Ask the Renban worm for an example and try a wrong answer. On a fog board compare staff, request a torch and follow its named carrier. Reopen **? Rule help** on a mixed board. |
| E1–E3 · Economy and prestige | Pin a goal, open a production batch, deliver two distinct requested digits and use an earned preset. Finish a finale and the Meeting Hall. Inspect the Legacy quote, keep a named resident, then found the next colony with a different charter. The archive allows a later crew to compare a recorded delivery. |
| A3, B4 · Native offline Library | Save *Ringing the Changes* and *The Graveyard Of Totality* while online. Switch to airplane mode, reopen the app and play from Saved. Try values, ABC pencil marks, colors, pen, undo and replay. In a fog puzzle enter a wrong digit under cover, reopen and replace it. Verify that a torch visitor leaves the setter's reveal pattern intact. |

Two village snapshots show the effect of changing the colony seed. The opening and Halo snapshots use reduced motion. [City during construction](evidence/phase2-village-seed23.png) · [Second village](evidence/phase2-village-reduced-seed91.png) · [Opening board](evidence/phase2-opening-reduced.png) · [Halo board](evidence/phase2-halo-fog-reduced.png)

The **Sudoku** tab is available on first launch. The automatic puzzle download setting starts off. Download before going offline. A playable package opens in Sodukromental. Puzzle details keep separate links to the setter and a verified CtC video. The Library retains supported art, rules and solve state locally. Packages that use an unsupported dynamic effect or overlapping grids show their support status and available reference. Manual completion is distinguished from an answer-verified solve.

The regression suite includes an actual four-archive playthrough in accelerated game time, a failed prestige write followed by a retry, migration of earlier saves, acquisition and cold offline editing of real setter packages, and the font geometry used by rain. The Android integration test covers the opening, cell-first inventory, an ecology hatch and a covered Library guess that survives closing and reopening the on-device database. [Four-archive journey](../test/phase2_four_archives_test.dart) · [Archive write recovery](../test/colony_archive_test.dart) · [Downloaded puzzle tests](../test/library_downloaded_integration_test.dart) · [Android device journey](../integration_test/debug_smoke_test.dart)

**Feedback priorities.** Record build number, device and Android version, board or puzzle title, actions and result. For balance feedback, record active solve time separately from time away or spent watching the colony. Physical tilt, TalkBack, recognition of a new rule, the effect of adding a worker and the time to a first voluntary prestige need human playtesting. [Expansion specification and acceptance scenarios](phase-2-expansion.md)
