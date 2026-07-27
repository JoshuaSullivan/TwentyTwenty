# TwentyTwenty

A comprehensive iOS app showcasing the Vision framework's modern Swift API — introduced in
iOS 18 and tracked here through iOS 27.

## Overview

TwentyTwenty demonstrates 32 different Vision framework models across 6 categories:

- **Detection** - Locate and identify objects, faces, poses, and features in images
- **Recognition** - Recognize text, animals, and documents
- **Generation** - Generate saliency maps, segmentation masks, and feature prints
- **Tracking** - Track objects, optical flow, and image registration in video
- **Classification** - Classify image content and aesthetics
- **Utility** - Calculate aesthetics scores and detect lens quality

Each model has a dedicated detail view with:
- Model description and iOS version requirements
- Image or video selection with recommended content types
- Model-specific configuration options
- Results visualization with overlays and statistics
- Performance metrics

## Newly supported in iOS 27

**Generate Iterative Segmentation** (`GenerateIterativeSegmentationRequest`) — the headline
addition, and the first model here that is genuinely interactive. It segments *any* object,
not just people or a generic foreground. Seed it by tapping a point, dragging a box, or
scribbling over the subject, then steer the result by adding points that mark regions to
include or exclude. Each point re-runs the request against cached image analysis, so later
iterations are typically faster than the first.

It differs from every other request in the framework in two ways:

- It is a **class** rather than a struct, because it accumulates refinement state across
  successive `perform` calls, and there is no API to remove a point. Undo is implemented by
  rebuilding the request from its seed and replaying the surviving points.
- It adopts the new `DownloadableAssetsRequest` protocol — its model is not bundled with
  iOS and is fetched on first use, with progress reported through Foundation's
  `ProgressManager`.

Vision caps refinement at 13 total points for point and scribble seeding, 11 for box seeding.

**Algorithm revision pickers** — iOS 27 adds `revision4` to Detect Face Rectangles and
Detect Face Landmarks, and `revision3` to Detect Human Rectangles. Those three screens now
let you switch revisions and compare results. The list is driven by each request's
`supportedRevisions`, which the OS filters at runtime, so newer revisions appear
automatically on newer systems. Apple ships no documentation on what they improve.

## Requirements

- iOS 26.0+ (deployment target)
- Xcode 26.0+ to build
- Xcode 27.0+ to include the Generate Iterative Segmentation model

The project builds on Xcode 26, but `GenerateIterativeSegmentationRequest` is declared only
in the iOS 27 SDK, and `@available` can't help with that — it gates execution, not
compilation. That model is therefore wrapped in `#if compiler(>=6.4)` (Swift 6.4 ships with
Xcode 27). On an Xcode 26 build it still appears in the model list, but opening it shows a
notice explaining that it wasn't compiled in.

Models are never hidden from the list. Anything that can't run routes to
`ModelUnavailableView`, which distinguishes the two reasons: the device's iOS is older than
the model requires, or the app was built with an SDK that predates the model's API.

## Architecture

The app follows MVVM architecture with:
- **Models** - Vision model definitions and registry
- **ViewModels** - Processing logic conforming to `BaseModelDetailViewModel`
- **Views** - SwiftUI views with reusable `ModelDetailView` template
- **Components** - Specialized visualizations for different result types

## Features

- Modern Vision API using Swift concurrency
- Interactive result visualizations with Canvas-based overlays
- Tap-, box- and scribble-driven interactive segmentation with iterative refinement
- On-demand Vision model downloading with progress reporting
- Selectable algorithm revisions on supported requests
- Video playback with real-time tracking overlays
- Color-coded pose joint rendering
- Optical flow vector field visualization
- Performance statistics and confidence metrics
- Accessibility support throughout
- Dark mode support
