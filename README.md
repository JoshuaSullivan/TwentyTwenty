# TwentyTwenty

A comprehensive iOS app showcasing the Vision framework's modern Swift API introduced in iOS 18.

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

## Vision Framework Reference

The `docs/vision-ios.swiftinterface` file contains the complete Swift interface for the iOS 18 Vision framework. This file can be used as a reference when working with AI coding assistants to understand available APIs, method signatures, and type definitions.

When asking an AI to help with Vision framework code, you can reference this file to ensure accurate implementation details.

## Features

- Modern Vision API using Swift concurrency
- Interactive result visualizations with Canvas-based overlays
- Video playback with real-time tracking overlays
- Color-coded pose joint rendering
- Optical flow vector field visualization
- Performance statistics and confidence metrics
- Accessibility support throughout
- Dark mode support
