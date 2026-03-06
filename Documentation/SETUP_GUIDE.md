# Hardware Setup Guide

## What You Need

| Item | Notes |
|---|---|
| iPad | USB-C port required; iPadOS 17.0+ |
| USB-C Digital AV Adapter | Apple or MFi-certified adapter |
| HDMI cable | Standard HDMI-A; length depends on your setup |
| MagicPlanet globe | Any size with HDMI input (40 cm – 3 m diameter) |

## Connection

1. Connect the HDMI cable to the MagicPlanet's **HDMI input port** (usually on the base or rear of the stand).
2. Connect the other end of the HDMI cable to the **Digital AV Adapter**.
3. Plug the Digital AV Adapter into the **iPad's USB-C port**.
4. Power on the MagicPlanet globe.
5. Launch **GlobeDisplay** on the iPad.

The app automatically detects the external display. A green "Globe connected" indicator appears in the bottom toolbar when the connection is active.

## First Launch

On first launch, a setup guide walks you through connecting the hardware. If you've already connected the globe, you'll see content appear immediately.

## Calibration

Every MagicPlanet globe has slightly different optics. Use the calibration controls in the bottom toolbar to match the projected image to the physical sphere:

| Control | Effect |
|---|---|
| **Longitude offset** (rotation slider, 0–360°) | Rotate the image east/west to align the prime meridian |
| **Projection correction** (γ, 1–4) | Adjust the radial distortion model. 1.0 = equidistant (default for most globes) |
| **South pole radius** (0.3–0.7) | Set where the south pole appears radially. 0.7 works for most models |
| **Brightness** (Settings) | Overall output brightness |
| **Flip H / Flip V** (Settings) | Mirror if image appears reversed |

### Recommended Starting Values

These values were calibrated on a standard MagicPlanet and should work without adjustment on most units:

```
Longitude offset:    0°
Projection γ:        1.0
South pole radius:   0.7
Brightness:          1.0
```

## Troubleshooting

**"No display" shown in the toolbar**
- Check that the HDMI cable is firmly seated at both ends.
- Try disconnecting and reconnecting the adapter.
- Some third-party adapters require the globe to be powered on before plugging in.

**Image appears rotated**
- Adjust the longitude offset slider.

**Image is distorted (stretched toward the poles)**
- Reduce the projection γ value toward 1.0.

**South pole appears cut off or shows a black ring**
- Adjust the south pole radius slider up or down.

**Content loads but globe is dark**
- Increase the brightness slider in Settings.
- Check the MagicPlanet's own brightness/contrast controls.

## Network Requirements

Live data overlays (earthquakes, volcanoes, wildfires) require an internet connection. Bundled planetary content works fully offline. The app shows an "Offline" indicator in the toolbar when no network is available, and live feeds will resume automatically when connectivity is restored.
