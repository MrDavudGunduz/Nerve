# `MapFeature`

Interactive map-based news exploration with high-performance annotation clustering.

## Overview

`MapFeature` transforms Nerve's main screen into a live, interactive map where news stories are pinned to their geographic locations. It handles annotation clustering, custom map styling, location services, and the map-centric user interface.

### Performance

The clustering engine uses a **quad-tree algorithm** with O(n log n) complexity, enabling smooth 60 FPS rendering with 1,000+ annotations. Clustering runs on a background actor and delivers results to the main thread via `@Observable` state.

## Topics

### Map Views

- `NewsMapView`
- `ClusterAnnotationView`
- `NewsAnnotationView`
- `SyncStatusIndicator`

### Clustering Engine

- `AnnotationClusterer`
- `ClusterAnnotation`
- `QuadTree`
- `ClusteringConfiguration`

### View Models

- `MapViewModel`
- `AnnotationDetailViewModel`

### Location Services

- `LocationManager`
- `RegionMonitor`

### Models

- `NewsAnnotation`
- `MapRegion`
- `ZoomLevel`
