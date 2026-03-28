# UCBuddy

macOS menu bar app that keeps Universal Control from being annoying.

If you use UC to share a keyboard/mouse across multiple Macs, you've hit these:
- The connection randomly drops and you have to open Display settings to kick it back
- Your modifier key swaps (Ctrl↔Cmd, etc.) keep reverting on the connected machine's virtual keyboard

UCBuddy sits in your menu bar and quietly fixes both. No Accessibility permissions, no kernel extensions, no bullshit.

## What it does

**Connection Guardian** - Polls Universal Control's network state every 10 seconds. If the connection drops, it auto-restarts UC (which re-launches via launchd). Configurable grace period so it doesn't spam restarts.

**Key Remap Persist** - Reads your physical keyboard's modifier key config from System Settings and mirrors it to the UC virtual keyboard. Checks every 30 seconds and re-applies when UC inevitably resets it. Uses the same `com.apple.keyboard.modifiermapping` mechanism as System Settings - doesn't fight with it.

Both are toggleable. Disable what you don't need.

## Install

```bash
swift build -c release
./bundle.sh
cp -r .build/release/UCBuddy.app /Applications/
open /Applications/UCBuddy.app
```

Enable **Launch at Login** in the menu bar dropdown so it runs on boot.

## Which machine?

Run UCBuddy on the Mac you're connecting TO (Machine B). That's the one whose virtual keyboard keeps losing its modifier config. Connection Guardian works from either machine, but the key remap fix specifically targets the virtual keyboard that UC creates on the receiving end.

## How it works under the hood

- UC monitoring: `pgrep -x UniversalControl` → `lsof -a -i -p <PID>` counting ESTABLISHED connections
- UC restart: `killall UniversalControl` (launchd brings it right back)
- Key remapping: `defaults -currentHost write -g com.apple.keyboard.modifiermapping.0-0-0` (the virtual KB entry)
- No `hidutil property --set` (that's a global sledgehammer that fights with System Settings)
- No sandbox, no privileged helpers, no Accessibility - just `Process()` calls to standard macOS tools

## Debug

```bash
log stream --predicate 'subsystem == "com.ucbuddy"'
```

Or click **Debug** in the menu bar popover.

## License

MIT
