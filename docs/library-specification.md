# Logic Masters Deutschland library specification

Phase 2 uses Sodukromental’s own Flutter player for every **Play** and **Resume** action. SudokuPad and F-Puzzles links are inputs to the importer. The native controls, coverage fixtures and offline release criteria are in the [Phase 2 player specification](phase-2-sudoku-library.md#native-solver-acceptance).

This specification defines the Android-first Sudoku Library in [Sodukromental](game-specification.md). The Library includes the full Logic Masters Deutschland Sudoku catalog and a standalone edition of every authored Sodukromental Sudoku board, including alternate finales and expeditions. All Library content is available from first launch as the catalog loads, independent of colony progress. The Sudoku Library will be offered to Logic Masters Deutschland free of charge.

## Player experience

- **Browse** shows title, author, difficulty, rule chips, availability, personal progress, and a **Featured on CtC** badge when verified. Search title and author. Sort by publication date, difficulty, rating, title, last played, or **Featured on CtC**. Show unknown difficulty and rating separately from scored entries. Identify difficulty estimated by the author when the portal provides that distinction.
- **Filter** by one or more rules with **Any** and **All** matching. Also filter by size, difficulty, saved status, progress, or **Featured on CtC**. Rule exclusions and a **Classic only** option require enough rule information to assert absence. Entries with incomplete rule coverage can be included in positive matches and show a **More rules may apply** marker.
- **Puzzle details** show the author’s original rules, tappable short rule explanations, a clue preview when available, and a **Read setter’s page** link for the Logic Masters entry. Featured entries show a **Watch solve on YouTube** link to the specific video. Players can save one puzzle or select several from a filtered list. The download queue shows progress and lets players retry or cancel individual entries.
- **Saved** opens from the local database, including after a cold launch in airplane mode. Players can search, sort, filter, and resume without connectivity. Removing a download releases its puzzle assets and preserves the reference and solve record if the player wants to download it again.

| Availability | Contents on the device | Player action |
| --- | --- | --- |
| **Play offline** | Complete board, local rules, all necessary clue artwork or geometry, and a verified definition supported by Sodukromental’s player. | Play and resume locally. Show **Manual check** when the puzzle requires the player to judge a custom rule. |
| **View offline** | A readable diagram and its instructions. | Open the saved reference locally. |
| **Saved · awaiting player support** | Verified puzzle payload retained for a future capability update. | Show the specific unsupported feature. Recheck locally after an app upgrade. |
| **Catalog entry** | Catalog metadata and the setter’s portal URL. | Offer **Save for offline**. **Read setter’s page** opens the Logic Masters entry when connected. |

Save deduced digits, notes, undo position, and completion separately from downloads. Use the same board controls as Incremental, including drag or tap placement, with ordinary Sudoku input in the Library. Offer **Check board** when all active constraints can be verified. A known single-solution puzzle can use an authorized complete solution for a final check when all clues are faithfully displayed. Mark manual-check solves explicitly. An original link gives access to the portal’s own solution-code workflow.

Bundle the authored Sodukromental boards with the app. Their Library editions retain the puzzle’s actual constraints. Players can enter digits directly, and fog boards use their own reveal rules during direct play. Give the sliding tutorial a standalone 4×4 edition. Colony progression controls access to **Play with Colony** and campaign encounters. The Library’s puzzle index and direct play are available independently.

### Automatic offline downloads

Add **Settings → Library → Automatically download Logic Masters puzzles**. The default is **Off**, including for profiles with no saved preference. Manual downloads are available in either setting.

When enabled, queue eligible puzzles across the full synchronized Logic Masters catalog, starting with the most recent, and add entries as older pages and new releases are discovered. Fetch puzzle content from its designated separate host and try to save a playable copy first. If only the complete rules and diagram can be stored, save those as **View offline**. Retain verified packages awaiting native capability support. Other entries keep their catalog metadata and source credit.

Show **Queued**, **Downloading**, **Paused**, or a failure reason in the download queue. Resume when connected and pause when reported device storage is insufficient. Reuse one job per puzzle revision for automatic and manual requests. Prioritize a manual request when it shares an automatic job. Turning the setting off pauses automatic jobs. Saved puzzles stay available in **Saved**, and a manually removed download is skipped by automatic jobs until the player explicitly saves it again.

### Featured on Cracking the Cryptic

Treat a verified Cracking the Cryptic feature as an editorial discovery signal. **Featured on CtC** sorts verified matches first, with the most recently featured first within that group. Use the puzzle publication date and portal ID to break ties and to order the other entries. The badge and sort work from local records, including for puzzles whose assets are still online.

On puzzle details, show **Watch solve on YouTube** with the direct link to the verified video. If several verified solves exist, open the newest available by default and list the others. When the author identifies a different grid in the video, show that note beside its link. If YouTube confirms a video has been removed or made private, mark it unavailable and preserve the feature credit. The title, badge, and link can be read offline. Video playback opens in the YouTube app or browser when connected.

Link by portal puzzle ID and YouTube video ID. Start with author-labelled solve links on Logic Masters detail pages and verify that the upload is on the official Cracking the Cryptic channel and features the puzzle. An authorized catalog refresh can also review the official uploads and the CtC catalogue for puzzles that lack links on the portal. Use an exact portal ID, exact puzzle share link in the solve section, or a reviewed match as evidence. A similar title, channel mention, or link in unrelated credits is a candidate for review. Award the badge after the connection to the actual solve is verified. [Cracking The Cryptic on YouTube](https://www.youtube.com/channel/UCC-UOdK8-mIjxBQm_ot1T-Q) · [CtC video catalogue](https://www.crackingthecryptic.com/sudokus) · [YouTube uploads API](https://developers.google.com/youtube/data/reference/rest/v3/playlistItems/list)

Store the confirmed relationship, its source and review date, the canonical watch URL, and any known puzzle revision note. Store video dates when verified. Recheck links on refresh. When using API-sourced video metadata, apply YouTube’s refresh and retention rules. [YouTube developer policies](https://developers.google.com/youtube/terms/developer-policies)

Use *The Most Beautiful Mathematical Equation* (`000KPF`) as a matching fixture. Its portal page links both the official CtC solve (`oo2lmGOUOPQ`) and a Sudoku Sleuth solve, so the matcher should select the official link. Use *The Magic Column* (`000DQ2`) to test the source’s note that the CtC video uses a slightly different grid. [Equation portal page](https://logic-masters.de/Raetselportal/Raetsel/zeigen.php?chlang=en&id=000KPF) · [Official equation video](https://www.youtube.com/watch?v=oo2lmGOUOPQ) · [Magic Column portal page](https://logic-masters.de/Raetselportal/Raetsel/zeigen.php?chlang=en&id=000DQ2) · [Official Magic Column video](https://www.youtube.com/watch?v=FXxdeBEKqfc)

### Play with Colony

Offer **Play with Colony** alongside normal play on compatible downloaded Logic Masters puzzles. Also list those downloads under **Library challenges** in the colony’s puzzle map. The option opens after the 5×5 clear and accepts boards up to the largest size unlocked in the current colony. Start with downloaded, single-grid puzzles whose clues and active constraints can be represented and fully checked in the shared player.

Keep the author’s givens, variant rules, clue geometry, attribution, and source link. The colony supplies digit copies for empty cells and adds its usual offers and personality reactions. Any harvestable craft text comes from game-owned flavor text. The downloaded revision stays pinned for the challenge. A puzzle that is suitable for manual Library play can still be opened there.

Store challenge progress by run and source puzzle ID, with the downloaded revision attached. A challenge clear earns the standard ordinary variant reward once per source ID per run. Authored campaign boards determine chapter unlocks, the finale, and prestige eligibility. Save ordinary Library progress separately so each play option can resume its own board. Once downloaded, compatible challenges work offline.

## Source and refresh

Use the plural endpoint `spezial.php?listname=sudokus` for discovery. It lists puzzles in pages and links to detail pages using IDs such as `000UN9`. The singular parameter opens the special-list menu. Use portal ID as the source key across locales and refreshes. Index the newest pages first and continue through the complete listing, including older pages. Expose each committed page promptly and show sync coverage while more pages are being indexed. [Sudoku list](https://logic-masters.de/Raetselportal/Suche/spezial.php?listname=sudokus) · [Example detail page](https://logic-masters.de/Raetselportal/Raetsel/zeigen.php?chlang=en&id=000UN9)

Read puzzle details for author, languages, publication and revision data, difficulty and rating, portal tags, rules, and any link to separately hosted puzzle content. Resolve and save the content URL separately from the canonical portal page. Prefer the selected language with an available author-language fallback. Parse the puzzle description and tag links as data and render safe text, known structures, and permitted assets in Flutter. The advanced-search route is disallowed for crawlers in the portal’s current robots file. Use the special list for discovery and build category filters from stored metadata. [Portal robots.txt](https://logic-masters.de/robots.txt) · [Portal publishing guide](https://logic-masters.de/Raetselportal/Hilfe/einstellen.php?chlang=en)

Implement refresh as resumable work. Respect the operator’s access rates, reuse cached detail responses when valid, and back off on temporary failures. Upsert by portal ID, reconcile page overlap, and advance the paging cursor only after a page is committed. Keep the last successful snapshot when a request or parser fails. Treat removal as confirmed only when an authoritative response indicates withdrawal. Keep a save pinned to its original board revision until the player chooses to restart on a newer revision.

## Rule taxonomy

Use stable app rule IDs with localized names, aliases, and descriptions. Store raw portal tag IDs and verbatim author rules alongside normalized matches. Treat a portal label such as **Online solving tool** as catalog metadata. A constraint can be reported by several sources.

| Evidence | How to use it |
| --- | --- |
| Portal tag | Map known tag IDs to categories. This indicates the author tagged the rule. |
| Structured constraint | Read explicit geometry and parameters from an imported puzzle. Use it for automated checking when the corresponding validator supports it. |
| Written rule | Match recognizable phrases in the description. Use matches for discovery and keep custom parameters in the explanation. Interpret the rule’s geometry only where it can be verified. |
| Reviewed custom rule | Record a review or author-provided mapping when a special variant needs one, with its provenance. |

Track coverage and support individually. A catalog row can identify Renban as present even if the importer can only draw the line. A tag-only match cannot establish an exhaustive rule list. For example, the written rules of *Whispers of the Zeitgeist* include Renban, Killer cages, and odd circles, which its displayed portal tags omit. Store absence as uncertain until the available puzzle evidence supports it. [Portal tags guide](https://logic-masters.de/Raetselportal/Hilfe/tags.php?chlang=en) · [Whispers of the Zeitgeist](https://logic-masters.de/Raetselportal/Raetsel/zeigen.php?chlang=en&id=000UN9)

## Formats, storage, and content access

Use a shared versioned board format for an imported square grid, its givens and regions, drawable clues, typed constraints, rules, and optional final validation data. Test with SudokuPad `scl` first, including self-contained links and approved resolution of short links. Treat `fpuz` as a separate adapter with its own fixtures. A shape or styled line may encode artwork only. For rules that need unsupported behavior, such as a reveal trigger the player cannot reproduce, publish a useful diagram if the author provides one and keep the original link available. [SudokuPad format reference](https://github.com/SudokuPad/sudokutools/wiki/Puzzle-Formats) · [Working import reference](https://github.com/StefanLobbenmeier/ninefold#sudokupad-url-import)

Store catalog metadata, rule matches, video matches, revisions, downloads, and saves in Drift records linked by source ID. Keep puzzle downloads and saves tied to their revisions. Download into a pending state. Check that all required content is local, decodable, and compatible before atomically exposing offline availability. Retrying a partial download resumes or replaces pending data while leaving any prior good copy available. Keep original attribution with each saved item.

The project owner has confirmed permission for automatic offline puzzle content from the separate puzzle host. Keep each author’s credit and the Logic Masters portal link with the catalog entry and with downloaded copies. Bundle the authored Sodukromental boards so the Library has puzzles on a fresh offline install.

## Acceptance for the first release

1. From a fresh offline install, open the Library before creating a colony. Verify that authored boards from alternate finale routes and expeditions are available. Find and finish a bundled variant by filtering two rules with **All**. Cold-launch again and confirm the solve persists.
2. Index through the last catalog page and verify that the oldest entries remain searchable. Refresh while an entry shifts across a page boundary. Verify deduplication by ID, locale fallback, attribution, and saved progress on the older downloaded revision.
3. Import a puzzle whose written rules mention a rule absent from its tags. Verify the positive filter finds it and that incomplete data does not assert a negative match. Verify that a localized rule alias resolves to the same rule.
4. Save a structured puzzle and a diagram-only entry. Simulate a failed download, a retry, and an airplane-mode restart. Verify that availability matches the assets actually stored and that a prior usable download stays available.
5. Open a custom-rule puzzle with unknown semantics. Verify its original rule text, author credit, and accurate play, view, or original-link status. Open progress from the Library without affecting the Incremental run.
6. Download an eligible Logic Masters puzzle and open it both normally and with the colony. Make different entries in each and resume both in airplane mode. Confirm that the author’s clues stay identical, that a helper can supply a needed digit, and that clearing the challenge pays once while preserving the campaign stage.
7. On a fresh profile, refresh the catalog and verify that automatic downloads start only after the setting is enabled. Exercise playable, diagram-only, and source-only entries. Interrupt a download, turn the setting off and on, and confirm that remaining jobs resume and an explicitly removed puzzle stays skipped.
8. Import both CtC fixtures. Verify the correct video identity, the different-grid note, and stable **Featured on CtC** ordering. An unrelated channel link or unverified title match should leave the badge empty. Restart in airplane mode and verify that the badge, sort, and stored video link are available.

## Debug catalog snapshot

On 25 November 2026 the listing importer reached page 1,627. Its last page held five entries. Deduplication across moving page boundaries yielded **32,523 portal IDs** in the bundled index. The index provides titles and setter credits before the first network connection. It also includes available difficulty and rating metadata. Ninety-three captured detail pages supplied rule and tag metadata in the snapshot. The app reads additional rules as it refreshes details or the player opens a puzzle.

The bundled featured set contains **67 distinct portal puzzles**. Two have individually reviewed source notes. For the other 65, the exact SudokuPad game on the setter’s puzzle description matched the play frame in the official CtC catalog. The paired watch page supplied the YouTube upload ID and the catalog supplied its date. Entries without a verified match remain eligible for future matching. The app checks additional setter-linked solves on refresh. [Logic Masters Sudoku listing](https://logic-masters.de/Raetselportal/Suche/spezial.php?listname=sudokus) · [Official CtC catalog](https://www.crackingthecryptic.com/sudokus)

The snapshot can be refreshed using `tool/snapshot_catalog.py`, then `tool/snapshot_features.py`. Both require Python and lxml. The feature tool records its cached detail-file map. From the repo root, feed that map into `dart run tool/cache_rule_metadata.dart` to reuse the app’s rule parser. Automatic download of the actual playable puzzles remains a player setting.
