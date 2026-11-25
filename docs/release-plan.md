# Sodukromental Android debug release plan

## Project product

Deliver an installable **Android debug APK** for end-to-end testing and player feedback. Include the campaign, standalone Sudoku Library, procedural creature creator, and companion features defined in the specifications. Hand over the APK, checksum, commit and build identifiers, test evidence, known limitations, and a short test and feedback guide. Publish the reviewed APK as a GitHub prerelease when authorized. An Actions artifact can also provide the same checked APK to testers with access.

The debug release tests whether the opening is discoverable, whether helpers and variant rules make later puzzles fun, and whether both modes work offline. A stable Android release follows feedback as a later project decision. The [Android delivery specification](android-delivery-specification.md) defines both distribution paths.

**Baseline.** The checkout contains the specifications and design. Prior checks found a configured GitHub default branch of `main` with no branches, workflows, or releases. The integration listed workflows and returned HTTP 403 on Actions settings and the repository secrets public-key endpoint. Verify workflow push and dispatch with the first debug build. Debug builds can use Android’s debug signing. The owner has confirmed automatic offline access to the separately hosted puzzle content.

## PRINCE2 delivery phases

Use five management stages. The [slice register](debug-release-slices.md) treats each slice as a small work package with an owner, dependencies, a product, and acceptance evidence. Build and review in dependency order, and run independent slices in parallel within the active phase. Review the product and whether it still supports the feedback goal before proceeding.

| Phase | Slices | Product | Evidence at the stage boundary |
| --- | --- | --- | --- |
| **1. Initiate and build the foundation** | F1–F3 | Pinned Flutter project, versioned shared contracts, regression CI, and a debug APK. | A clean checkout formats, analyzes, tests, builds, installs, and launches. Confirm the workflow path and record emulator and physical test availability. |
| **2. First playable build** | P1–P5 | The verified 4×4 opening through 5×5 and the first designed helper and nest, with a standalone Library sample. | Complete the opening on a clean install, interrupt a delivery, and resume offline. Settle the starter economy and both work-perk choices. Produce a debug APK for early testing. |
| **3. Complete campaign and Library** | C1–C7 and L1–L5 | All 28 authored boards, the three finale routes and prestige, and the full Logic Masters Library integration. | Validate all boards and reveal paths, complete a 16-board route with the original amoeba, and verify standalone Library access, catalog coverage, and an offline colony challenge. |
| **4. Companions and device readiness** | D1–D5 | Retained companions, speech, opt-in roaming, tilt, and accessible presentation. | Verify companion identity and speech through prestige, run Android permission and sensor scenarios, and review the Hallmark screens at test widths. Label physical observations and platform compile results with their evidence. |
| **5. Verify and hand over the debug release** | R1–R3 | The reviewed APK, release notes and evidence, and a feedback register. | Reinstall the delivered artifact, match it to the tested commit and checksum, run the launch and offline smoke flows, and hand it over with reproducible test scenarios. |

## Roles and controls

The project owner represents the business and user interests and sets the release objective. The project manager is the coordinator for scope, cross-module interfaces, forecasts, and stage decisions within the agreed tolerance. The technical lead represents supplier interests and checks feasibility. Implementation agents deliver assigned work packages. An independent reviewer performs product assurance on the tested revision. The same plan and slice register hold product descriptions, progress, evidence links, risks, issues, and lessons to keep administration proportionate.

| Agent lane | Standing instructions |
| --- | --- |
| **Foundation and CI** | Own the Flutter scaffold, build hosts, dependency lock, shared contracts, migrations, and CI. Provide deterministic clock, network, and device fixtures. Verify the normal debug workflow before other agents depend on it. |
| **Puzzle engine and content** | Own board rules, puzzle assets, and logical validation. Use the existing verified fixtures and write original boards. Supply uniqueness and visible-deduction evidence, including fog reveal order. |
| **Colony and companions** | Own resource transactions, worker schedules, growth paths, procedural identities, settlement work, and prestige. Test inventory and jobs across retries and restores. Keep taught phrases tied to explicit player submissions. |
| **Library and sources** | Own the approved Logic Masters integration, complete catalog crawl, downloads, rule evidence, CtC matching, and standalone Library state. Use real samples and controlled fixtures. |
| **Hallmark UI and art** | Own Flutter screens and Flame presentation. Use the design tokens, original pixel layers, and accessible interactions. Keep device-specific commands behind the shared interfaces. |
| **Android delivery** | Own tilt, overlay permissions, the debug workflow and tester artifact. Test Android controls on the emulator and record physical results where a device is available. Keep production signing and publishing in the follow-on plan. |
| **Independent verification** | Check the finished commit against the acceptance evidence. Report reproduction steps, actual test results, device and OS, and release blockers. Keep this review separate from implementation. |

### Review and coordination on every slice

The story, game mechanics, and UI/UX agents each review **every debug slice**, including build and data work. For infrastructure, reviewers examine a concrete player consequence such as a lost companion on upgrade, a misleading availability label, or a hard-to-reproduce feedback report. Record one testable observation or a reasoned pass per discipline and slice. The [coordinator review](agent-review.md) links the three inputs, the decision, the owner of a change, and the resulting evidence.

| Agent | Instructions and decision boundary |
| --- | --- |
| Story | Read the acceptance scenario in order as a first-time player. Check what the player knows, the helper’s motive, whether the reaction communicates the rule, and whether any dialogue, identity, or attribution survives a restart. Return a slice ID, observation, proposed action, and observable result. |
| Game mechanics | Play or simulate the happy path and one interruption or counterexample. Check solveability, inventories, earned resources, unlocks, retries and replay. Supply a reproducible move sequence, seed, fixture, or invariant. |
| UI/UX designer | Inspect the slice via touch, tap selection, keyboard, and assistive labels as applicable. Check the portrait board, narrow screens, contrast, motion alternatives, visual feedback, empty states, and permission wording. Give a precise screen, action, and expected result. |
| Review coordinator and independent assurance | Combine the three reviews per slice. Resolve duplicate findings, give implementers concrete changes, and request a retest of the same scenario. Record both accepted changes and declined suggestions with reasons. Verify builds independently. |
| Project manager and architect | Own stage decisions, module contracts and integration. Settle conflicting recommendations against the intended player experience and release tests. Retain open evidence gaps in the register. Authorize reversible engineering and balance choices within the debug scope. |

Implementation agents work in disjoint file areas in the shared checkout using the same pinned dependencies. Reuse economical agents across slices and reserve architectural decisions for integration. The story, mechanics and UI/UX agents can also implement their own assigned components. Independent assurance and the project manager retain acceptance authority. A review pass contains the initial finding, the coordinator decision, the implementation change, and the independent result on the current build. The tester handoff identifies checks still requiring a physical device.

## Tolerances and exceptions

- **Scope and benefits.** Accept the Required slices before handoff. Record field observations and any identified follow-on work in the register. Reassess whether each phase still supports app testing and actionable feedback.
- **Quality and risk.** A reproducible crash in a required flow, save loss, an unsolvable required board, or an overlay consent bypass blocks the debug handoff. Test real tilt and overlay behavior on an available physical device. If emulator checks pass and a physical check remains outstanding, label that check explicitly for device feedback before stable publication.
- **Time, cost, and sustainability.** Forecast effort after the scaffold exposes the actual build and test times. Reuse committed fixtures, caches, and existing runners. The coordinator manages ordinary trade-offs inside the approved scope and authorized resources.
- **Exceptions.** Escalate a forecast breach when it changes the agreed deliverable, needs new spending or access, or weakens a required quality check. State the impact and options. Continue unaffected slices while resolving the exception.

Check GitHub workflow push and dispatch early. If the Actions path is blocked, complete and verify a local debug APK through an authorized emulator or device and record the outstanding CI or publication evidence. Obtain real sample payloads and continue past absent formats using the Library’s specified diagram and original-link states. Mark a source outage separately from a failed app behavior.

| Risk to watch | Owner | Response |
| --- | --- | --- |
| Workflow write or dispatch fails under the current GitHub integration. | Foundation | Test both in Phase 1. Preserve the tested local APK and identify the exact permission needed for the Actions evidence. |
| A late board is ambiguous or fog hides a required deduction. | Puzzle | Validate the solution and visible solve path as each board is authored. Batch solver runs and fix failed boards before the campaign gate. |
| Pagination or a separate payload host changes. | Library | Check live samples early, retain committed pages on failure, and replay controlled fixtures against the changed adapter. |
| Tilt or companion behavior differs by device. | Android | Exercise emulator states before handoff. Record device and OS for physical checks, and direct feedback to D2 or D3 when field evidence is pending. |

At each stage boundary, record the accepted slice IDs, outstanding exceptions, estimated effort for the next phase, and lessons applied to the next work packages. Use the register and its evidence links for the status report.

## Debug handoff and feedback

Use the **Debug** path in Build APK for the Android candidate. The optional public GitHub prerelease uses the tested bytes and a preview tag such as `v0.1.0-debug.1`. The stable update channel uses GitHub’s latest stable release endpoint. [GitHub releases](https://docs.github.com/en/rest/releases/releases#get-the-latest-release)

Include test prompts for the three draggable 4s, first helper and creature choice, offline Library and CtC sorting, the late variant and prestige flows, and companion permission behavior. Log the build, device and OS, slice ID, reproduction and expected result, severity, next action, and acceptance test for each report. Fix blockers first and retest the same slice. Keep playability and balance findings for the next debug iteration.

Close this project stage with the downloadable debug build and evidence. Use the findings to decide the next work package. Production signing, stable publish and live update verification stay tracked in the [follow-on slices](debug-release-slices.md#stable-release-follow-on).
