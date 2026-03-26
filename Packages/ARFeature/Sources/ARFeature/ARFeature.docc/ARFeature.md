# `ARFeature`

Augmented reality and spatial computing experiences for news exploration.

## Overview

`ARFeature` brings news stories to life in 3D. On **iOS**, it renders USDZ models anchored to real-world surfaces via ARKit. On **visionOS**, it provides volumetric windows and immersive spatial map experiences using RealityKit and SwiftUI spatial APIs.

### Platform Behavior

| Platform         | Experience                                                |
| ---------------- | --------------------------------------------------------- |
| **iOS / iPadOS** | Camera-based AR — 3D models anchored to detected surfaces |
| **macOS**        | 3D model viewer (SceneKit fallback)                       |
| **visionOS**     | Volumetric windows + immersive spatial map                |

## Topics

### iOS AR Views

- `ARNewsView`
- `ARSessionManager`
- `ModelAnchorManager`

### visionOS Spatial Views

- `VolumetricNewsView`
- `SpatialMapView`
- `ImmersiveSpaceCoordinator`

### 3D Asset Management

- `USDZAssetLoader`
- `AssetCache`
- `PlaceholderEntity`

### Interactions

- `GestureHandler`
- `SpatialAudioManager`
- `EntityTransformController`

### View Models

- `ARNewsViewModel`
- `SpatialMapViewModel`
