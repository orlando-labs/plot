package plot.selftest

import plot
from plot import UnsupportedFormatError

export main

EXPECTED = 32

def check(score, condition):
  if condition:
    score + 1
  else:
    score

def main():
  score = 0

  # A polygon with a hole and metadata.
  island = plot.polygon(
    [[0, 0], [6, 0], [6, 5], [0, 5]],
    holes: [[[2, 1], [4, 1], [4, 3], [2, 3]]],
    value: 12, id: "island", properties: {population: 1200})
  base = plot.figure(width: 640, height: 420)
  map_figure = base.polygon_heatmap([island], label: "population")
    .coordinates(aspect: :equal)
    .title("Polygon map")
  svg = map_figure.text()

  score = check(score, base.layers.count() == 0 and map_figure.layers.count() == 1)
  score = check(score, svg.starts_with?("<svg") and svg.contains?("fill-rule=\"evenodd\""))
  score = check(score, svg.contains?("island") and svg.contains?("population: 1200"))
  score = check(score, svg.contains?("class=\"colorbars\"") and svg.contains?("Polygon map"))

  # Face-valued triangulation heatmap.
  vertices = [[0, 0], [2, 0], [2, 2], [0, 2], [1, 3]]
  triangles = [[0, 1, 2], [0, 2, 3], [3, 2, 4]]
  tri = plot.figure(width: 500, height: 400)
    .triangulation(vertices, triangles, values: [0.1, 0.7, 1.0],
      palette: :magma, label: "intensity")
    .coordinates(aspect: :equal)
  tri_svg = tri.text()
  score = check(score, tri.validate().count() == 0)
  score = check(score, tri_svg.contains?("class=\"layer mesh\"") and tri_svg.split("<path").count() == 4)
  score = check(score, tri_svg.contains?("intensity") and tri_svg.contains?("#fcfdbf"))

  # Vertex-valued meshes reduce values to each face.
  vertex_mesh = plot.figure().mesh(vertices, triangles,
    values: [0, 1, 2, 3, 4], value_mode: :vertex)
  vertex_svg = vertex_mesh.text()
  score = check(score, vertex_mesh.validate().count() == 0 and vertex_svg.contains?("<title>1"))

  # Matrix heatmaps are polygon layers.
  matrix = plot.figure(width: 360, height: 260)
    .heatmap([[1, 2, 3], [4, 5, 6]])
    .axes(show: false)
  matrix_svg = matrix.text()
  score = check(score, matrix.layers[0].data.count() == 6)
  score = check(score, matrix_svg.split("<path").count() == 7)

  # Feature metadata and Mercator projection.
  country = plot.feature(
    plot.polygon([[30, 50], [35, 50], [35, 55], [30, 55]]),
    properties: {name: "Example", score: 9}, id: "EX")
  geographic = plot.figure().map([country], projection: :mercator, value: :score)
  geo_svg = geographic.text()
  score = check(score, geographic.axes_visible == false and geographic.aspect_mode == :equal)
  score = check(score, geo_svg.contains?("Example") and geo_svg.contains?("value: 9"))

  # Ordinary series compose with polygon geometry.
  composite = plot.figure().polygons([island], opacity: 0.4)
    .line([[0, 0], [3, 4], [6, 1]])
    .points([[1, 1], [5, 4]])
  composite_svg = composite.text()
  score = check(score, composite_svg.contains?("<polyline") and composite_svg.split("<circle").count() == 3)

  # Reference lines, arbitrary guides and labeled point annotations compose
  # with ordinary plot layers in both backends.
  annotated = plot.figure(width: 520, height: 360)
    .domain(0, 0, 6, 5)
    .vline(2, label: "asymptote")
    .hline(3, label: "threshold", dash: [3, 2])
    .guide([0, 1], [5, 4], label: "trend")
    .annotate([4, 2], "sample")
  annotation_svg = annotated.text()
  score = check(score, annotation_svg.contains?("class=\"layer annotation vline\"") and
    annotation_svg.contains?("class=\"layer annotation hline\"") and
    annotation_svg.contains?("class=\"layer annotation guide\"") and
    annotation_svg.contains?("class=\"layer annotation point\""))
  score = check(score, annotation_svg.contains?("stroke-dasharray=\"6 5\"") and
    annotation_svg.contains?("asymptote") and annotation_svg.contains?("sample"))
  annotation_png = annotated.render(format: :png)
  score = check(score, annotation_png.bytes.slice(0, 8).hex() ==
    "89504e470d0a1a0a")

  # Views preserve geometry/styles, recompute coordinates, and clip geometry
  # and labels to the new data domain in both export backends.
  whole = plot.figure(width: 640, height: 420).title("View test")
    .line([[0, 0], [2, 4], [4, 16]])
    .annotate([2, 4], "inside")
    .annotate([4, 16], "outside")
  zoomed = whole.view(x: [1, 3], y: [0, 10])
  score = check(score, whole.domain_value == null and zoomed.domain_value == [1, 0, 3, 10])
  score = check(score, zoomed.layers == whole.layers and zoomed.title_text == whole.title_text)
  score = check(score, zoomed.view(x: [1.5, 2.5]).domain_value == [1.5, 0, 2.5, 10])
  zoom_svg = zoomed.text()
  score = check(score, zoom_svg.contains?("clip-path=\"url(#plot-clip)\"") and
    zoom_svg.contains?("inside") and not zoom_svg.contains?("outside"))
  score = check(score, zoomed.render(format: :png).bytes.slice(0, 8).hex() == "89504e470d0a1a0a")
  zoom_scene = zoomed.coordinates(y: :down).notebook_scene()
  score = check(score, zoom_scene[:version] == 1 and zoom_scene[:y_down] and
    zoom_scene[:bounds] == [1, 0, 3, 10] and zoom_scene[:layers].count() == 3)
  bad_view = false
  try:
    whole.view(x: [3, 1])
  rescue ArgumentError:
    bad_view = true
  score = check(score, bad_view)
  # Dash iteration is bounded by the visible interval, not endpoint distance.
  long_guide = plot.figure(width: 320, height: 240)
    .guide([-1.0e12, 0], [1.0e12, 0], dash: [6, 5])
    .view(x: [-1, 1], y: [-1, 1]).render(format: :png)
  score = check(score, long_guide.bytes.slice(0, 8).hex() == "89504e470d0a1a0a")

  # Immutable 3D view state, surface presets and transparent asymptotic planes.
  initial_view = plot.view3d(preset: :isometric)
  rotated_view = initial_view.rotated(azimuth: 15, elevation: -5)
  score = check(score, initial_view.azimuth == 45 and rotated_view.azimuth == 60 and
    rotated_view.elevation < initial_view.elevation)
  figure_3d = plot.figure3d(width: 480, height: 360)
    .surface([[0, 1], [1, 2]], preset: :surface_mesh)
    .asymptote_plane(:z, 0, label: "Z = 0")
    .camera(preset: :isometric)
  scene_3d = figure_3d.scene()
  score = check(score, figure_3d.layers.count() == 2 and
    figure_3d.layers[1].opacity < 0.2)
  score = check(score, scene_3d.metadata[:triangles] == 2 and
    scene_3d.commands.count() > 4)
  png_3d = figure_3d.render(format: :png)
  score = check(score, png_3d.mime == "image/png" and
    png_3d.bytes.slice(0, 8).hex() == "89504e470d0a1a0a")

  # Invalid topology is diagnosed before rendering.
  invalid = plot.figure().triangulation([[0, 0], [1, 0], [0, 1]], [[0, 1, 9]])
  diagnostics = invalid.validate()
  score = check(score, diagnostics.count() == 1 and diagnostics[0].code == :invalid_vertex_index)

  mismatch = plot.figure().polygon_heatmap([island], values: [1, 2])
  score = check(score, mismatch.validate()[0].code == :value_count_mismatch)

  png = map_figure.render(format: :png)
  score = check(score, png.mime == "image/png" and png.width == 640 and
    png.height == 420 and png.bytes.count() > 100 and
    png.bytes.slice(0, 8).hex() == "89504e470d0a1a0a")

  unsupported = false
  try:
    map_figure.render(format: :pdf)
  rescue UnsupportedFormatError |error|:
    unsupported = error.message.contains?(":svg") and error.message.contains?(":png")
  score = check(score, unsupported)

  score
