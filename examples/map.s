package examples.map

import plot

export main

def main():
  regions = [
    plot.feature(
      plot.polygon([[28, 52], [34, 52], [34, 57], [28, 57]]),
      properties: {name: "West", density: 42}, id: "west"),
    plot.feature(
      plot.polygon([[34, 51], [41, 51], [41, 57], [34, 57]]),
      properties: {name: "East", density: 81}, id: "east")
  ]

  plot.figure(width: 900, height: 560)
    .map(regions, projection: :mercator, value: :density,
      palette: :viridis, label: "density")
    .title("Regions")
    .save("map.svg")
