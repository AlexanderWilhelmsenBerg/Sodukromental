# Incremental campaign specification

See the [Phase 2 board and staffing requirements](phase-2-expansion.md) and [settlement expansion](phase-2-colony.md) for proposed changes to the debug campaign.

The campaign starts with three draggable 4s and ends when the player clears a chosen finale and finishes their civilization’s Meeting Hall. Afterward they can explore the other routes, tackle expeditions, or prestige into a new seed. The [game specification](game-specification.md) defines the sliding puzzle, growing board, creatures, and economy.

## The play loop

1. **Read the board.** Deduce one or more digits, add pencil marks, and see which copies are available.
2. **Direct the colony.** Request a digit, prioritize a torch, or send a builder to gather a marked letter. A helper can offer a favorite from stock while the player considers the board.
3. **Make the placement.** Drag the digit from a helper or the tray, or select it and tap the cell. Keep working while the next delivery travels.
4. **Collect and choose.** Receive the puzzle-clear reward and decide how to spend it. A faster carrier helps with urgent singles. A larger carrier helps when several copies are missing. A producer or a building improves later boards.

Show the next campaign objective in one place and reveal new menus when they become actionable. Keep digits, notes, and the rules chip available during collection. The colony can increase supply, carry torches, and assist with a check on request. The player makes every Sudoku placement.

## Campaign and unlocks

The proposed route to a first ending uses **16 boards**. Thirteen shared encounters teach the core systems, then the player chooses a three-board finale route. Each clear opens the next part of the selected route, and the player chooses when to move on.

| Encounter | Puzzle or event | What changes after the clear |
| --- | --- | --- |
| 1 | Slide the 4×4, harvest three 4s, and create the amoeba to fetch the last 4. | The first digit can produce RNA. Grow into 5×5. |
| 2 | Solve the irregular 5×5 and request the five missing 5s. | Open creature design, DNA production, and the first letter-built nest project. |
| 3 | Solve the 6×6 and compare a helper’s ability with the amoeba’s basic trip. | Found the village, unlock rank-2 producers, and enable a tray restock rule. |
| 4 | Solve the irregular 7×7 while the village keeps requested digits stocked. | Open house and storehouse projects and introduce a second worker assignment. |
| 5 | Solve the 8×8 and choose how to allocate helpers. | Found the city, unlock rank-3 producers, and enable separate digit and building assignments. |
| 6 | Solve the first 9×9 with ordinary Sudoku rules. | Open the variant campaign. |
| 7 | The Renban worm eats loose digits and introduces gravity. | Unlock the variant map and saved rule explanations. |
| 8 | Thermometer lesson. | Add the thermometer rule to the reference. |
| 9 | Halo fog lesson. | Open a torchbearer assignment. The amoeba can cover it. |
| 10 | Kropki lesson with white and black dots. | Add both dot types to the reference. |
| 11 | German Whispers lesson. | Add the line rule to the reference. |
| 12 | Killer cages lesson. | Add cage sums to the reference. |
| 13 | Arrows lesson. | Found the civilization, open its Meeting Hall project, and choose a finale route. |

### Finale routes

Each route teaches two distinct rules on separate boards, then asks the player to use both in a finale. All three routes use visible clues. The worm and the Halo fog lesson remain part of the shared campaign. Trail fog opens as an optional lesson after Halo, and Linked torches opens after Trail with a reveal that requires several correct placements.

| Route | First lesson | Second lesson | Finale |
| --- | --- | --- | --- |
| **Lines** | Palindrome. A creature traces a line from both ends. Its digits read the same in either direction. | Region Sum Lines. Bridges divide a line at region boundaries. Every segment has the same digit sum. | Use mirrored values and equal sums to solve a board where the two types of line intersect. [Palindrome rules](https://logic-masters.de/DSM/2025/dokumente/DSM_2025_Qualifikation_Raetsel.pdf) · [Region Sum Lines](https://logic-masters.de/Raetselportal/Raetsel/zeigen.php?chlang=en&id=0008TB) |
| **Outside clues** | Sandwich. A baker puts a total at the grid edge. Digits strictly between 1 and 9 in the indicated row or column add to that total. | X-Sums. A surveyor marks an edge clue. Add the first X digits from that edge, where X is the digit in the first cell and is included in the sum. | Use both clue types on a single board. Distinct signs and accessible labels identify each clue. [Sandwich and X-Sums definitions](https://logic-masters.de/Raetselportal/Raetsel/zeigen.php?id=000VM5) |
| **Positions** | Diagonal. A creature stretches ribbons across the two long diagonals. Each diagonal contains 1–9 once. | Anti-Knight. A hopping helper demonstrates the chess knight move. Two cells a knight’s move apart must contain different digits. | Solve a board where an anti-knight exclusion and a diagonal deduction interact. |

Use the main specification’s early-board rewards. Each ordinary variant lesson awards **3 DNA and 10 RNA** on its first clear in the run. Each route finale awards **8 DNA and 20 RNA**. Validate every board for uniqueness and a logical solution. Each finale needs a deduction that uses both of its featured rules.

After encounter 13, the player can start building the Meeting Hall from **two roof pieces, four supports, and two beams**. The settlement notice supplies any missing material roles. Completing the hall and one route finale reveals the finished colony and records the run as complete. The original amoeba can do all required construction. Return to the route map at any time to change routes. Save entries and notes with each board, and settle or pause its reserved digit jobs before dispatching work for the next board. Cleared boards and one-time rewards stay recorded. Each remaining route opens as an alternative path to the ending or an optional goal for the completed colony.

## Endgame

Keep the completed colony active until the player chooses to prestige. Players can finish the remaining routes, replay learned variants for practice, or take on expeditions that combine rules from different lessons. An expedition opens after its rules have been learned and the Meeting Hall is complete. Each uses a new authored board with its own clue layout.

| Expedition | Puzzle focus | Colony activity |
| --- | --- | --- |
| Hilltop workshop | Thermometer and Arrows. Both rules have visible clues. | Assign helpers to stock digits while a builder brings letters to the workshop. |
| Night market | Kropki and Trail fog. Reveal the dot and its two cells before asking the player to use it. | Prioritize torches as new market stalls become visible. |
| Canal crossings | Renban and Region Sum Lines. Their paths have distinct patterns. | Decide which digit copies to restock after the worm eats its planned tiles. |
| Kiln quarter | Killer cages and German Whispers. Use both the cage totals and the minimum differences along each line. | Send builders to hang signs, then use the visible totals to plan digit requests. |

An expedition’s first clear earns one cosmetic project for the colony, such as a patterned roof or an animated lantern. Finish the project with letter materials. The Rule Almanac shows learned rules, solved expedition boards, and the crews that helped. To master a rule, clear two distinct authored boards that use it, including a board that combines it with another rule. Keep the individual fog types in the Fog entry. Replays update personal records, with first-clear rewards tied to the original encounter and run. [Melvor Idle skill progression](https://store.steampowered.com/app/1267910/Melvor_Idle/) · [Kittens Game settlement jobs](https://wiki.kittensgame.com/en/game-tabs/outpost)

The proposed content set has **28 authored boards**. It includes thirteen shared boards, nine finale-route boards, two optional fog lessons, and four expeditions. [Library challenges](library-specification.md#play-with-colony) offer additional puzzles after 5×5 using compatible downloaded Logic Masters boards. They use the current colony and award the ordinary variant clear reward once per puzzle per run. The authored encounters control the campaign’s unlocks and ending.

## Prestige reset

**Start a new colony** becomes available after completing the Meeting Hall and any route finale. Preview the Legacy payout, available bonuses, and next opening before the player confirms. The player can keep playing their current colony and return to the preview later.

| Source | Legacy points on reset |
| --- | ---: |
| Complete a run and archive it | 2 |
| Each route finale cleared in that run and credited for the first time in the profile | 1 per route |
| Complete the run under a charter credited for the first time in the profile | 1 |

The first ordinary clear with one route pays **3 Legacy**. A later clear on the same route pays **2**, with first-time route and charter bonuses added when applicable. In the preview, choose permanent upgrades up to the balance after the quoted payout. Buy consecutive ranks in order. Unspent Legacy remains in the profile. Upgrades apply from the next run’s opening milestones. [Kittens Game reset and carryover](https://wiki.kittensgame.com/en/general-information/game-mechanics#reset) · [Kittens Game permanent upgrades](https://wiki.kittensgame.com/en/game-tabs/science/metaphysics)

| Upgrade | Legacy cost | Effect |
| --- | --- | --- |
| Shorter routes | 2, 3, and 4 for ranks 1 through 3 | Ordinary digit deliveries take 10, 20, or 30 percent less time than baseline, before the creature’s own movement bonus. |
| Warm start | 2 once | Install one rank-1 RNA producer at no resource cost once 4×4 is cleared. |
| Extra nest | 3 once | Open one additional housing slot after 5×5. |

Archive the old colony with its creature appearances, growth recipes, buildings, and clear history. Keep Legacy, permanent upgrades, learned rule entries, and cosmetic patterns at profile level. Let the player carry one creature into the new colony with its appearance, personality, and learned habits. Start the new seed with fresh resources, board progress, and buildings. Use the same Library saves and downloads across colonies. [Keeping a companion](companion-specification.md)

Offer the 4×4 tutorial or a quick opening. The quick opening starts at 5×5 with the starter amoeba, the sixteen carried 4×4 tiles, and 6 RNA. Record the equivalent 4×4 clear and opening actions when creating the new run. The seed determines new creatures. A retained amoeba returns in its existing role.

Store the reset as a single transaction. Save the old run’s final snapshot, credit Legacy once by archived run ID, record first-time bonuses and upgrade purchases, and create the new run with the chosen companion. Reload at any step should show either the previous colony or the complete next opening with its balance.

### Optional charters

Choose one charter when starting a prestige run. State its restriction and reward in the preview. Clear a route and complete the Meeting Hall under that restriction to earn its first-time bonus on the next prestige. The board keeps its usual solve rules and accessibility controls. [Kittens Game challenges](https://wiki.kittensgame.com/en/game-tabs/challenges)

| Charter | How play changes |
| --- | --- |
| **One Helper** | The starter amoeba is the only hatch available and handles all digit, torch, and building work. The retained creature can accompany the player and talk. |
| **Hand Orders** | Batching and directed queues stay available. Players issue each restock request. |
| **No Producers** | DNA and RNA come from the tutorial and puzzle clears. Production upgrades, including Warm start, are inactive for the run. |

### Additional mechanic to prototype

Let players choose an archived creature to appear in a mosaic on the new Meeting Hall. Builders assemble its silhouette from collected letters. The mosaic gives prestige a visible link to the previous colony and uses the construction system already needed for the campaign.

## Automation and meaningful upgrades

| Milestone | What the player can automate | Decision that remains |
| --- | --- | --- |
| Amoeba | Fetch a requested digit. After the tutorial, batch requests by value. | Choose what to ask for based on the visible puzzle. |
| After 5×5 | Queue requests for several values. A second helper can work in parallel when available. | Choose a movement or carrying feature and a job. |
| Village | Keep a chosen stock level for selected digits. Begin with a restock target of one or two copies per chosen value. | Pick which values to stock and suspend restocking when another job matters more. |
| City | Assign workers to digit delivery or building. When fog unlocks, allocate a worker to torch jobs as well. | Decide whether faster digit supply, faster construction, or shorter reveal delays matters now. |
| Civilization | Choose a settlement policy. Shared reserves allow two more chosen restock values, and shared crews lend idle workers to pending construction jobs. | Pick a policy before the finale and change it at the colony screen. |

For every value, calculate demand from the board’s required count, placed copies, the tray, and uniquely reserved or in-flight copies. A held digit and its reserved tray entry represent one tile. Restocking uses counts and player settings as its inputs. Torch requirements take precedence over routine work. A worker can finish its current trip and then take the next required job even when no specialist is present. The colony schedule shows what will arrive next and why.

Use a **2-second first trip**, **3 seconds for an ordinary digit or letter trip**, and **2 seconds for a basic torch delivery** as initial playtest values. Quick steps shortens ordinary digit trips by 25 percent. Extra digit grip lets a creature carry one additional copy of the requested digit per trip. Spend the guaranteed puzzle rewards on the first designed creature and both starter producers, or continue with the amoeba and spend the same resources later. The nest adds an optional worker slot. Progress past the tutorial depends on puzzle clears and the finale’s glyphs, so speculative purchases and random favorites cannot block completion. [Creature paths and job effects](creature-creator-specification.md)

When the player returns, show a single summary of producer output and completed trips. The two-minute production cap follows the main specification. Settle trips already queued at departure, honoring their reservations and the destination capacity. Resume new restock requests when the game is open. Restore the same board and visible fog cells.

## Rules, feedback, and difficulty

- In ordinary placement phases, entries can be changed, erased, or undone and returned to inventory. **Check board** identifies visible conflicts. Creature reactions use those same visible clues, and their antics can be adjusted in settings. Completing the grid checks every active rule and explains any remaining conflict. Fog placements follow the encounter’s correct-placement reveal rule.
- Offer an optional hint that shows where to look, followed by an explanation if requested. Base both stages on the clues and rules visible to the player, including the current torch coverage. Author a logical route through every required board. Use a uniqueness check for the full puzzle and a separate visibility check for each step of a fog route.
- Make the first use of each rule short and focused. A lesson must contain a deduction that uses the introduced rule. Reuse earlier activities at larger scale only when a collection or construction upgrade changes the player’s decision.
- Preserve the run on close and give a consistent way to retry an encounter from its authored start. Keep the creature roster, construction progress, and earned rewards. Clear the old board’s pending jobs when restoring its inventory, reveal events, and rule state. Save first-clear rewards and unlocks once by run and encounter ID.
- Make the full campaign finishable offline. On-screen direction controls, tap-to-place, and reduced-motion options cover the same actions as tilt, dragging, and full animation.

## What the reference games contribute

| Reference | Pattern | Application in Sodukromental |
| --- | --- | --- |
| **A Dark Room** | A small initial interaction reveals more tools as the world opens. | The sentence yields the first three 4s. Only then does the amoeba action appear, followed by production and building as the board grows. [Developer press kit](https://press.doublespeakgames.com/adr/index.html) |
| **Kittens Game** | Workers assigned to distinct jobs change what a settlement produces. | Assign helpers to carry digits, light fog, or build with letters. The preferred assignment changes with the board. [Kittens Game jobs](https://wiki.kittensgame.com/en/game-tabs/outpost) |
| **Universal Paperclips** | Progress moves from the initial object to new scales of activity. | Grow the board, manage workers, then use the civilization to support expeditions with different puzzle rules. [Universal Paperclips](https://www.decisionproblem.com/paperclips/index2.html) |
| **Melvor Idle** | Offline progress and distinct skills give players parallel goals. | Let production finish during an absence and let players complete the Rule Almanac while following their chosen finale route. [Melvor Idle developer listing](https://store.steampowered.com/app/1267910/Melvor_Idle/) |

## What to verify before release

1. Complete the required route from a fresh run with the amoeba and no passive purchases. Validate every board, use each fog path, finish the Meeting Hall, and reach the recorded ending. Repeat with the intended upgrade path and alternate creature recipes.
2. Account for all tiles during board growth, worm removal, helper offers, cancellation, placement, undo, and restore. Test pauses midway through a glyph delivery or a fog reveal and confirm each reward or delivery is applied once.
3. Playtest the tutorial with first-time players. Check whether they discover that the sentence’s 4s are movable, understand why the amoeba exists, and can request the next digit without help. Use a small graduated cue if testing shows they miss the sentence interaction.
4. Measure idle gaps during a solve. Use **five seconds** as the initial limit for a stretch where a player has a deduction ready and can do nothing except wait for a digit or torch. Also check that players can describe why they would pick one helper or upgrade over another.
5. Verify the logical solve path for all three finales and four expeditions. Exercise route switching without losing solves. Confirm each Almanac mastery entry has enough eligible boards.
6. Prestige after one route and after multiple routes. Verify first-time bonuses, saved Library content, the archived colony, and the 5×5 quick opening. Interrupt the transition and confirm the run creates and pays out once. Finish each charter with a standard helper and check that the restriction and reward are enforced.
7. With known personality seeds, test favorite-number flocking, puzzled reactions, a digit reclaimed from a Collector, and a Tinkerer’s fragment used as a support. Repeat a conflict, undo it during an animation, and reopen during a reaction. Confirm that each required copy remains available, the fragment pays once, and a conflict between tentative tiles prompts inspection. Repeat with a saved Logic Masters challenge.

The encounter count, delivery times, and build prices are proposed first-release values. Use playtest results to tune them while keeping the clear objectives and ending intact.
