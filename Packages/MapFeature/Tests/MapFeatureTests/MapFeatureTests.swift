//
//  MapFeatureTests.swift
//  MapFeatureTests
//
//  This file previously contained all test suites as a monolith.
//  Each suite has been extracted into its own focused file for clarity,
//  discoverability, and parallel development.
//
//  ┌─────────────────────────────────────────────────────────┐
//  │  Test Suite Structure                                   │
//  ├─────────────────────────────────────────────────────────┤
//  │  Support/                                               │
//  │    TestFixtures.swift      — Shared factory helpers     │
//  │    StubTypes.swift         — Spy / stub test doubles    │
//  │                                                         │
//  │  BoundingBoxTests.swift                                 │
//  │  QuadTreeTests.swift                                    │
//  │  AnnotationClustererTests.swift                         │
//  │  NewsClusterTests.swift                                 │
//  │  NewsAnnotationTests.swift                              │
//  │  CredibilityColorTests.swift                            │
//  │  ClusterZoomBoundingBoxTests.swift                      │
//  │  MapViewModelCategoryFilterTests.swift                  │
//  │  MapViewModelStateTests.swift                           │
//  │  MapViewModelLoadNewsTests.swift                        │
//  └─────────────────────────────────────────────────────────┘
//
