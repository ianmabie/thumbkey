# Prototype status

Scroll behavior, version 0.3.0 build 20 (October 18, 2026):

- The shared 3D viewer forwards wheel and trackpad scroll events to the surrounding page instead of SceneKit's camera controller. Drag rotation and the angle presets remain available for both mice. Removed the scroll-to-zoom hint.
- Signed release build, strict installed-signature verification, and diff whitespace check pass. Installed and relaunched at the existing app path with build 19 retained as rollback. Saved mappings were unchanged at installation.
- Native inspection confirms the updated hint, page scrolling over the Naga viewer, and camera reset. Further isolated gesture checks were stopped when the user began interacting with the app; their subsequent mapping edits were left intact. This update does not change geometry or input routing.

Final multi-angle photo pass, version 0.3.0 build 19 (October 18, 2026):

- Reviewed six additional user photos locally. Rebuilt the MX front as a continuous shallow slope with broader click paddles, a slimmer wheel bridge, molded button lips, and a recessed lower nose. Subdivided the curved front closure and kept its upper/lower boundary joined so low views do not reveal cracks or fan-triangle creases.
- Lowered both rear rim profiles while preserving the rounded elliptical backs and flat underside contact areas. Extended the Naga plate seam across the left flank and around the heel, and adjusted the twelve-button cap proportions. Existing mapping IDs and the 12-/6-/2-button layouts are retained.
- Signed release build and strict installed-signature verification pass. Thirty-one rendered views include new low front, thumb-side, and rear angles. All 17/11/7 Naga controls and five MX controls pass the visible-hit checks. Diagnostic construction plus rendering times were 4.26/3.94/3.89/1.09 seconds, including the extra views.
- Installed and relaunched build 19 at the existing app path, retaining build 18 as rollback. Native inspection confirmed both updated models and a direct thumb-rest click selected its editor. Restored MX / Thumb gesture button / Overview / Everywhere with mappings paused as before. The saved mappings SHA-256 is unchanged. Input and permission code are unchanged; these checks cover model rendering and selection, not physical input delivery.
- Personal reference photos remain outside the repository and application. These original photo-referenced models are illustrations rather than measured CAD replicas.

Photo-corrected footprints, version 0.3.0 build 18 (October 18, 2026):

- Used the user's two underside photos and rear three-quarter photo to replace the generic outlines: separate Naga flank profiles with the front-right step and fuller rear; an MX thumb recess and broader rear ledge. The underside contact areas are flat, with smooth perimeter rolls and matte base materials.
- Corrected the Naga's front skate, rounded U-shaped rear skate, larger puck and vertical switches. Corrected the MX's pad sizes, colors and placement. All original button IDs and saved mappings remain unchanged.
- Signed release and strict verification pass. All 25 final review images rendered successfully. All 17/11/7 Naga and five MX mapped buttons pass visible-hit checks. Diagnostic construction plus rendering timings: 2.58/2.38/2.39/1.21 seconds. These are photo-referenced illustrations, not CAD measurements. User photographs remain outside the repository.
- Installed build 18 at the existing live application path after a clean quit, retaining build 17 as rollback. Strict installed-signature verification passes. Native inspection confirmed both corrected Bottom views and Overview silhouettes. Restored Naga / 12-button plate / side button 2 / Overview / Everywhere, with mappings paused as before. The mappings file SHA-256 is unchanged, including the user's side-button-2 macro. Battery/transport status returned Naga 100% charging over wired USB and MX 65% over 2.4 GHz.

Rounded heels and underside inspection, version 0.3.0 build 17 (October 18, 2026):

- Rounded both rear crowns and rolled the underside upward into the heel instead of tapering to a point at the floor. Consistent rear curvature and denser end sampling keep the closing mesh smooth. Closed the MX upper/lower boundary exactly.
- Added surface-conforming underside details: Naga front/rear skates, sensor ring, cover puck, ring-finger lock, wireless slider and profile selector; MX four glide pads, sensor, power slider and Easy-Switch controls. Added underside lighting, a Bottom preset and unrestricted arcball rotation. Preset changes stop ongoing rotation.
- Signed release build and strict signature verification pass. Twenty-five review renders cover all mouse/plate presets plus rear and oblique underside views. All 17/11/7 Naga and five MX mapped controls pass visible-hit validation. Final offline build/render timings are 3.42/2.74/2.73/1.20 seconds, including images and hit checks. Input capture, configuration and permission code are unchanged.
- Build 17 is installed at the existing live application path. Clean quit, retained build 16 as rollback, and strict installed-signature verification pass. Native checks confirm Bottom views for both mice and unrestricted dragging from the Naga underside into an oblique view. Restored Naga / 12-button plate / button 1 / Overview / Everywhere, with mappings paused as before. The saved mappings SHA-256 is unchanged.
- Bluetooth investigation: macOS Bluetooth was on with a keyboard connected, but the Naga did not appear in My Devices or Nearby Devices. ThumbKey's read-only device diagnostic saw only the Logitech USB receiver. Requested that the user put the Naga in Bluetooth pairing mode using the manufacturer instructions; the user subsequently deferred Bluetooth setup. At build 17 installation, the Naga is visible over wired USB, 100% charging. Existing extra-button driver mode requires USB or the receiver, so full extra-button mapping over Bluetooth is not claimed.

Live model update and icon refresh, version 0.3.0 build 16 (October 18, 2026):

- Includes the complete build 15 model polish. Renamed the bundled icon resource to `ThumbKeyMouse.icns` and explicitly loads it as the application icon at launch, avoiding reliance on the previously cached app image. The icon artwork is unchanged from the mouse design introduced in build 13.
- Signed release build and clean installed-bundle verification pass. Installed at the existing path after a clean quit, retaining build 14 as rollback. The saved mappings file SHA-256 is unchanged. Native inspection confirms the new MX details and the About panel's mouse icon with version 0.3.0 (16). The Dock's pinned entry points to this same live bundle. The MX / Back button / Overview selection and paused preference are preserved.

Additional photo-reference polish, version 0.3.0 build 15 (October 18, 2026):

- Reviewed new manufacturer and close-up front/right/left photographs. Rebuilt the Naga ring-finger button as the long side paddle beneath right-click and added the lower textured grip. Tightened its wheel bridge and sampled all conforming cap boundaries densely to prevent edges cutting into the shell.
- Recessed and angled the MX thumb wheel, replaced raised navigation and wheel-mode blocks with low conforming caps, and modeled shallow thumb-rest flutes in the surface. Refined graphite materials and rounded both USB-C apertures.
- Signed release build and signature verification pass. Eighteen multi-angle review renders cover all four configurations. All 17/11/7 Naga and five MX controls pass visible-hit checks, with no missing targets. Native input, mappings, profiles, and permission code are unchanged.
- Cached section data and shared projected vertices reduce construction/render time: the final offline pass reports 2.35/2.13/2.13 seconds for the Naga configurations and 0.50 seconds for MX on this machine, including preset renders and hit checks. These are diagnostic timings, not an interaction benchmark.
- These model changes are installed in build 16, together with the application-icon refresh fix. The final build 15 review renders remain available locally.

Extra-control and thumb-rest corrections, version 0.3.0 build 14 (October 18, 2026):

- Replaced all five Naga extra-control boxes with individually shaped, beveled caps that follow the shell surface: tapered left-click shoulder buttons, closer behind-wheel controls, and a narrow curved ring-finger paddle. Constant-width recesses avoid thick black ends. Control origins and nose deformation preserve accurate clickable targets.
- Rebuilt the MX thumb rest as a continuous upper surface, rounded lip, and underside, with zero-slope taper into the nose and heel. Removed the disconnected base-seam stubs, rolled the heel underside upward, and replaced floating skate blocks with thin pads that follow the base.
- Signed release build succeeds. All 17/11/7 Naga and five MX controls pass the four-preset visible-hit checks. The renderer now exits with an error if any mapped target is missing. Eighteen review images cover all four configurations and add front-right Naga / rear-thumb MX views to expose the corrected areas. No input protocol, saved mapping, or permission logic changed.
- Installed build 14 at the existing app path after a clean quit, preserving the Apple Development signing identity and a rollback copy. Signature verification passed. Native inspection confirmed the updated MX thumb rest and Naga extra-control geometry. The mappings file SHA-256 was unchanged; the original paused state and MX / Back button / Overview selection were restored.

Mouse icon and realism pass, version 0.3.0 build 13 (October 18, 2026):

- Replaced the keypad icon with an original vector-drawn mouse, split click surface, teal wheel, and two thumb buttons. Generated all ten standard/Retina PNG sizes and the bundled ICNS.
- Refined both models' crown curvature, rounded/lowered nose, charging-port placement, and button cap heights. Naga extra controls sit closer to the click shoulder; all 12-/6-/2-button identities and arrangements are unchanged.
- Blended the MX thumb rest into the side surface without covering Back/Forward, reduced its rim and rib contrast, and tightened the thumb-wheel recess so it no longer overlaps the wordmark. Added subtle generated plastic grain and studio softbox reflections to distinguish graphite and metal.
- Signed release build passes. All 16 model renders were generated; all 17/11/7 Naga and five MX controls pass visible-target ray checks. Multi-angle visual inspection includes the crown, wheel recesses, side panels, right-side control, and thumb rest. No input, mapping, permission, or profile logic changed.
- Build 13 was reviewed offline; its mouse icon and model improvements are included in the installed build 14.

Surface and lighting refinement, version 0.3.0 build 12 (October 18, 2026):

- Inspected both user-provided Polycam scans locally. Kept raw captures and desk textures out of the repository. Adjusted MX crown placement and thumb-rest termination using the scan and product references; retained the Naga's correct 12-/6-/2-button layouts.
- Corrected uneven-section curve slopes, deformation normals, and seam paths that previously cut through curved surfaces. Replaced wheel rib cylinders with grooved lathe geometry; added physically based graphite/metal, generated studio light, contact shadows, and subtler selection. Enlarged the mapping view from 300 to 390 points.
- Signed release build succeeds. Offline previews cover all four configurations from four preset angles; ray checks verify all 17/11/7 Naga and five MX controls remain visible/selectable from a preset. No input/configuration code changed.
- Installed build 12 with the stable signing identity and rollback retained. Native inspection confirmed correct graphite colors in both cached mouse cards and the larger interactive MX mapping view, with the existing paused state preserved. The mappings file SHA-256 was unchanged during installation. Both connected mice continued to show battery and transport status.

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
