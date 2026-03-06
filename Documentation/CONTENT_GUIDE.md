# Content Creation Guide

GlobeDisplay can display any equirectangular image in the NOAA Science on a Sphere (SOS) format. This guide explains how to find, prepare, and import content.

## Image Requirements

| Property | Requirement |
|---|---|
| Projection | Equirectangular (plate carrée) |
| Aspect ratio | 2:1 (width = 2× height) |
| Orientation | 0° longitude at center; North Pole at top; South Pole at bottom |
| Format | JPEG or PNG |
| Recommended size | 2048×1024 (minimum), 4096×2048 (preferred for static display) |

## Free Content Sources

### NOAA Science on a Sphere Catalog
**https://sos.noaa.gov/catalog/datasets/**

500+ curated datasets covering atmosphere, biosphere, cryosphere, hydrosphere, land, ocean, and space. All datasets are in SOS format and import directly into GlobeDisplay.

To download a dataset:
1. Browse the catalog and open a dataset page.
2. Download the dataset bundle (`.zip` or `.sos` folder).
3. Import via GlobeDisplay (feature coming in Phase 2).

### NASA Visible Earth
**https://visibleearth.nasa.gov/**

High-resolution Earth imagery. Most datasets are public domain. Download the largest available JPEG and import.

### NASA SVS (Scientific Visualization Studio)
**https://svs.gsfc.nasa.gov/**

Animated and static planetary datasets. Look for equirectangular downloads.

### Solar System Scope Textures
**https://www.solarsystemscope.com/textures/**

High-quality planet textures under CC BY 4.0. Free for use with attribution.

### NASA 3D Resources
**https://nasa3d.arc.nasa.gov/images**

Planetary surface maps in various formats. Filter for equirectangular projections.

## Preparing Custom Images

If your source image isn't in equirectangular format, you'll need to reproject it. Common tools:

- **G.Projector** (NASA, free) — reprojects between many map projections
- **QGIS** (free, open source) — full GIS suite with reprojection support
- **Photoshop / GIMP** — for cropping and resizing after reprojection

### Checking Orientation

The SOS convention: **prime meridian (0° longitude) must be at the horizontal center of the image.** In practice, this means:
- Left edge = 180°W
- Center = 0° (prime meridian, through Greenwich, UK)
- Right edge = 180°E

If your image has a different center longitude, use GlobeDisplay's **longitude offset** slider to correct it without altering the image file.

## SOS Bundle Format

GlobeDisplay supports the standard NOAA SOS bundle structure:

```
MyDataset.sos/
├── label.json          ← metadata (title, description, attribution, category)
└── image.jpg           ← equirectangular image (or image.png)
```

**label.json format:**
```json
{
  "name": "My Dataset Title",
  "description": "Optional educational description shown in the info panel.",
  "category": "earth",
  "credit": "Source name and license",
  "license": "CC BY 4.0"
}
```

Valid `category` values: `planets`, `earth`, `atmosphere`, `ocean`, `space`.

## Attribution

When displaying content, always include proper attribution for the data source. GlobeDisplay shows attribution in the content info panel (ⓘ button on each content card). Make sure the `credit` and `license` fields in `label.json` are accurate.

For NASA public domain content, use: `Public Domain (U.S. Government Work)`.
For Solar System Scope content: `Solar System Scope / solarsystemscope.com (CC BY 4.0)`.
