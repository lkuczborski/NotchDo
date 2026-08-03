# NotchDo Agent Guide

## Project

- NotchDo is a SwiftPM macOS 14+ app built with Swift 6.2. It is a minimal, notch-hosted Apple Reminders client.
- Keep changes native, focused, and consistent with the existing structure under `Sources/NotchDo/{App,Models,Stores,Support,Views,Windowing}`.
- Prefer one named type per Swift file, in production code and tests. Name files after their primary type.
- Keep UI state on `@MainActor` and use the Observation framework for shared observable state. Avoid broad invalidations in reminder lists and rows.

## UI Architecture

- Use SwiftUI first for all UI, layout, animation, input, accessibility, drag/drop, menus, and presentation.
- Fall back to AppKit only when SwiftUI cannot provide the required macOS behavior. Keep such code narrowly isolated in `Windowing` or a small bridge/representable, and document why the fallback is necessary.
- The AppKit panel is a fixed WindowServer surface sized for the expanded view; animate the SwiftUI surface/mask rather than resizing the panel during expansion.
- Preserve the compact, minimal visual language and fluid hover/expand/collapse behavior. Respect Reduce Motion and maintain keyboard and VoiceOver semantics; use semantic SwiftUI controls instead of gesture-only interactions.
- For visual or interaction changes, verify the actual running app, including collapsed and expanded states, focus, popovers, scrolling, and outside-click behavior.

## Reminders and Data Integrity

- EventKit is the sole source of truth. Do not add a separate task database, cloud service, or shadow copy of reminder data.
- Mutate existing `EKReminder` objects instead of reconstructing them so fields NotchDo does not expose remain intact.
- Treat synchronization as two-way wherever public EventKit APIs permit it. Handle authorization, external-change notifications, stale async reloads, optimistic updates, rollback, and visible failures deliberately.
- Preserve the reminder order returned by EventKit. Its public API exposes no manual sort-position metadata, so do not claim or implement persistent reordering without a supported API.
- Tests must use the `ReminderEventStore` seam and fakes; never read or modify the user's real Reminders data.

## Tests

- Use Apple's Swift Testing framework exclusively: `import Testing`, `@Suite`, `@Test`, `#expect`, `#require`, and `Issue.record`. Do not add XCTest test cases or assertions.
- Add meaningful behavior and regression tests, especially for failure paths, rollbacks, async races, interaction transitions, formatting boundaries, and geometry. Do not add tests that merely execute SwiftUI view bodies or inflate coverage.
- Keep tests deterministic with injected clocks, fixed calendars/time zones, isolated `UserDefaults` suites, and EventKit fakes. Serialize tests that share main-actor or process-global state.

## Verification

- Run release tests after behavioral changes: `swift test --configuration release`.
- Run a release build for production-code changes: `swift build --configuration release`.
- For app-level or UI changes, bundle, launch, and verify with `./script/build_and_run.sh --verify`; use the other modes documented in `README.md` when debugging.
- Keep `README.md` user-facing. Put maintainer-only signing, notarization, and publishing logic in `script/release.sh` rather than expanding the README.
- Do not modify generated/local artifacts in `.build/`, `dist/`, `Design/`, or QA image files.
