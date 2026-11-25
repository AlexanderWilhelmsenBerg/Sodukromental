# Retained companions

Any creature the player grows can become their companion. It starts with a random personality, then develops habits from shared puzzles and the work the player encourages. Use *Black & White* as inspiration for forming an attachment by observing a creature’s behavior over time. [Peter Molyneux’s Black & White postmortem](https://www.gamedeveloper.com/design/postmortem-lionhead-studios-i-black-white-i-)

## Keeping one creature through prestige

Offer **Keep as companion** in each creature’s profile and let the player confirm their choice in the prestige preview. Reserve one companion slot at no Legacy cost. Carry the same creature ID forward, including its name, generated body, coloration, favorite digit, personality, learned habits, and saved speech. The prestige transaction archives the old colony and transfers the chosen creature to the new run. The archive holds a visual record, and the companion keeps one conversation history.

After prestige, the companion can be invited to the app’s home screen or Library. A returning non-amoeba can rejoin work after the 5×5 clear using the dedicated companion slot. The next run’s milestones govern when its learned work perks become available. Under **One Helper**, it can visit and talk while the amoeba handles the work. If the player retains the previous amoeba, the 3-DNA tutorial action calls that same amoeba back for the fourth 4. The quick opening starts with the returning amoeba in its usual role.

## Learning and roaming

Use a small saved learning model. Each distinct puzzle the companion helps clear adds one shared clear, keyed by run and encounter. A contribution can be carrying a digit the player places, delivering a reveal torch, or finishing a required project for that puzzle. In its profile, **Good job** can remember the type of the last completed task once per encounter. Use that preference to choose between equal-priority jobs, with player orders and required torches still taking precedence.

| Provisional milestone | Behavior |
| --- | --- |
| **2 shared clears** | Remembers the player’s last valid request and can suggest it when stock is low. |
| **4 shared clears and retained through prestige** | Starts visiting familiar parts of the app on its own, such as the home screen, Library edge, and its profile. The player can call it back from the companion control. |
| **6 shared clears and retained through prestige** | May ask whether it can explore outside the app on Android. |

Use visible UI events, known inventory, and the saved habit record. Its personality remains recognizable even as its routines improve. Roaming uses predefined waypoints outside puzzle cells and controls and pauses while the companion has priority work. A reduced-motion setting can show it waiting at its arrival point. Keep in-app visits available on Android, iOS, Windows, and Linux.

## Speech bubbles

In **Talk to creature**, let the player type any phrase they want to teach it. When they send it, save it on the device. The creature sometimes repeats a short part in a speech bubble, such as during a greeting or while waiting by its favorite number. Start playtesting with one echo at most every 90 seconds. Keep each bubble short and let the player mute speech or delete individual phrases.

The player supplies the phrase by sending it through **Talk to creature**. The companion can use its ordinary greetings outside the app. Echoing player phrases outside requires the separate **Allow this phrase outside the app** choice for each phrase, initially off. The Android renderer receives sprite data and the phrases approved for that outing.

## Android home screen visits

The companion asks inside the app, “Can I explore outside the game?” The choices are **Stay here** and **Let it roam**. Selecting **Let it roam** takes the player to Android’s display-over-other-apps setting if needed. Check `Settings.canDrawOverlays()` on return and start the outing only with both the app’s opt-in and Android’s grant. A declined request leaves the companion inside the app. The player can revisit the choice in its profile. [Android special overlay access](https://developer.android.com/reference/android/provider/Settings#canDrawOverlays(android.content.Context))

Use a native Kotlin adapter behind a Flutter platform channel. Declare Android’s `SYSTEM_ALERT_WINDOW` access in builds that ship outside visits. Render the creature in a small, non-focusable `TYPE_APPLICATION_OVERLAY` window that moves among safe points on the home screen or supported app windows. Keep touch bounds close to the sprite and let the rest of the screen work normally. Start while Sodukromental is visible after the player requests an outing. If the outing continues while the app is in the background, use Android’s user-visible foreground service path with **Return to game** and **Stop roaming** actions, subject to the release channel’s service requirements. Recheck the grant at session start and resume. Remove the overlay when roaming stops, the grant is revoked, or the display locks. The window may be hidden by Android or by sensitive screens. [Android application overlays](https://developer.android.com/reference/android/view/WindowManager.LayoutParams#TYPE_APPLICATION_OVERLAY) · [Android service restrictions](https://developer.android.com/develop/background-work/services/fgs/restrictions-bg-start) · [Flutter platform channels](https://docs.flutter.dev/platform-integration/platform-channels)

## Acceptance cases

1. Keep a named creature through prestige and verify that the new run and archived colony show the same saved identity and appearance. A retry of the reset should restore that choice once. Repeat with a retained amoeba and with One Helper.
2. Clear two distinct puzzles with the same creature, replay one, and check that its learned data advances only for new qualifying events. Restore the save and verify it remembers the same preference and phrase list.
3. Teach a phrase, confirm it can appear in an in-app bubble, and delete it. Check that the outside renderer receives player phrases only when explicitly approved.
4. Test the Android ask, grant, refusal, revocation, lock screen, and **Stop roaming** on physical devices. Exercise home screen visits and normal interactions outside the creature’s bounds. Check that in-app visits work on platforms with no system overlay adapter.
