package examples.triangulation_heatmap

import plot

export main

def main():
  vertices = [
    [0, 0], [2, 0], [4, 0],
    [0, 2], [2, 2], [4, 2],
    [1, 4], [3, 4]
  ]
  triangles = [
    [0, 1, 4], [0, 4, 3],
    [1, 2, 5], [1, 5, 4],
    [3, 4, 6], [4, 7, 6], [4, 5, 7]
  ]
  temperatures = [12, 18, 27, 23, 31, 36, 29]

  plot.figure(width: 900, height: 620)
    .triangulation(vertices, triangles, values: temperatures,
      palette: :magma, label: "temperature")
    .coordinates(aspect: :equal)
    .axes(x_label: "x", y_label: "y")
    .title("Triangulation heatmap")
    .save("triangulation-heatmap.svg")
