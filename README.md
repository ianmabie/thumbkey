# ThumbKey

A small, local macOS app for mapping Razer Naga and Logitech MX Master 3S buttons to shortcuts, held keys, typed text, and macros. Native SwiftUI, macOS 14+, no dependencies, accounts, or network requests.

## Native macOS interface

The main window uses a standard SwiftUI unified toolbar for profiles, status, refresh, mapping controls, and import/export. Mouse render cards remain directly selectable. Editing uses a grouped native Form; List view uses standard selectable rows with keyboard navigation. View angles use a native segmented picker that also shows Custom after manual rotation. Shortcut recording uses a SwiftUI button with an AppKit keyboard responder, preserving individual modifier keys such as Right Command. The floating shortcut overlay uses system Liquid Glass on macOS 26 or later, with regular-material and Reduce Transparency fallbacks. SceneKit and input capture retain their platform bridges.

## Use

Build with `Scripts/build-app.sh`, then open `../ThumbKey.app`. Grant **Input Monitoring** (reads button input) and **Accessibility** (sends shortcuts). Enable mappings in the window. ThumbKey remembers whether mappings were enabled across relaunches, sleep, and reconnects. Pause releases held keys and restores normal mouse reporting.

Select a mouse using its 3D card beside the title. Each card shows battery level, charging state when available, and Wired USB / 2.4 GHz wireless / Bluetooth from the active transport. Refresh updates both cards; unavailable readings are shown explicitly. Choose **3D view** to select buttons on the mouse, or **List view** for labeled button rows, then choose an action. Only one view is shown at a time, and ThumbKey remembers your view preference. Use **Bottom** to inspect the base, or drag to rotate freely upside down. The underside switches and sensors are visual details; the button list contains the controls ThumbKey can map. Naga users also select the attached **2-, 6-, or 12-button side plate**:

| Action | Behavior |
| --- | --- |
| Keep default action | Leave the input for the mouse or foreground app to handle. |
| Press a shortcut once | Send a shortcut once on each press, such as Copy. |
| Hold keys while pressed | Hold the chosen keys until the mouse button is released. Useful for push-to-talk or a modifier. |
| Run a sequence of actions | Run shortcuts, text, and delays in order. Stops when the active app changes. |
| Disable this button | Ignore presses while mappings are enabled. |

Click the key recorder and press a combination on your regular keyboard. For a modifier alone, press and release it. **Right Command** and **Left Command** are distinguished when recorded alone. Combinations recorded with a regular key use the usual modifier family (for example, Command–C).

The **Action** menu also includes named **macOS actions**: Mission Control (Control–↑), App Exposé (Control–↓), Show Desktop (F11), Previous Desktop (Control–←), and Next Desktop (Control–→). These send the standard shortcut once per press, show the action name in the mapping view, and provide a test button without recording any keys. Existing custom names and saved shortcuts are preserved. The corresponding shortcut must be enabled in System Settings → Keyboard → Keyboard Shortcuts → Mission Control. If you customized those system keys, use **Press a shortcut once** with your chosen combination instead.

**Action → Figma → Drag canvas (hold button)** holds Space and the left mouse button together. In Figma, hold that button and move the mouse to drag the canvas; release to stop and restore the previous tool. Switching apps, pausing mappings, disconnecting, or the two-minute hold limit ends the drag. Click the canvas first if text editing has focus. Add a Figma app profile before assigning it if you want the button to keep its other action in other apps. You can also record Space using **Hold keys while pressed**.

**Action → Figma → Add comment (C)** sends C once to enter [Figma’s comment mode](https://help.figma.com/hc/en-us/articles/360041068574-Add-comments-to-files). Click the canvas where you want the comment, then type your message. Press Escape to leave comment mode. Click the canvas first if a text field is focused; use a Figma app profile to limit this assignment to Figma.

**Action → Figma** also includes three canvas zoom presets:

- **Zoom with scroll wheel (hold ⌘)**: hold one assigned mouse button and scroll over the canvas in either direction. Releasing the button restores normal scrolling.
- **Zoom in** and **Zoom out**: send Command–plus or Command–minus once per press; assign each direction to its own button.

These use [Figma’s canvas zoom controls](https://help.figma.com/hc/en-us/articles/360041065034-Adjust-your-zoom-and-view-options). Use a Figma app profile if you want other apps to keep their current assignments.

**Fill in a dictation shortcut** offers two presets. These fill in keys; they do not launch or configure the other app:

- **Superwhispr**: hold Right Command. Select Right Command as the push-to-talk key in Superwhispr too.
- **LocalScribe**: reads LocalScribe’s current configured keyboard shortcut and fills it as held keys. Reapply the preset if that shortcut changes. If no saved shortcut exists, it uses Control–Option–Space, which is also the initial button 1 mapping for a new configuration.

### Shortcut reference

Open ThumbKey’s menu bar icon to see the configured actions for the active mouse, side plate, and foreground app profile. Each row names the physical button, action, and keys; click a row to edit that mapping. Unassigned, disabled, and unfinished actions are omitted. Macro contents are represented by action counts.

Choose **Action → ThumbKey → Show shortcut overlay** on any button to show a floating shortcut reference while held. The menu bar also offers **Show shortcut overlay**, and the button editor provides a preview. The overlay leaves keyboard focus in the foreground app, follows its profile, and hides when you release the button. If two overlay buttons are held, it stays visible until both are released; Escape or the close button dismisses early. Menu-bar and editor previews can also be dismissed with an outside click. Configured extra controls that are unavailable or need identification are labeled accordingly. Pausing or changing mouse capture closes the overlay.

### MX Master 3S

Five physical presses are supported: Back, Forward, main wheel click, thumb-rest gesture press, and the wheel-mode button. The thumb rest maps its press, not movement gestures. Primary left/right clicks and vertical/horizontal scrolling stay native. Only assigned buttons are temporarily diverted through HID++ 2.0 REPROG_CONTROLS_V4; pause, quit, or a startup failure restores each button’s previous reporting state. No persistent button configuration, DPI, or onboard settings are written. Avoid running another mouse remapper on the same buttons.

The connected Bolt receiver was verified with an MX Master 3S on paired slot 2, including all five temporary button diversions and restoration. Bluetooth has a code path but has not been physically validated. A USB charging cable does not turn an MX Master into a wired data mouse; the card continues to show its actual wireless transport. Receiver presence alone cannot prove the paired mouse is awake; a failed query shows unavailable battery data rather than an invented percentage.

### 3D views

The mouse cards replace the dropdown. Drag the main 3D view to rotate it; scrolling moves the surrounding page. Click a visible control to open that button’s editor. Switch to **List view** to select from labeled rows instead; selection and the editor are shared between both views. The list shows each physical button and its assigned action, including custom names. Extra-button reporting is available in a disclosure below the Naga map in either view. The current mapping appears below the 3D view. The angle buttons restore their view even after manual rotation, including when you click the same angle again. Reset returns to Overview. Both the Naga card and the main illustration show the selected side plate, with the same physical button arrangement as the list.

These are original **photo-referenced 3D illustrations**, created from multiple manufacturer views rather than downloaded scans. They include smooth shell meshes, curved click panels, wheel grooves, MX thumb-rest details, the Naga ring-finger control, and separate plate geometry. The 12-button plate uses four columns of three; the six-button plate uses curved rows. Thumb / Top / Right presets make hidden controls easier to find. Positions remain approximate, not measured CAD; the hardware mapping itself is separate from this visualization. No Sketchfab account or internet connection is required. See [model references and construction](MODEL-REFERENCES.md).

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

If macOS Secure Input is active, ThumbKey shows **Blocked by Secure Input**, releases held keys and waits without spending its reconnect attempts. Keyboard-style side buttons keep their original output in this state. Close password prompts or lock and unlock the Mac; if Secure Input remains stuck, save your work and log out or restart. Mappings resume automatically when it clears, unless you manually paused them. ThumbKey does not disable Secure Input. See [Apple's explanation](https://developer.apple.com/library/archive/technotes/tn2150/_index.html).

**Test shortcut** checks the selected shortcut independently of physical mouse detection. Held shortcuts are sent for three seconds and then released. For LocalScribe push-to-talk, use **Hold keys while pressed** and **Fill in a dictation shortcut → LocalScribe** to copy its current shortcut. A successful shortcut test checks delivery to the other app; it does not prove that macOS is allowing physical mouse input to be observed.

## Input isolation

Mouse selection uses cached 3D scenes and performs connection/battery requests in the background. Cards distinguish **Connected**, **Receiver detected** (the receiver is present but the mouse has not yet been confirmed awake), and **Not detected**. Disconnected mice remain selectable for editing saved mappings. Battery is shown only when an actual percentage is available; Naga receiver battery queries are currently unsupported and hidden. If an asleep mouse does not answer, wake it and use Refresh, or select another mouse; this does not turn off your mapping preference.

If optional Naga extra-button reporting fails, the standard side-panel mappings continue working. The app explains that the extra controls are unavailable rather than pausing every button. Bluetooth/receiver support for those extra controls is still limited as described above.

ThumbKey observes Naga keyboard and mouse HID interfaces nonexclusively. It filters keyboard and auxiliary mouse events only when one-use hardware timestamp evidence identifies the Naga. Left/right/middle click and pointer motion remain native. Other keyboards and mice provide transient collision evidence, not actions. Unmatched or ambiguous events pass through. Dedicated V3 Pro button report 4 is handled separately and cannot collide with ordinary keyboard usages of the same number.

No keyboard history is saved. A bounded in-memory queue holds timing evidence and clears when mapping stops. The input filter matches Naga reports to events at the HID boundary using their original hardware timestamp. Matching evidence routes immediately; missing evidence waits at most 12 ms and then leaves the event native. Ambiguous input also stays native. A dedicated action queue sends shortcuts independently of the app’s UI, including while window overview animations run. Other remappers may conflict. Consumer/media controls and wheel tilt remapping are outside this version. No scripts, shell execution, root helper, or private entitlement are included.

## Build and validation

Requires Swift 6.2+ and a stable Apple Development signing certificate:

```
swift test
Scripts/build-app.sh
```

Override build paths with `THUMBKEY_BUILD_DIR`, `THUMBKEY_CACHE_DIR`, `THUMBKEY_APP_OUTPUT`, and `THUMBKEY_SIGN_IDENTITY`. The build script refuses ad-hoc signing to preserve macOS permission identity across updates. This is a development build, not notarized distribution.

`ThumbKey --devices` lists compatible input interfaces without starting capture. `ThumbKey --check-extra-mode` temporarily enables extra-button reporting, verifies it, then verifies restoration of the original mode; it does not start mappings.

Tests cover configuration migration, per-plate routing/learning, actual V3 keyboard/mouse report descriptors, dedicated reports, mode packet validation, left/right modifier flags, held-key ownership, recovery, exact hardware-timestamp correlation, rapid action delivery, and cancellation. See [VALIDATION.md](VALIDATION.md) for completed checks and physical checks still pending.

Protocol research used the [OpenRazer V3 Pro pull request](https://github.com/openrazer/openrazer/pull/2904), [hardware issue](https://github.com/openrazer/openrazer/issues/2885), and [naga-control](https://github.com/Rainexn0b/naga-control). ThumbKey implements the observed wire format independently and includes no code or dependency from those projects.

MX protocol references: [Logitech HID++ feature documentation](https://github.com/Logitech/cpg-docs), [OpenLogi device IDs](https://openlogi.org/hidpp/model-ids), and [Solaar’s observed wire formats](https://github.com/pwr-Solaar/Solaar). ThumbKey implements the protocol independently and bundles no code from these projects. `--check-mx` reads device/control/battery data; `--check-mx-buttons` also verifies temporary diversion and restoration of all five controls without starting mappings.

## Extra buttons and shortcut reference

The shortcut overlay uses the same cached static render as the mouse selector, built from the main 3D mesh and selected Naga side plate; the overlay graphic does not rotate or intercept clicks.

Naga extra-button setup negotiates its receiver transaction ID with read-only queries before entering temporary reporting mode. It keeps the accepted ID for mode checks and restoration, and retries on Naga activity after an asleep receiver could not be configured. Unavailable extra controls show a warning and reconnection action. A saved shortcut is inactive when its action is Keep default action; use Hold keys while pressed for dictation. Focus a text field before dictating to insert there.

Protocol cross-checks: [OpenRazer Naga V3 support](https://github.com/openrazer/openrazer/pull/2904) and the [Naga3Mapper control implementation](https://github.com/potnkettle/Naga3Mapper/blob/main/Sources/Core/Razer.swift). Only the wire-format facts were used; ThumbKey keeps its own non-seizing HID capture and per-event keyboard isolation.
