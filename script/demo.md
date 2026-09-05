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

Use CleanShot X **Studio**, with microphone, system audio, and camera off.
Capture a clean region containing the notch and Quick Capture. Exclude personal
windows, desktop icons, notifications, and menu-bar details. Keep raw Studio
projects alongside exports. Add explanatory captions inside the safe margins.

| Shot | Target pace | Action | Caption |
| --- | --- | --- | --- |
| Opening | 4 s | Collapsed notch, then expand | NotchDo 0.3.0 · Capture ideas. Find your focus. |
| Capture | 12 s | Control–Option–R; enter “Prepare the autumn lookbook” | Capture a reminder from any app with a global shortcut. |
| Context | 15 s | Notes “Select six sketches for the first edition”; Studio; Tomorrow; save | Add notes, choose a list, and schedule it before you save. |
| Shortcut | 10 s | Settings; record Control–Option–N; invoke it; dismiss | Make Quick Capture yours with a configurable shortcut. |
| Details | 15 s | Expand notch; open fictional reminder; edit notes, date/time, priority, recurrence | Refine the details without leaving the notch. |
| Scopes | 16 s | Today, Overdue, Scheduled, All Open; hold each 3–4 s | Four smart scopes bring reminders from every list into focus. |
| Search | 10 s | Command–F; type “cafe”; show café match; close once | Find titles instantly. Search understands accents and capitalization. |
| Empty | 7 s | Select Someday | Empty lists are ready for your next idea. |
| Read-only | 7 s | Select Shared inspiration | Browse shared lists safely, with editing disabled when read-only. |
| First list | 10 s | Restart first-list scenario; Create List “Fresh ideas” | A clear first step: create a list and start capturing. |
| Permission | 7 s | Restart permission scenario; show explanatory state | Clear guidance from the very first launch. |
| Closing | 4 s | Return to features; collapse | NotchDo · Your reminders, right on the notch. |

Trim pauses and setup between shots. Preserve readable holds after each action.
Review the complete final export for coverage, caption contrast, cursor pacing,
correct dates, and absence of personal data before attaching it to the draft.
