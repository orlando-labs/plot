# Sputnik Plot

`plot` is a self-contained 2D and 3D plotting package for Sputnik. Its
implemented core is deliberately geometry-first: arbitrary polygons and
indexed meshes are the common representation for polygon art, triangulations,
heatmaps, plans, maps and 3D surfaces. Built-in backends emit portable 2D SVG
and native 2D/3D PNG without an external plotting library or conversion
utility.

The public specification remains in [API.md](API.md). This implementation
currently covers immutable `Figure` and `Figure3D` models, polygon/mesh
geometry, line and point composition, matrix and polygon heatmaps, map
features, identity and Web Mercator projection, validation, palettes, axes,
colorbars, SVG and PNG export.

## Polygon heatmap

```sputnik
import plot

areas = [
  plot.polygon([[0, 0], [3, 0], [3, 2], [0, 2]], value: 12),
  plot.polygon([[3, 0], [6, 0], [5, 3], [3, 2]], value: 29)
]

plot.figure()
  .polygon_heatmap(areas, palette: :viridis, label: "value")
  .coordinates(aspect: :equal)
  .save("areas.svg")
```

Polygons may contain holes:

```sputnik
shape = plot.polygon(
  [[0, 0], [8, 0], [8, 6], [0, 6]],
  holes: [[[2, 2], [6, 2], [6, 4], [2, 4]]]
)
```

## Triangulation and arbitrary meshes

```sputnik
vertices = [[0, 0], [2, 0], [2, 2], [0, 2]]
triangles = [[0, 1, 2], [0, 2, 3]]

plot.figure()
  .triangulation(vertices, triangles, values: [0.2, 0.9],
    palette: :magma, label: "intensity")
  .coordinates(aspect: :equal)
  .save("mesh.svg")
```

`mesh` also accepts faces with more than three vertices. Values can be attached
to faces (`value_mode: :face`, the default) or vertices
(`value_mode: :vertex`); vertex values are averaged for each vector face.

## Maps

```sputnik
regions = [
  plot.feature(
    plot.polygon([[30, 50], [35, 50], [35, 55], [30, 55]]),
    properties: {name: "North", population: 820000}, id: "N")
]

plot.figure()
  .map(regions, projection: :mercator, value: :population,
    palette: :viridis, label: "population")
  .save("map.svg")
```

Use `projection: :identity` for already projected coordinates and
`:mercator`/`:web_mercator` for longitude/latitude. A `Feature` can contain one
or several `Polygon` values, so multipolygons and islands are represented
without a special rendering path. IDs and properties are embedded into SVG
`<title>` elements for accessible tooltips.

## Technical lines and annotations

Reference lines span the final plot domain, while `guide` accepts any two data
points and `annotate` adds a labeled marker:

```sputnik
plot.figure()
  .line(series)
  .vline(Math.PI() / 2, label: "asymptote", dash: [7, 5])
  .hline(0, label: "baseline")
  .guide([1, 2], [4, 5], label: "trend", dash: [])
  .annotate([3, 4], "maximum")
  .save("annotated.png")
```

`label_at: :start | :middle | :end` selects a line-label anchor. `dx` and `dy`
are screen-pixel offsets, so labels stay readable when the data domain changes.
All annotation types and dash patterns render identically through SVG and PNG.

## Images at data coordinates (0.2.0)

`Figure.image` places a raster image at `at: [x, y]` (or a `Point`). The source
can be a file path string, encoded `Bytes` in memory, or a reusable
`plot.image(source)` / `RasterImage` value:

```sputnik
badge = plot.image("badge.png")
plot.figure().line([[0, 0], [5, 8], [10, 3]])
  .image(badge, at: [5, 8], width: 48, anchor: :bottom, offset: [0, -8])
  .image(blob, at: [10, 3], width: 64, height: 32, anchor: :top_left,
    offset: [6, 6], opacity: 0.8)
  .save("images.png")
```

`width` and `height` are positive, finite screen-pixel sizes. Omit both to use
the source dimensions; supply one to preserve the source aspect ratio; supply
both to stretch to that rectangle. Sizes stay fixed when the domain changes.

`anchor` identifies the point **on the image** attached to the data coordinate:
`:center` (default), `:top_left`, `:top`, `:top_right`, `:right`,
`:bottom_right`, `:bottom`, `:bottom_left`, or `:left`. `offset: [dx, dy]` then
shifts that placement in screen pixels: positive X goes right and positive Y
goes down, for either data-axis orientation. For an arbitrary top-left offset,
use `anchor: :top_left, offset: [dx, dy]`. `opacity` ranges from 0 to 1.

PNG, JPEG, BMP and GIF are decoded by the bundled
[stb_image](https://github.com/nothings/stb/blob/4e9b368bfc071e97206ea5c6adba68dd0cbf8897/stb_image.h)
decoder; GIF uses its first frame, and JPEG EXIF orientation is not applied.
Input is limited to 64 MiB, 16384 pixels per side and 16 million pixels total.
Invalid or unsupported data raises `ArgumentError`; filesystem failures retain
their usual errors. Loading a path requires the normal filesystem-read grant;
decoding requires a native adapter (including for SVG output).

The source is read and decoded once when added or loaded with `plot.image`.
Rendering never rereads it. SVG embeds a PNG data URI; PNG composites the same
RGBA pixels with alpha-aware bilinear resizing. Images follow layer order,
remain upright, contribute their anchor point to automatic bounds, and are
clipped to the plot area, including in `view(...)`. Notebook hosts using scene
version 1 display the complete PNG for figures containing images; interactive
zoom remains available through `view(...)` in code.

## 2D data views and notebook zoom

`Figure.view` creates a new figure with a data-coordinate window. It is not a
bitmap crop: geometry is clipped, axes and ticks are redrawn, and annotations
are included only when their entire label fits inside the plot area.

```sputnik
p = plot.figure().line([[0, 0], [1, 1], [2, 4], [3, 9]])
detail = p.view(x: [1, 2.5], y: [0, 7])
detail.save("detail.png")  # SVG works as well
```

Both axes are optional. An omitted axis keeps the current figure's range;
calling `detail.view(x: [1.5, 2])` keeps `y: [0, 7]`. Bounds must be finite,
increasing numeric pairs. `p` remains unchanged, and the view retains all
source layers, styles, labels, colorbars and coordinate orientation.

In Sputnik Notebook for macOS, pass the **figure**, not its rendered PNG:

```sputnik
notebook.show(p, caption: "Drag a rectangle to inspect the curve")
```

The native viewer supports rectangle selection, X/Y minimum/maximum inputs,
reset, and saving/sharing the current view from its lightbox. It redraws an
inert scene locally without rerunning Sputnik. Live frames keep an explicitly
selected range until reset. This currently applies to 2D figures; 3D figures,
pre-rendered images and scenes exceeding the host's limits retain the raster
viewer. UI zoom is temporary presentation state, not a change to the Sputnik
value or saved project; use `view(...)` in code for a reproducible view.

## Graph paper backgrounds (0.3.0)

Version 0.3.0 adds repeatable paper tiles for
2D figures. The tiles are generated procedurally in Sputnik: warm `:amber` or
cool `:blue` paper, fine subdivisions, stronger lines every five and ten cells,
and subtle, deterministic paper grain.

```sputnik
paper = plot.graph_paper(style: :amber, spacing: 8, texture: true)
plot.figure(background: paper)
  .line([[0, 0], [1, 2], [2, 1]], stroke: "#234663")
  .save("old-school.png")
paper.save("paper-tile.png")  # .svg also works

# A custom PNG/JPEG/BMP/GIF path, Bytes, or loaded RasterImage works too.
custom = plot.tiled_background("paper-tile.png", color: "#ffffff")
plot.figure(background: custom).line([[0, 0], [1, 1]]).save("custom.svg")
```

`graph_paper` returns a `GraphPaper` background. Its grain repeats at natural
pixel size, while grid lines are drawn separately **in data coordinates inside
the plot frame**. Major lines and axis ticks share one calculation, anchored to
multiples of the tick step from data zero. Each major interval has ten minor
subdivisions and a stronger half-interval line. `view` and `screen` recompute
the coordinate transform, clipping and ticks, including for downward Y and
equal-aspect coordinates. Margins keep the paper grain without grid lines.

By default, each view chooses a readable major step from 1, 2, 2.5, 5 × a power
of ten. `spacing` (integer 4–32, default 8) is a density hint for this automatic
selection, rather than a fixed screen-pixel grid. Set explicit steps in **data
units** to retain exactly the same units per cell through zoom:

```sputnik
p = plot.figure(background: plot.graph_paper(style: :blue))
  .axes(x_step: 2, y_step: 0.5, x_label: "VOLTAGE / V", y_label: "CURRENT / mA")
  .line([[0, 0], [4, 1], [8, 2]])
p.view(x: [1, 5], y: [0.25, 1.25]).save("detail.png")
# .axes(x_step: null, y_step: null) restores automatic steps.
```

Custom `tiled_background` images retain their original behavior: read once,
repeat at natural size from canvas `(0, 0)`, with an optional solid `color`
underlay for transparent pixels. They suppress the ordinary gray grid.
`GraphPaper.save` exports a standalone sample tile (80 × 80 by default), with
`spacing` pixels per minor sample cell. The sample is independent of a figure's
data coordinates. `texture: false` disables paper grain. SVG embeds a single
grain image and vector grid lines; PNG composites the same grain and lines.
Both remain self-contained. From 0.3.1, Notebook scene v2 also transports the
bounded RGBA grain tile, tick-step settings and typography. Updated macOS and
web viewers recalculate the grid and labels locally on selection, pan, zoom
and reset, and use the same renderer for PNG export. Older scene-v1 viewers
keep the full PNG fallback. Arbitrary image layers and custom raster backgrounds
remain raster-only. Use `view(...)` in code to save a reproducible range.

2D export text defaults to dark `#1f2937`, with 16 px ticks and colorbar labels,
18 px axis names, 26 px titles, and 16 px annotations. PNG's built-in bitmap
font now uses the requested glyph height with fractional antialiasing, so
12–15 px sizes no longer collapse to 7 px. Customize axes, titles and colorbars
with `.typography(size: 20, color: "#152535")`; annotation layers retain their
own `label_size` and `label_color` options. Default padding is 72 px.

Run the two Sputnik examples (damped oscillation and synthetic Ohm's-law
measurements with a least-squares fit):

```sh
mkdir -p out/paper
../sputnik-lang/build/sputnik run examples/graph_paper.build.yaml --grant fs.write=out/paper --grant ffi
```

`out/paper/` contains both tiles and both graphs in PNG and self-contained SVG,
plus zoomed views of both graphs. Source: [examples/graph_paper.s](examples/graph_paper.s).
For the focused tile checks:

```sh
../sputnik-lang/build/sputnik run test/paper.build.yaml --grant fs.read=test/fixtures --grant fs.read=out/paper --grant fs.write=out/paper --grant ffi
```

## Static 3D and view state

`Figure3D` renders indexed geometry through a z-buffered native PNG backend.
The same surface can be shown as a filled surface, a surface with mesh edges,
a wireframe, contours, a surface with contours, or points:

```sputnik
xs = [-2, -1, 0, 1, 2]
ys = [-2, -1, 0, 1, 2]
z = ys.map |y|: xs.map |x|: x * x + y * y

plot.figure3d(width: 1100, height: 760)
  .surface(z, x: xs, y: ys, preset: :surface_mesh,
    palette: :viridis)
  .asymptote_plane(:z, 0, label: "z = 0", opacity: 0.18)
  .camera(preset: :isometric)
  .axes(x_label: "X", y_label: "Y", z_label: "HEIGHT")
  .save("surface.png")
```

Surface presets are `:surface`, `:surface_mesh`, `:wireframe` (also `:mesh`),
`:contours`, `:surface_contours`, and `:points`. Camera presets are
`:isometric`, `:three_quarter`, `:presentation`, `:top`, `:front`, `:back`,
`:left`, and `:right`. Every preset can be refined with `azimuth`, `elevation`,
`roll`, `distance`, `target`, `projection`, `fov`, and `ortho_scale`.

The camera is stored in the immutable `ViewState3D` rather than in the PNG
renderer:

```sputnik
view = plot.view3d(:three_quarter)
next_view = view.rotated(azimuth: 12, elevation: -4).zoomed(1.15)
next_frame = figure.view(next_view)
scene = next_frame.scene()
```

This keeps input handling out of the plotting core while giving a future
notebook-like adapter a stable state transition and a backend-neutral
`Scene3D`. No notebook adapter or event loop is part of the package yet.
Asymptotic planes are axis-aligned (`:x`, `:y`, or `:z`) and default to 18%
opacity; their fill, stroke, label, width, and opacity can be customized.

## Build and test

```sh
../sputnik-lang/build/sputnik build sputnik.build.yaml --target both --out-dir build
../sputnik-lang/build/sputnik build test/selftest.build.yaml --target both --out-dir out
./out/plot.selftest
```

SVG and PNG are built-in output formats:

```sputnik
svg: Str = figure.text(format: :svg)
bytes: Bytes = figure.bytes(format: :svg)
figure.save("figure.svg")

png: Bytes = figure.bytes(format: :png)
figure.save("figure.png")
```

The PNG backend is compiled with the package and includes RGBA compositing,
even-odd polygon fills (including holes), 2D mesh faces, antialiased lines and
points, axes, labels and colorbars. Its 3D path adds camera projection, depth
testing, opaque and transparent passes, triangle shading, mesh edges,
depth-aware lines, points and contour overlays. It uses Sputnik's native extension
ABI; its bundled image decoder needs no additional system libraries. Execution
without a native adapter reports that PNG and image decoding require a native
package build. Unsupported formats
such as PDF are rejected with `UnsupportedFormatError`; the package never
writes a differently encoded file under a misleading extension.
