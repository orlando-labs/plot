package examples.gallery3d

import plot

export main

def linspace(first, last, count):
  values = []
  count.times |index|:
    ratio = index * 1.0 / (count - 1)
    values.push!(first + ratio * (last - first))
  values

def paraboloid_figure():
  xs = linspace(-3, 3, 33)
  ys = linspace(-3, 3, 33)
  heights = ys.map |y|:
    xs.map |x|: 0.32 * (x * x + y * y)
  plot.figure3d(width: 1100, height: 780, background: "#f8fafc")
    .surface(heights, x: xs, y: ys, preset: :surface_mesh,
      palette: :viridis, edge_color: "#334155", edge_width: 0.65)
    .camera(preset: :isometric)
    .axes(x_label: "X", y_label: "Y", z_label: "HEIGHT")
    .title("PARABOLOID - SURFACE MESH")

def reciprocal_figure():
  negative_x = linspace(-4, -0.35, 25)
  positive_x = linspace(0.35, 4, 25)
  ys = linspace(-3, 3, 31)
  negative_z = ys.map |y|:
    negative_x.map |x|: 1.5 / x + 0.08 * y
  positive_z = ys.map |y|:
    positive_x.map |x|: 1.5 / x + 0.08 * y
  cold = plot.palette(["#172554", "#1d4ed8", "#38bdf8", "#bae6fd"])
  warm = plot.palette(["#ffedd5", "#fb923c", "#ea580c", "#7c2d12"])
  plot.figure3d(width: 1120, height: 780, background: "#fffdf7")
    .surface(negative_z, x: negative_x, y: ys, preset: :surface,
      palette: cold)
    .surface(positive_z, x: positive_x, y: ys, preset: :surface,
      palette: warm)
    .asymptote_plane(:x, 0, label: "X = 0", fill: "#ef4444",
      stroke: "#991b1b", opacity: 0.20)
    .asymptote_plane(:z, 0, label: "Z = 0", fill: "#3b82f6",
      stroke: "#1d4ed8", opacity: 0.16)
    .camera(preset: :presentation, azimuth: -48, elevation: 27,
      distance: 19, fov: 38)
    .axes(x_label: "X", y_label: "Y", z_label: "1.5/X")
    .title("RECIPROCAL SURFACE AND ASYMPTOTIC PLANES")

def terrain_figure():
  xs = linspace(-6, 6, 39)
  ys = linspace(-4.5, 4.5, 31)
  heights = ys.map |y|:
    xs.map |x|:
      peak_a = 3.8 * Math.exp(0 - ((x + 2.0) * (x + 2.0) / 5.0 +
        (y - 0.8) * (y - 0.8) / 3.5))
      peak_b = 2.9 * Math.exp(0 - ((x - 2.6) * (x - 2.6) / 3.0 +
        (y + 1.3) * (y + 1.3) / 4.0))
      ridge = 0.55 * Math.sin(x * 1.15) * Math.cos(y * 0.85)
      peak_a + peak_b + ridge - 0.35
  terrain = plot.palette([
    "#123c2d", "#2f6b3e", "#6f873d", "#a28f4f", "#bca477",
    "#a69b8f", "#d8d3c8", "#ffffff"
  ])
  plot.figure3d(width: 1180, height: 800, background: "#e8f3f8")
    .surface(heights, x: xs, y: ys, preset: :surface_contours,
      palette: terrain, levels: 11, contour_color: "#f8fafc",
      contour_width: 1.2, shading: :smooth)
    .camera(preset: :three_quarter, azimuth: -52, elevation: 34,
      distance: 24, fov: 39)
    .axes(x_label: "EAST", y_label: "NORTH", z_label: "ELEVATION")
    .title("PROCEDURAL TERRAIN - SURFACE CONTOURS")

def main():
  paraboloid_figure().save("examples/output/paraboloid-3d.png")
  reciprocal_figure().save("examples/output/reciprocal-asymptotes-3d.png")
  terrain_figure().save("examples/output/terrain-contours-3d.png")
  3
