# Demo testing and recording

Always use the demo app for manual feature testing, UI verification, screenshots,
and recordings. It uses fictional in-memory reminders and cannot read or modify
personal Apple Reminders data.

## Launch

Quit the production NotchDo app first. The launcher refuses to start while it
is running so Quick Capture cannot open the production app and expose real
reminders. Keep production NotchDo closed throughout testing or recording.

```sh
./script/demo.sh features
```

Each launch resets the fixtures. Other scenarios:

- `./script/demo.sh first-list`: no lists, for testing list creation.
- `./script/demo.sh permission`: simulated permission state.

The app is built at `/tmp/notchdo-demo/NotchDo Demo.app`. Set
`NOTCHDO_DEMO_OUTPUT` to use another location outside the repository.
The demo has separate preferences; check its Settings for the configured
Quick Capture shortcut.

## Isolation

- `NOTCHDO_DEMO` is a compile-time flag, not a production setting.
- The live EventKit adapter is excluded. EventKit only constructs unsaved
  model objects; all lists and reminders are held in memory.
- The demo requires the `com.luku.NotchDo.Demo` bundle identifier and has no
  Reminders entitlement or permission usage description.
- Launch at Login is simulated. Links to Apple Reminders and privacy settings
  are disabled.
- Never distribute the demo app. Production packaging uses `script/release.sh`
  without the demo flag or its build directory.

## Recording

- Launch the demo before preparing the recording.
- Hide unrelated windows and personal desktop content. Confirm the actual
  recording area; app-isolated screenshots do not show every visible window.
- Keep recordings and editing files outside the repository.
- Show the relevant workflow, trim pauses, and keep text readable.
- Review the exported recording for personal content and framing before sharing.
