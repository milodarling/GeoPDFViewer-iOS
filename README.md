# GeoPDF Viewer (iOS)

Opens a Geospatial PDF, reads its ISO 32000 georeferencing, and shows your
current location as a dot on the map — using only Apple frameworks (PDFKit,
CoreGraphics, CoreLocation). No GDAL/proj dependency.

Licensed under the MIT License — see [LICENSE](LICENSE).

## Scope today

Supports the **simple, common case**: a north-up map whose georeferenced area is
a rectangle aligned to latitude/longitude, with `GPTS` already in WGS84 lat/lon.
The bundled sample (`El Cajon Mountain Trail Map.pdf`) is exactly this.

For any other map the app still **displays the PDF** and shows a plain-language
banner explaining why live location isn't available, rather than silently
placing the dot in the wrong spot. See *Extending support* to add more types.

## Project layout

```
GeoPDFViewer.xcodeproj              open this in Xcode
GeoPDFViewer/
  App/
    GeoPDFViewerApp.swift           @main SwiftUI entry
    RootView.swift                  open bundled sample / pick a file
    DocumentPicker.swift            UIDocumentPicker wrapper (PDFs)
  UI/
    GeoPDFMapView.swift             SwiftUI wrapper (UIViewControllerRepresentable)
    GeoPDFMapViewController.swift   PDFKit view + track/dot overlay + banners
    QRScannerView.swift             AVFoundation QR scanner
    TrackingHUD.swift               live stats panel + Start/Pause/Finish/Discard
    StatFormatting.swift            shared locale-aware stat formatting
    SessionsListView.swift          browse saved sessions
    SessionDetailView.swift         saved route on a MapKit map + stats
  Tracking/
    TrackModels.swift               TrackPoint, TrackStats, TrackSessionMeta (Codable)
    TrackStore.swift                crash-safe JSON-lines persistence (active session)
    TrackRecorder.swift             CLLocationManager owner: path, stats, background, restore
    SessionModels.swift             SessionSummary (Codable) for saved sessions
    SessionLibrary.swift            saved-session store (Application Support/Sessions)
  GeoPDFKit/                        reusable, UI-free core
    MeasureGEO.swift                raw parsed /Measure(GEO) data (no interpretation)
    GeoPDFParser.swift              CGPDF traversal: page /VP -> /Measure -> GPTS/Bounds/GCS
    Georeferencer.swift             Georeferencer protocol, GeographicBounds,
                                    unsupported-reason model, builder protocol + registry
    SimpleAxisAlignedGeoreferencer.swift
                                    the one supported strategy + its validating builder
    MathHelpers.swift               linear fit + cluster helpers
    GeoPDFLoader.swift              open PDF -> parse -> registry -> GeoPDFLoadOutcome
  Resources/
    El Cajon Mountain Trail Map.pdf bundled sample map
  Info.plist                        includes NSLocationWhenInUseUsageDescription
```

Data flow: `GeoPDFLoader.load(url:)` → `.georeferenced` / `.unsupported` / `.failed`.
The view controller renders the PDF in all three cases; it only tracks location
in the `.georeferenced` case.

### How validation decides "supported"

`SimpleAxisAlignedGeoreferencerBuilder.build(from:)` rejects with a specific
reason unless **all** hold:

| Check | Rejection code |
|---|---|
| Valid 4-number BBox | `.malformed` |
| Exactly 4 registration points | `.nonStandardRegistration` |
| Registration is the BBox's four unit corners (not a clipped neatline) | `.nonStandardRegistration` |
| GPTS values are in lat/lon range (not projected meters) | `.projectedCoordinates` |
| The 4 geographic corners form an axis-aligned rectangle (2 distinct lats, 2 lons) | `.rotatedOrSkewed` |
| lon→x and lat→y fit linearly with tiny residual (north-up, unswapped axes) | `.rotatedOrSkewed` |

Each reason carries a user-facing `message`, shown in the banner.

## Extending support (future map types)

1. Implement `GeoreferencerBuilder`. In `build(from:)`, either return
   `.success(yourGeoreferencer)` or `.rejected(reason)`.
2. Implement the matching `Georeferencer` (`pagePoint(for:)`, `contains(_:)`,
   `geographicBounds`).
3. Register it in `GeoreferencerRegistry.default`, **before** the simple builder
   if it's more specific.

Nothing in the parser, loader, or UI changes. Concrete next steps:

- **`ProjectedQuadGeoreferencerBuilder`** — USGS US Topo / USFS quads store the
  map in a projected CRS (UTM, State Plane) named by `/GCS` WKT. The neatline is
  a rotated trapezoid in lat/lon. Project the incoming WGS84 fix into that CRS,
  then interpolate. Needs a projection routine (roll a UTM transform, or add a
  small proj wrapper).
- **`BilinearGeoreferencerBuilder`** — general non-affine 4-corner maps: bilinear
  interpolation over `(pageFractions ↔ gpts)` without assuming axis alignment.
- **Datum handling** — GPS is WGS84; older maps may be NAD27/NAD83 (tens of
  metres off). Read the datum from `/GCS` WKT and shift if needed.

## Live tracking

On a georeferenced map, the HUD's **Start** records your session:

- **Path** — drawn live on the PDF as a blue polyline overlay, glued to the map
  through pan/zoom. Coordinates are stored as lat/lon, so the same track renders
  on any map that covers the area.
- **Stats** — elapsed time (pause-aware), distance, elevation gain (with a 1 m
  noise deadband), and pace (min/km or /mi by locale).
- **Persistence** — each fix is appended to a JSON-lines file plus a metadata
  file in Application Support (`TrackStore`). A crash or termination loses at
  most the last unwritten fix; on next launch the session is restored, and if it
  was recording it resumes.
- **Background** — recording continues while backgrounded via
  `allowsBackgroundLocationUpdates` + the `location` background mode (enabled
  only while recording; the blue status indicator shows).
- **Saved sessions** — **Finish** archives the session into
  `Application Support/Sessions/<id>/` (a small `summary.json` + full
  `points.jsonl`). The **Sessions** button (top-left) lists saved sessions;
  tapping one shows its route on a MapKit map plus stats, so past tracks are
  viewable without the original GeoPDF. Swipe to delete. **Discard** ends the
  active session without saving.

**Known limitation:** while the app is *fully terminated* (not just
backgrounded), iOS records no new points until you reopen it — the saved
path/stats stay intact and continue, but bridging the dead-time gap needs
significant-location-change relaunch (`startMonitoringSignificantLocationChanges`),
a deliberate follow-up. Elevation gain accuracy depends on GPS barometric
altitude, which is noisy; the deadband trades small real gains for less drift.

## Build & run

1. Open `GeoPDFViewer.xcodeproj` in Xcode (15+).
2. Select the **GeoPDFViewer** scheme and an iOS Simulator, then Run (⌘R).
   - For a physical device, set your team under *Signing & Capabilities* and
     change `PRODUCT_BUNDLE_IDENTIFIER` (currently `com.example.GeoPDFViewer`).
3. Open a map three ways:
   - Tap the bundled **Sample**.
   - Tap **Open** (toolbar) to import a GeoPDF from Files — it's copied into the
     app's folder and added to **My Files**.
   - In the **Files app**, go to *On My iPhone ▸ GeoPDFViewer* and drop `.pdf`
     files straight in; pull to refresh the list in the app. (Enabled by
     `UIFileSharingEnabled` + `LSSupportsOpeningDocumentsInPlace` in Info.plist.)
   - Tap **Scan QR** (toolbar) and point the camera at a QR code containing an
     `http(s)` link to a PDF — it's downloaded, verified to be a real PDF (by its
     `%PDF-` header, not just the MIME type), and imported into **My Files**.
     Requires a physical device (`NSCameraUsageDescription` in Info.plist); the
     Simulator has no camera.
   Swipe to delete files under **My Files**.
4. Simulate a position: **Features ▸ Location ▸ Custom…**, enter a point inside
   the sample's extent, e.g. **lat 32.91, lon −116.85** — the blue dot appears on
   the map. A point outside the extent hides the dot (as intended).

Requires only Apple frameworks (PDFKit, CoreGraphics, CoreLocation, SwiftUI,
UIKit) — no packages to resolve.

## Sample file georeferencing (for reference)

`El Cajon Mountain Trail Map.pdf`, page 1:

```
Viewport /BBox  [36 576 756 90]
Measure  /Subtype /GEO
  Bounds/LPTS  [0 1  0 0  1 0  1 1]          (page-fraction corners)
  GPTS         [32.890606 -116.8861,          lat/lon of each corner
                32.929108 -116.8861,
                32.929108 -116.81816,
                32.890606 -116.81816]
  GCS  WKT "WGS 84 / UTM zone 11N"            (display CRS; GPTS itself is lat/lon)
```

Extent: lat 32.8906–32.9291, lon −116.8861 to −116.81816 (El Cajon Mtn, San
Diego County). Axis-aligned → the simple linear path applies.

A standalone inspector (`../inspect_geo.py`) dumps these fields from any GeoPDF
for debugging.
