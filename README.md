# ThumbKey

A small macOS app that maps the Razer Naga's 12 side buttons to keyboard shortcuts and macros. Native SwiftUI, macOS 14+, no dependencies, no network requests, no Synapse requirement or firmware changes.

## Status

Version 0.1.1 fixes the initial exclusive-capture failure. The app now enables mapping on the connected USB Naga V3 Pro with the normal Input Monitoring and Accessibility grants and passes 15 tests. Physical button delivery still needs hands-on validation. See [VALIDATION.md](VALIDATION.md) for completed and pending checks.

## Use

Build the app using the instructions below, then open `../ThumbKey.app`. Grant **Input Monitoring** and **Accessibility** using the controls in the window, then quit and reopen if macOS requests it. Click **Enable mappings**. The app starts paused on every launch; observation and filtering start only when explicitly enabled.

Select one of the 12 buttons and choose:

- **Original key**: leaves its original keyboard input unchanged.
- **Hotkey**: sends the selected combination once per press.
- **Hold keys**: holds a combination or modifier until the side button is released.
- **Macro**: runs an ordered list of shortcuts, typed text, and delays, once per press. Stops if the active app changes.
- **Do nothing**: swallows that side button while mappings are enabled.

Click the shortcut recorder, then type the combination on your regular keyboard. To record a modifier by itself, press and release it. Button 1 initially holds Control–Option–Space for LocalScribe dictation; LocalScribe must be running with that shortcut configured. Other buttons initially forward their original keys.

Factory input identities are 1–9, 0, minus, equals. Click **Learn this button**, then press that numbered physical side button if your pad uses different inputs. Learning updates all profiles and swaps conflicting slot identities. The latest matched Naga press is shown in the grid, with press/release feedback below it. Numbering follows the labels on the physical plate.

**Everywhere** is the fallback profile. **Add app profile** creates a copy for a currently running application; the matching profile applies automatically when that app is foreground. Changes save immediately. Import/export JSON via the ellipsis menu. Imports validate size/structure and back up the old configuration before replacement.

The menu bar grid icon opens the editor, pauses mapping, releases all held keys, or quits. Closing the window leaves the menu bar app running. Pause or quit restores the original side-pad behavior. Sleep pauses mapping; enable it again when ready. A disconnected device releases owned keys; macros are cancelled. Held keys have a two-minute release watchdog.

## Device access

Only Razer devices whose product name contains Naga and whose HID interface is a keyboard (and not a mouse or built-in device) are eligible. The current connected V3 Pro is USB vendor `1532`, product `00e7`, with boot and extended keyboard reports. The app opens keyboard interfaces nonexclusively and uses a session event filter. It matches each candidate key event against one-use Naga HID evidence using hardware timestamps, rather than treating every press of a number key as a mouse button. Other keyboards provide transient collision evidence. Unmatched or ambiguous events remain native, as do Original key bindings. The pointer interface is not opened or modified. No root helper, private entitlement, firmware remapping, or additional permission is used. Other remappers may still conflict with event filtering.

The descriptor parser supports keyboard array and variable input fields and decodes both actual V3 Pro keyboard descriptors. Media/consumer-control inputs remain native and cannot be learned as side-pad keyboard triggers in this version. Pointer buttons, DPI, RGB, firmware configuration, gaming anti-cheat compatibility, and onboard profiles are outside this version. A button already assigned entirely inside firmware may need its firmware binding restored before it is detectable here. Bluetooth/receiver transports and physical key transitions need hands-on validation; device discovery alone does not prove input capture.

No keyboard event history is saved. A bounded in-memory queue holds hardware timing evidence for correlation, and is cleared when mapping stops. Candidate mouse events may wait up to 12 ms for HID evidence and collision checks. If event timing cannot be matched, that event passes through instead of running a mapping. Exact simultaneous identical inputs are intentionally left native; this is a conservative correlation method, not a system-provided device identifier on each keyboard event. Your chosen mappings and macro text are stored locally at `~/Library/Application Support/ThumbKey/bindings.json`. No script or shell execution is included. Mapping controls require user-granted Input Monitoring and Accessibility; the app does not change macOS privacy settings itself.

## Build

Swift 6.2+ and an Apple Development signing certificate:

```
swift test
Scripts/build-app.sh
```

Build locations can be overridden with `THUMBKEY_BUILD_DIR`, `THUMBKEY_CACHE_DIR`, `THUMBKEY_APP_OUTPUT`, and `THUMBKEY_SIGN_IDENTITY`. The build script refuses ad-hoc signing so permission identity remains stable across updates. This is a development build, not a notarized distribution.

`ThumbKey --devices` enumerates compatible keyboard interfaces without opening input capture. Tests cover device isolation, the actual V3 report layouts, rollover/truncation, overlapping held modifiers, panic release, profile selection, persistence, invalid import rejection, and one-use timestamp correlation including stale evidence and keyboard collisions. Physical button mapping still requires the user's permission grant and a press/release check on the mouse.
