package examples.graph_paper

import plot

export main

def oscillation(paper):
  signal = []
  upper = []
  lower = []
  601.times |i|:
    t = i / 50.0
    envelope = 4 * Math.exp(0 - 0.22 * t)
    signal.push!([t, envelope * Math.cos(2 * Math.PI() * 0.65 * t)])
    upper.push!([t, envelope])
    lower.push!([t, 0 - envelope])
  plot.figure(width: 1200, height: 800, background: paper)
    .coordinates(padding: 80).domain(0, -5, 12, 5)
    .title("LAB 01 / DAMPED OSCILLATION")
    .axes(x_label: "TIME / s", y_label: "AMPLITUDE / V")
    .line(upper, stroke: "#a65f3b", stroke_width: 1.4, opacity: 0.7)
    .line(lower, stroke: "#a65f3b", stroke_width: 1.4, opacity: 0.7)
    .hline(0, stroke: "#735a42", stroke_width: 1, dash: [])
    .line(signal, stroke: "#234663", stroke_width: 2.5)
    .annotate([7.8, 3.6], "4 exp(-0.22 t) cos(2 PI 0.65 t)",
      fill: "none", stroke: "none", label_color: "#193b57", dx: 0, dy: -8)
    .annotate([8.6, 1.8], "ENVELOPE: +/- 4 exp(-0.22 t)",
      fill: "none", stroke: "none", label_color: "#703b24", dx: 0, dy: -8)

def measurements(paper):
  # Synthetic laboratory readings with deterministic measurement error.
  errors = [0.02, -0.03, 0.04, -0.02, 0.01, -0.04, 0.03, 0.01, -0.02, 0.02, -0.01]
  samples = []
  errors.each_with_index |error, i|:
    voltage = 0.5 + i * 0.8
    samples.push!([voltage, voltage / 4.7 + error])
  mean_x = samples.map |p|: p[0]
  mean_y = samples.map |p|: p[1]
  mx = mean_x.sum() / samples.count()
  my = mean_y.sum() / samples.count()
  numerator = 0.0
  denominator = 0.0
  samples.each |p|:
    numerator = numerator + (p[0] - mx) * (p[1] - my)
    denominator = denominator + (p[0] - mx) * (p[0] - mx)
  slope = numerator / denominator
  intercept = my - slope * mx
  result = plot.figure(width: 1200, height: 800, background: paper)
    .coordinates(padding: 80).domain(0, 0, 10, 2.5)
    .title("LAB 02 / OHM'S LAW")
    .axes(x_label: "VOLTAGE / V", y_label: "CURRENT / mA")
    .guide([0, intercept], [10, 10 * slope + intercept],
      stroke: "#9e493b", stroke_width: 2, dash: [], opacity: 1)
  samples.each |p|:
    result = result.guide([p[0], p[1] - 0.045], [p[0], p[1] + 0.045],
      stroke: "#244c64", stroke_width: 1.1, dash: [], opacity: 0.85)
  result.points(samples, fill: paper.color, stroke: "#244c64", stroke_width: 2, radius: 4.5)
    .annotate([2.4, 2.05], "11 SYNTHETIC MEASUREMENTS", fill: "none", stroke: "none",
      label_color: "#173d55", dx: 0, dy: -8)
    .annotate([2.4, 1.78], "LEAST-SQUARES FIT / R ~ 4.7 kOhm", fill: "none", stroke: "none",
      label_color: "#803629", dx: 0, dy: -8)

def main():
  amber = plot.graph_paper(style: :amber)
  blue = plot.graph_paper(style: :blue)
  amber.save("out/paper/amber-tile.png")
  amber.save("out/paper/amber-tile.svg")
  blue.save("out/paper/blue-tile.png")
  blue.save("out/paper/blue-tile.svg")
  first = oscillation(amber)
  second = measurements(blue)
  first.save("out/paper/damped-oscillation.png")
  first.save("out/paper/damped-oscillation.svg")
  second.save("out/paper/ohms-law.png")
  second.save("out/paper/ohms-law.svg")
  first.view(x: [2, 5], y: [-2, 2]).save("out/paper/oscillation-detail.png")
  first.view(x: [2, 5], y: [-2, 2]).save("out/paper/oscillation-detail.svg")
  second.view(x: [3, 7], y: [0.5, 1.6]).save("out/paper/ohms-law-detail.png")
  second.view(x: [3, 7], y: [0.5, 1.6]).save("out/paper/ohms-law-detail.svg")
  print("Graph paper tiles and Sputnik plots saved to out/paper/")
  0
