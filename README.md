# Universal Sky Plugin
Dynamic Sky for Godot Engine 4.5
---------------------------------------------

<img width="1911" height="973" alt="univsky1" src="https://github.com/user-attachments/assets/4a419f61-bb58-4b91-873d-429dd4a8f62f" />

---------------------------------------------

## Status:
> 0.2 Alpha 
---------------------------------------------

## Features:
---------------------------------------------
### Rendering:
- Forward.
- Mobile.
- Compatibility.

### Standard Sky:
- Rayleigh and mie scattering.
- Night scattering.
- Artistic control.
- Moon and moon phases.
- Deep space.
- Stars field scintillation.
- Simple dynamic clouds.
- Clouds panorama(static clouds).
- Incrementally ray-marched volumetric clouds (Forward+).
- Sun eclipses

### Planetary:
- Day and night cycle.
- Simple sun and moon position.
- Realistic sun and moon positions.
- Datetime with basic gregorian calendar.
- Realistic deep space rotation.

## Volumetric Clouds

Add a `VolumetricClouds` resource to your `StandardSkyMaterial` to configure coverage, density, wind, lighting, resolution, and update speed.

Volumetric clouds use compute shaders and require the Forward+ renderer. See `example/volumetric_clouds.tscn` for a configured example.

Lower update-frame values provide faster visual updates, while higher values reduce the per-frame GPU cost.

### Credits

Based on [Clay John’s volumetric cloud demo v2](https://github.com/clayjohn/godot-volumetric-cloud-demo-v2), released under the MIT license. The original license notice is included in [`LICENSES/volumetric-clouds-MIT.txt`](LICENSES/volumetric-clouds-MIT.txt).
