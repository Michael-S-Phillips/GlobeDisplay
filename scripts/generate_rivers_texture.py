#!/usr/bin/env python3
"""
Generates rivers_2048x1024.png — a transparent-background equirectangular
overlay of world rivers, suitable for compositing over a globe base map.

Requirements:
    pip install cartopy matplotlib shapely

Output:
    GlobeDisplay/Resources/BundledContent/rivers_2048x1024.png
"""

import matplotlib
matplotlib.use('Agg')  # Non-interactive backend — no display required
import matplotlib.pyplot as plt
import cartopy.crs as ccrs
import cartopy.feature as cfeature
from pathlib import Path

OUTPUT_PATH = Path(__file__).parent.parent / "GlobeDisplay" / "Resources" / "BundledContent" / "rivers_2048x1024.png"

WIDTH_PX  = 2048
HEIGHT_PX = 1024
DPI       = 100

fig_width  = WIDTH_PX  / DPI
fig_height = HEIGHT_PX / DPI

fig = plt.figure(figsize=(fig_width, fig_height), dpi=DPI)
ax = fig.add_axes([0, 0, 1, 1],
                  projection=ccrs.PlateCarree(central_longitude=0))
ax.set_extent([-180, 180, -90, 90], crs=ccrs.PlateCarree())
ax.set_facecolor('none')
fig.patch.set_alpha(0.0)

rivers = cfeature.NaturalEarthFeature(
    category='physical',
    name='rivers_lake_centerlines',
    scale='10m',
    edgecolor='#4488CC',
    facecolor='none'
)
ax.add_feature(rivers, linewidth=0.6, alpha=0.6)

OUTPUT_PATH.parent.mkdir(parents=True, exist_ok=True)
fig.savefig(
    OUTPUT_PATH,
    dpi=DPI,
    format='png',
    transparent=True,
    bbox_inches=None,
    pad_inches=0
)
plt.close(fig)
print(f"Saved: {OUTPUT_PATH}  ({WIDTH_PX}×{HEIGHT_PX})")
