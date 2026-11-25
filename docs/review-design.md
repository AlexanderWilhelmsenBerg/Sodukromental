# Debug release design review

The board follows the Hum palette, with outlined regions, monospaced digits, tactile tile controls, and a habitat that yields to the grid on small windows. The opening makes the digits in the sentence actionable before revealing DNA, the amoeba, production, and settlement controls. This review records interaction evidence and follow-up questions for the debug preview. Build, source, and handset acceptance belong to their owning work packages.

## Design evidence

- `test/colony_screen_test.dart` exercises the opening at 320, 375, 414, and 768 dp with 1.6× text. It checks square 48 dp targets for all three sentence tokens and the anchored-cell semantic label. It performs the authored slides, drags one sentence token, taps the other two, hatches the amoeba, reloads the pending delivery, claims its digit, and expands to 5×5.
- `test/assurance_board_input_test.dart` exercises the shared board's semantics, touch, drag, and arrow-key cursor placement. The campaign's **Select square** action supplies full-size row and column controls from 7×7 onward. Reduced motion uses immediate board changes and stationary reaction sprites.
- The tilt filter test injects readings for all four directions and checks the dead zone and stability threshold. Handset orientation and screen reader speech remain device checks.

## Slice findings

| Slice | Interaction review and debug feedback |
| --- | --- |
| F1 | The native app can present the same Flutter board at phone and wide sizes. Record the first emulator and device launches separately. |
| F2 | The opening restores token identity and a pending 4 delivery from the saved run. Retest after installing over an older preview. |
| F3 | Ensure the preview job runs widget tests and captures emulator launch evidence. Track download and installation outcomes as separate events. |
| P1 | All three source tokens stay selectable by tap or keyboard focus and leave outlines at their original positions. Ask a new player to find the tokens and explain why the amoeba is needed before adding another cue. |
| P2 | The first 5×5 presents one highlighted irregular region and opens digit requests beside the tray. Check that players can explain the thick outline and make the second request without prompting. |
| P3 | Digit production shows each installed rank and rate, and exposes prices in the purchase control. Verify players can find it both from the board and in Colony jobs. |
| P4 | The habitat offers a direct claim path and the jobs sheet groups creature design with construction. Gatherable glyphs have text and list controls. Playtest whether the relationship between the harvested letter and the assembled nest reads at phone size. |
| P5 | The same shared board accepts drag, select and tap, and physical keyboard actions. Run a fresh standalone Library solve and reopen the campaign during a delivery. |
| C1 | New board sizes use the same board affordances and keep the stock count in the tile. Stress-test long sessions and scroll position across size changes. |
| C2 | The habitat shows the active worker, cargo, reaction, and reclaim action. Colony jobs exposes assignment and restocking. Watch for visual congestion when a group reacts during a delivery on a narrow phone. |
| C3 | The campaign opens the creature designer after 5×5 and the profile from the worker list. Compare unlocked and gated branch readability, preview composition, and price visibility at 320 dp. |
| C4 | Renban has a brief worm animation driven by the authored path. Rules open persistent explanations, and on-screen controls cover all four gravity directions. Compare markings and stacked clues at 320 dp and with simulated color vision differences. |
| C5 | Fog hides digits, candidates, and marks whose clue cells are hidden. Torch arrivals can animate a reveal highlight. Check whether players notice where a torch landed when focusing on the tray. |
| C6 | Shared lessons, route stages, fog extras, and expeditions appear in the Campaign map as they unlock. The Rule Almanac shows learned rules, fog types, mastery markers, and completed expeditions. Capture the full route choice and ending in the independent acceptance run. |
| C7 | Prestige previews the payout, charter, companion, next opening, and selected upgrade balance. Test budget behavior late in a second run and verify that an explicit empty companion choice is respected. |
| L1 | Verify title, author, and original-rule text for multilingual catalog listings, including an entry with partial metadata. Measure discovery when the live source is unavailable. |
| L2 | Verify that Any/All and sort controls stay understandable while scrolling and while the filter returns zero results. Include a filter match derived from written rules. |
| L3 | Validate how playable, diagram, source-only, and pending downloads are announced. Exercise pause, failure, and restoration with airplane mode. |
| L4 | Verify both named CtC video fixtures, badge navigation, and the different-grid message before recording acceptance. |
| L5 | Use a bundled variant offline and return from a Colony challenge. Check that the two saved solves retain distinct progress, and puzzle access remains available before hatching. |
| D1 | Check profile and companion controls with a retained amoeba and a designed creature. Confirm that clearing a companion choice, recalling a visitor, and deleting learned phrases have understandable feedback. |
| D2 | The filtered accelerometer and direction buttons share the settling command. Verify left/right signs, inverted orientation, and interaction during a real drag on a handset. |
| D3 | The overlay requires physical verification across permission grant, refusal, revocation, lock, and stop. Ask a tester to find **Call back** while the companion is visiting another app. |
| D4 | The opening layout and token targets pass four viewport widths at enlarged text. The shared board has keyboard focus and the dense board has a linear selector. Capture settings, Library, creator, and cargo poses with system text scaling and TalkBack on physical hardware. |
| D5 | Touch and keyboard provide platform-independent input. Verify window resizing, hardware keyboard, and in-app companion visits on future desktop and iOS builds. |
| R1 | Run independent acceptance with exact candidate bytes and issue reports keyed to the owning slices. Include the opening, one full ending, and representative late-game interactions. |
| R2 | APK and checksum acceptance should include the exact install and launch test, as well as manual navigation into both top-level destinations. |
| R3 | Ask testers to include device, text scale, reduced-motion preference, board name, and the last input when reporting a UI defect. Link each finding to the regression scenario above. |

## Stable-release follow-on

| Slice | Design evidence to collect |
| --- | --- |
| S1 | Observe physical tilt, overlay controls, first-time token discovery, and the time players spend waiting for deliveries. Use the same screen-size coverage when fixing findings. |
| S2 | Check that a signed update preserves progress and settings across a real install and presents the same download fingerprint as the release handoff. |
| S3 | Run the live update banner and Settings entry through current, newer, incompatible, and unavailable server states on the distributed Android build. |

## Screen captures

The debug handoff packages the original PNGs in `campaign-design/`. The `boards-contact-sheet.png`, `colony-contact-sheet.png`, and `library-and-settings-contact-sheet.png` index the captures at 320, 375, 414, and 768 dp. The boards sheet covers the opening, Renban, a Sandwich edge clue, and the dark starting state for Halo. The colony sheet covers the creator, the creature profile, settlement management, and sprite poses. Library and Settings use the fixture app shell.
