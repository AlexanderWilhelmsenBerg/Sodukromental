# Independent Android debug review

Use this review with the [slice register](debug-release-slices.md) and [release plan](release-plan.md). The 28 required work packages are listed below, followed by the three stable-release work packages. The review records executed checks, findings and retests. The slice register records delivery status.

The starting checkout contained the game specifications and design. `git rev-parse --verify HEAD` reported that there was no revision. Review of the candidate must identify the tested revision or snapshot and tie it to the delivered APK. A domain test, widget smoke test, emulator run and physical-device observation each establish different results. The review records the environment and command or action for each result.

| Slice | Independent check | Result and evidence |
| --- | --- | --- |
| F1 | Start Flutter and Flame from the pinned toolchain. Record lockfile, clean checkout and available Android build and test environments. | Pending candidate and toolchain. |
| F2 | Round-trip versioned boards, commands and stable tile IDs. Migrate an earlier save and confirm that both modes and pending work survive. | Pending implementation. |
| F3 | Inspect the Debug default and run the lockfile-based format, analysis and regressions. Verify the workflow actually builds, uploads, installs and launches its APK. | Pending workflow and runner. |
| P1 | Check the three anchors, reject an early drop, perform the four slides, use three inline tokens for 3 DNA, spend it on the amoeba and resume its delivery. | Pending campaign entry point. |
| P2 | Check that nine old tile IDs remain in cells, seven move to the tray, four old digits are supplied and all five new digits are fetched. Validate connected regions, unique completion and interrupted progress. | Pending campaign entry point. |
| P3 | Reopen after each first clear and each producer purchase. Check starter affordability, tick intervals, exactly-once credits and the offline cap. | Pending colony entry point. |
| P4 | Compare the body preview and opening work perks. Complete a favorite offer and nest letter delivery, including an interrupted job and identity reload. | Pending creator entry point. |
| P5 | On a fresh offline profile, enter Sudoku first and finish a bundled variant. Then exercise both game modes and restart to verify separate saves. | Pending integrated UI. |
| C1 | Check every growth size through 9×9 for connected regions where required, unique completion and old tile ID conservation while the newest digit is missing. | Pending board pack and campaign entry point. |
| C2 | Exercise work assignment changes, stock, priority, favorite grouping, offer expiry, theft return, one-time salvage and the later building projects. Check tile IDs and materials before and after each operation. | Pending colony entry point. |
| C3 | Cover each of the 54 growth choices, including the joined branches and starter recipes. Check milestone-gated perks and reload of the resolved identity. | Pending creator and colony entry points. |
| C4 | Check the six variant lessons, worm-removal counts, and stable IDs across four gravity directions. Confirm fixed tiles stay fixed. | Pending board pack and engine entry point. |
| C5 | Walk the visible-only Halo, Trail and Linked Torches routes with the amoeba. Check missing hidden clues, delivery and replay of each reveal. | Pending fog and colony entry points. |
| C6 | Check all 28 authored boards, nine route boards and four expeditions. Check the paired constraints on each finale, progress across route switches, and a 16-board ending with the original amoeba and its Meeting Hall. | Pending full campaign. |
| C7 | Preview and retry prestige, confirm one credit per first achievement, reload the archive, and start both openings. Exercise all charters and settlement policies. | Pending prestige entry point. |
| L1 | Traverse the approved full listing through its final page. Check portal IDs, committed cursor, overlap, locale fallback, representative details and the separate payload host. | Pending application import and source coverage. |
| L2 | Search *Whispers of the Zeitgeist* for a rule absent from its tags. Check Any and All, the requested sorting, uncertain exclusions and original text. | Pending Library entry point. |
| L3 | Download each supported format and fallback, interrupt a revision update and recover the last good copy. Check off-by-default, manual/automatic deduplication, pause and restart. | Pending download entry point. |
| L4 | Check `000KPF` and `000DQ2` for official video identity, newest-first sorting, the different-grid note and offline metadata. | Pending Library entry point. |
| L5 | Count standalone campaign boards and check rules. After 5×5, open the same downloaded puzzle in both modes, resume offline independently, preserve its pinned revision and pay the challenge reward once. | Pending full campaign and offline Library. |
| D1 | Retain and reload a named companion and original amoeba. Check One Helper, shared-clear deduplication, taught phrases, deletion and in-app visits. | Pending companion entry point. |
| D2 | Inject four tilt directions, check upside down while the surface remains portrait, and compare the on-screen fallback. Check on a phone when available. | Pending Android adapter and test device. |
| D3 | Check app consent, Android grant and refusal, revocation, lock and stop. Observe home and ordinary app behavior, touch bounds and the separate phrase permission. | Pending Android adapter and test device. |
| D4 | Capture the campaign, Library, creator, colony, companion and Settings at 320, 375, 414 and 768 dp. Check large text, rules, focus, tap and keyboard placement, reduced motion and sprite poses. | Pending integrated UI. |
| D5 | Exercise input, in-app visits and motion fallback through shared interfaces. Record Windows, Linux and iOS simulator builds where runners are available. | Pending shared entry points and runner inventory. |
| R1 | Re-run the early and late flows, authored boards, saves, upgrade, offline, permission and update fixtures on the candidate. Record field checks. | Pending integrated candidate. |
| R2 | Check package, version, signature, hash and launch against the built bytes. Record the APK path, install evidence and any authorized publication. | Pending APK and test device. |
| R3 | Verify APK access, tester steps, known limits and report-to-retest routing. | [Tester guide](debug-handoff.md) drafted. Candidate details and delivery pending. |
| S1 | Triage field reports and rerun accepted blockers and physical device scenarios. | Stable follow-on. |
| S2 | Verify production signer continuity, upgrade, published checksum and manifest on an authorized stable release. | Stable follow-on. |
| S3 | Check the deployed stable release response and an in-app compatible-update notice. | Stable follow-on. |

## Findings and retests

Record the slice, observed behavior, reproduction, owner response and independent retest evidence. For a spec review, identify the resulting change and leave the runtime result pending until exercised.
