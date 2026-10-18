# Original mouse models

The native SceneKit models are original generated geometry, built from visual reference on October 18, 2026. They are illustrations with approximate proportions, not photogrammetry, manufacturer CAD, or dimensional scans. No reference photographs, third-party textures, meshes, or manufacturer logo artwork are copied into the app. The geometry runs entirely offline.

## References reviewed

### Logitech MX Master 3S

- [Manufacturer product gallery](https://www.logitech.com/en-us/shop/p/mx-master-3s): top, left profile, underside, rear, and front three-quarter views.
- [Manufacturer getting-started guide](https://support.logi.com/hc/en-za/articles/5218056588311-Getting-Started-MX-Master-3S): multi-view overview and Back/Forward close-up, including wheel, gesture button, and charging port locations.
- User-supplied three-quarter product photograph and additional straight top view / close thumb-side photograph (`mx-master-3s-bluetooth-edition-top-view-graphite-new-1.webp`, `design-medium.jpg`).

### Razer Naga V3 Pro

- [Manufacturer product page](https://www.razer.com/gaming-mice/razer-naga-v3-pro): labeled top and left profile, isolated side profile, 12-/6-/2-button plates, front/right wheel detail, and in-hand side views.
- Additional user-supplied top, front/left, and detached-plate photographs (`shopping.jpeg`, `shopping 2.jpeg`, `images 2.jpeg`, and `Review--Razer-Naga-V3-Pro.jpg.webp`) establish panel fit and individual cap locations.
- The V3 photographs establish four columns of three for the 12-button plate (1/2/3 bottom-to-top in the front column, through 10/11/12 in the rear), curved 1/2/3 and 6/5/4 rows for the six-button plate, the raised ring-finger control, and two edge controls beside left-click.

These pages inform shape and location only. Firmware input identities and button delivery still require separate physical validation; they cannot be proved from photos.

## Construction and interaction

`MouseGeometry.swift` constructs section-interpolated, asymmetric shell meshes with explicit normals and rounded nose/heel silhouettes. Concave click-paddle contours are ear-clipped, subdivided, and projected onto the shell; this avoids overlapping fan triangles around the wheel bridge. The removable Naga panel follows the shell instead of protruding as a flat slab. All three plates have individually oriented beveled caps, with textured grips on the six-/two-button plates. MX has a concave flared thumb rest with sweeping ribs, recessed wheel housings, and grooved metal wheels. USB-C recesses and underside details complete the silhouette. Geometry is shared between the header cards and mapping view; both use the selected Naga plate. Native lights/materials replace downloaded textures.

`SidePlate.visualRows` is the shared physical layout for the geometry and accessible button grid. In thumb-side view (nose left), the 12-button top row is 3/6/9/12, middle 2/5/8/11, bottom 1/4/7/10. The six-button rows are 1/2/3 then 6/5/4. On the two-button plate, Forward is ahead of Back. Saved configuration IDs and input identities are preserved. Physical plate detection still requires selecting the attached plate in the UI; the model does not claim to detect a hardware swap.

Each mapped control has a stable `button-<configuration id>` scene node. Clicking the nearest visible surface selects that button; the picker does not select a hidden control through the shell. The matching button list remains available for keyboard/accessibility use. Selecting a plate changes both its mesh and its physical arrangement in the list without changing stored button identities. The view presets reset camera position; dragging and scrolling allow further inspection.

For an offline visual regression pass, run the built executable with `--render-mice <output-directory>`. This renders all four mouse/plate configurations from four angles (16 images), verifies the expected control IDs, and writes `model-validation.json` with ray-tested visible hit targets without starting input capture, opening a configuration, or changing mappings. It requires a local Metal-capable Mac. Render outputs are review artifacts and are not model textures.
