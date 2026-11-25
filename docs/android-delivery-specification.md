# Android CI, APK releases, and updates

The current [release plan](release-plan.md) ends at an Android debug APK for tester feedback. Use the debug workflow and preview handoff in this stage. The production release steps and live stable update verification define the follow-on stage.

## Continuous integration

Add a required GitHub Actions check for pull requests and pushes to the default branch. Pin Flutter, the JDK, and the Android build tools used by CI. Resolve Dart packages from the committed lockfile. Run formatting, analysis, and the regression suite before running Android integration tests on an emulator. Use the same jobs for the exact commit submitted to the manual build. [Flutter testing](https://docs.flutter.dev/testing/overview)

| Test layer | Required regression coverage |
| --- | --- |
| Puzzle rules | Confirm the documented four-slide opener, reject lock moves, award the three DNA once, and verify uniquely solvable 5×5 through 9×9 growth fixtures with preserved tile counts. Test constraint and fog reveal fixtures before adding each campaign puzzle. |
| Colony and persistence | Verify growth path dependencies, seeded creature identities, upgrade costs, offline payouts, inventory conservation during offers and pranks, and exactly-once prestige with a retained companion and its learned habits. |
| Library and updates | Use local fixtures for Logic Masters imports, featured-video matching, offline download defaults, save migrations, and release metadata. Exercise duplicate, partial, unavailable, and offline responses. |
| Widgets and device | Use a scripted Android flow from the first slide through the amoeba’s delivery and the first constructed creature. Resume an offline save, place a digit with touch, and install a higher-version APK over an earlier signed test APK. Test portrait and gravity separately on a physical phone. |

Keep network responses, clocks, and creature seeds controllable in tests. Save failure logs and screenshots from integration tests to the workflow. Ordinary pull request checks use test signing and fixture data.

## Manual Build APK workflow

Add `.github/workflows/build-apk.yml` to the default branch when the Flutter Android project is present. The **Run workflow** menu exposes one dropdown. [GitHub Actions workflow inputs](https://docs.github.com/en/actions/reference/workflows-and-actions/workflow-syntax#onworkflow_dispatchinputs)

```yaml
name: Build APK
on:
  workflow_dispatch:
    inputs:
      build_type:
        description: Android APK type
        required: true
        type: choice
        default: debug
        options:
          - debug
          - release
```

| Dropdown value | Build and output |
| --- | --- |
| **debug** | Run the shared checks, build with `flutter build apk --debug`, and upload the installable debug APK as an Actions artifact. Give it a separate application ID suffix so a tester can keep the public app installed alongside it. |
| **release** | Run the shared checks on the selected default-branch commit, then use `flutter build apk --release` with the persistent release signing key. Build one universal APK. Upload it as an Actions artifact and publish it to a new GitHub Release. [Flutter APK commands and signing](https://docs.flutter.dev/deployment/android) |

### Debug preview handoff

Use the tested debug APK from Actions or the verified local build. Record its checksum, source commit, debug application ID, installed version, and test results. Deliver the artifact with installation instructions, known limits, and the feedback scenarios in the release plan. For an authorized public GitHub preview, attach those exact bytes to a prerelease such as `v0.1.0-debug.1`. GitHub’s latest stable endpoint excludes prereleases. Exercise the stable update rules with fixtures in the debug build. [Get the latest release](https://docs.github.com/en/rest/releases/releases#get-the-latest-release)

Use an authorized persistent debug signing key when one is available for preview-to-preview upgrades. Test save-preserving upgrades with the same test key. If successive preview builds use different debug signatures, state the install behavior in the handoff.

### Stable release follow-on

Use the committed Flutter `version` value in `pubspec.yaml` as the source of the release name and Android build number. For example, `1.2.0+12` produces tag `v1.2.0`, version code `12`, and asset `sodukromental-1.2.0-android.apk`. Require a greater semantic version and version code than the previous public Android release. Inspect the APK package ID and version after the build and verify the release signer with `apksigner`. [Android versioning](https://developer.android.com/studio/publish/versioning) · [apksigner](https://developer.android.com/tools/apksigner)

Build and publish in separate jobs. Store the release signing key and passwords in GitHub secrets scoped to release builds. Recover the keystore only in the signing job’s temporary workspace and keep a separate backup of the persistent key. Grant `contents: write` only to the publishing job. Run release jobs serially and use the checked commit SHA as the tag target.

Create or resume a draft tied to that tag and commit. Attach the verified APK, its SHA-256 checksum, and a compact `android-update.json` with the application ID, version, version code, and APK asset name. Publish only after the assets are present and mark it as the latest stable release. If the tag belongs to a different commit, fail with the conflicting tag. Rerunning an already published version reports the existing release. [GitHub CLI release creation](https://cli.github.com/manual/gh_release_create) · [GitHub Releases API](https://docs.github.com/en/rest/releases/releases)

## Detecting an app update

Enable GitHub release checks in the GitHub-distributed Android build. Read the installed version and build number through `package_info_plus`. Query the [public latest-release endpoint](https://api.github.com/repos/AlexanderWilhelmsenBerg/Sodukromental/releases/latest) after launch or resume, at most once every 24 hours after a successful automatic check. Back off after temporary failures and respect any retry window supplied by the server. Offer **Check for updates** in Settings. Cache the release and use conditional requests when the server has supplied an ETag. [package_info_plus](https://pub.dev/packages/package_info_plus) · [GitHub REST request guidance](https://docs.github.com/en/rest/using-the-rest-api/best-practices-for-using-the-rest-api)

Read `android-update.json` from the release assets and validate that it matches the tag, the installed application ID, and an APK asset on the release. A newer stable release has both a greater semantic version and a greater Android version code. Use numeric version comparison so `1.10.0` sorts after `1.9.0`. Treat an absent release, offline access, a malformed response, and a rate limit as distinct check outcomes. Preserve the last validated release on temporary errors.

For a newer Android release, show a dismissible **Update available** banner with the version and a **View release** button. Keep a Settings entry for that update after dismissal and show the banner again for the next version. Put the banner outside an active puzzle. The button opens the published GitHub release through `url_launcher`, where the user can download the signed APK and use Android’s installer. GitHub’s latest-release endpoint returns public stable releases. [Get the latest release](https://docs.github.com/en/rest/releases/releases#get-the-latest-release)

## Acceptance

1. The workflow dropdown defaults to Debug. A debug run produces an installable APK in Actions and launches on Android. Verify the debug handoff checksum against those tested bytes.
2. Install the initial signed test build and create a campaign and Library save. Expose a newer release through a fixture endpoint. Verify the banner, settings entry, and release link. Install a build signed by the same test key with a higher version code and verify that both saves reopen.
3. Test `1.9.0` to `1.10.0`, a missing APK, a mismatched package ID, an unchanged release, and a throttled or offline request. Confirm that only a validated newer version prompts the player.
4. In the stable release stage, verify that the release path stops on failed tests, a signature mismatch, or an incompatible version code. Verify a successful publish has one tag at the checked commit, a signed APK, and matching update metadata. Retry a draft and an existing public release.
