# AR Model Resources

Place USDZ model files in this directory for SPM resource processing.

## Required Models

| Category       | File Name              | Description                |
|----------------|------------------------|----------------------------|
| `.technology`  | `tech_device.usdz`    | 3D device model            |
| `.science`     | `science_model.usdz`  | Scientific visualization   |
| `.health`      | `health_dna.usdz`     | DNA helix model            |
| `.environment` | `environment_globe.usdz` | Earth globe model       |

## Guidelines

- Keep USDZ files under 10 MB each for fast loading.
- Test models with Reality Composer Pro before adding.
- Models are resolved by `ARAssetManager` via the bundle.
