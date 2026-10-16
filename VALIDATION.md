# Prototype status

Recovery fix, version 0.1.2:

- Reproduced the reported state: button 1 was correctly assigned to hold Control–Option–Space, but the running app showed Mappings paused after a device/filter interruption. Re-enabling restored Mappings on.
- Added persistent user intent, automatic recovery after relaunch/wake/device or filter changes, bounded startup retries, and visible off/reconnecting status. Manual pause and revoked permissions cancel recovery; keys/macros are stopped before reconnecting.
- Seventeen core tests pass, including recovery across sleep/wake, retry exhaustion, restart intent, and manual pause. Physical end-to-end dictation remains subject to the user retry below.
- Installed and verified the signed release. Native UI checks confirmed enabled mappings restore after quit/relaunch, a manually paused state stays paused after quit/relaunch, and re-enabling returns Mappings on. Both existing permissions remained granted. The final app is running with mappings enabled. Actual cable/receiver reconnect and sleep/wake recovery still need hardware validation.

Verified on October 16, 2026, on Apple Silicon:

- Release build compiles and the app bundle verifies with the existing Apple Development signing identity.
- The original eight core tests pass: the 12 distinct default inputs, actual Naga V3 Pro boot/extended keyboard descriptors, shared-modifier ownership, emergency key release, device isolation, profile/macro persistence, and invalid configuration rejection.
- Read-only discovery identifies two USB keyboard interfaces for the connected Razer Naga V3 Pro (`1532:00e7`). It does not open input capture in diagnostic mode.
- The native window opens, identifies the connected mouse, displays all 12 buttons, changes action modes, and adds a macro step.

Capture-failure regression, version 0.1.1:

- The initial `IOHIDDeviceOpen(...SeizeDevice)` path failed with `0xe00002c1` after both user permissions were granted.
- Replaced exclusive capture with nonexclusive HID observation plus a session event filter and one-use hardware timestamp correlation.
- Seven additional tests pass for mouse/keyboard separation, expired evidence, release/repeat guards, duplicate Naga interfaces, ambiguity, and delayed keyboard collision evidence (15 total tests).
- Installed the signed update at the existing app path. Existing permissions and mappings remained available. Enabling mappings now succeeds and the native window shows **Mappings on** with no device-open error.
- A keyboard `1` entered normally into the editor while mapping was enabled, without triggering the mouse's dictation binding; the test edit was then removed.
- Pause/resume was checked in the native window. Intentional shutdown notifications are ignored, and callbacks carry a session token so an old filter cannot stop a newer one.

Still requires hands-on testing:

- Actual physical side-pad event correlation and shortcut delivery; ordinary keyboard typing must remain native.
- Every physical button, press/release, learning, and original-key forwarding.
- Hotkey recording, shortcut delivery, macro text/timing, and app-specific routing.
- LocalScribe hold-to-dictate, overlapping held buttons, disconnects, and sleep/wake.
- Bluetooth and wireless-receiver connections.

Mappings start paused on first use and restore the user's last enabled/paused choice on subsequent launches. Hardware discovery, filter startup, and parser tests do not prove end-to-end physical input mapping. This is an initial development prototype for testing and iteration.
