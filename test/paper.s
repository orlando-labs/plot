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
  # Compare the entire rendered canvas, including all tile boundaries, with
  # natural-sized source pixels. This also catches doubled grid lines at seams.
  sheet = plot.figure(width: 163, height: 161, background: amber)
    .axes(show: false).coordinates(padding: 0)
  sheet_pixels = plot.image(sheet.bytes(format: :png)).pixels
  161.times |y|:
    163.times |x|:
      require(sheet_pixels.slice((y * 163 + x) * 4, 4).hex() ==
        amber.raster.pixels.slice(((y % 80) * 80 + x % 80) * 4, 4).hex(), "grid seam changed")
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
  print("PASS paper tiling, seams, alpha, SVG, views, snapshots and validation")
  0
