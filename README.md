# ThumbKey

A small, local macOS app for mapping Razer Naga and Logitech MX Master 3S buttons to shortcuts, held keys, typed text, and macros. Native SwiftUI, macOS 14+, no dependencies, accounts, or network requests.

## Use

Build with `Scripts/build-app.sh`, then open `../ThumbKey.app`. Grant **Input Monitoring** (reads button input) and **Accessibility** (sends shortcuts). Enable mappings in the window. ThumbKey remembers whether mappings were enabled across relaunches, sleep, and reconnects. Pause releases held keys and restores normal mouse reporting.

Select a mouse using its 3D card beside the title. Each card shows battery level, charging state when available, and Wired USB / 2.4 GHz wireless / Bluetooth from the active transport. Refresh updates both cards; unavailable readings are shown explicitly. Then select a button in the rotatable 3D illustration or the matching numbered list and choose an action. Naga users also select the attached **2-, 6-, or 12-button side plate**:

| Action | Behavior |
| --- | --- |
| Keep default action | Leave the input for the mouse or foreground app to handle. |
| Press a shortcut once | Send a shortcut once on each press, such as Copy. |
| Hold keys while pressed | Hold the chosen keys until the mouse button is released. Useful for push-to-talk or a modifier. |
| Run a sequence of actions | Run shortcuts, text, and delays in order. Stops when the active app changes. |
| Disable this button | Ignore presses while mappings are enabled. |

Click the key recorder and press a combination on your regular keyboard. For a modifier alone, press and release it. **Right Command** and **Left Command** are distinguished when recorded alone. Combinations recorded with a regular key use the usual modifier family (for example, Command–C).

**Fill in a dictation shortcut** offers two presets. These fill in keys; they do not launch or configure the other app:

- **Superwhispr**: hold Right Command. Select Right Command as the push-to-talk key in Superwhispr too.
- **LocalScribe**: reads LocalScribe’s current configured keyboard shortcut and fills it as held keys. Reapply the preset if that shortcut changes. If no saved shortcut exists, it uses Control–Option–Space, which is also the initial button 1 mapping for a new configuration.

### MX Master 3S

Five physical presses are supported: Back, Forward, main wheel click, thumb-rest gesture press, and the wheel-mode button. The thumb rest maps its press, not movement gestures. Primary left/right clicks and vertical/horizontal scrolling stay native. Only assigned buttons are temporarily diverted through HID++ 2.0 REPROG_CONTROLS_V4; pause, quit, or a startup failure restores each button’s previous reporting state. No persistent button configuration, DPI, or onboard settings are written. Avoid running another mouse remapper on the same buttons.

The connected Bolt receiver was verified with an MX Master 3S on paired slot 2, including all five temporary button diversions and restoration. Bluetooth has a code path but has not been physically validated. A USB charging cable does not turn an MX Master into a wired data mouse; the card continues to show its actual wireless transport. Receiver presence alone cannot prove the paired mouse is awake; a failed query shows unavailable battery data rather than an invented percentage.

### 3D views

The mouse cards replace the dropdown. The main 3D view rotates and zooms; click a numbered marker to open that button’s editor. Selection also follows the button list, and the current mapping appears below the view. Reset restores the viewing angle. The Naga illustration changes its side pad for the selected plate.

These are original built-in **illustrations with approximate positions**, not the supplied scans or measured CAD. No third-party meshes are bundled. The [downloadable MX scan by Sircher](https://sketchfab.com/3d-models/logitech-mx-master-3s-revopoint-mini-3d-scan-9a82df69ffee4c6faa28f75e65ba192c) is marked CC BY 4.0 but requires Sketchfab sign-in to download. The [supplied Naga scan](https://grabcad.com/library/razer-naga-pro-3d-scans-1) depicts the older Naga Pro, not V3 Pro; its extra-control geometry does not match. Replacing the illustrations with properly licensed, matching assets remains pending.

### Side plates

Each plate has its own saved button mappings; top and ring-finger mappings are shared. Switching plates in the selector changes the displayed side buttons and active mappings immediately, releasing held keys. Existing 12-button mappings and app profiles are preserved and backed up on migration.

**Automatic plate detection is not implemented.** The current hardware research has not established a reliable plate identity signal. Select the attached plate after swapping it. The app deliberately does not guess 6 versus 12 from number keys, because their first six inputs are identical. Physical 6-/2-button plate behavior still needs validation on the mouse. Defaults use keyboard 1–6 for the six-button plate and Back/Forward mouse inputs for the two-button plate; use identification if yours differs.

### Extra controls on Naga V3 Pro

Five additional slots describe their physical positions: two beside left-click, two behind the wheel, and the ring-finger button right of right-click. Enable **extra-button reporting** to use the dedicated reports from firmware-handled controls.

This optional feature uses temporary driver mode (`03 00`) on the V3 Pro USB cable (`1532:00e7`) or USB receiver (`1532:00e8`). It snapshots the original reporting mode, verifies the change, and restores the original mode on pause/quit or startup failure. It never writes onboard button bindings, firmware, DPI, or RGB settings. Unassigned extra controls may lose their usual firmware functions while this mode is active. If the process crashes before cleanup, reconnect the mouse to reset reporting. Bluetooth control is not supported yet.

Initial dedicated codes follow the ongoing [OpenRazer V3 Pro hardware work](https://github.com/openrazer/openrazer/pull/2904): DPI up/down, AI Prompt Master, and Hypershift/ring-finger. **These positions and delivery still require physical validation on each firmware version.** The front button behind the wheel starts unassigned: identify its actual input before mapping it. Check the ring-finger button's physical lock if it cannot be pressed.

### Identify a button

**Identify this physical button…** is only needed if a slot does not respond or responds to the wrong control. Click it, then press that physical mouse button. Identification learns its incoming signal and applies the identity across app profiles for that plate. Other mappings pause during identification, which times out after 15 seconds. It does not assign the action. Conflicting identities within that button group swap atomically; a conflict with another active group is rejected.

Technical input details are collapsed by default. For example, **Keyboard 1** (formerly `HID key 30`) means that the mouse currently sends the input of a keyboard's 1 key. It does not describe the shortcut ThumbKey will send.

## Profiles and storage

**Everywhere** is the fallback profile. **Add app profile** copies it for a running application; that profile applies when the app is foreground. Changes save immediately. Import/export JSON via the ellipsis menu. Imports validate structure/size and back up existing settings. Mappings and macro text stay in `~/Library/Application Support/ThumbKey/bindings.json`.

The menu bar opens the editor, pauses mappings, releases held keys, or quits. Closing the window keeps ThumbKey running. Manual Pause and permission loss cancel automatic recovery. Recovery retries are bounded to three attempts; failed recovery requires enabling mappings again. Held keys have a two-minute release watchdog. Overlapping held shortcuts share modifier ownership so one button cannot release another button's key.

## Input isolation

ThumbKey observes Naga keyboard and mouse HID interfaces nonexclusively. It filters keyboard and auxiliary mouse events only when one-use hardware timestamp evidence identifies the Naga. Left/right/middle click and pointer motion remain native. Other keyboards and mice provide transient collision evidence, not actions. Unmatched or ambiguous events pass through. Dedicated V3 Pro button report 4 is handled separately and cannot collide with ordinary keyboard usages of the same number.

No keyboard history is saved. A bounded in-memory queue holds timing evidence and clears when mapping stops. Candidate events can wait up to 12 ms for HID/collision checks. This is conservative correlation, not a system-provided device identity for every event. Other remappers may conflict. Consumer/media controls and wheel tilt remapping are outside this version. No scripts, shell execution, root helper, or private entitlement are included.

## Build and validation

Requires Swift 6.2+ and a stable Apple Development signing certificate:

```
swift test
Scripts/build-app.sh
```

Override build paths with `THUMBKEY_BUILD_DIR`, `THUMBKEY_CACHE_DIR`, `THUMBKEY_APP_OUTPUT`, and `THUMBKEY_SIGN_IDENTITY`. The build script refuses ad-hoc signing to preserve macOS permission identity across updates. This is a development build, not notarized distribution.

`ThumbKey --devices` lists compatible input interfaces without starting capture. `ThumbKey --check-extra-mode` temporarily enables extra-button reporting, verifies it, then verifies restoration of the original mode; it does not start mappings.

Tests cover configuration migration, per-plate routing/learning, actual V3 keyboard/mouse report descriptors, dedicated reports, mode packet validation, left/right modifier flags, held-key ownership, recovery, and conservative input correlation. See [VALIDATION.md](VALIDATION.md) for completed checks and physical checks still pending.

Protocol research used the [OpenRazer V3 Pro pull request](https://github.com/openrazer/openrazer/pull/2904), [hardware issue](https://github.com/openrazer/openrazer/issues/2885), and [naga-control](https://github.com/Rainexn0b/naga-control). ThumbKey implements the observed wire format independently and includes no code or dependency from those projects.

MX protocol references: [Logitech HID++ feature documentation](https://github.com/Logitech/cpg-docs), [OpenLogi device IDs](https://openlogi.org/hidpp/model-ids), and [Solaar’s observed wire formats](https://github.com/pwr-Solaar/Solaar). ThumbKey implements the protocol independently and bundles no code from these projects. `--check-mx` reads device/control/battery data; `--check-mx-buttons` also verifies temporary diversion and restoration of all five controls without starting mappings.
