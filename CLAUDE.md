# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Build & Run

This is a pure Xcode project with no external dependencies (no CocoaPods, SPM packages, or Carthage). Built with Xcode 26.2.

```bash
# Build from command line
xcodebuild -project xxl_app.xcodeproj -scheme xxl_app -sdk iphonesimulator build

# Run tests (placeholder tests only — no real test coverage exists)
xcodebuild -project xxl_app.xcodeproj -scheme xxl_app -sdk iphonesimulator test
```

Open `xxl_app.xcodeproj` directly in Xcode for development. No workspace file is needed.

## Architecture

**Photo Calendar app** (照片日历) — reads photos from the system photo library and arranges them into calendar grids by date.

- **100% SwiftUI**, minimum iOS 17.0. Targets iPhone, iPad, Mac, and visionOS.
- **No third-party dependencies.** Uses only Apple frameworks: Photos/PhotosUI, CoreLocation, MapKit, Combine, SwiftData.
- Swift strict concurrency is enabled (`SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor`).

### Key Files

| File | Role |
|------|------|
| `xxl_appApp.swift` | `@main` entry point. Root view is `CalendarPhotoView`. Sets up a SwiftData `ModelContainer` (template artifact, not actively used). |
| `CalendarPhotoView.swift` | **Largest file (~820 lines).** Main view with month/year pickers, plus inline `FullScreenImageView` and `ExportableCalendarView`. Contains export-to-image logic. |
| `PhotoAlbumManager.swift` | Central `ObservableObject` manager. Handles photo fetching (`PHAsset`/`PHCachingImageManager`), image loading, and geocoding with triple-fallback (local bounding-box → CLGeocoder → BigDataCloud → Nominatim). |
| `CalendarGridView.swift` | Monthly `LazyVGrid` with 7 columns (weeks start on Monday). |
| `YearlyCalendarView.swift` | Year-at-a-glance view with 12 month grids and `YearlyDayPhotoView` subview. |
| `DayPhotoView.swift` | Single day cell rendering a photo thumbnail. |
| `ContentView.swift` | `PhotosPicker`-based view — early/unused, not referenced from the main flow. |
| `Item.swift` | SwiftData `@Model` — Xcode template leftover, not used by calendar features. |

### Data Flow

`CalendarPhotoView` owns `@StateObject PhotoAlbumManager` and passes it to child views via `@ObservedObject`. Views reactively bind to `photoManager.photosByDay` and `photoManager.photosByMonth`. Year/month picker changes are debounced (300ms) before triggering photo reload.

### Notable Implementation Details

- **Geocoding fallback chain**: Local bounding-box lookup (9 hardcoded Chinese cities) → Apple CLGeocoder → BigDataCloud API → OSM Nominatim. Includes 30-second retry logic for throttling (up to 3 retries).
- **Location deduplication**: GPS points within 15km are consolidated; capped at 45 unique locations per month.
- **Export**: Uses `ImageRenderer` at 3x scale for high-resolution output saved to the photo library.
- **Entitlements**: CloudKit and APN are configured but not actively used in code.
