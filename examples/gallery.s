package examples.gallery

import plot

export main

def hexagon(cx, cy, radius):
  ring = []
  6.times |index|:
    angle = Math.PI() / 3.0 * index
    ring.push!([cx + radius * Math.cos(angle),
      cy + radius * Math.sin(angle)])
  ring

def paraboloid_hexmap():
  cells = []
  column = 0
  while column < 21:
    row = 0
    while row < 14:
      x = column * 1.5
      y = (row + (column % 2) * 0.5) * Math.sqrt(3)
      dx = x - 15.0
      dy = y - 11.7
      height = dx * dx + dy * dy
      cells.push!(plot.polygon(hexagon(x, y, 0.98), value: height))
      row = row + 1
    column = column + 1

  plot.figure(width: 1100, height: 760, background: "#f8fafc")
    .polygon_heatmap(cells, palette: :viridis, stroke: "#f8fafc",
      stroke_width: 1.25, label: "HEIGHT")
    .coordinates(aspect: :equal, padding: 44)
    .axes(show: false)
    .title("PARABOLOID HEIGHT HEXMAP")

def tangent_plot():
  result = plot.figure(width: 1120, height: 680, background: "#fffdf7")
    .domain(0 - 2.5 * Math.PI(), -6, 2.5 * Math.PI(), 6)
    .axes(x_label: "X", y_label: "TAN(X)")
    .title("TANGENT OVER FIVE PERIODS")

  period = -2
  while period < 3:
    points = []
    sample = 0
    while sample <= 180:
      phase = ((0 - Math.PI() / 2.0 + 0.03) +
        sample * (Math.PI() - 0.06) / 180.0)
      x = period * Math.PI() + phase
      y = Math.tan(x)
      if y >= -6 and y <= 6:
        points.push!([x, y])
      sample = sample + 1
    result = result.line(points, stroke: "#d97706", stroke_width: 3)
    period = period + 1

  asymptotes = [
    [-2.5, "-5PI/2"], [-1.5, "-3PI/2"], [-0.5, "-PI/2"],
    [0.5, "PI/2"], [1.5, "3PI/2"], [2.5, "5PI/2"]
  ]
  asymptotes.each_with_index |entry, index|:
    label_dx = 6
    label_dx = -6 if index == asymptotes.count() - 1
    result = result.vline(entry[0] * Math.PI(), label: entry[1],
      stroke: "#64748b", stroke_width: 1.5, opacity: 0.9,
      dash: [7, 5], label_color: "#475569", dx: label_dx, dy: 7)
  result

def terrain_height(x, y):
  dx1 = (x - 11.0) / 7.5
  dy1 = (y - 17.0) / 6.5
  dx2 = (x - 30.0) / 6.0
  dy2 = (y - 8.0) / 5.0
  dx3 = (x - 24.0) / 11.0
  dy3 = (y - 21.0) / 4.0
  (1150 * Math.exp(0 - 1.7 * (dx1 * dx1 + dy1 * dy1)) +
    820 * Math.exp(0 - 1.9 * (dx2 * dx2 + dy2 * dy2)) +
    430 * Math.exp(0 - 2.4 * (dx3 * dx3 + dy3 * dy3)) +
    90 * Math.sin(x * 0.48) * Math.cos(y * 0.37) - 120)

def terrain_map():
  cells = []
  x = 0
  while x < 40:
    y = 0
    while y < 26:
      value = terrain_height(x + 0.5, y + 0.5)
      cells.push!(plot.polygon([[x, y], [x + 1, y],
        [x + 1, y + 1], [x, y + 1]], value: value))
      y = y + 1
    x = x + 1

  terrain = plot.palette([
    "#163c2b", "#24543b", "#3f6d43", "#6f8247", "#9a914f",
    "#b39b68", "#bca98a", "#9e9183", "#d8d3c8", "#ffffff"
  ])
  map = plot.figure(width: 1200, height: 800, background: "#d7eaf4")
    .polygon_heatmap(cells, palette: terrain, stroke: "none",
      stroke_width: 0, label: "ELEVATION")
    .domain(0, 0, 40, 26)
    .coordinates(aspect: :equal, padding: 38)
    .axes(show: false)
    .title("PROCEDURAL TERRAIN MAP")

  lake = plot.polygon([[27.4, 10.4], [29.1, 9.4], [31.3, 9.8],
    [32.6, 11.0], [31.2, 12.0], [28.8, 11.8]])
  river = [[29.5, 10.8], [27.1, 12.0], [25.5, 13.8], [23.0, 14.4],
    [20.8, 13.5], [18.2, 13.9], [15.7, 12.7], [13.2, 11.5],
    [10.4, 10.9], [7.7, 9.2], [4.8, 8.7], [2.0, 7.1], [0, 6.8]]
  road = [[3, 19], [7, 17.5], [11.5, 15.5], [16, 15], [20.5, 13.5],
    [24, 11.5], [28, 8.5], [33, 6.4], [38, 5.2]]
  towns = [[7, 17.5], [16, 15], [24, 11.5], [33, 6.4]]

  map = map.polygons([lake], fill: "#4f9dc4", stroke: "#d6f0ff",
    stroke_width: 2)
  map = map.line(river, stroke: "#3b9fd1", stroke_width: 5)
  map = map.line(road, stroke: "#f3d9a5", stroke_width: 4)
  map.points(towns, fill: "#7f1d1d", radius: 5,
    stroke: "#fff7ed", stroke_width: 2)

def main():
  paraboloid_hexmap().save("examples/output/paraboloid-hexmap.png")
  tangent_plot().save("examples/output/tangent-periods.png")
  terrain_map().save("examples/output/terrain-map.png")
  3
