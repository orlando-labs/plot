package plot.paper_test

import plot

export main

def require(condition, message):
  raise ValueError(message) unless condition

def main():
  # A non-square tile tests both phases and incomplete tiles at canvas edges.
  source = plot.image("test/fixtures/rgb.bmp")
  paper = plot.tiled_background(source)
  base = plot.figure(width: 7, height: 5, background: paper)
    .axes(show: false).coordinates(padding: 0).domain(0, 0, 1, 1)
  raster = plot.image(base.bytes(format: :png))
  5.times |y|:
    7.times |x|:
      require(raster.pixels.slice((y * 7 + x) * 4, 4).hex() ==
        source.pixels.slice((x % 2) * 4, 4).hex(), "tile phase or edge differs")
  rgba = Base64.decode("iVBORw0KGgoAAAANSUhEUgAAAAIAAAACCAYAAABytg0kAAAAFklEQVR4nGP4z8DwHwgbGIA0EDAwAABB1Qd6cSjDtAAAAABJRU5ErkJggg==")
  transparent = plot.figure(width: 5, height: 3,
    background: plot.tiled_background(rgba, color: "transparent"))
    .axes(show: false).coordinates(padding: 0)
  pixels = plot.image(transparent.bytes(format: :png)).pixels
  require(pixels.slice(4, 4).hex() == "00ff0080", "tile alpha lost")
  require(pixels.slice((2 * 5 + 3) * 4, 4).hex() == "00ff0080", "alpha at repeated edge differs")
  opaque = plot.figure(width: 2, height: 2, background: plot.tiled_background(rgba))
    .axes(show: false).coordinates(padding: 0)
  require(plot.image(opaque.bytes(format: :png)).pixels.slice(4, 4).hex() == "7fff7fff",
    "tile alpha was not composited over the underlay")
  require(base.view(x: [0.2, 0.8]).bytes(format: :png).hex() == base.bytes(format: :png).hex(),
    "view changed paper scale or phase")
  require(base.screen(width: 9).background == paper, "copy lost background")
  require(base.notebook_scene() == null, "unsupported notebook scene exposed")
  svg = base.text()
  require(svg.contains?("<pattern") and svg.contains?("patternUnits=\"userSpaceOnUse\"") and
    svg.contains?("data:image/png;base64,") and svg.contains?("url(#plot-paper)"), "SVG tile missing")

  amber = plot.graph_paper()
  blue = plot.graph_paper(style: :blue)
  require(amber.raster.width == 80 and amber.raster.height == 80, "tile dimensions")
  require(amber.raster.png.hex() == plot.graph_paper().raster.png.hex(), "paper is not reproducible")
  require(amber.raster.png.hex() != blue.raster.png.hex(), "paper palettes identical")
  require(amber.raster.png.hex() != plot.graph_paper(texture: false).raster.png.hex(), "texture has no effect")
  # A generic tile remains a screen-space decoration; graph paper separates
  # its stationary grain from a grid anchored to actual data coordinates.
  flat = plot.graph_paper(texture: false)
  grid = plot.figure(width: 480, height: 360, background: flat)
    .coordinates(padding: 40).domain(-1, -1, 3, 3).axes(x_step: 1, y_step: 1)
  whole = grid.text()
  require(whole.contains?("paper-grid-line major x\" data-value=\"0\" x1=\"140\"") and
    whole.contains?("axis-tick x\" data-value=\"0\" x=\"140\""), "major grid and X tick differ")
  require(whole.contains?("paper-grid-line major y\" data-value=\"0\" x1=\"40\" y1=\"250\""),
    "major Y grid differs from data transform")
  zoom = grid.view(x: [0.25, 2.25])
  require(zoom.x_step == 1 and zoom.y_step == 1 and grid.domain_value == [-1, -1, 3, 3],
    "view lost fixed steps or mutated original")
  require(zoom.text().contains?("paper-grid-line major x\" data-value=\"1\" x1=\"190\"") and
    zoom.text().contains?("axis-tick x\" data-value=\"1\" x=\"190\""), "zoom grid and tick differ")
  down = grid.coordinates(y: :down).text()
  require(down.contains?("paper-grid-line major y\" data-value=\"0\" x1=\"40\" y1=\"110\""),
    "downward Y grid differs")
  equal = grid.coordinates(aspect: :equal).text()
  require(equal.contains?("paper-grid-line major x\" data-value=\"0\" x1=\"170\""),
    "equal-aspect grid ignores centered frame")
  auto = plot.figure(width: 480, height: 360, background: flat)
    .coordinates(padding: 40).domain(-0.3, -0.6, 3.7, 3.4)
  require(auto.text().contains?("paper-grid-line major x\" data-value=\"0\" x1=\"70\""),
    "automatic grid follows view edge instead of data zero")
  auto.view(x: [0.001, 0.007], y: [-0.0005, 0.0005]).bytes(format: :png)
  auto.domain(1.0e250, 1.0e-100, 2.0e250, 2.0e-100).bytes(format: :png)
  precise = auto.axes(x_step: 0.00000001).view(x: [1, 1.00000004]).text()
  require(precise.contains?(">1.00000001</text>") and precise.contains?(">1.00000002</text>"),
    "deep zoom collapses distinct tick labels")
  # Raster positions must agree with the SVG transform as well.
  before_pixels = plot.image(grid.bytes(format: :png)).pixels
  after_pixels = plot.image(zoom.bytes(format: :png)).pixels
  require(before_pixels.slice((62 * 480 + 140) * 4, 4).hex() != "faf3dfff" and
    before_pixels.slice((62 * 480 + 145) * 4, 4).hex() == "faf3dfff", "PNG major line position differs")
  require(after_pixels.slice((62 * 480 + 190) * 4, 4).hex() != "faf3dfff" and
    after_pixels.slice((62 * 480 + 140) * 4, 4).hex() == "faf3dfff", "PNG grid did not scale and pan")
  require(whole.contains?("font-size=\"16\" fill=\"#1f2937\""), "default text size or contrast")
  styled = grid.typography(size: 20, color: "#152535").view(x: [0, 2])
  require(styled.font_size == 20 and styled.text_color == "#152535" and
    styled.text().contains?("font-size=\"20\" fill=\"#152535\""), "typography lost on copy")
  letters = plot.figure(width: 96, height: 96).axes(show: false).coordinates(padding: 0)
    .annotate([0.5, 0.5], "H", fill: "none", stroke: "none", label_size: 17, dx: 0, dy: 0)
    .domain(0, 0, 1, 1)
  glyph = plot.image(letters.bytes(format: :png)).pixels
  first_row = 96
  last_row = -1
  96.times |y|:
    96.times |x|:
      if glyph.slice((y * 96 + x) * 4, 4).hex() != "ffffffff":
        first_row = Math.min(first_row, y)
        last_row = Math.max(last_row, y)
  require(last_row - first_row + 1 == 17, "PNG font size still rounds down")
  with_axes = plot.figure(width: 300, height: 200, background: amber).line([[0, 0], [1, 1]])
  require(not with_axes.text().contains?("#e5e7eb"), "default grid overlays paper")
  require(plot.figure().text().contains?("#e5e7eb"), "ordinary grid disappeared")
  amber.save("out/paper/test-tile.png")
  require(plot.image("out/paper/test-tile.png").png.hex() == amber.raster.png.hex(), "saved tile differs")
  custom = plot.tiled_background("out/paper/test-tile.png")
  require(custom.raster.png.hex() == amber.raster.png.hex(), "custom path tile differs")
  snapshot = plot.figure(width: 81, height: 81, background: custom)
    .axes(show: false).coordinates(padding: 0)
  before = snapshot.bytes(format: :png).hex()
  fs.write_bytes("out/paper/test-tile.png", Bytes.new("replaced"))
  require(snapshot.bytes(format: :png).hex() == before, "background source was reread")

  [0, 3, 33, 8.5, "8"].each |spacing|:
    rejected = false
    try:
      plot.graph_paper(spacing: spacing)
    rescue ArgumentError:
      rejected = true
    require(rejected, "invalid spacing accepted")
  rejected = false
  try:
    plot.graph_paper(style: :unknown)
  rescue ArgumentError:
    rejected = true
  require(rejected, "unknown paper style accepted")
  rejected = false
  try:
    plot.graph_paper(texture: "true")
  rescue ArgumentError:
    rejected = true
  require(rejected, "invalid texture flag accepted")
  [0, -1, "1"].each |step|:
    rejected = false
    try:
      grid.axes(x_step: step)
    rescue ArgumentError:
      rejected = true
    require(rejected, "invalid tick step accepted")
  rejected = false
  try:
    grid.axes(x_step: 0.000001).bytes(format: :png)
  rescue ArgumentError:
    rejected = true
  require(rejected, "unbounded grid iteration accepted")
  print("PASS paper tiles, data grid, ticks, zoom, orientation, alpha and typography")
  0
