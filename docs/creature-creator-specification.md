# Creature creator

After 5×5, press growth choices to build a creature. Each choice shapes a shared preview and can open more choices elsewhere in the graph. The selected inputs form a recipe for a procedural individual. A second hatch from the same recipe can have a different color, markings, favorite digit, or personality. The tutorial starts with one inexpensive amoeba that favors 4 and draws its own appearance and personality from the run seed. [Evolve’s branching evolution](https://github.com/pmotschmann/Evolve/wiki/Evolution)

## Growth paths

Use one chosen node per group in an ordinary growth recipe. The first hatch offers **bipedal, quadrupedal, or slime glide**, **round, long, or squat**, and **smooth skin, short fur, or gel coat**. That gives 27 starting body recipes before work perks or procedural variation. Later milestones open the full table.

| Path | Growth buttons |
| --- | --- |
| **Locomotion** | Bipedal, quadrupedal, six legs, many tiny feet, slime glide, hovering. |
| **Body shape** | Round, long, squat, wide and flat, segmented, two connected lobes. |
| **Coat** | Smooth skin, short fur, gel coat, scales, overlapping plates, paper fibers. |
| **Senses** | Whiskers, upright ears, eye stalks, a rotating eye, feelers, ears on ankles. |
| **Carrying** | Hands, pincers, hooked tail, a lip pocket, sticky pad, a cradle above its head. |
| **Building** | Fold letters, stack letters, weave strips, press pieces together, wedge pieces into place, polish each piece. |
| **Torch handling** | Carry a hooded lamp, sling a lantern, balance a candle, trail a lamp on its tail, lift a torch on fins, carry a light under its chin. |
| **Gestures** | Swing arms widely, bob its head, tap its tail, flap its sides, fan its feelers, salute with both hands. |
| **Odd changes** | A tail with feet, a fin on its knee, a hinge in its belly, fur on one elbow, a floating hand, an extra mouth that only yawns. |

Growth paths can join. **Short fur + Hovering** opens **Fur on the underside**. **Quadrupedal + Gel coat** opens **Translucent paws**. **Slime glide + Hooked tail** opens **A tail with feet**, which can trot while the body slides. **Wide and flat + A cradle above its head** opens **Carry things sideways**. Give each cross-path choice a visible effect on the preview. A whimsical extra can grow its own mount or move independently of the main gait.

| Milestone | Choices it adds |
| --- | --- |
| **5×5** | Starting movement, shape, and coat. Pick one work perk. |
| **6×6** | Six legs, many tiny feet, scales, overlapping plates, and all Senses and Carrying choices. Favorite stock and Stable footing open. |
| **7×7** | Wide and flat bodies, all Building and Gestures choices, and the odd changes Fin on its knee, Hinge in its belly, and Fur on one elbow. |
| **8×8** | Hovering, segmented bodies, two connected lobes, paper fibers, and a second work perk. |
| **Halo fog** | All Torch handling choices and Fast torch trip. |
| **Arrows** | A third work perk, A tail with feet, A floating hand, and An extra mouth that only yawns. |

Present nodes as short actions in the creator, such as **Grow four legs**, **Grow fur**, and **Grow a tail with feet**. Each node declares a stable ID, its group, required inputs, milestone, body or animation effect, and any work effect. Join branches when their prerequisites are satisfied and their milestones are reached. A combined choice uses the latest prerequisite milestone unless the table places it later. Changes update the preview and show which dependent choices need attention. Persist the selected node IDs so a saved recipe can be opened and edited later.

## Work perks

Each body can take basic digit, building, and torch jobs. The selected perk defines its effect, and the body defines how the creature performs it. For example, Quick steps can speed up a slime glide or lengthen a biped’s stride. An extra grip can be a hand, a sticky patch, or a tail depending on the selected paths.

| Perk | Unlock | Effect |
| --- | --- | --- |
| **Quick steps** | 5×5 | Multiply ordinary digit-trip time by 0.75. |
| **Extra digit grip** | 5×5 | Carry one more requested copy of the same digit. |
| **Stable footing** | 6×6 | Multiply digit-trip time by 0.65 during an encounter with tilt gravity. |
| **Favorite stock** | 6×6 | Raise the automatically stocked target of this creature’s favorite digit by one when the player selects it for restocking. Apply one bonus per digit. |
| **Letter carrier** | 7×7 | Carry one extra letter for the same project. |
| **Fast builder** | 7×7 | Multiply letter-trip time by 0.80. |
| **Visible conflict check** | 8×8 | On request, point to a conflict established by clues the player can see. |
| **Longer offer** | 8×8 | Extend the ordinary digit hold-up window by two seconds. |
| **Fast torch trip** | Halo fog | Multiply torch-trip time by 0.75. |

Choose at least one work perk. Calculate travel time from the base duration, applicable Legacy speed effects, and matching perk multipliers, rounded once to milliseconds. Limit the reduction to half the base time for initial tuning. Reserve distinct pieces for parallel workers and clamp extra loads to the active request and available stock.

## Preview and hatch

1. **Grow.** Press a path and see the preview draw or move the new part. Preview the main gait and cargo pose at gameplay size. A simplified list navigation presents the same branches and prerequisites.
2. **Review.** Check chosen growth paths, work perks, current price, and available housing. Show a preview palette until hatching reveals the individual’s coloration.
3. **Hatch.** Reveal the individual’s random colors, physical details, favorite digit, and personality. Let the player name it and revisit its saved recipe. The [companion specification](companion-specification.md) describes keeping it across runs.

For designed creature number K in the current run, charge `ceil(4 × 1.45^(K−1))` DNA and `ceil(8 × 1.45^(K−1))` RNA. Growth choices and the first perk are included in that price. Each additional perk adds **1 DNA and 2 RNA** for the first playtest. Hatching the first creature still costs **4 DNA and 8 RNA**.

Derive an individual seed from the run seed and saved creation sequence. Give appendages, markings, coloration, favorite digit, and personality their own deterministic draws. Sample palettes independently of growth choices and keep each sprite readable against the scene. Draw the favorite uniformly from digits unlocked at hatching. Store the resolved anatomy, palette, favorite, and personality with the individual. Regenerate a part with a compatible mount if its first draw cannot animate on the selected body. Every appended part needs an attachment point and a pose for travel, with the main gait determined by locomotion.

The hatch command uses one ID through review, retry, and resume. In one transaction, validate the growth graph, perk unlocks, charter, housing, price, and wallet. Spend the balance and save the generated creature with the command ID. Retries return the original result. Present an updated quote for confirmation if the current price changes.

## Regression cases

- Check all 27 starter body recipes with either first work perk. Confirm the tutorial and 5×5 rewards can still fund both starter producers and the first hatch.
- Open a cross-path choice, change a prerequisite, and restore it. Compare the preview and saved node IDs. Validate each resulting gait and independent appendage during an idle, travel, and carry pose.
- Generate several individuals from one recipe. Verify varied seeded color, personality, and favorite digit and stable results after reload. Use fixed test seeds rather than relying on a random difference in a single run.
- Verify a basic 3-second digit trip with Quick steps takes 2,250 ms. Submit a duplicate hatch, fill the last housing slot, and activate One Helper. Check that a saved recipe’s late nodes become selectable when the new run earns their milestones.
