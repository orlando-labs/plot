# Sputnik Plot

`sputnik-plot` is a self-contained 2D and 3D plotting package for Sputnik. Its
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
ABI but no third-party raster or compression dependency. Bytecode-only
execution reports that PNG requires a native package build. Unsupported formats
such as PDF are rejected with `UnsupportedFormatError`; the package never
writes a differently encoded file under a misleading extension.
