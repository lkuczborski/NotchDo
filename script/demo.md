# NotchDo 0.3.0 recording guide

Run `./script/demo.sh features`, `./script/demo.sh first-list`, or
`./script/demo.sh permission`. Each launch resets the in-memory reminders.
The output defaults to `/tmp/notchdo-v0.3.0-demo/NotchDo Demo.app`; set
`NOTCHDO_DEMO_OUTPUT` to retain it elsewhere.

## Isolation

- `NOTCHDO_DEMO` is a compile-time flag, never a production runtime switch.
- The live `EKEventStore: ReminderEventStore` adapter is excluded. The demo
  uses EventKit only to construct unsaved model objects, as the tests do.
- No live authorization, source/calendar enumeration, fetch, save, or removal
  is called. All lists and reminders are fictional and held in arrays.
- The app requires `com.luku.NotchDo.Demo`, uses that bundle's preferences,
  has no Reminders entitlement or permission usage description, and fakes
  Launch at Login. Links to Apple Reminders and privacy settings are inert.
- Production packaging uses `script/release.sh` without the demo flag or
  demo scratch directory. Never upload the demo app as a distribution build.

## Studio recording plan

Target a captivating 35–45 second reel. Start with an empty desktop and the
collapsed app. Invoke global Quick Capture directly, add a fictional reminder
with notes and a date, then expand the notch to reveal that same reminder.
Follow with one Today view and brief Command–F search. Omit the menu-based
capture opening, exhaustive scope tour, onboarding, and empty states.

Use CleanShot X **Studio**, with microphone, system audio, and camera off.
Keep raw Studio projects and exports in the ignored `recordings/` directory.
Verify a short test take before the full capture: unrelated windows can remain
visible in the actual screen recording even when app-isolated UI screenshots
look clean. Reject any take containing personal desktop content or unrelated
windows; never upload rejected takes.

Add brief explanatory captions in editing. Trim pauses, preserve readable
holds, and review the complete final export for framing, text readability,
pacing, and absence of personal data before attaching it to the draft release.
