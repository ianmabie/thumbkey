# Prototype status

Surface and lighting refinement, version 0.3.0 build 11 (October 18, 2026):

- Inspected both user-provided Polycam scans locally. Kept raw captures and desk textures out of the repository. Adjusted MX crown placement and thumb-rest termination using the scan and product references; retained the Naga's correct 12-/6-/2-button layouts.
- Corrected uneven-section curve slopes, deformation normals, and seam paths that previously cut through curved surfaces. Replaced wheel rib cylinders with grooved lathe geometry; added physically based graphite/metal, generated studio light, contact shadows, and subtler selection. Enlarged the mapping view from 300 to 390 points.
- Signed release build succeeds. Offline previews cover all four configurations from four preset angles; ray checks verify all 17/11/7 Naga and five MX controls remain visible/selectable from a preset. No input/configuration code changed.
- Native installation and UI verification are pending while the Mac is locked. The existing running app has not been replaced. Candidate: `work/thumbkey/ThumbKey-studio-release-build11.app` in the parent workspace.

Photo-referenced model refinement, version 0.3.0 build 10 (October 18, 2026):

- Rebuilt both original models against the additional supplied top/side/detached-panel photos. The Naga header card now follows the selected 12-/6-/2-button plate, as does the mapping model. Shared physical rows preserve mapping IDs and correct the two-button front/back placement.
- All 28 core tests pass, including the physical plate layouts and their complete, unique mapping identities. Signed release build succeeds. Sixteen offline renders cover every mouse/plate configuration at Overview, Thumb, Top, and Right angles. Ray checks find all 17/11/7 Naga controls and all five MX controls visible from at least one preset, with no missing targets.
- Checked shell/panel fit, concave click seams, wheel targets, thumb-rest ribs, and the Top→Right camera roll correction. Reference photos are not bundled or uploaded.
- Installed the signed build at the existing app path after quitting cleanly, retaining rollback bundles. Native UI verified 12→6→2→12 updates both the header card and mapping model, preserves original button 1, and opens the correct editors when clicking six-button 3, two-button Forward, twelve-button 12, and the ring-finger cap. Top→Right remains upright.
- Native MX checks verified direct main-wheel and thumb-rest model clicks. Fixed shared wheel material ownership so selecting the main wheel no longer highlights the horizontal wheel. Build 10 was installed and the isolated highlight verified. Both permissions remained granted; the mappings file SHA-256 was unchanged. Finished with Naga / 12-button plate / button 1 selected, Overview camera, and mappings paused as before installation. Per-device status showed Naga 100% charging over USB and MX 65% over 2.4 GHz.


MX Master 3S and mouse cards, version 0.3.0 (October 18, 2026):

- All 27 core tests passed: version 1/2→3 configuration migration preserves Naga mappings and adds five MX slots to every profile; mouse/plate routing remains separate; Logitech CID namespace, request/event filtering, temporary diversion flags, battery parsing, and transport resolution are covered.
- Hardware diagnostic identified the connected Bolt MX Master 3S on paired slot 2, found controls 0052/0053/0056/00C3/00C4, read 65% battery over 2.4 GHz, and verified temporary diversion plus restoration for all five controls. The Naga reported 100% charging over wired USB. These checks prove protocol exchange, not physical shortcut delivery.
- Signed MX support was installed before starting 3D work. Existing Naga mappings and app profiles were preserved, and both macOS permissions remained allowed. The LocalScribe preset reads its current configured shortcut instead of assuming the default.
- Two selectable 3D mouse cards replace the dropdown and show per-device power/transport. Original photo-referenced models are labeled as illustrations; third-party scans and reference photos are not bundled. The initial working version was pushed as 8065478 before this modeling refinement, as requested.
- Original sculpted-model candidate build 8 compiles and is signed. Offline rendering produced and visually checked 12 images: four angles of each mouse plus overview/thumb views of the six- and two-button Naga plates. Fixed mesh-end closure, top camera orientation, and readable physical button labels. Nearest-surface hit testing avoids selecting a hidden control through the shell. Live installation/click checks of this final refinement are pending because the Mac locked during validation.
- Physical MX presses/held shortcuts, Bluetooth, receiver disconnect/recovery, and remapper conflicts still require hands-on testing. The currently selected mouse and paused/enabled preference are retained across installation.


Extra controls and plate layouts, version 0.2.0 (October 18, 2026):

- Added five named top/ring-finger slots, a Right Command hold preset, distinct left/right modifier recording, explanatory action labels, and an input-identification section with collapsed technical details.
- Added separate saved mappings and routing for 12-/6-/2-button plates. Version 1 configurations migrate with their 12 existing bindings and app profiles preserved; the app backs up the original file before writing version 2. Switching the plate selector releases held keys. Plate identity is not inferred from shared number-key inputs.
- All 23 core tests pass, including migration, per-plate routing and atomic identification, the actual mouse descriptor, dedicated report 4 parsing, reporting-mode reply validation, and distinct Right Command press/release flags, plus the existing recovery/correlation tests.
- The signed candidate discovers three supported interfaces on the connected USB Naga V3 Pro (`1532:00e7`): one mouse and two keyboard interfaces. Primary click buttons are excluded from remapping.
- Ran the candidate's reversible `--check-extra-mode` diagnostic on the connected mouse: it confirmed temporary mode `03 00` and verified restoration of the original mode. This validates feature-report control, not physical button delivery.
- Installed signed version 0.2.0 build 5 at the existing app path, retaining rollback copies. Both existing permissions remained granted. The native UI shows Mappings on and all five extra controls. The 2-/6-/12-button selector shows the matching side-button count, and returning to 12 restores the original button 1 mapping. A local comparison of the migrated settings against the automatic backup confirmed all original twelve bindings were unchanged.
- Verified the clearer action menu and the Superwhispr/LocalScribe preset menu in the native window. Fixed preset explanations to follow assigned keys rather than a button's name, so renaming or changing a shortcut cannot show a false LocalScribe hint. Fixed singular macro action counts.
- Enabled extra-button reporting in the running UI. Pausing showed Mappings paused and a read-only hardware query confirmed mode `00 00`; resuming on the final build showed Mappings on and a second query confirmed `03 00`. The app is left enabled on the attached 12-button plate, with extra-button reporting enabled and existing actions preserved.
- Still pending: each extra control's physical code/press/release, the front behind-wheel button's identification, Superwhispr accepting synthetic Right Command, side-pad behavior while driver mode is active, physical alternate plates, receiver/Bluetooth behavior, reconnect/idle restoration, and actual Right Command preset delivery to Superwhispr.
- Automatic plate switching remains unimplemented: no reliable plate identity report has been established. The interface explicitly requires selecting the attached plate after a swap. Physical swap observations are needed before adding automatic detection.

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
