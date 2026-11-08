package plot.images_test

import plot

export main

def main():
  png = fs.read_bytes("test/fixtures/rgba.png")
  fs.write_bytes("out/image-source.png", png)
  raster = plot.image("out/image-source.png")
  base = plot.figure(width: 360, height: 240).domain(0, 0, 10, 10)
  figure = base.image(raster, at: [5, 5], width: 64, anchor: :center)
  expected = base.image(png, at: [5, 5], width: 64).text()
  raise ValueError("path and blob differ") unless figure.text() == expected
  fs.write_bytes("out/image-source.png", Bytes.new("replaced"))
  raise ValueError("image source was reread") unless figure.text() == expected
  bmp = plot.image("test/fixtures/rgb.bmp")
  jpg = plot.image("test/fixtures/rgb.jpg")
  gif = plot.image("test/fixtures/animated.gif")
  raise ValueError("BMP dimensions") unless bmp.width == 2 and bmp.height == 1
  raise ValueError("width aspect ratio") unless base.image(bmp, at: [0, 0], width: 24).layers[0].options[:height] == 12
  raise ValueError("height aspect ratio") unless base.image(bmp, at: [0, 0], height: 18).layers[0].options[:width] == 36
  raise ValueError("JPEG dimensions") unless jpg.width == 2 and jpg.height == 2
  raise ValueError("GIF first frame") unless gif.width == 1 and gif.height == 1 and gif.pixels.hex() == "ff0000ff"
  missing = false
  try:
    plot.image("out/nonexistent-image.png")
  rescue IOError:
    missing = true
  raise ValueError("missing file") unless missing
  # Finite but distant geometry must be clipped before raster iteration.
  base.image(raster, at: [-1.0e100, 1.0e100], width: 1.0e100).bytes(format: :png)
  figure.save("out/images.png")
  figure.save("out/images.svg")
  print("PASS image files, blobs, snapshots, PNG/JPEG/BMP/GIF and exports")
  0
