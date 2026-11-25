# Mechanics acceptance review

This review covers all 28 required Android debug slices. The campaign engine was exercised with an injected clock and JSON round trips. Android device observations, live source access, and release publication have their own evidence owners.

| Slice | Mechanics review and evidence |
| --- | --- |
| F1 | The board contracts and campaign engine run in Dart without Flutter or plugin dependencies. The first campaign regression boots from a new seed. Use the foundation evidence for a clean Android or Flame launch. |
| F2 | Campaign schema 2 preserves individual digit IDs, board progress, tile provenance, active and queued trips, balances, and offers. The legacy count-and-origin save fixture migrates into distinct copies. Board payload schema 1 rejects out-of-range rule and fog geometry. The integration owner verifies the SQLite migration and durable transaction. |
| F3 | Run the campaign and independent board suites in the Debug APK workflow alongside formatting and analysis. The local core tests establish the platform-independent behavior. Emulator installation and launch use the Android owner's evidence. |
| P1 | The four documented slides work from the original fixture. Anchors stay fixed, invalid token placement earns nothing, and each source token retains its identity through reload. A reserved fourth 4 resumes at two seconds and only one claim clears the board. |
| P2 | The 5×5 starts at the specified connected layout. The documented solve places all nine matching carried tiles back in their coordinates. Every one of the 16 original IDs survives growth, one station copy is added per old digit, and the first 5 starts traveling automatically. |
| P3 | Tests cover one-time RNA and DNA rewards, preserved fractional production time, the two-minute offline cap, and purchasing both starter producers and the first designed helper with opening rewards. |
| P4 | Hatch retries return the original creature without spending again. A queued nest reloads with distinct glyphs and adds one housing slot. Idle and delivery offers use an explicit reservation. Creator rendering and both perk poses are verified in the creature suite and UI. |
| P5 | Library challenges and campaign saves coexist independently. Use the integrated widget and app-flow evidence for tap, drag, keyboard, and Library before a colony is created. |
| C1 | Pure Dart fixtures validate the six sizes and connected 5×5 and 7×7 regions. The route suite clears all growth stages, with the next digit withheld from each stage until collected. |
| C2 | The scheduler reserves distinct digits and materials, ranks torch requests first, and accounts for in-flight copies when restocking. Undo restores the physical tile. Collector recall and fragment replacement use the same snapshot as inventory. Physical animations and how often antics interrupt play need playtesting. |
| C3 | Hatch validates the milestone, charter, price, recipe, and housing together. The separate creature suite owns starter combinations, cross-path mounts, gait frames, and seed resolution coverage. |
| C4 | Rule payloads cover Renban, Thermometer, both Kropki dot types, German Whispers, Killer, and Arrows. The board suite verifies rule necessity by removing each family. Worm shortages are authored, and tilt changes the loose tray order independently of values and notes. |
| C5 | The starter torch is a saved trip. Correct visible entries fix a tile, while attempted wrong entries leave the fog intact. The campaign test clears Halo, Trail, and Linked, and the independent board suite verifies its deduction sequence using visible clues. |
| C6 | One starter helper clears each 16-board route and completes the 2-roof, 4-support, 2-beam Meeting Hall. The first clear of a reopened finale pays only once. The board suite checks the 28 authored boards, including expedition combinations. |
| C7 | A single prestige snapshot archives clear history, buildings, the creature's visual record, and route or charter credits, then loads the selected opening. Tests cover quick start, replaying the tutorial, retained amoeba, first-time route and charter rewards, and charter restrictions. |
| L1 | Campaign challenge logic uses a stable source ID and pins the first valid definition for that run. Full crawl counts, separate payload host usage, locale fallbacks, and restart behavior belong to Library source verification. |
| L2 | A shared rule enum supplies rule labels, explanations, and application geometry for authored and compatible imported boards. Library evidence covers Any, All, and uncertainty when source rules are unstructured. |
| L3 | Campaign never makes a network request and checks imported payload solutions and supported size before opening a challenge. Download permission, deduplication, revision fallback, and offline content belong to Library and persistence verification. |
| L4 | Featured metadata is independent of campaign progression. The Library review owns official video identification, source caveats, ordering, and offline fixtures. |
| L5 | All 28 authored board definitions are exported for standalone play. Colony challenges use separately saved progress and pay once per source ID per run, without advancing the campaign. The Library integration checks both play modes and installed offline content. |
| D1 | With One Helper, the retained founder rejoins the tutorial as the same saved creature. Task contributors advance shared clear history by run and encounter. Companion tests cover phrases, outside approval flags, milestones, and local visit scheduling. |
| D2 | Each direction feeds the same pure-Dart tilt command. A directional change cannot affect the solution grid or inventory. Sensor thresholds and real portrait behavior need Android runner and handset evidence. |
| D3 | Campaign saves the retained companion identity and memory used to gate the overlay. Permission grants, revocation, lock, ordinary-app touch, and service stop require the native and physical-device evidence. |
| D4 | Slide, flat-index taps, notes, direct offer claims, and tile IDs expose stable accessible commands. Responsive layouts, logical focus order, scale, and animation readability require UI screenshots and interaction checks. |
| D5 | This engine has no platform dependencies or system-clock access beyond its optional default constructor clock. Device stubs can inject timestamps and tilt directions. Platform-specific compile status is recorded separately. |
| R1 | Verify the campaign tests and independent board tests at the integrated revision. Device observations and any failures outside the mechanics scope belong in the combined acceptance evidence. |
| R2 | Keep the source revision, tested package, and hash aligned at handoff. Show launch from a new install or saved game while offline. APK build, emulator, and publication are covered by Android delivery. |
| R3 | Ask testers to exercise the prompt interaction, early production choice, optional fog triggers, tilt, and one-helper completion. Keep solve quality, offer pacing, and device feedback linked to their owning slice. |

The authored growth and variant fixtures use fixed digit layouts so save and resume always return to the same puzzle. The generated creature seed still changes when a new colony starts.

Relevant suites are `test/campaign_test.dart` and the independent board acceptance suite. Timing balances, first-time discovery of the opening prompt, native sensor and overlay behavior, external catalog completeness, and release publication require their respective acceptance evidence.
