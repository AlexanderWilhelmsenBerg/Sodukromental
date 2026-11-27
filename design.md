<!-- Hallmark · genre: playful · macrostructure: Map / Diagram · theme: Hum · native app adaptation -->
<!-- Hallmark · pre-emit critique: P4 H5 E4 S5 R4 V4 -->

# Sodukromental visual design

Use Hallmark’s Hum direction for a playful pixel colony with an uncluttered Sudoku playing surface. The audience includes dedicated variant solvers and new players who arrive for the creatures. Keep the grid central. Creature animation should explain a delivery, a reveal, a mischief event, or a building task.

## Design philosophies

- **Make mechanics visible.** In the MDA game-design framework, a mechanic produces an observable behavior and a player experience. A favorite digit brings helpers to the tray. A cargo tail visibly wraps around a second copy. A torch reveals the next clue. Each animation helps the player understand what happened. [Hunicke, LeBlanc, and Zubek’s MDA framework](https://aaai.org/papers/ws04-04-001-mda-a-formal-approach-to-game-design-and-game-research/)
- **Reveal complexity when it is useful.** Start with the board, the sentence, and the draggable 4s. Add DNA after the first placement, the hatch action at three DNA, and the creator after 5×5. Keep rules and advanced filters within reach through their own controls. [Nielsen Norman Group on progressive disclosure](https://www.nngroup.com/articles/progressive-disclosure/)
- **Use accessible direct controls.** A tile responds to dragging and to select-then-place. Pair color with line patterns, icons, and text. Provide cell labels, keyboard movement, and a visible focus outline. Keep color, touch target size, text scaling, and reduced motion in the same design and test plan. [Flutter accessibility](https://docs.flutter.dev/ui/accessibility)

## Tokens

Use named Flutter theme tokens for widget surfaces and pass the same tokens to Flame. Treat the following sRGB values as the Android palette.

| Token | Value | Use |
| --- | --- | --- |
| Paper | `#FBF6E8` | Screen background. |
| Board | `#FFFBF2` | Sudoku cells and readable rule panels. |
| Ink | `#1D242B` | Primary text and digits. |
| Muted ink | `#49545D` | Author names, secondary labels, and notes. |
| Grid rule | `#5B646E` | Cell rules and outlined regions. |
| Pear | `#E6DC53` | Primary action and the current creature offer. Use Ink for its label. |
| Pear edge | `#827615` | Solid edge on the primary button. |
| Cyan wash | `#C5E9F0` | Selected cell and rule-chip background. |
| Link and focus | `#005B74` | Links and visible focus. |
| Coral wash | `#F8C0B0` | Conflict background and rare reaction highlights. |
| Error ink | `#982735` | Conflict text and marks. |
| Fog | `#262D35` | Hidden-cell surface. |
| Torch | `#FFE59A` | Light and reveal highlights. |

Use upright **Plus Jakarta Sans** for headings and controls and **JetBrains Mono** for board digits, quantities, and inventory counts. Bundle both fonts for offline use. Use tabular digits so counts and values hold their positions. Use a 4, 8, 12, 16, and 24 dp spacing scale, with 8 dp control corners and 12 dp panel corners. The board’s orthogonal grid retains square editing cells.

Derive the primary action from Hallmark Hum’s tactile button. Give it a solid lower edge and let the edge shorten when pressed. Use the same face, edge, and focus proportions for the Hatch and Build actions. Reserve coral for a local reaction or error and the cyan wash for the current selection. Use a 140 ms default feedback transition and a shorter press transition. Replace travel and bounce with an immediate state change when reduced motion is enabled.

## Screen structure

| Screen | Composition and priorities |
| --- | --- |
| **Campaign board** | A compact objective above the square board. The 4×4 prompt has three inline digit tokens with a visible border and tap selection. Keep the number pad under the board. In Phase 3, houses, water sources and walking routes occupy free space around the board and pad across the campaign screen. |
| **Library** | A search field and one filter row above readable puzzle rows. Each row shows title, author, rule chips, and offline status. A verified CtC badge opens the solve link from details. Keep the selected filters visible while the list scrolls. |
| **Creature creator** | Phase 3 presents one of five branching decisions at a time. Show the action and work effect for each immediate child. Keep price, bed space, Back and Hatch accessible. Reveal the individual after a successful saved hatch. |
| **Colony** | Keep active deliveries and the next project close to the board. Open detailed assignments, resources, and buildings from the habitat. Give the player a list view of the same tasks for keyboard and screen-reader use. |
| **Companion** | Show its name, personality, learned habits, **Talk to creature**, and **Keep as companion** in one profile. In the Library or home screen, use a small sprite and one short speech bubble beside the controls. Keep **Call back** accessible during a visit. |
| **Settings** | Group downloads, assistive controls, and updates. An available Android update appears on the Library or home screen and has an entry in Settings. |

Use two top-level destinations, **Sudoku** and **Colony**, with Settings accessible from either. Preserve the player’s scroll and selection when switching destinations. The board and a single active creature action give the play screen its visual focus.

## Motion and layout validation

Snap pixel sprites and their attachment points at whole-pixel scales. Keep markings and legs individually poseable. Use an outline, texture, or symbol for each rule clue so it remains identifiable under color-vision changes. Place creature reactions at the edge of a cell or within the habitat to keep digits legible.

Verify a Flutter implementation at **320, 375, 414, and 768 dp** widths, including large text and keyboard focus. Use 48 dp targets for controls. On narrow screens, provide a zoomed board or linear cell selector with full-size targets for the dense 9×9 grid. Verify the first prompt’s three inline digits also work through tap selection and screen-reader actions. Test no horizontal clipping, clearly readable puzzle rules, and stable layout as the hatch saves, recovers from a failure, or reveals the new resident.
