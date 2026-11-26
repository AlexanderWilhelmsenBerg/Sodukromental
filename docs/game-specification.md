# Sodukromental game specification

The [Phase 2 expansion](phase-2-expansion.md) specifies the next debug iteration, including the new number pad, breaking the 9×9 grid and owned torch crews.

Draft for design discussion

Sodukromental is an offline-first game that ships on Android first, with iOS, Windows, and Linux as later targets. **Library** lets players find and solve variant Sudoku by rule. **Incremental** begins with a sliding Sudoku and grows the board from 4×4 through 9×9. A colony of pixel creatures gathers the new digits. After the first 9×9 clear, variants arrive as events on the board. A worm draws a Renban line and eats digits, and torchbearers reveal puzzles hidden in fog.

- [Logic Masters Deutschland library specification](library-specification.md) covers catalog access, rule matching, optional automatic offline downloads, Cracking the Cryptic features, and acceptance checks.
- [Incremental campaign specification](incremental-campaign-specification.md) covers encounter order, automation, finale routes, expeditions, and prestige.
- [Creature creator specification](creature-creator-specification.md) covers branching growth choices, work perks, hatch prices, and procedural generation.
- [Companion specification](companion-specification.md) covers keeping a creature through prestige, learning, speech, and Android home screen visits.
- [Android delivery specification](android-delivery-specification.md) covers regression CI, debug and release APKs, GitHub publishing, and in-app update checks.
- [Android debug release plan](release-plan.md) covers the five delivery phases and agent assignments.
- [Debug release slice register](debug-release-slices.md) tracks specification coverage, acceptance evidence, and follow-on work.
- [Visual design](../design.md) covers the Hallmark visual direction, interaction, and layout.

## The first run

| Step | Player action | Result |
| --- | --- | --- |
| 1. Slide | Rearrange digits 1–3 around three anchored clues on a 4×4 board. | Four gaps become valid places for a 4. |
| 2. Drag | Take the three 4s from the sentence above the board and place them in three gaps. | Each placed 4 earns 1 DNA. One gap remains. |
| 3. Create an amoeba | Spend the 3 DNA in the Creatures menu. | The run’s first organism sets off to find the fourth 4. |
| 4. Grow | Place the 4 that the amoeba brings back, then solve the expanding boards in order. | Each size brings forward the digit tiles and adds a new digit for helpers to find. |
| 5. Design and expand | Choose creature features, meet helpers with randomly assigned favorites, and send builders to gather letters. | Upgraded grid digits produce DNA and RNA, and builders turn letters into homes. Puzzle milestones open village, city, and civilization projects. |
| 6. Discover variants | Clear the first 9×9 and follow the worm onto the next board. | Renban and gravity open the first variant encounter. Further clears introduce fog and other rules. |

The pacing takes inspiration from Evolve’s progression from small manual actions to managing a growing system. Here, Sudoku gives each expansion a concrete purpose. [Evolve](https://github.com/pmotschmann/Evolve#about)

## Sliding Sudoku

The opening 4×4 board has 2×2 boxes, twelve tiles showing digits 1–3, and four empty cells. All four copies of the digit 4 are missing. Three digits are anchored and carry a visible lock mark. Drag an unanchored tile into an orthogonally adjacent gap, or tap the tile and then the gap. During rearrangement, duplicate digits can appear in a row, column, or box. The player can undo slides or restart this part of the puzzle.

Place this prompt above the board.

> In this 4×4 puzzle, the 4 is missing. Can you find someone to help you?

The prompt contains exactly three digit 4 glyphs. All three are draggable tokens, including the two in `4×4`. A player can also select a token and tap its destination. When used, the token leaves an outline in the sentence so the remaining tokens stay in place.

Accept the first token when filling every gap with a 4 would make the board a valid Sudoku. Until then, offer feedback to keep sliding and return the token to the prompt. Every reachable valid arrangement qualifies. The first accepted drop fixes the arrangement of the 1–3 tiles, and the player can fill the remaining gaps in any order. For each accepted drop, save the token’s placement and its **+1 DNA** together so reopening the game cannot repeat the award.

At 3 DNA, **Create amoeba** becomes available in the Creatures menu. The action spends the 3 DNA and creates the run’s first creature, or calls back the retained amoeba after prestige. The amoeba crawls out, finds the fourth 4, and holds it up. It sets the 4 in the tray if the player leaves it unclaimed. The player places it in the remaining gap to clear the board and earn RNA. Record the arrival and delivery so a restart resumes the same amoeba and task.

### Verified opening board

An asterisk marks an anchor. A dot marks an empty cell.

```text
 1* · │ 3  ·
 ·  2 │ 1* 2
──────┼──────
 2  3 │ 1  3
 ·  3*│ 2  1
```

One shortest route slides `R2C2 → R1C2`, `R3C2 → R2C2`, `R3C3 → R3C2`, and `R2C2 → R2C1`. The four valid places for a 4 are now `R1C4`, `R2C2`, `R3C3`, and `R4C1`. A shortest-path search across the six goal arrangements for these anchors found that four slides are required.

### Generating later slide boards

1. Start with a complete grid, choose a digit to withhold, and take out every copy of that digit. Choose the anchored cells from the remaining tiles.
2. Scramble by sliding tiles into adjacent gaps while preserving the anchors. Reversing the moves proves that the start can reach a board completable with the withheld digit.
3. Search against every valid goal for the 4×4 board and check the shortest solve. Use the shortest path length to reject already-solved or off-target scrambles. A random walk can double back and make a long scramble easy.
4. Use the verified opening board as the tutorial. In later slide challenges, requests for the missing digits go to the player’s existing creatures.

## Growing the board from 4×4 to 9×9

After the tutorial, the campaign advances through **5×5 → 6×6 → 7×7 → 8×8 → 9×9**. Each size uses digits 1 through its width once per row, column, and region. The 5×5 and 7×7 use outlined, orthogonally connected irregular regions with five or seven cells apiece. The 6×6 uses 2×3 boxes, the 8×8 uses 2×4 boxes, and the 9×9 uses 3×3 boxes. A first appearance of an irregular board highlights one full region so the player can see how the boundary works.

When a board grows from size N to N+1, animate an extra row and column into view. Carry forward every tile from the completed board. Keep tiles in their cells wherever they match the next board’s authored clues. The others gather in the tray, and suitable tiles from that tray can fill any additional authored clues. An intact solved N×N corner would force N copies of the new digit into the same column, so some tiles need to move for the larger board to work.

The larger board needs one additional copy of every old digit. Existing collection stations supply those copies immediately. All N+1 copies of the new digit start missing, and the player sends helpers to find them. The amoeba can do that on its own on 5×5. Later specialists can bring larger batches or take parallel requests. The player drags each tile from the tray into place. A selected tile and tapped cell provide the same action.

On the first 5×5, the player starts with carried clues and a tray of old digits. The amoeba finds the first 5 while the player works through the visible clues. The previous board’s completed state stays available in the run record. Clearing 5×5 opens the creature designer as the campaign moves into 6×6.

Use authored, uniquely solvable boards for the first campaign. For each size, verify the region layout, the solution, the starting clues with every new digit withheld, and the tile inventory after growth. Include some blanks for old digits so the larger board still calls for deduction. A feasibility check produced a uniquely solvable example at each size from 5×5 to 9×9, including connected irregular regions at 5×5 and 7×7. These examples establish that the transition works and leave clue difficulty open for playtesting.

### Verified 5×5 expansion

The left side shows the clues. On the right, each letter identifies one five-cell region.

```text
1 2 3 4 ·    A A A A B
3 4 · · ·    C C A B B
· 1 · 3 ·    C C C B B
· 3 · · ·    E E D D D
· · · · ·    E E E D D
```

Following the documented 4×4 solve, nine old tiles stay in their cells and seven move to the tray. The stations give the tray one additional 1, 2, 3, and 4. That leaves eleven old tiles ready to place and five 5s for the amoeba to find.

## Creature jobs and favorite numbers

The player may pencil candidates at any time. Placing a digit uses one copy from the tray or a creature’s offer. Removing or undoing a placement returns that copy. A request names the digit and number of copies wanted. A creature runs to the station, takes as many requested copies as it can carry, and comes back with a digit held overhead. The player can drag that digit straight onto the board or tap it and then tap a cell. Begin playtesting with a four-second offer window. Pause the countdown while the player has selected the offered digit. When the window expires, unclaimed tiles go to the shared tray.

Each creature has a favorite number. The starter amoeba always favors 4 and can fetch any unlocked digit, one at a time. Give each later creature an equally likely random favorite from the digits unlocked when it hatches. Draw it from the individual seed at creation, reveal it when the creature hatches, and save it with that creature. Several creatures can share a favorite. When two ordinary requests have the same priority, a free creature takes a matching favorite first. Otherwise it takes the oldest available request. The player’s explicit priorities and required torch deliveries take precedence.

When idle, a creature can lift one of its favorite digits from the visible tray and hold it up as an offer. Show the same tile ID as reserved in the tray, with a control to take it from either view. Claiming it from either view dismisses the other. Return an unclaimed tile after the offer window or when an urgent job starts. An idle offer comes from stock the player already owns. A creature with an empty tray can show a small favorite-number emblem while it waits. The creature’s offer gives the player a digit to consider, and the player decides which cell to use.

Allow workers to take digit, torch, or building assignments. A worker finishes its current delivery or returns the reserved material before changing jobs. A vacancy in a specialist role uses the amoeba or another available worker for a basic trip. This leaves all required numbers and torch reveals reachable with any valid race design.

### Personalities and mischief

Give each generated creature a seeded personality independent of its favorite number and work features. Save it with the creature and show it on the creature’s profile. The amoeba’s first trip follows the scripted tutorial. When a favorite digit appears in the tray or in a visible board cell, nearby idle creatures that favor it can flock around it and cheer. Gather around the edge of the cell or tray so the digit stays readable and easy to drag. Priority work takes precedence.

In ordinary placement phases, creatures can react to a conflict the player can see. For example, a newly placed 7 next to a fixed 7 in the same row is a clear target. If two tentative digits conflict, creatures can look puzzled at the pair. Moving or breaking a tile requires a visible rule conflict that identifies the affected tile against fixed clues. In fog, the rejected tile goes straight back to the tray and creatures can react to it there. Keep the opening slide tutorial and its DNA tokens on their scripted path.

| Personality | Reaction |
| --- | --- |
| **Curious** | Runs up, tilts its head, peers at the digit from the other side, and leaves a little question mark. |
| **Collector** | Carries the conflicting digit to its nest, a village shelf, or the city storehouse and proudly displays it. Tap **Bring back** to reclaim the same tile. It also returns to the tray after two seconds as a starter timing value. |
| **Tinkerer** | Taps the conflicting tile until it breaks into a building fragment. Supply a replacement of the same value immediately, including when the tray is at its automatic restock limit. One fragment can substitute for one support in a building recipe. Earn at most one fragment per encounter per run. After that, the creature can tap the tile and look disappointed. |

Offer **Full antics**, **Reactions only**, and **Off** in settings. Full antics become available after 5×5 and include moving and breaking tiles. Use that setting by default after the unlock and honor any preference already set. Reactions only keeps flocking and expressive poses, with tiles left where the player put them. Off keeps normal work and digit offers. All settings preserve the same deductions and required supplies.

Let one idle worker claim each incident. Recheck its target before committing the action. An undo, a new placement, or a switch to a different board can cancel a pending reaction. A completed theft records the single tile in a temporary stash. A completed break swaps the broken tile for its replacement and credits its fragment in the same save. Resume or undo reconciles the recorded tile location so each digit and fragment is counted once.

## DNA and RNA economy

| Resource | Earned from | Spent on |
| --- | --- | --- |
| Digits | Carried tiles and creature deliveries. | Filling cells in the active board. |
| RNA | First puzzle clears and upgraded digits that produce RNA. | Growing creatures, upgrading production, and improving equipment. |
| DNA | The three tutorial drops, milestone clears, and upgraded digits that produce DNA. | Creating the amoeba, designing later creatures, and unlocking features. |
| Building materials | Creatures harvest marked letters and symbols from encounter descriptions. Tinkerers can salvage an occasional fragment. | Nests, houses, and workshops. A fragment can substitute for a support. |

### Puzzle rewards and grid upgrades

Use these amounts as the first playtest budget. Each placement or clear pays once per run, with a stable reward ID so retry and resume preserve the same balance.

| Milestone | DNA | RNA | Opens |
| --- | ---: | ---: | --- |
| Three tutorial drops | 1 each | 0 | Create amoeba for 3 DNA. |
| 4×4 clear | 0 | 6 | One production slot and the RNA upgrade. |
| 5×5 clear | 5 | 12 | The creature designer, a second production slot, and the DNA upgrade. |
| 6×6 through 9×9 first clears | Board size | Twice the board size plus 4 | More collection, construction, and feature choices. |
| First clear of a variant encounter | 3 | 10 | The encounter’s next rule or related feature. |
| First clear of a variant route finale | 8 | 20 | Complete the campaign once the Meeting Hall is built. |

Open **Upgrade digit** from a fixed clue or a numeral on a completed grid. For example, upgrade a visible 4 and a small marker shows that **4 produces RNA**. Store the upgrade on the digit’s value for the run, so it carries from one board to the next. Show the marker on one eligible copy and the production rate in the colony menu. If the digit is missing or hidden on the current board, show its production on a tile in the habitat until a visible copy is available. Each active value produces once per interval, regardless of how many copies appear. Placement, erasing, and undoing leave the production clock intact.

| Upgrade | Cost for rank 1 | Rank 1 output |
| --- | --- | --- |
| RNA producer | 4 RNA | 1 RNA every 10 seconds. |
| DNA producer | 1 DNA and 6 RNA | 1 DNA every 40 seconds. |

Use one producer per selected digit value. For playtesting, rank 2 unlocks at the village and rank 3 at the city. Buying target rank R costs R times the rank-1 price and produces R units per interval. Credit production from elapsed time on resume, with a starter cap of two productive minutes per absence. Save the last credited time and partial interval so reopening the app cannot collect the same payout twice. The starter budget supports the first designed creature and both rank-1 producers from the opening rewards. Collection and torch carrying remain available through basic worker jobs throughout the campaign.

### Creatures menu

Show resource totals, current workers and favorite digits, build costs, and the requirements for upcoming actions. Start with **Create amoeba · 3 DNA**, or **Call amoeba** when the player retained it through prestige. After creation, show its assignment in the same spot. The first clear of 5×5 unlocks **Design creature**. The player presses choices along growth paths, then confirms a hatch that saves the procedural individual and debits the quoted cost together. [Evolve evolution menu and resources](https://github.com/pmotschmann/Evolve/wiki/Evolution)

Each additional creature increases the price of the next. The proposed base price for the Kth designed creature, starting at K = 1, is `ceil(4 × 1.45^(K−1)) DNA` and `ceil(8 × 1.45^(K−1)) RNA`. Count completed creations in the run. The first three base prices are 4 DNA and 8 RNA, then 6 DNA and 12 RNA, then 9 DNA and 17 RNA. The base price covers the available starter features. Show any price for advanced features before confirmation. The opening shelter houses the amoeba and one designed creature. More housing opens additional slots.

### Letters as building materials

After 5×5, add an optional flavor sentence below the puzzle prompt. Mark harvestable letters in it and let the player assign a builder to collect them. A tiny creature can pull the **A** from “A nest is a home.” and carry it across the screen as a roof frame. The **t** and **i** can become supports and the **o** a ring for the nest. A readable imprint stays in the sentence when the piece leaves. Keep the original sentence available to the screen reader, and allow tap selection as an alternative to dragging.

Record each harvestable character as a distinct piece with an authored role, such as roof, support, ring, or beam. It moves from the sentence to a worker and then to the build site. The first nest uses one roof, two supports, and one ring and adds one housing slot. Houses and workshops use larger sets. The finished structure should still show the letter shapes that went into it. Put these structures beside or below the puzzle so the colony can grow without covering the board.

Reserve a piece when it is assigned and credit it once when delivered. Cancelled trips return a piece to its source, and resuming a trip keeps its original reservation. Puzzle rules stay readable in their own text. The tutorial’s three draggable 4s remain placement tokens. Use authored material roles and whole displayed characters for each translation so a nest can be built with different letters in different languages. If the current text runs out, a settlement notice provides the roles the selected project still needs after counting stored and in-flight pieces.

### From creatures to civilization

New stages open through puzzle milestones. Each stage adds a decision about how to use the growing population.

| Stage | Player decision | Effect on puzzles |
| --- | --- | --- |
| Creatures | Pick movement and collection features when growing a creature. | Specialists can deliver priority digits quickly or bring more copies in a trip. |
| Village | Gather letters for houses and choose a first shared building. | Open housing slots, hold more digit stock, or increase production ranks. |
| City | Choose which districts to develop, such as a workshop or a school. | Improve collection throughput, increase production ranks, or unlock targeted rule help. |
| Civilization | Choose a shared policy for several cities, such as pooling reserves or sharing puzzle expertise. | Move resources between cities or apply their abilities to harder puzzle sets. |

The first playable milestone covers the amoeba, the 5×5 expansion, one designed creature, and a nest. The campaign opens the village after 6×6, the city after 8×8, and the civilization after Arrows. Clearing a finale route and finishing the Meeting Hall opens prestige and expeditions. [Campaign and endgame](incremental-campaign-specification.md)

For the playtest, time the amoeba’s first trip and compare the two starter features on the same sequence of collection requests. Balance by how often players finish a deduction and have nothing productive to do while waiting. On larger boards, deciding which digits to collect next should matter more than making repeated collection taps.

For each action, save its changes to the board, inventory, pending trips, and rewards in one transaction. Each trip pays out once, each milestone clear pays out once, and refunds return the digit even if the tray reaches its automated collection cap. On resume, settle completed pending trips up to the available storage and show what arrived.

## Procedural pixel creatures

Press growth choices for locomotion, shape, coat, and other anatomy. Joined paths can add details such as translucent paws or a tail with feet. The selected nodes define the visible changes. Hatching uses separate seeded draws for appendages, markings, coloration, favorite number, and personality. Save the resolved art, attachment points, selected work perks, and individual identity. [Growth paths and pricing](creature-creator-specification.md)

Give each newly created amoeba a seeded outline, markings, and coloration. Its simple crawl and favorite 4 teach the opening. Store a visible signature for each newly generated founder and check distinct appearances across fresh seeds. A retained amoeba keeps its existing identity and appearance.

One favorite creature can travel through prestige. It remembers shared work and phrases the player submits in **Talk to creature**. A returning companion can visit other app screens and can request permission for an Android home screen outing. [Companion behavior and Android access](companion-specification.md)

### Walking and running animations

Build each moving appendage as its own pixel layer with an attachment point and pose frames. Give walking bodies a walk cycle and a run cycle for each supported leg count. Two legs alternate. Four legs can step in staggered phases and run in pairs. Six legs can walk in a ripple and run with two alternating groups of three. Advance the cycle with travel distance so feet stay planted during the contact frames. Arms swing, tails counterbalance, and feelers bob in both gaits. Floating bodies use drift and dash, and the starter amoeba squashes and stretches as it crawls.

The carrying pose takes over the appendage holding a digit or construction letter while the other appendages keep moving. Keep the item attached through pickup, travel, the overhead offer, and delivery. Use whole-pixel scaling and keep the silhouette clear at gameplay size. Add short poses for cheering, inspecting, sneaking with a digit, and tapping it apart. A reduced-motion setting can show task changes, offers, and reactions with simple poses and status icons.

## Variants after 9×9

Clearing the first 9×9 opens a campaign of authored 9×9 encounters. Introduce each new rule on its own before combining it with others. The opening animation shows where the rule applies. After it ends, a persistent rule chip explains the constraint and highlights the affected cells when tapped.

### Renban worm and gravity

A pixel worm crawls across the next board. Its trail remains as a Renban line. Digits on that line form a consecutive set without repeats, in any order. A four-cell line could contain `6, 4, 7, 5`. Pattern the trail so it stays recognizable when color is unavailable.

The worm eats a known set of loose digit tiles on its route. The other loose tiles spill off the board and collect along the low edge, and the eaten copies become collection jobs for the helpers. Retain the encounter’s authored clues as anchors. Choose which tiles the worm eats and which clues remain when authoring the puzzle. Save the encounter’s anchors, removed tiles, and collection jobs together so resuming or skipping the animation leads to the same solvable state.

Gravity moves loose tiles in the collection area and leaves the Sudoku’s givens, markings, pencil notes, and placed digits fixed. Group copies of each digit into selectable stacks with visible counts when the edge fills up. A tile counts toward the solution when the player drags it to a cell and drops it. Pause settling during a drag and resume when it ends.

Treat the phone’s four edges as the gravity directions. Holding it normally sends digits toward the bottom of the portrait layout. Turning it sideways sends them left or right. Turning it upside down sends them toward the layout’s top edge. Keep the board and interface in one portrait coordinate frame throughout the rotation. Request upright portrait on supported phones through Flutter. A portrait-shaped play surface also fits inside a resized Android or desktop window. [Flutter orientation API](https://api.flutter.dev/flutter/services/SystemChrome/setPreferredOrientations.html)

Read mobile accelerometer samples through `sensors_plus` and use a low-pass filter to estimate the in-plane gravity vector. The mobile adapter maps a steady direction to one edge of the portrait play surface. A dead zone holds the last direction when the device is nearly flat, and a stable-direction threshold prevents bouncing between edges. Four on-screen arrows and desktop key bindings issue the same direction commands. Each direction settles the same set of tiles in a predictable order. [sensors_plus](https://pub.dev/packages/sensors_plus)

### Fog of war and torchbearers

A fog board starts fully dark. The colony receives one starter torch, and a creature carries it to the encounter’s starting patch. The patch illuminates the first clue and enough surrounding information for at least one deducible placement. The amoeba can carry the first torch with its basic abilities.

The player drags a digit into a visible cell. A correct placement becomes fixed and can earn a torch for the reveal specified by that board. A wrong digit returns to the tray and leaves the fog unchanged. Each newly satisfied reveal condition grants one torch and one delivery task. When a torchbearer arrives, the target cells light up and stay visible. Save the revealed cells, earned triggers, and pending trips so pausing or reopening preserves the reveal sequence.

| Fog rule | What a correct placement can light |
| --- | --- |
| **Halo** | The orthogonally adjacent cells. A placement at R3C4 can light R2C4, R4C4, R3C3, and R3C5. |
| **Trail** | The next marked patch on an authored path. A path marker shows where the creature heads. |
| **Linked torches** | An authored patch elsewhere on the board. Some links light when one marked cell is correct, and later links can require several marked cells. |

Test a logical solve route using only information visible at each step. Each target patch must advance the solve, and every required cell and clue must become available without guessing or paid upgrades. Torch jobs earned by solving stay separate from the digit request queue so a full queue cannot block the next reveal.

### Building the rule roster

Add rules in short chapters. Give each rule a clue animation, a durable symbol, and one tutorial puzzle where using the new rule makes a deduction possible. Once learned, bring rules back in authored combinations.

| Rule | How it appears | Sudoku constraint |
| --- | --- | --- |
| **Renban** | A worm leaves a patterned trail. | Line digits form a consecutive set with no repeats, in any order. |
| **Fog of war** | Torchbearers light patches as the player solves. | The puzzle’s reveal rule controls which cells and clues become visible. |
| **Thermometer** | A creature warms a bulb and fills the tube cell by cell. | Digits strictly increase from bulb to tip. |
| **Kropki** | Beetles leave white and black dots between cells. | White dots mark a difference of one. Black dots mark a 2:1 ratio. An all-dots-given condition is stated separately when present. |
| **German Whispers** | A creature strings a ridged line between cells. | Adjacent digits on the line differ by at least five. |
| **Killer cages** | Builders draw dashed pen boundaries and hang sum signs. | Digits in a cage sum to its total without repeats. |
| **Arrows** | A courier paints an arrow and circles its starting cell. | The arrow’s cells add up to the digit in the circle. |

The finale routes introduce Palindrome and Region Sum Lines, Sandwich and X-Sums, or Diagonal and Anti-Knight. Optional fog lessons and later expeditions combine visibility with other clues. Every solve path must expose the clue information needed to justify each deduction. Store rule geometry, validation, visibility triggers, and animation cues in the puzzle definition so each encounter can be checked before release. [Finale routes and expeditions](incremental-campaign-specification.md)

## Variant Sudoku library

Open the [Library specification](library-specification.md) for the full Logic Masters Deutschland Sudoku catalog and standalone editions of every authored Sodukromental board. The Library is available from first launch and will be offered to Logic Masters Deutschland free of charge. Automatic downloads from the separate puzzle host have confirmed permission and default to off. Verified Cracking the Cryptic features have a **Featured on CtC** badge and sort, with a link to the individual solve. Compatible downloads can also open as optional **Play with Colony** challenges. Save ordinary Library solves and colony challenges independently.

## Framework and platform plan

Use **Dart with Flutter and Flame** in one project. Flutter handles the Library, rule text, creature designer, menus, and accessible board controls. Flame runs inside Flutter through `GameWidget` and handles pixel-art sprites, articulated appendages, carried items, fog, the worm, and falling-tile effects. Both support Android, iOS, Windows, and Linux. [Flutter supported platforms](https://docs.flutter.dev/reference/supported-platforms) · [Flame supported platforms](https://docs.flame-engine.org/latest/flame/platforms.html) · [Flame GameWidget](https://docs.flame-engine.org/latest/flame/game_widget.html)

| Dependency | Use | Add when |
| --- | --- | --- |
| Flutter SDK and Dart | Shared widgets, drag and tap input, keyboard shortcuts, semantics, and platform builds. | Android scaffold. |
| `flame` | Sprite sheets, layered appendages, animation, and visual effects. | Android scaffold. [Flame sprite components](https://docs.flame-engine.org/latest/flame/components/sprite_components.html) |
| `drift` and `drift_flutter` | Local SQLite for saves, resource transactions, the downloaded catalog, rule filters, and schema migrations. Use `drift_dev` and `build_runner` for generated database code. | First persistent save. [Native Drift](https://drift.simonbinder.eu/platforms/vm/) · [drift_flutter](https://pub.dev/packages/drift_flutter) |
| `sensors_plus` | Accelerometer readings on Android and iOS. The desktop input adapter uses keys and direction buttons for gravity. | Renban and gravity prototype. [sensors_plus](https://pub.dev/packages/sensors_plus) |
| `characters` | Split harvestable description glyphs on Unicode grapheme boundaries. | First nest. [characters](https://pub.dev/packages/characters) |
| `http` and `html` | HTTP client and HTML parser for the approved catalog integration. Parse portal pages in the source adapter and return normalized records to shared code. | Catalog integration. [http](https://pub.dev/packages/http) · [html](https://pub.dev/packages/html) |
| `url_launcher` | Open the Logic Masters setter page and verified CtC video on explicit request. Puzzle play and resume use the in-app Flutter board. | Library links. [url_launcher](https://pub.dev/packages/url_launcher) |
| `package_info_plus` | Read the installed version and Android build number for notifications from the GitHub release channel. | Android updates. [package_info_plus](https://pub.dev/packages/package_info_plus) |
| `flutter_test` and `integration_test` | Domain, widget, save and resume, and device tests. | Development and CI. [Flutter testing](https://docs.flutter.dev/testing/overview) |

Start on Flutter stable. Pin the SDK version and commit `pubspec.lock` once the Android scaffold resolves these dependencies together.

### Shared code and platform input

Keep the puzzle solver, slide rules, tile inventory, economy, procedural creature generation, and save format in pure Dart. Use a versioned deterministic generator for creature seeds and persist the resolved art recipe and favorite digit. Flutter and Flame consume the same game state. Animations read committed events, while reward and production clocks use saved timestamps so offline progress is consistent across devices.

Use a shared board geometry for Flutter’s interactive cells and Flame’s animation layer. Flutter exposes drag and tap-to-place, focus navigation, and cell labels for assistive technology. Screen-reader actions, taps, and desktop input all submit the same placement commands. Keep the accelerometer behind a direction-input interface so Android and iOS can normalize their device axes and Windows and Linux can supply directions through keyboard or mouse controls.

### Build order

1. **Android** is the first release. Exercise the complete 4×4-to-5×5 loop on a phone, with offline saves and touch placement. Test orientation and the tilt adapter on physical devices when the gravity encounter is ready.
2. **Windows and Linux** get early build and launch checks against the same codebase. Use a resizable window, mouse dragging, and keyboard controls. Build on a Windows and a Linux runner respectively.
3. **iOS** uses the same touch interactions, data, and game code. Build and sign on macOS with Xcode, then verify accelerometer direction and portrait behavior on an iPhone. [Flutter platform setup](https://docs.flutter.dev/platform-integration)

## First playable milestone

1. Open the verified board with zero 4s. Slide into a valid arrangement and place the three 4s from the prompt. Confirm the DNA balance progresses from 0 to 3.
2. Create one amoeba for 3 DNA. Close and reopen offline during its trip, collect its delivered 4 once, and finish the board to earn RNA.
3. Upgrade a 4 to produce RNA. Grow into 5×5, account for all 16 carried tiles, find all five missing 5s with the amoeba, and finish the board. Upgrade another digit to produce DNA. Save and resume to check the production totals.
4. Create a second creature through feature selection and take a digit it holds up in 6×6. Leave an offer unclaimed and check that it returns to the tray once. Confirm that urgent jobs can interrupt idle offers.
5. Assign a creature to build the first nest from letters carried out of the flavor text. Resume mid-trip and verify that the letters can each be spent once and the nest opens a housing slot.
6. Start fresh test runs and check that each newly created amoeba has a distinct visible signature and always favors 4. Hatch several individuals from the same growth recipe with test seeds. Confirm that their favorite, color, personality, and supported appendages resolve at hatch and persist after reload. Preview legs in walk and run cycles, a slime glide, and a carried digit that stays attached.
7. Save an original or authorized variant puzzle, reopen the app in airplane mode, find it by rule, and finish it.

## Campaign acceptance checks

- Replay the size sequence through 9×9 and verify that every completed board satisfies its own rows, columns, and regions. Each growth step preserves the previous tile inventory and starts with all copies of the new digit missing.
- Clear 9×9, watch the worm eat the specified loose tiles, and recover them through helper requests. Verify the resulting board uses the authored Renban rule.
- Rotate a phone through all four edges while gravity is active. The play surface keeps its portrait frame, loose digits settle toward the low edge, and givens and placed digits stay fixed. Repeat using the on-screen arrows and verify the same outcomes.
- Start in full fog and follow the starter torch through a Halo and a Linked torches encounter. Confirm that a correct trigger reveals its intended cells once, a wrong placement leaves visibility unchanged, and resuming mid-delivery completes the same reveal.

## Open decisions after the playtest

- Whether the slide board appears once per run or returns as a short milestone challenge.
- How much time should pass between requesting a digit and placing it once production is automated.
- How quickly production upgrades and housing should pay off as creature costs rise.
- How much the Legacy upgrades should accelerate repeated runs, including under the optional charters.
