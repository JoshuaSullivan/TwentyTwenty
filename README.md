# TwentyTwenty

A comprehensive iOS app showcasing the Vision framework's modern Swift API introduced in iOS 18.

## Overview

TwentyTwenty demonstrates 31 different Vision framework models across 6 categories:

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

- iOS 18.0+
- Xcode 16.0+
- Swift 6.0+

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
