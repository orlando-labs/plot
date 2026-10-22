package plot

# Sputnik Plot is a declarative, immutable plotting API with self-contained SVG
# and PNG backends. Polygons and indexed meshes are the primitive geometry:
# maps, triangulations and heatmaps are thin adapters over the same renderer.

export figure, point, polygon, feature, palette
export figure3d, point3, view3d
export Figure, Point, Polygon, Feature, Palette, Layer, Diagnostic, Rendered
export Figure3D, Point3, ViewState3D, Scene3D, Layer3D
export PlotError, ValidationError, UnsupportedFormatError

class PlotError < Exception:
  attr message

  def init(@message)
  def to_str():
    @message

class ValidationError < PlotError:
  attr diagnostics

  def init(@message, @diagnostics = [])

class UnsupportedFormatError < PlotError

native def _render_png_native(width as Int, height as Int, background as Str,
    commands as List) -> Bytes from "plot.render_png":
  raise UnsupportedFormatError("PNG rendering requires a native plot build")

native def _render_3d_png_native(width as Int, height as Int,
    background as Str, scene as List) -> Bytes from "plot.render_3d_png":
  raise UnsupportedFormatError("3D PNG rendering requires a native plot build")

class Diagnostic:
  attr severity
  attr code
  attr message
  attr layer

  def init(@severity, @code, @message, @layer = null)

class Point:
  attr x
  attr y

  def init(@x, @y):
    _require_number(@x, "point x")
    _require_number(@y, "point y")

  def to_array():
    [@x, @y]

class Point3:
  attr x
  attr y
  attr z

  def init(@x, @y, @z):
    _require_number(@x, "point3 x")
    _require_number(@y, "point3 y")
    _require_number(@z, "point3 z")

  def to_array():
    [@x, @y, @z]

class ViewState3D:
  attr preset
  attr azimuth
  attr elevation
  attr roll
  attr distance
  attr target
  attr projection
  attr fov
  attr ortho_scale

  def init(@preset = :three_quarter, @azimuth = 45, @elevation = 25,
      @roll = 0, @distance = :auto, @target = :auto,
      @projection = :perspective, @fov = 42, @ortho_scale = :auto)

  def with(preset: @preset, azimuth: @azimuth, elevation: @elevation,
      roll: @roll, distance: @distance, target: @target,
      projection: @projection, fov: @fov, ortho_scale: @ortho_scale):
    ViewState3D(preset, azimuth, elevation, roll, distance, target,
      projection, fov, ortho_scale)

  def rotated(azimuth: 0, elevation: 0, roll: 0):
    with(azimuth: @azimuth + azimuth, elevation: @elevation + elevation,
      roll: @roll + roll, preset: :custom)

  def zoomed(factor):
    _require_positive(factor, "view zoom factor")
    next_distance = @distance
    next_scale = @ortho_scale
    next_distance = @distance / factor if _number?(@distance)
    next_scale = @ortho_scale / factor if _number?(@ortho_scale)
    with(distance: next_distance, ortho_scale: next_scale, preset: :custom)

  def targeted(value):
    with(target: _coerce_point3(value).to_array(), preset: :custom)

class Layer3D:
  attr kind
  attr data
  attr values
  attr value_mode
  attr opacity
  attr palette
  attr label
  attr options

  def init(kind, data, values: null, value_mode: :vertex,
      opacity: 1, palette: null, label: null, options: {}):
    @kind = kind
    @data = data
    @values = values.copy if Array === values
    @values = values unless Array === values
    @value_mode = value_mode
    @opacity = opacity
    @palette = palette
    @label = label
    @options = options.copy

class Scene3D:
  attr bounds
  attr camera
  attr commands
  attr title
  attr metadata

  def init(@bounds, @camera, @commands, @title = null, @metadata = {})

  def native_payload():
    title_text = ""
    title_text = @title.to_str if @title != null
    [@camera, @bounds, @commands, title_text]

class Polygon:
  attr rings
  attr value
  attr fill
  attr stroke
  attr id
  attr properties

  def init(outer, holes: [], value: null, fill: null, stroke: null, id: null, properties: {}):
    @rings = [_coerce_ring(outer)]
    holes.each |hole|:
      @rings.push!(_coerce_ring(hole))
    @value = value
    @fill = fill
    @stroke = stroke
    @id = id
    @properties = properties.copy

  def outer():
    @rings[0]

  def holes():
    _tail(@rings)

class Feature:
  attr polygons
  attr properties
  attr value
  attr fill
  attr stroke
  attr id

  def init(geometry, properties: {}, value: null, fill: null, stroke: null, id: null):
    @polygons = _coerce_polygons(geometry)
    @properties = properties.copy
    @value = value
    @fill = fill
    @stroke = stroke
    @id = id

class Palette:
  attr colors
  attr name
  attr missing

  def init(colors, name: :custom, missing: "#d1d5db"):
    unless Array === colors and colors.count() > 0:
      raise ArgumentError("palette requires at least one color")
    colors.each |color|:
      unless Str === color and color.starts_with?("#"):
        raise ArgumentError("palette colors must be CSS hex strings")
    @colors = colors.copy
    @name = name
    @missing = missing

  def color(value, min: 0, max: 1):
    return @missing if value == null
    return value if Str === value and value.starts_with?("#")
    unless _number?(value):
      return @colors[_stable_bucket(value.to_str, @colors.count())]
    span = max - min
    ratio = if span == 0 then 0.5 else (value - min) * 1.0 / span
    ratio = 0 if ratio < 0
    ratio = 1 if ratio > 1
    index = Math.floor(ratio * (@colors.count() - 1)).to_int()
    @colors[index]

class Layer:
  attr kind
  attr data
  attr values
  attr value_mode
  attr fill
  attr stroke
  attr stroke_width
  attr opacity
  attr palette
  attr label
  attr options

  def init(kind, data, values: null, value_mode: :face, fill: null,
      stroke: "#ffffff", stroke_width: 1, opacity: 1, palette: null,
      label: null, options: {}):
    @kind = kind
    @data = data
    @values = values.copy if Array === values
    @values = values unless Array === values
    @value_mode = value_mode
    @fill = fill
    @stroke = stroke
    @stroke_width = stroke_width
    @opacity = opacity
    @palette = palette
    @label = label
    @options = options.copy

  def with(fill: @fill, stroke: @stroke, stroke_width: @stroke_width,
      opacity: @opacity, palette: @palette, label: @label):
    Layer(@kind, @data, values: @values, value_mode: @value_mode,
      fill: fill, stroke: stroke, stroke_width: stroke_width,
      opacity: opacity, palette: palette, label: label, options: @options)

class Rendered:
  attr format
  attr mime
  attr bytes
  attr width
  attr height
  attr diagnostics
  attr metadata

  def init(@format, @mime, content, @width, @height, @diagnostics = [], @metadata = {}):
    if Bytes === content:
      @text_value = null
      @bytes = content
    else:
      @text_value = content
      @bytes = Bytes.new(content)

  def text():
    if @text_value == null:
      raise UnsupportedFormatError("rendered PNG is binary; use bytes")
    @text_value

class Figure:
  attr width
  attr height
  attr background
  attr layers
  attr title_text
  attr axes_visible
  attr aspect_mode
  attr y_direction
  attr padding_value
  attr palette_value
  attr domain_value
  attr x_label
  attr y_label

  def init(width: 1120, height: 700, background: "#ffffff", layers: [],
      title: null, axes: true, aspect: :auto, y_direction: :up, padding: 56,
      palette: null, domain: null, x_label: null, y_label: null):
    _require_positive(width, "width")
    _require_positive(height, "height")
    @width = width
    @height = height
    @background = background
    @layers = layers.copy
    @title_text = title
    @axes_visible = axes
    @aspect_mode = aspect
    @y_direction = y_direction
    @padding_value = padding
    @palette_value = _palette_of(palette or :sputnik)
    @domain_value = domain.copy if Array === domain
    @domain_value = domain unless Array === domain
    @x_label = x_label
    @y_label = y_label

  def screen(width: @width, height: @height):
    _copy({width: width, height: height})

  def title(value):
    _copy({title: value})

  def axes(show: true, x_label: @x_label, y_label: @y_label):
    _copy({axes: show, x_label: x_label, y_label: y_label})

  def coordinates(aspect: @aspect_mode, y: @y_direction, padding: @padding_value):
    unless aspect == :auto or aspect == :equal:
      raise ArgumentError("aspect must be :auto or :equal")
    unless y == :up or y == :down:
      raise ArgumentError("y must be :up or :down")
    _copy({aspect: aspect, y_direction: y, padding: padding})

  def domain(x_min, y_min, x_max, y_max):
    _copy({domain: [x_min, y_min, x_max, y_max]})

  # A data-coordinate view, not a cropped bitmap. Geometry and styles remain
  # shared; axes, ticks and annotations are resolved anew on every render.
  def view(x: null, y: null):
    bounds = @domain_value or _figure_bounds(@layers)
    xr = if x == null then [bounds[0], bounds[2]] else x
    yr = if y == null then [bounds[1], bounds[3]] else y
    _require_view_range(xr, "x")
    _require_view_range(yr, "y")
    domain(xr[0], yr[0], xr[1], yr[1])

  # Inert, versioned scene for notebook hosts. Screen geometry retains its
  # source coordinate transform, and guide/label semantics stay explicit.
  def notebook_scene():
    bounds = @domain_value or _figure_bounds(@layers)
    layout = _layout(self, bounds)
    scene_layers = []
    @layers.each_with_index |layer, index|:
      commands = []
      _png_layer(commands, layer, self, layout, index, fit_labels: false)
      metadata = {kind: layer.kind.to_str, commands: commands}
      if layer.kind == :vline or layer.kind == :hline:
        metadata.store!(:guide_value, layer.data)
      if layer.kind == :vline or layer.kind == :hline or layer.kind == :guide or layer.kind == :annotation:
        label_points = [layer.data]
        unless layer.kind == :annotation:
          label_points = _annotation_line_points(layer, bounds, @y_direction)
        anchor = _annotation_label_data_point(layer, label_points)
        metadata.store!(:anchor, [anchor.x, anchor.y])
        metadata.store!(:offset, [layer.options[:dx], layer.options[:dy]])
        metadata.store!(:label_at, layer.options[:label_at].to_str)
      scene_layers.push!(metadata)
    decorations = []
    _png_colorbars(decorations, self, layout)
    {version: 1, bounds: bounds, frame: [layout[:left], layout[:top], layout[:plot_width], layout[:plot_height]],
      padding: @padding_value, color_scale: _has_color_scale(@layers), aspect_equal: @aspect_mode == :equal,
      y_down: @y_direction == :down, axes: @axes_visible, background: @background,
      title: (@title_text or "").to_str, x_label: (@x_label or "").to_str, y_label: (@y_label or "").to_str,
      layers: scene_layers, decorations: decorations}

  def palette(value):
    _copy({palette: _palette_of(value)})

  # Adds arbitrary polygons. A single ring, a list of Polygon values, and
  # Feature values are accepted. Holes use SVG's even-odd fill rule.
  def polygons(data, values: null, fill: null, stroke: "#ffffff",
      stroke_width: 1, opacity: 1, palette: null, label: null):
    geometries = _coerce_polygons(data)
    assigned = []
    geometries.each_with_index |shape, index|:
      value = shape.value
      if Array === values:
        value = values[index] if index < values.count()
      assigned.push!(Polygon(shape.outer(), holes: shape.holes(), value: value,
        fill: shape.fill, stroke: shape.stroke, id: shape.id,
        properties: shape.properties))
    layer = Layer(:polygons, assigned, values: values, fill: fill,
      stroke: stroke, stroke_width: stroke_width, opacity: opacity,
      palette: palette, label: label)
    _append(layer)

  def polygon_heatmap(data, values: null, palette: :viridis,
      stroke: "#ffffff", stroke_width: 0.75, opacity: 1, label: null):
    polygons(data, values: values, palette: palette, stroke: stroke,
      stroke_width: stroke_width, opacity: opacity, label: label)

  # Indexed faces may contain three or more vertex indices. With
  # value_mode: :vertex, each face receives the mean of its vertex values.
  def mesh(vertices, faces, values: null, value_mode: :face, fill: null,
      palette: null, stroke: "#ffffff", stroke_width: 0.75, opacity: 1,
      label: null):
    verts = vertices.map |entry|: _coerce_point(entry)
    copied_faces = faces.map |face|: face.copy
    data = {vertices: verts, faces: copied_faces}
    layer = Layer(:mesh, data, values: values, value_mode: value_mode,
      fill: fill, stroke: stroke, stroke_width: stroke_width,
      opacity: opacity, palette: palette, label: label)
    _append(layer)

  def triangulation(vertices, triangles, values: null, value_mode: :face,
      fill: null, palette: null, stroke: "#ffffff", stroke_width: 0.75,
      opacity: 1, label: null):
    layer_figure = mesh(vertices, triangles, values: values,
      value_mode: value_mode, fill: fill, palette: palette, stroke: stroke,
      stroke_width: stroke_width, opacity: opacity, label: label)
    layer = layer_figure.layers.last()
    options = layer.options.copy
    options.store!(:triangles_only, true)
    replacement = Layer(:mesh, layer.data, values: layer.values,
      value_mode: layer.value_mode, fill: layer.fill, stroke: layer.stroke,
      stroke_width: layer.stroke_width, opacity: layer.opacity,
      palette: layer.palette, label: layer.label, options: options)
    next_layers = @layers.copy
    next_layers.push!(replacement)
    _copy({layers: next_layers})

  # Matrix heatmaps are represented by unit square polygons, so they share
  # color scaling, vector export and composition with all other geometry.
  def heatmap(matrix, palette: :viridis, stroke: "none", stroke_width: 0,
      opacity: 1, label: null):
    cells = []
    matrix.each_with_index |row, y|:
      row.each_with_index |value, x|:
        cells.push!(Polygon([[x, y], [x + 1, y], [x + 1, y + 1], [x, y + 1]],
          value: value))
    polygons(cells, palette: palette, stroke: stroke,
      stroke_width: stroke_width, opacity: opacity, label: label)

  def line(data, stroke: null, stroke_width: 2, opacity: 1, label: null):
    series = _series_points(data)
    layer = Layer(:line, series, stroke: stroke or _categorical_color(@layers.count()),
      stroke_width: stroke_width, opacity: opacity, label: label)
    _append(layer)

  def points(data, fill: null, radius: 4, stroke: "#ffffff",
      stroke_width: 1, opacity: 1, label: null):
    series = _series_points(data)
    layer = Layer(:points, series, fill: fill or _categorical_color(@layers.count()),
      stroke: stroke, stroke_width: stroke_width, opacity: opacity,
      label: label, options: {radius: radius})
    _append(layer)

  # Reference lines span the resolved plot domain and do not change the other
  # axis. They are useful for asymptotes, thresholds and technical guides.
  def vline(x, label: null, stroke: "#64748b", stroke_width: 1.25,
      opacity: 0.8, dash: [6, 5], label_color: null, label_size: 12,
      label_at: :start, dx: 6, dy: 6):
    _require_number(x, "vertical line x")
    options = _annotation_options(dash, label_color or stroke, label_size,
      label_at, dx, dy)
    _append(Layer(:vline, x, stroke: stroke, stroke_width: stroke_width,
      opacity: opacity, label: label, options: options))

  def hline(y, label: null, stroke: "#64748b", stroke_width: 1.25,
      opacity: 0.8, dash: [6, 5], label_color: null, label_size: 12,
      label_at: :end, dx: -6, dy: -14):
    _require_number(y, "horizontal line y")
    options = _annotation_options(dash, label_color or stroke, label_size,
      label_at, dx, dy)
    _append(Layer(:hline, y, stroke: stroke, stroke_width: stroke_width,
      opacity: opacity, label: label, options: options))

  # An arbitrary annotated technical segment in data coordinates.
  def guide(start, finish, label: null, stroke: "#64748b",
      stroke_width: 1.25, opacity: 0.8, dash: [], label_color: null,
      label_size: 12, label_at: :middle, dx: 0, dy: -14):
    guide_points = [_coerce_point(start), _coerce_point(finish)]
    options = _annotation_options(dash, label_color or stroke, label_size,
      label_at, dx, dy)
    _append(Layer(:guide, guide_points, stroke: stroke, stroke_width: stroke_width,
      opacity: opacity, label: label, options: options))

  # A labeled point. Label offsets are screen pixels so they remain legible at
  # every data scale and in both vector and raster output.
  def annotate(point, label, fill: "#b91c1c", radius: 5,
      stroke: "#ffffff", stroke_width: 1.5, opacity: 1,
      label_color: "#374151", label_size: 12, dx: 8, dy: -12):
    _require_positive(radius, "annotation radius")
    options = _annotation_options([], label_color, label_size, :start, dx, dy)
    options.store!(:radius, radius)
    _append(Layer(:annotation, _coerce_point(point), fill: fill, stroke: stroke,
      stroke_width: stroke_width, opacity: opacity, label: label,
      options: options))

  # A map is a polygon layer with optional Web Mercator projection, equal
  # scales and no axes. Feature metadata is preserved in SVG <title> nodes.
  def map(features, projection: :identity, value: null, palette: :viridis,
      fill: null, stroke: "#ffffff", stroke_width: 0.75, opacity: 1,
      label: null):
    shapes = []
    raw = if Feature === features then [features] else features
    raw.each |entry|:
      if Feature === entry:
        entry.polygons.each |shape|:
          picked = entry.value
          if Symbol === value or Str === value:
            picked = _property(entry.properties, value, picked)
          projected = _project_polygon(shape, projection)
          shapes.push!(Polygon(projected.outer(), holes: projected.holes(),
            value: picked, fill: entry.fill or shape.fill,
            stroke: entry.stroke or shape.stroke, id: entry.id or shape.id,
            properties: entry.properties))
      else:
        shape = _project_polygon(_coerce_polygon(entry), projection)
        shapes.push!(shape)
    result = polygons(shapes, fill: fill, palette: palette, stroke: stroke,
      stroke_width: stroke_width, opacity: opacity, label: label)
    result.coordinates(aspect: :equal).axes(show: false)

  def validate():
    diagnostics = []
    if @domain_value:
      unless Array === @domain_value and @domain_value.count() == 4:
        diagnostics.push!(Diagnostic(:error, :invalid_domain,
          "domain must be [x_min, y_min, x_max, y_max]"))
      else:
        if @domain_value[2] <= @domain_value[0] or @domain_value[3] <= @domain_value[1]:
          diagnostics.push!(Diagnostic(:error, :invalid_domain,
            "domain maximums must be greater than minimums"))
    @layers.each_with_index |layer, layer_index|:
      if layer.kind == :polygons:
        if Array === layer.values and layer.values.count() != layer.data.count():
          diagnostics.push!(Diagnostic(:error, :value_count_mismatch,
            "polygon values count does not match polygon count", layer_index))
        layer.data.each |shape|:
          shape.rings.each |ring|:
            if ring.count() < 3:
              diagnostics.push!(Diagnostic(:error, :short_ring,
                "polygon rings require at least three points", layer_index))
      elif layer.kind == :mesh:
        vertices = layer.data[:vertices]
        faces = layer.data[:faces]
        faces.each |face|:
          if face.count() < 3:
            diagnostics.push!(Diagnostic(:error, :short_face,
              "mesh faces require at least three indices", layer_index))
          if layer.options.has_key?(:triangles_only) and face.count() != 3:
            diagnostics.push!(Diagnostic(:error, :not_a_triangle,
              "triangulation faces must contain exactly three indices", layer_index))
          face.each |index|:
            unless Int === index and index >= 0 and index < vertices.count():
              diagnostics.push!(Diagnostic(:error, :invalid_vertex_index,
                "mesh face contains an out-of-range vertex index", layer_index))
        if Array === layer.values:
          expected = faces.count()
          expected = vertices.count() if layer.value_mode == :vertex
          if layer.values.count() != expected:
            diagnostics.push!(Diagnostic(:error, :value_count_mismatch,
              "mesh values count does not match " + layer.value_mode.to_str + " count",
              layer_index))
          unless layer.value_mode == :vertex or layer.value_mode == :face:
            diagnostics.push!(Diagnostic(:error, :invalid_value_mode,
              "mesh value_mode must be :face or :vertex", layer_index))
    diagnostics

  def render(format: :svg):
    unless format == :svg or format == :png:
      raise UnsupportedFormatError("built-in backends support :svg and :png; requested " + format.to_str)
    diagnostics = validate()
    errors = diagnostics.select |item|: item.severity == :error
    if errors.count() > 0:
      raise ValidationError("figure contains invalid geometry", diagnostics)
    bounds = @domain_value or _figure_bounds(@layers)
    if format == :svg:
      svg = _render_svg(self, bounds)
      return Rendered(:svg, "image/svg+xml", svg, @width, @height, diagnostics,
        {bounds: bounds, layers: @layers.count(), backend: :svg})
    commands = _png_commands(self, bounds)
    png = _render_png_native(@width, @height, @background, commands)
    Rendered(:png, "image/png", png, @width, @height, diagnostics,
      {bounds: bounds, layers: @layers.count(), backend: :png})

  def text(format: :svg):
    unless format == :svg:
      raise UnsupportedFormatError("text is only available for :svg; use bytes for :png")
    render(format: format).text()

  def bytes(format: :svg):
    render(format: format).bytes

  def save(path, format: null):
    path_text = if Str === path then path else path.to_str()
    selected = format or _format_from_path(path_text)
    unless selected == :svg or selected == :png:
      raise UnsupportedFormatError("built-in backends support :svg and :png")
    extension = "." + selected.to_str
    if format and path_text.contains?(".") and not path_text.ends_with?(extension):
      raise ArgumentError("path extension conflicts with format " + selected.to_str)
    if selected == :svg:
      _write_text_file(path_text, text(format: selected))
    else:
      _write_bytes_file(path_text, bytes(format: selected))
    null

  def _append(layer):
    next_layers = @layers.copy
    next_layers.push!(layer)
    _copy({layers: next_layers})

  def _copy(changes):
    Figure(
      width: _pick(changes, :width, @width),
      height: _pick(changes, :height, @height),
      background: _pick(changes, :background, @background),
      layers: _pick(changes, :layers, @layers),
      title: _pick(changes, :title, @title_text),
      axes: _pick(changes, :axes, @axes_visible),
      aspect: _pick(changes, :aspect, @aspect_mode),
      y_direction: _pick(changes, :y_direction, @y_direction),
      padding: _pick(changes, :padding, @padding_value),
      palette: _pick(changes, :palette, @palette_value),
      domain: _pick(changes, :domain, @domain_value),
      x_label: _pick(changes, :x_label, @x_label),
      y_label: _pick(changes, :y_label, @y_label))

class Figure3D:
  attr width
  attr height
  attr background
  attr layers
  attr title_text
  attr axes_visible
  attr padding_value
  attr palette_value
  attr view_state
  attr x_label
  attr y_label
  attr z_label

  def init(width: 1120, height: 760, background: "#f8fafc", layers: [],
      title: null, axes: true, padding: 54, palette: null, view_state: null,
      x_label: "X", y_label: "Y", z_label: "Z"):
    _require_positive(width, "width")
    _require_positive(height, "height")
    @width = width
    @height = height
    @background = background
    @layers = layers.copy
    @title_text = title
    @axes_visible = axes
    @padding_value = padding
    @palette_value = _palette_of(palette or :viridis)
    @view_state = view_state or _view_preset(:three_quarter)
    @x_label = x_label
    @y_label = y_label
    @z_label = z_label

  def screen(width: @width, height: @height):
    _copy({width: width, height: height})

  def title(value):
    _copy({title: value})

  def axes(show: true, x_label: @x_label, y_label: @y_label,
      z_label: @z_label):
    _copy({axes: show, x_label: x_label, y_label: y_label, z_label: z_label})

  def view(state):
    unless ViewState3D === state:
      raise ArgumentError("view requires plot.ViewState3D")
    _validate_view3d(state)
    _copy({view_state: state})

  def camera(preset: null, azimuth: null, elevation: null, roll: null,
      distance: null, target: null, projection: null, fov: null,
      ortho_scale: null):
    next_view = @view_state
    next_view = _view_preset(preset) if preset != null
    next_view = next_view.with(
      preset: if preset == null then :custom else preset,
      azimuth: _current_or(azimuth, next_view.azimuth),
      elevation: _current_or(elevation, next_view.elevation),
      roll: _current_or(roll, next_view.roll),
      distance: _current_or(distance, next_view.distance),
      target: _current_or(target, next_view.target),
      projection: _current_or(projection, next_view.projection),
      fov: _current_or(fov, next_view.fov),
      ortho_scale: _current_or(ortho_scale, next_view.ortho_scale))
    _validate_view3d(next_view)
    _copy({view_state: next_view})

  def surface(z, x: null, y: null, preset: :surface, palette: :viridis,
      opacity: 1, edge_color: "#334155", edge_width: 0.8,
      levels: 10, contour_color: "#ffffff", contour_width: 1.5,
      shading: :smooth, label: null):
    geometry = _surface3d_geometry(z, x, y)
    options = _surface3d_options(preset, edge_color, edge_width, levels,
      contour_color, contour_width, shading)
    layer = Layer3D(:mesh, geometry, values: geometry[:values],
      value_mode: :vertex, opacity: opacity, palette: palette,
      label: label, options: options)
    _append(layer)

  def mesh3d(vertices, faces, values: null, value_mode: :vertex,
      preset: :surface, palette: :viridis, opacity: 1,
      edge_color: "#334155", edge_width: 0.8, levels: 10,
      contour_color: "#ffffff", contour_width: 1.5,
      shading: :smooth, label: null):
    geometry = _mesh3d_geometry(vertices, faces)
    assigned_values = values
    if assigned_values == null:
      assigned_values = geometry[:vertices].map |vertex|: vertex.z
      value_mode = :vertex
    options = _surface3d_options(preset, edge_color, edge_width, levels,
      contour_color, contour_width, shading)
    layer = Layer3D(:mesh, geometry, values: assigned_values,
      value_mode: value_mode, opacity: opacity, palette: palette,
      label: label, options: options)
    _append(layer)

  def line3d(data, stroke: "#d97706", stroke_width: 2.5, opacity: 1,
      label: null):
    points3 = data.map |entry|: _coerce_point3(entry)
    layer = Layer3D(:line, points3, opacity: opacity, label: label,
      options: {stroke: stroke, stroke_width: stroke_width})
    _append(layer)

  def points3d(data, fill: "#b91c1c", radius: 4,
      stroke: "#ffffff", stroke_width: 1, opacity: 1, label: null):
    points3 = data.map |entry|: _coerce_point3(entry)
    layer = Layer3D(:points, points3, opacity: opacity, label: label,
      options: {fill: fill, radius: radius, stroke: stroke,
        stroke_width: stroke_width})
    _append(layer)

  def asymptote_plane(axis, value, label: null, fill: null,
      stroke: null, stroke_width: 1.2, opacity: 0.18):
    unless axis == :x or axis == :y or axis == :z:
      raise ArgumentError("asymptote plane axis must be :x, :y or :z")
    _require_number(value, "asymptote plane value")
    plane_fill = fill or _plane_color3d(axis)
    plane_stroke = stroke or _plane_stroke3d(axis)
    options = {axis: axis, value: value, fill: plane_fill,
      stroke: plane_stroke, stroke_width: stroke_width}
    _append(Layer3D(:plane, null, opacity: opacity, label: label,
      options: options))

  def validate():
    _validate_figure3d(self)

  def scene():
    diagnostics = validate()
    errors = diagnostics.select |item|: item.severity == :error
    if errors.count() > 0:
      raise ValidationError("3D figure contains invalid geometry", diagnostics)
    _scene3d(self, diagnostics)

  def render(format: :png):
    unless format == :png:
      raise UnsupportedFormatError("the built-in 3D backend currently supports :png")
    resolved_scene = scene()
    png = _render_3d_png_native(@width, @height, @background,
      resolved_scene.native_payload())
    Rendered(:png, "image/png", png, @width, @height,
      resolved_scene.metadata[:diagnostics],
      resolved_scene.metadata)

  def bytes(format: :png):
    render(format: format).bytes

  def save(path, format: null):
    path_text = if Str === path then path else path.to_str()
    selected = format or _format_from_path(path_text)
    unless selected == :png:
      raise UnsupportedFormatError("3D figures currently save as PNG")
    if path_text.contains?(".") and not path_text.ends_with?(".png"):
      raise ArgumentError("3D PNG path must end with .png")
    _write_bytes_file(path_text, bytes(format: :png))
    null

  def _append(layer):
    next_layers = @layers.copy
    next_layers.push!(layer)
    _copy({layers: next_layers})

  def _copy(changes):
    Figure3D(
      width: _pick(changes, :width, @width),
      height: _pick(changes, :height, @height),
      background: _pick(changes, :background, @background),
      layers: _pick(changes, :layers, @layers),
      title: _pick(changes, :title, @title_text),
      axes: _pick(changes, :axes, @axes_visible),
      padding: _pick(changes, :padding, @padding_value),
      palette: _pick(changes, :palette, @palette_value),
      view_state: _pick(changes, :view_state, @view_state),
      x_label: _pick(changes, :x_label, @x_label),
      y_label: _pick(changes, :y_label, @y_label),
      z_label: _pick(changes, :z_label, @z_label))

def figure(width: 1120, height: 700, background: "#ffffff"):
  Figure(width: width, height: height, background: background)

def figure3d(width: 1120, height: 760, background: "#f8fafc"):
  Figure3D(width: width, height: height, background: background)

def point(x, y):
  Point(x, y)

def point3(x, y, z):
  Point3(x, y, z)

def view3d(preset: :three_quarter):
  _view_preset(preset)

def polygon(outer, holes: [], value: null, fill: null, stroke: null,
    id: null, properties: {}):
  Polygon(outer, holes: holes, value: value, fill: fill, stroke: stroke,
    id: id, properties: properties)

def feature(geometry, properties: {}, value: null, fill: null, stroke: null,
    id: null):
  Feature(geometry, properties: properties, value: value, fill: fill,
    stroke: stroke, id: id)

def palette(colors, missing: "#d1d5db"):
  Palette(colors, missing: missing)

# ---------------------------------------------------------------- geometry

def _number?(value):
  Int === value or Float === value

def _require_number(value, label):
  unless _number?(value):
    raise ArgumentError(label + " must be numeric")
  unless value - value == 0:
    raise ArgumentError(label + " must be finite")
  value

def _require_positive(value, label):
  _require_number(value, label)
  unless value > 0:
    raise ArgumentError(label + " must be greater than zero")
  value

def _require_view_range(values, axis):
  unless (Array === values or Tuple === values) and values.count() == 2:
    raise ArgumentError(axis + " view must be [minimum, maximum]")
  values.each |value|:
    _require_number(value, axis + " view bound")
    unless value - value == 0:
      raise ArgumentError(axis + " view bounds must be finite")
  unless values[1] > values[0] and values[1] * 1.0 - values[0] < 1.0e300:
    raise ArgumentError(axis + " view maximum must exceed minimum with a finite span")
  values

def _coerce_point(value):
  return value if Point === value
  if (Array === value or Tuple === value) and value.count() >= 2:
    return Point(value[0], value[1])
  raise ArgumentError("point must be plot.Point or [x, y]")

def _coerce_point3(value):
  return value if Point3 === value
  if (Array === value or Tuple === value) and value.count() >= 3:
    return Point3(value[0], value[1], value[2])
  raise ArgumentError("point3 must be plot.Point3 or [x, y, z]")

def _current_or(value, fallback):
  if value == null then fallback else value

def _view_preset(name):
  if name == :isometric:
    return ViewState3D(:isometric, 45, 35.264, 0, :auto, :auto,
      :orthographic, 42, :auto)
  if name == :three_quarter:
    return ViewState3D(:three_quarter, 45, 25, 0, :auto, :auto,
      :perspective, 42, :auto)
  if name == :presentation:
    return ViewState3D(:presentation, -38, 30, 0, :auto, :auto,
      :perspective, 36, :auto)
  if name == :top:
    return ViewState3D(:top, 45, 89.9, 0, :auto, :auto,
      :orthographic, 42, :auto)
  if name == :front:
    return ViewState3D(:front, -90, 0, 0, :auto, :auto,
      :orthographic, 42, :auto)
  if name == :back:
    return ViewState3D(:back, 90, 0, 0, :auto, :auto,
      :orthographic, 42, :auto)
  if name == :left:
    return ViewState3D(:left, 180, 0, 0, :auto, :auto,
      :orthographic, 42, :auto)
  if name == :right:
    return ViewState3D(:right, 0, 0, 0, :auto, :auto,
      :orthographic, 42, :auto)
  raise ArgumentError("unknown 3D camera preset: " + name.to_str)

def _validate_view3d(state):
  _require_number(state.azimuth, "camera azimuth")
  _require_number(state.elevation, "camera elevation")
  _require_number(state.roll, "camera roll")
  if state.elevation <= -90 or state.elevation >= 90:
    raise ArgumentError("camera elevation must be between -90 and 90 degrees")
  unless state.distance == :auto or (_number?(state.distance) and state.distance > 0):
    raise ArgumentError("camera distance must be :auto or positive")
  unless state.target == :auto or Array === state.target or Tuple === state.target:
    raise ArgumentError("camera target must be :auto or [x, y, z]")
  _coerce_point3(state.target) unless state.target == :auto
  unless state.projection == :perspective or state.projection == :orthographic:
    raise ArgumentError("camera projection must be :perspective or :orthographic")
  _require_number(state.fov, "camera fov")
  if state.fov <= 1 or state.fov >= 179:
    raise ArgumentError("camera fov must be between 1 and 179 degrees")
  unless (state.ortho_scale == :auto or
      (_number?(state.ortho_scale) and state.ortho_scale > 0)):
    raise ArgumentError("orthographic scale must be :auto or positive")
  state

def _surface3d_geometry(z, x_values, y_values):
  unless Array === z and z.count() >= 2:
    raise ArgumentError("surface z must contain at least two rows")
  unless Array === z[0] and z[0].count() >= 2:
    raise ArgumentError("surface rows must contain at least two values")
  row_count = z.count()
  column_count = z[0].count()
  z.each |row|:
    unless Array === row and row.count() == column_count:
      raise ArgumentError("surface z must be a rectangular matrix")
    row.each |value|: _require_number(value, "surface z value")
  xs = []
  if x_values == null:
    column_count.times |column|: xs.push!(column)
  else:
    unless ((Array === x_values or Tuple === x_values) and
        x_values.count() == column_count):
      raise ArgumentError("surface x count must match z columns")
    x_values.each |value|: xs.push!(_require_number(value, "surface x value"))
  ys = []
  if y_values == null:
    row_count.times |row|: ys.push!(row)
  else:
    unless ((Array === y_values or Tuple === y_values) and
        y_values.count() == row_count):
      raise ArgumentError("surface y count must match z rows")
    y_values.each |value|: ys.push!(_require_number(value, "surface y value"))

  vertices = []
  values = []
  row_count.times |row|:
    column_count.times |column|:
      height = z[row][column]
      vertices.push!(Point3(xs[column], ys[row], height))
      values.push!(height)
  triangles = []
  sources = []
  face_index = 0
  (row_count - 1).times |row|:
    (column_count - 1).times |column|:
      a = row * column_count + column
      b = a + 1
      d = (row + 1) * column_count + column
      c = d + 1
      triangles.push!([a, b, c])
      sources.push!(face_index)
      face_index = face_index + 1
      triangles.push!([a, c, d])
      sources.push!(face_index)
      face_index = face_index + 1
  {vertices: vertices, triangles: triangles, sources: sources,
    face_count: triangles.count(), values: values}

def _mesh3d_geometry(vertices, faces):
  unless Array === vertices or Tuple === vertices:
    raise ArgumentError("mesh3d vertices must be an array")
  unless Array === faces or Tuple === faces:
    raise ArgumentError("mesh3d faces must be an array")
  points = vertices.map |entry|: _coerce_point3(entry)
  triangles = []
  sources = []
  faces.each_with_index |face, face_index|:
    unless (Array === face or Tuple === face) and face.count() >= 3:
      raise ArgumentError("mesh3d faces require at least three indices")
    offset = 1
    while offset < face.count() - 1:
      triangles.push!([face[0], face[offset], face[offset + 1]])
      sources.push!(face_index)
      offset = offset + 1
  {vertices: points, triangles: triangles, sources: sources,
    face_count: faces.count()}

def _surface3d_options(preset, edge_color, edge_width, levels,
    contour_color, contour_width, shading):
  normalized = preset
  normalized = :wireframe if preset == :mesh
  unless (normalized == :surface or normalized == :surface_mesh or
      normalized == :wireframe or normalized == :contours or
      normalized == :surface_contours or normalized == :points):
    raise ArgumentError("unknown 3D surface preset: " + preset.to_str)
  unless Int === levels and levels >= 0:
    unless Array === levels or Tuple === levels:
      raise ArgumentError("contour levels must be a non-negative Int or array")
  unless shading == :smooth or shading == :flat or shading == :unlit:
    raise ArgumentError("3D shading must be :smooth, :flat or :unlit")
  {preset: normalized, edge_color: edge_color, edge_width: edge_width,
    levels: levels, contour_color: contour_color,
    contour_width: contour_width, shading: shading}

def _plane_color3d(axis):
  return "#ef4444" if axis == :x
  return "#22c55e" if axis == :y
  "#3b82f6"

def _plane_stroke3d(axis):
  return "#991b1b" if axis == :x
  return "#166534" if axis == :y
  "#1d4ed8"

# --------------------------------------------------------------- 3D scene

def _validate_figure3d(figure):
  diagnostics = []
  figure.layers.each_with_index |layer, layer_index|:
    if layer.opacity < 0 or layer.opacity > 1:
      diagnostics.push!(Diagnostic(:error, :invalid_opacity,
        "3D layer opacity must be between 0 and 1", layer_index))
    if layer.kind == :mesh:
      vertices = layer.data[:vertices]
      triangles = layer.data[:triangles]
      triangles.each |triangle|:
        triangle.each |index|:
          unless Int === index and index >= 0 and index < vertices.count():
            diagnostics.push!(Diagnostic(:error, :invalid_vertex_index,
              "3D mesh contains an out-of-range vertex index", layer_index))
      if Array === layer.values:
        expected = vertices.count()
        expected = layer.data[:face_count] if layer.value_mode == :face
        if layer.values.count() != expected:
          diagnostics.push!(Diagnostic(:error, :value_count_mismatch,
            "3D mesh values count does not match value_mode", layer_index))
      unless layer.value_mode == :vertex or layer.value_mode == :face:
        diagnostics.push!(Diagnostic(:error, :invalid_value_mode,
          "3D mesh value_mode must be :vertex or :face", layer_index))
  diagnostics

def _empty_bounds3d():
  [null, null, null, null, null, null]

def _include_point3(bounds, point):
  if bounds[0] == null:
    bounds[0] = point.x
    bounds[1] = point.y
    bounds[2] = point.z
    bounds[3] = point.x
    bounds[4] = point.y
    bounds[5] = point.z
  else:
    bounds[0] = point.x if point.x < bounds[0]
    bounds[1] = point.y if point.y < bounds[1]
    bounds[2] = point.z if point.z < bounds[2]
    bounds[3] = point.x if point.x > bounds[3]
    bounds[4] = point.y if point.y > bounds[4]
    bounds[5] = point.z if point.z > bounds[5]
  bounds

def _include_axis3(bounds, axis, value):
  if axis == :x:
    bounds[0] = value if bounds[0] == null or value < bounds[0]
    bounds[3] = value if bounds[3] == null or value > bounds[3]
  elif axis == :y:
    bounds[1] = value if bounds[1] == null or value < bounds[1]
    bounds[4] = value if bounds[4] == null or value > bounds[4]
  else:
    bounds[2] = value if bounds[2] == null or value < bounds[2]
    bounds[5] = value if bounds[5] == null or value > bounds[5]
  bounds

def _bounds3d(layers):
  bounds = _empty_bounds3d()
  layers.each |layer|:
    if layer.kind == :mesh:
      layer.data[:vertices].each |point|: _include_point3(bounds, point)
    elif layer.kind == :line or layer.kind == :points:
      layer.data.each |point|: _include_point3(bounds, point)
  layers.each |layer|:
    if layer.kind == :plane:
      _include_axis3(bounds, layer.options[:axis], layer.options[:value])
  if bounds[0] == null:
    bounds = [-1, -1, -1, 1, 1, 1]
  bounds[0] = -1 if bounds[0] == null
  bounds[1] = -1 if bounds[1] == null
  bounds[2] = -1 if bounds[2] == null
  bounds[3] = 1 if bounds[3] == null
  bounds[4] = 1 if bounds[4] == null
  bounds[5] = 1 if bounds[5] == null
  if bounds[0] == bounds[3]:
    bounds[0] = bounds[0] - 0.5
    bounds[3] = bounds[3] + 0.5
  if bounds[1] == bounds[4]:
    bounds[1] = bounds[1] - 0.5
    bounds[4] = bounds[4] + 0.5
  if bounds[2] == bounds[5]:
    bounds[2] = bounds[2] - 0.5
    bounds[5] = bounds[5] + 0.5
  bounds

def _resolved_camera3d(state, bounds, padding):
  _validate_view3d(state)
  center = Point3((bounds[0] + bounds[3]) / 2.0,
    (bounds[1] + bounds[4]) / 2.0,
    (bounds[2] + bounds[5]) / 2.0)
  target = center
  target = _coerce_point3(state.target) unless state.target == :auto
  dx = bounds[3] - bounds[0]
  dy = bounds[4] - bounds[1]
  dz = bounds[5] - bounds[2]
  radius = Math.sqrt(dx * dx + dy * dy + dz * dz) / 2.0
  radius = 1 if radius <= 0
  distance = state.distance
  if distance == :auto:
    half_fov = state.fov * Math.PI() / 360.0
    distance = radius * 1.35 / Math.tan(half_fov)
  ortho_scale = state.ortho_scale
  if ortho_scale == :auto:
    ortho_scale = Math.max(dx, Math.max(dy, dz)) * 1.45
  projection_code = 0
  projection_code = 1 if state.projection == :orthographic
  [state.azimuth, state.elevation, state.roll, distance,
    target.x, target.y, target.z, projection_code, state.fov,
    ortho_scale, padding]

def _scene3d(figure, diagnostics):
  bounds = _bounds3d(figure.layers)
  camera_values = _resolved_camera3d(figure.view_state, bounds,
    figure.padding_value)
  commands = _commands3d(figure, bounds)
  triangle_count = 0
  figure.layers.each |layer|:
    if layer.kind == :mesh:
      triangle_count = triangle_count + layer.data[:triangles].count()
  metadata = {bounds: bounds, layers: figure.layers.count(),
    triangles: triangle_count, backend: :png3d,
    view_state: figure.view_state, diagnostics: diagnostics}
  Scene3D(bounds, camera_values, commands, figure.title_text, metadata)

def _commands3d(figure, bounds):
  commands = []
  figure.layers.each |layer|:
    if layer.kind == :mesh:
      _mesh_commands3d(commands, layer)
    elif layer.kind == :line:
      points = layer.data.map |point|: point.to_array()
      commands.push!([2, [points], layer.options[:stroke],
        layer.options[:stroke_width], layer.opacity, 1])
    elif layer.kind == :points:
      points = layer.data.map |point|: point.to_array()
      commands.push!([3, points, layer.options[:fill], layer.options[:stroke],
        layer.options[:stroke_width], layer.options[:radius], layer.opacity])
    elif layer.kind == :plane:
      _plane_commands3d(commands, layer, bounds)
  _axes_commands3d(commands, figure, bounds) if figure.axes_visible
  commands

def _preset_has_fill3d(preset):
  (preset == :surface or preset == :surface_mesh or
    preset == :surface_contours)

def _preset_has_edges3d(preset):
  preset == :surface_mesh or preset == :wireframe

def _preset_has_contours3d(preset):
  preset == :contours or preset == :surface_contours

def _mesh_commands3d(commands, layer):
  vertices = layer.data[:vertices]
  triangles = layer.data[:triangles]
  colors = _mesh_colors3d(layer)
  preset = layer.options[:preset]
  fill_flag = 0
  fill_flag = 1 if _preset_has_fill3d(preset)
  edge_flag = 0
  edge_flag = 1 if _preset_has_edges3d(preset)
  shading_code = 1
  shading_code = 0 if layer.options[:shading] == :unlit
  shading_code = 2 if layer.options[:shading] == :smooth
  vertex_arrays = vertices.map |point|: point.to_array()
  commands.push!([1, vertex_arrays, triangles, colors, layer.opacity,
    layer.options[:edge_color], layer.options[:edge_width], fill_flag,
    edge_flag, shading_code])
  if preset == :points:
    point_color = _palette_of(layer.palette or :viridis).colors[3]
    commands.push!([3, vertex_arrays, point_color, "#ffffff", 0.8, 3.2,
      layer.opacity])
  if _preset_has_contours3d(preset):
    contour_lines = _contour_lines3d(layer)
    if contour_lines.count() > 0:
      commands.push!([2, contour_lines, layer.options[:contour_color],
        layer.options[:contour_width], layer.opacity, 1])
  commands

def _mesh_colors3d(layer):
  triangles = layer.data[:triangles]
  sources = layer.data[:sources]
  values = layer.values
  numeric = []
  values.each |item|:
    if _number?(item):
      numeric.push!(item)
  extent = if numeric.count() == 0 then [0, 1] else numeric.minmax()
  colors = _palette_of(layer.palette or :viridis)
  result = []
  triangles.each_with_index |triangle, triangle_index|:
    value = null
    if Array === values:
      if layer.value_mode == :face:
        value = values[sources[triangle_index]]
      else:
        selected_values = triangle.map |index|: values[index]
        value = selected_values.sum() * 1.0 / triangle.count()
    result.push!(colors.color(value, min: extent[0], max: extent[1]))
  result

def _contour_levels3d(layer):
  levels = layer.options[:levels]
  if Array === levels or Tuple === levels:
    return levels.map |value|: _require_number(value, "contour level")
  return [] if levels == 0
  values = layer.values
  numeric = values.select |value|: _number?(value)
  return [] if numeric.count() == 0
  extent = numeric.minmax()
  result = []
  levels.times |index|:
    ratio = (index + 1) * 1.0 / (levels + 1)
    result.push!(extent[0] + ratio * (extent[1] - extent[0]))
  result

def _contour_lines3d(layer):
  vertices = layer.data[:vertices]
  triangles = layer.data[:triangles]
  values = layer.values
  if (layer.value_mode == :face or not Array === values or
      values.count() != vertices.count()):
    values = vertices.map |point|: point.z
  lines = []
  _contour_levels3d(layer).each |level|:
    triangles.each |triangle|:
      intersections = []
      3.times |edge|:
        a_index = triangle[edge]
        b_index = triangle[(edge + 1) % 3]
        a_value = values[a_index]
        b_value = values[b_index]
        crosses = ((a_value < level and b_value >= level) or
          (b_value < level and a_value >= level))
        if crosses:
          span = b_value - a_value
          ratio = (level - a_value) * 1.0 / span
          a = vertices[a_index]
          b = vertices[b_index]
          intersections.push!([a.x + ratio * (b.x - a.x),
            a.y + ratio * (b.y - a.y),
            a.z + ratio * (b.z - a.z) + 0.001])
      if intersections.count() >= 2:
        lines.push!([intersections[0], intersections[1]])
  lines

def _plane_vertices3d(axis, value, bounds):
  dx = (bounds[3] - bounds[0]) * 0.03
  dy = (bounds[4] - bounds[1]) * 0.03
  dz = (bounds[5] - bounds[2]) * 0.03
  if axis == :x:
    return [[value, bounds[1] - dy, bounds[2] - dz],
      [value, bounds[4] + dy, bounds[2] - dz],
      [value, bounds[4] + dy, bounds[5] + dz],
      [value, bounds[1] - dy, bounds[5] + dz]]
  if axis == :y:
    return [[bounds[0] - dx, value, bounds[2] - dz],
      [bounds[3] + dx, value, bounds[2] - dz],
      [bounds[3] + dx, value, bounds[5] + dz],
      [bounds[0] - dx, value, bounds[5] + dz]]
  [[bounds[0] - dx, bounds[1] - dy, value],
    [bounds[3] + dx, bounds[1] - dy, value],
    [bounds[3] + dx, bounds[4] + dy, value],
    [bounds[0] - dx, bounds[4] + dy, value]]

def _plane_commands3d(commands, layer, bounds):
  axis = layer.options[:axis]
  vertices = _plane_vertices3d(axis, layer.options[:value], bounds)
  triangles = [[0, 1, 2], [0, 2, 3]]
  colors = [layer.options[:fill], layer.options[:fill]]
  commands.push!([1, vertices, triangles, colors, layer.opacity,
    layer.options[:stroke], layer.options[:stroke_width], 1, 1, 0])
  if layer.label != null:
    center = [(vertices[0][0] + vertices[2][0]) / 2.0,
      (vertices[0][1] + vertices[2][1]) / 2.0,
      (vertices[0][2] + vertices[2][2]) / 2.0]
    commands.push!([4, center, layer.options[:stroke], 12, 8, 8, 0,
      layer.label.to_str])
  commands

def _axes_commands3d(commands, figure, bounds):
  x0 = bounds[0]
  y0 = bounds[1]
  z0 = bounds[2]
  x1 = bounds[3]
  y1 = bounds[4]
  z1 = bounds[5]
  box = [
    [[x0,y0,z0],[x1,y0,z0]], [[x0,y1,z0],[x1,y1,z0]],
    [[x0,y0,z1],[x1,y0,z1]], [[x0,y1,z1],[x1,y1,z1]],
    [[x0,y0,z0],[x0,y1,z0]], [[x1,y0,z0],[x1,y1,z0]],
    [[x0,y0,z1],[x0,y1,z1]], [[x1,y0,z1],[x1,y1,z1]],
    [[x0,y0,z0],[x0,y0,z1]], [[x1,y0,z0],[x1,y0,z1]],
    [[x0,y1,z0],[x0,y1,z1]], [[x1,y1,z0],[x1,y1,z1]]
  ]
  commands.push!([2, box, "#94a3b8", 1, 0.45, 1])
  commands.push!([2, [[[x0,y0,z0],[x1,y0,z0]]], "#dc2626", 2, 1, 0])
  commands.push!([2, [[[x0,y0,z0],[x0,y1,z0]]], "#16a34a", 2, 1, 0])
  commands.push!([2, [[[x0,y0,z0],[x0,y0,z1]]], "#2563eb", 2, 1, 0])
  commands.push!([4, [x1,y0,z0], "#991b1b", 12, 7, 4, 0,
    figure.x_label.to_str]) if figure.x_label != null
  commands.push!([4, [x0,y1,z0], "#166534", 12, 7, 4, 0,
    figure.y_label.to_str]) if figure.y_label != null
  commands.push!([4, [x0,y0,z1], "#1d4ed8", 12, 7, 4, 0,
    figure.z_label.to_str]) if figure.z_label != null
  commands

def _coerce_ring(value):
  unless Array === value or Tuple === value:
    raise ArgumentError("polygon ring must be an array of points")
  value.map |entry|: _coerce_point(entry)

def _looks_like_point(value):
  ((Array === value or Tuple === value) and value.count() >= 2 and
    _number?(value[0]) and _number?(value[1]))

def _coerce_polygon(value):
  return value if Polygon === value
  if Array === value or Tuple === value:
    return Polygon(value)
  raise ArgumentError("geometry must be plot.Polygon or a point ring")

def _coerce_polygons(value):
  return value.polygons.copy if Feature === value
  return [value] if Polygon === value
  unless Array === value or Tuple === value:
    raise ArgumentError("polygons require a ring, Polygon, Feature, or array")
  return [] if value.count() == 0
  if _looks_like_point(value[0]):
    return [Polygon(value)]
  result = []
  value.each |entry|:
    if Feature === entry:
      entry.polygons.each |shape|: result.push!(shape)
    else:
      result.push!(_coerce_polygon(entry))
  result

def _series_points(data):
  unless Array === data or Tuple === data:
    raise ArgumentError("series data must be an array")
  result = []
  data.each_with_index |entry, index|:
    if _number?(entry):
      result.push!(Point(index, entry))
    else:
      result.push!(_coerce_point(entry))
  result

def _dash_pattern(value):
  return [] if value == null
  unless Array === value or Tuple === value:
    raise ArgumentError("dash must be an array of positive lengths")
  result = []
  value.each |length|:
    _require_positive(length, "dash length")
    result.push!(length)
  result

def _annotation_options(dash, label_color, label_size, label_at, dx, dy):
  _require_positive(label_size, "annotation label size")
  _require_number(dx, "annotation label dx")
  _require_number(dy, "annotation label dy")
  unless label_at == :start or label_at == :middle or label_at == :end:
    raise ArgumentError("label_at must be :start, :middle or :end")
  {dash: _dash_pattern(dash), label_color: label_color,
    label_size: label_size, label_at: label_at, dx: dx, dy: dy}

def _property(properties, key, fallback):
  return fallback unless Map === properties or StrictMap === properties
  return properties[key] if properties.has_key?(key)
  alternate = if Symbol === key then key.to_str else key.to_symbol
  return properties[alternate] if properties.has_key?(alternate)
  fallback

def _project_polygon(shape, projection):
  return shape if projection == :identity
  unless projection == :mercator or projection == :web_mercator:
    raise ArgumentError("projection must be :identity or :mercator")
  rings = shape.rings.map |ring|:
    ring.map |p|: _project_mercator(p)
  Polygon(rings[0], holes: _tail(rings),
    value: shape.value, fill: shape.fill, stroke: shape.stroke,
    id: shape.id, properties: shape.properties)

def _project_mercator(p):
  latitude = p.y
  latitude = 85.05112878 if latitude > 85.05112878
  latitude = 0 - 85.05112878 if latitude < 0 - 85.05112878
  radians = latitude * Math.PI() / 180
  y = Math.log(Math.tan(Math.PI() / 4 + radians / 2)) * 180 / Math.PI()
  Point(p.x, y)

# ---------------------------------------------------------------- palettes

def _palette_of(value):
  return value if Palette === value
  if value == :sputnik:
    return Palette(["#16697a", "#489fb5", "#ffa62b", "#82c0cc", "#ede7e3"], name: :sputnik)
  if value == :okabe_ito:
    return Palette(["#0072b2", "#e69f00", "#009e73", "#cc79a7", "#56b4e9", "#d55e00"], name: :okabe_ito)
  if value == :viridis:
    return Palette(["#440154", "#414487", "#2a788e", "#22a884", "#7ad151", "#fde725"], name: :viridis)
  if value == :magma:
    return Palette(["#000004", "#3b0f70", "#8c2981", "#de4968", "#fe9f6d", "#fcfdbf"], name: :magma)
  if value == :balance:
    return Palette(["#3b4cc0", "#7b9ff9", "#dddddd", "#f4987a", "#b40426"], name: :balance)
  raise ArgumentError("unknown palette: " + value.to_str)

def _categorical_color(index):
  colors = ["#16697a", "#ffa62b", "#489fb5", "#9b5de5", "#2a9d8f", "#e76f51"]
  colors[index % colors.count()]

def _stable_bucket(text, count):
  total = 0
  text.bytes().each |value|:
    total = (total * 31 + value) % 2147483647
  total % count

def _tail(values):
  result = []
  index = 1
  while index < values.count():
    result.push!(values[index])
    index = index + 1
  result

# ---------------------------------------------------------------- bounds/layout

def _empty_bounds():
  [null, null, null, null]

def _include_point(bounds, point):
  if bounds[0] == null:
    bounds[0] = point.x
    bounds[1] = point.y
    bounds[2] = point.x
    bounds[3] = point.y
  else:
    bounds[0] = point.x if point.x < bounds[0]
    bounds[1] = point.y if point.y < bounds[1]
    bounds[2] = point.x if point.x > bounds[2]
    bounds[3] = point.y if point.y > bounds[3]
  bounds

def _include_x(bounds, x):
  if bounds[0] == null:
    bounds[0] = x
    bounds[2] = x
  else:
    bounds[0] = x if x < bounds[0]
    bounds[2] = x if x > bounds[2]
  bounds

def _include_y(bounds, y):
  if bounds[1] == null:
    bounds[1] = y
    bounds[3] = y
  else:
    bounds[1] = y if y < bounds[1]
    bounds[3] = y if y > bounds[3]
  bounds

def _figure_bounds(layers):
  bounds = _empty_bounds()
  layers.each |layer|:
    if layer.kind == :polygons:
      layer.data.each |shape|:
        shape.rings.each |ring|:
          ring.each |point|: _include_point(bounds, point)
    elif layer.kind == :mesh:
      layer.data[:vertices].each |point|: _include_point(bounds, point)
    elif layer.kind == :line or layer.kind == :points:
      layer.data.each |point|: _include_point(bounds, point)
    elif layer.kind == :guide:
      layer.data.each |point|: _include_point(bounds, point)
    elif layer.kind == :annotation:
      _include_point(bounds, layer.data)
  layers.each |layer|:
    if layer.kind == :vline:
      _include_x(bounds, layer.data)
    elif layer.kind == :hline:
      _include_y(bounds, layer.data)
  return [0, 0, 1, 1] if bounds[0] == null and bounds[1] == null
  bounds[0] = 0 if bounds[0] == null
  bounds[1] = 0 if bounds[1] == null
  bounds[2] = 1 if bounds[2] == null
  bounds[3] = 1 if bounds[3] == null
  if bounds[0] == bounds[2]:
    bounds[0] = bounds[0] - 0.5
    bounds[2] = bounds[2] + 0.5
  if bounds[1] == bounds[3]:
    bounds[1] = bounds[1] - 0.5
    bounds[3] = bounds[3] + 0.5
  bounds

def _layout(figure, bounds):
  left = figure.padding_value
  right = figure.padding_value
  right = right + 72 if _has_color_scale(figure.layers)
  top = figure.padding_value
  bottom = figure.padding_value
  top = top + 24 if figure.title_text
  plot_width = figure.width - left - right
  plot_height = figure.height - top - bottom
  dx = bounds[2] - bounds[0]
  dy = bounds[3] - bounds[1]
  sx = plot_width * 1.0 / dx
  sy = plot_height * 1.0 / dy
  unless plot_width > 0 and plot_height > 0 and sx > 0 and sy > 0 and sx - sx == 0 and sy - sy == 0:
    raise ArgumentError("plot view has no drawable area or its range is too small")
  if figure.aspect_mode == :equal:
    scale = Math.min(sx, sy)
    sx = scale
    sy = scale
    left = left + (plot_width - dx * scale) / 2.0
    top = top + (plot_height - dy * scale) / 2.0
  {left: left, top: top, sx: sx, sy: sy,
    plot_width: dx * sx, plot_height: dy * sy, bounds: bounds}

def _screen_point(point, layout, y_direction):
  x = layout[:left] + (point.x - layout[:bounds][0]) * layout[:sx]
  y = 0
  if y_direction == :down:
    y = layout[:top] + (point.y - layout[:bounds][1]) * layout[:sy]
  else:
    y = (layout[:top] + layout[:plot_height] -
      (point.y - layout[:bounds][1]) * layout[:sy])
  Point(x, y)

def _annotation_line_points(layer, bounds, y_direction):
  if layer.kind == :vline:
    top_value = bounds[1]
    bottom_value = bounds[3]
    if y_direction == :up:
      top_value = bounds[3]
      bottom_value = bounds[1]
    return [Point(layer.data, top_value), Point(layer.data, bottom_value)]
  if layer.kind == :hline:
    return [Point(bounds[0], layer.data), Point(bounds[2], layer.data)]
  layer.data

def _annotation_label_data_point(layer, points):
  position = layer.options[:label_at]
  return points[0] if position == :start
  return points[points.count() - 1] if position == :end
  first = points[0]
  last = points[points.count() - 1]
  Point((first.x + last.x) / 2.0, (first.y + last.y) / 2.0)

def _annotation_label_screen(layer, points, layout, y_direction):
  data_point = _annotation_label_data_point(layer, points)
  screen = _screen_point(data_point, layout, y_direction)
  dx = layer.options[:dx]
  align = 1
  align = 0 if dx > 0
  align = 2 if dx < 0
  [screen.x + dx, screen.y + layer.options[:dy], align]

def _layer_values(layer):
  values = []
  if layer.kind == :polygons:
    layer.data.each |shape|:
      values.push!(shape.value) if _number?(shape.value)
  elif layer.kind == :mesh and Array === layer.values:
    layer.values.each |value|:
      values.push!(value) if _number?(value)
  values

def _value_extent(layer):
  values = _layer_values(layer)
  return [0, 1] if values.count() == 0
  values.minmax()

def _has_color_scale(layers):
  layers.any? |layer|: _layer_values(layer).count() > 0

# ---------------------------------------------------------------- PNG scene

# The Sputnik side resolves layout, palettes and layer semantics into a compact
# backend-neutral display list. The native backend only owns pixel rasterizing
# and PNG encoding, which keeps SVG and PNG geometrically equivalent.
def _png_commands(figure, bounds):
  layout = _layout(figure, bounds)
  commands = []
  if figure.title_text:
    commands.push!([4, "#111827", 20, figure.width / 2.0, 18, 1,
      figure.title_text.to_str])
  if figure.axes_visible:
    _png_axes(commands, figure, layout)
  commands.push!([5, layout[:left], layout[:top], layout[:plot_width], layout[:plot_height]])
  figure.layers.each_with_index |layer, index|:
    _png_layer(commands, layer, figure, layout, index)
  commands.push!([6])
  _png_colorbars(commands, figure, layout)
  commands

def _png_axes(commands, figure, layout):
  left = layout[:left]
  top = layout[:top]
  right = left + layout[:plot_width]
  bottom = top + layout[:plot_height]
  6.times |i|:
    ratio = i / 5.0
    x = left + ratio * layout[:plot_width]
    y = top + ratio * layout[:plot_height]
    xv = layout[:bounds][0] + ratio * (layout[:bounds][2] - layout[:bounds][0])
    yv = layout[:bounds][3] - ratio * (layout[:bounds][3] - layout[:bounds][1])
    yv = layout[:bounds][1] + ratio * (layout[:bounds][3] - layout[:bounds][1]) if figure.y_direction == :down
    commands.push!([2, "#e5e7eb", 1, 1, [[x, top], [x, bottom]]])
    commands.push!([2, "#e5e7eb", 1, 1, [[left, y], [right, y]]])
    commands.push!([4, "#4b5563", 11, x, bottom + 9, 1, _tick(xv)])
    commands.push!([4, "#4b5563", 11, left - 8, y - 4, 2, _tick(yv)])
  frame = [[left, top], [right, top], [right, bottom], [left, bottom]]
  commands.push!([1, "none", "#9ca3af", 1, 1, [frame]])
  if figure.x_label:
    commands.push!([4, "#374151", 13, (left + right) / 2.0,
      bottom + 33, 1, figure.x_label.to_str])
  if figure.y_label:
    commands.push!([4, "#374151", 13, left, top - 22, 0,
      figure.y_label.to_str])
  commands

def _png_layer(commands, layer, figure, layout, index, fit_labels: true):
  if layer.kind == :polygons:
    extent = _value_extent(layer)
    colors = _palette_of(layer.palette or figure.palette_value)
    layer.data.each |shape|:
      fill = shape.fill or layer.fill or colors.color(shape.value,
        min: extent[0], max: extent[1])
      stroke = shape.stroke or layer.stroke
      commands.push!([1, fill, stroke, layer.stroke_width, layer.opacity,
        _png_rings(shape.rings, layout, figure.y_direction)])
  elif layer.kind == :mesh:
    vertices = layer.data[:vertices]
    faces = layer.data[:faces]
    extent = _value_extent(layer)
    colors = _palette_of(layer.palette or figure.palette_value)
    faces.each_with_index |face, face_index|:
      value = _mesh_face_value(layer, face, face_index)
      fill = layer.fill or colors.color(value, min: extent[0], max: extent[1])
      ring = face.map |vertex_index|: vertices[vertex_index]
      commands.push!([1, fill, layer.stroke, layer.stroke_width, layer.opacity,
        _png_rings([ring], layout, figure.y_direction)])
  elif layer.kind == :line:
    commands.push!([2, layer.stroke, layer.stroke_width, layer.opacity,
      _png_points(layer.data, layout, figure.y_direction)])
  elif layer.kind == :points:
    commands.push!([3, layer.fill, layer.stroke, layer.stroke_width,
      layer.opacity, layer.options[:radius],
      _png_points(layer.data, layout, figure.y_direction)])
  elif layer.kind == :vline or layer.kind == :hline or layer.kind == :guide:
    points = _annotation_line_points(layer, layout[:bounds], figure.y_direction)
    commands.push!([2, layer.stroke, layer.stroke_width, layer.opacity,
      _png_points(points, layout, figure.y_direction), layer.options[:dash]])
    _png_annotation_label(commands, layer, points, layout, figure.y_direction, fit_labels: fit_labels)
  elif layer.kind == :annotation:
    commands.push!([3, layer.fill, layer.stroke, layer.stroke_width,
      layer.opacity, layer.options[:radius],
      _png_points([layer.data], layout, figure.y_direction)])
    _png_annotation_label(commands, layer, [layer.data], layout,
      figure.y_direction, fit_labels: fit_labels)
  commands

def _png_annotation_label(commands, layer, points, layout, y_direction, fit_labels: true):
  if layer.label != null:
    position = _annotation_label_screen(layer, points, layout, y_direction)
    return commands if fit_labels and not _annotation_label_fits(layer, position, layout)
    commands.push!([4, layer.options[:label_color],
      layer.options[:label_size], position[0], position[1], position[2],
      layer.label.to_str])
  commands

def _annotation_label_fits(layer, position, layout):
  width = layer.label.to_str.length() * layer.options[:label_size] * 0.75
  left = position[0] - width * position[2] / 2.0
  left >= layout[:left] and left + width <= layout[:left] + layout[:plot_width] and position[1] >= layout[:top] and position[1] + layer.options[:label_size] <= layout[:top] + layout[:plot_height]

def _png_points(points, layout, y_direction):
  result = []
  points.each |point|:
    screen = _screen_point(point, layout, y_direction)
    result.push!([screen.x, screen.y])
  result

def _png_rings(rings, layout, y_direction):
  result = []
  rings.each |ring|:
    result.push!(_png_points(ring, layout, y_direction))
  result

def _png_colorbars(commands, figure, layout):
  bar_index = 0
  figure.layers.each |layer|:
    values = _layer_values(layer)
    if values.count() > 0:
      extent = values.minmax()
      colors = _palette_of(layer.palette or figure.palette_value)
      x = layout[:left] + layout[:plot_width] + 18
      y = layout[:top] + bar_index * 132
      bar_height = 88
      cell_height = bar_height * 1.0 / colors.colors.count()
      colors.colors.reversed.each_with_index |color, color_index|:
        cell_top = y + color_index * cell_height
        cell = [[x, cell_top], [x + 14, cell_top],
          [x + 14, cell_top + cell_height + 0.5], [x, cell_top + cell_height + 0.5]]
        commands.push!([1, color, "none", 0, 1, [cell]])
      frame = [[x, y], [x + 14, y], [x + 14, y + bar_height], [x, y + bar_height]]
      commands.push!([1, "none", "#9ca3af", 1, 1, [frame]])
      commands.push!([4, "#374151", 11, x + 20, y, 0, _tick(extent[1])])
      commands.push!([4, "#374151", 11, x + 20, y + bar_height - 7, 0,
        _tick(extent[0])])
      if layer.label:
        commands.push!([4, "#374151", 11, x, y - 15, 0, layer.label.to_str])
      bar_index = bar_index + 1
  commands

# ---------------------------------------------------------------- SVG backend

def _render_svg(figure, bounds):
  layout = _layout(figure, bounds)
  out = []
  out.push!("<svg xmlns=\"http://www.w3.org/2000/svg\" width=\"" + _n(figure.width) +
    "\" height=\"" + _n(figure.height) + "\" viewBox=\"0 0 " +
    _n(figure.width) + " " + _n(figure.height) + "\" role=\"img\">")
  out.push!("<rect width=\"100%\" height=\"100%\" fill=\"" +
    _xml(figure.background) + "\"/>")
  if figure.title_text:
    out.push!("<text x=\"" + _n(figure.width / 2.0) + "\" y=\"32\" text-anchor=\"middle\" font-family=\"system-ui,sans-serif\" font-size=\"20\" font-weight=\"600\" fill=\"#111827\">" + _xml(figure.title_text.to_str) + "</text>")
  if figure.axes_visible:
    out.push!(_render_axes(figure, layout))
  out.push!("<defs><clipPath id=\"plot-clip\"><rect x=\"" + _n(layout[:left]) + "\" y=\"" + _n(layout[:top]) + "\" width=\"" + _n(layout[:plot_width]) + "\" height=\"" + _n(layout[:plot_height]) + "\"/></clipPath></defs>")
  out.push!("<g class=\"plot-layers\" clip-path=\"url(#plot-clip)\">")
  figure.layers.each_with_index |layer, index|:
    out.push!(_render_layer(layer, figure, layout, index))
  out.push!("</g>")
  out.push!(_render_colorbars(figure, layout))
  out.push!("</svg>")
  out.join("")

def _render_axes(figure, layout):
  out = []
  left = layout[:left]
  top = layout[:top]
  right = left + layout[:plot_width]
  bottom = top + layout[:plot_height]
  out.push!("<g class=\"axes\" font-family=\"system-ui,sans-serif\" font-size=\"11\" fill=\"#4b5563\">")
  6.times |i|:
    ratio = i / 5.0
    x = left + ratio * layout[:plot_width]
    y = top + ratio * layout[:plot_height]
    xv = layout[:bounds][0] + ratio * (layout[:bounds][2] - layout[:bounds][0])
    yv = layout[:bounds][3] - ratio * (layout[:bounds][3] - layout[:bounds][1])
    yv = layout[:bounds][1] + ratio * (layout[:bounds][3] - layout[:bounds][1]) if figure.y_direction == :down
    out.push!("<line x1=\"" + _n(x) + "\" y1=\"" + _n(top) + "\" x2=\"" + _n(x) + "\" y2=\"" + _n(bottom) + "\" stroke=\"#e5e7eb\"/>")
    out.push!("<line x1=\"" + _n(left) + "\" y1=\"" + _n(y) + "\" x2=\"" + _n(right) + "\" y2=\"" + _n(y) + "\" stroke=\"#e5e7eb\"/>")
    out.push!("<text x=\"" + _n(x) + "\" y=\"" + _n(bottom + 18) + "\" text-anchor=\"middle\">" + _tick(xv) + "</text>")
    out.push!("<text x=\"" + _n(left - 8) + "\" y=\"" + _n(y + 4) + "\" text-anchor=\"end\">" + _tick(yv) + "</text>")
  out.push!("<rect x=\"" + _n(left) + "\" y=\"" + _n(top) + "\" width=\"" + _n(layout[:plot_width]) + "\" height=\"" + _n(layout[:plot_height]) + "\" fill=\"none\" stroke=\"#9ca3af\"/>")
  if figure.x_label:
    out.push!("<text x=\"" + _n((left + right) / 2.0) + "\" y=\"" + _n(bottom + 42) + "\" text-anchor=\"middle\" font-size=\"13\">" + _xml(figure.x_label.to_str) + "</text>")
  if figure.y_label:
    mid = (top + bottom) / 2.0
    out.push!("<text x=\"18\" y=\"" + _n(mid) + "\" text-anchor=\"middle\" font-size=\"13\" transform=\"rotate(-90 18 " + _n(mid) + ")\">" + _xml(figure.y_label.to_str) + "</text>")
  out.push!("</g>")
  out.join("")

def _render_layer(layer, figure, layout, index):
  if layer.kind == :polygons:
    return _render_polygon_layer(layer, figure, layout, index)
  if layer.kind == :mesh:
    return _render_mesh_layer(layer, figure, layout, index)
  if layer.kind == :line:
    return _render_line_layer(layer, figure, layout, index)
  if layer.kind == :points:
    return _render_points_layer(layer, figure, layout, index)
  if layer.kind == :vline or layer.kind == :hline or layer.kind == :guide:
    return _render_annotation_line_layer(layer, figure, layout, index)
  if layer.kind == :annotation:
    return _render_annotation_point_layer(layer, figure, layout, index)
  ""

def _render_colorbars(figure, layout):
  out = ["<g class=\"colorbars\" font-family=\"system-ui,sans-serif\" font-size=\"11\" fill=\"#374151\">"]
  bar_index = 0
  figure.layers.each_with_index |layer, layer_index|:
    values = _layer_values(layer)
    if values.count() > 0:
      extent = values.minmax()
      colors = _palette_of(layer.palette or figure.palette_value)
      x = layout[:left] + layout[:plot_width] + 18
      y = layout[:top] + bar_index * 132
      bar_height = 88
      cell_height = bar_height * 1.0 / colors.colors.count()
      colors.colors.reversed.each_with_index |color, color_index|:
        out.push!("<rect x=\"" + _n(x) + "\" y=\"" + _n(y + color_index * cell_height) +
          "\" width=\"14\" height=\"" + _n(cell_height + 0.5) + "\" fill=\"" +
          _xml(color) + "\"/>")
      out.push!("<rect x=\"" + _n(x) + "\" y=\"" + _n(y) + "\" width=\"14\" height=\"" +
        _n(bar_height) + "\" fill=\"none\" stroke=\"#9ca3af\"/>")
      out.push!("<text x=\"" + _n(x + 20) + "\" y=\"" + _n(y + 9) + "\">" + _tick(extent[1]) + "</text>")
      out.push!("<text x=\"" + _n(x + 20) + "\" y=\"" + _n(y + bar_height) + "\">" + _tick(extent[0]) + "</text>")
      if layer.label:
        out.push!("<text x=\"" + _n(x) + "\" y=\"" + _n(y - 8) + "\" font-weight=\"600\">" + _xml(layer.label.to_str) + "</text>")
      bar_index = bar_index + 1
  out.push!("</g>")
  out.join("")

def _render_polygon_layer(layer, figure, layout, index):
  out = ["<g class=\"layer polygons\" data-layer=\"" + index.to_str + "\">"]
  extent = _value_extent(layer)
  colors = _palette_of(layer.palette or figure.palette_value)
  layer.data.each |shape|:
    fill = shape.fill or layer.fill or colors.color(shape.value, min: extent[0], max: extent[1])
    stroke = shape.stroke or layer.stroke
    path = _polygon_path(shape, layout, figure.y_direction)
    out.push!("<path d=\"" + path + "\" fill=\"" + _xml(fill) +
      "\" fill-rule=\"evenodd\" stroke=\"" + _xml(stroke) +
      "\" stroke-width=\"" + _n(layer.stroke_width) + "\" opacity=\"" +
      _n(layer.opacity) + "\" vector-effect=\"non-scaling-stroke\">")
    tooltip = _tooltip(shape.id, shape.value, shape.properties)
    out.push!("<title>" + _xml(tooltip) + "</title>") if tooltip
    out.push!("</path>")
  out.push!("</g>")
  out.join("")

def _render_mesh_layer(layer, figure, layout, index):
  out = ["<g class=\"layer mesh\" data-layer=\"" + index.to_str + "\">"]
  vertices = layer.data[:vertices]
  faces = layer.data[:faces]
  extent = _value_extent(layer)
  colors = _palette_of(layer.palette or figure.palette_value)
  faces.each_with_index |face, face_index|:
    value = _mesh_face_value(layer, face, face_index)
    fill = layer.fill or colors.color(value, min: extent[0], max: extent[1])
    parts = []
    face.each_with_index |vertex_index, point_index|:
      p = _screen_point(vertices[vertex_index], layout, figure.y_direction)
      command = if point_index == 0 then "M" else "L"
      parts.push!(command + _n(p.x) + " " + _n(p.y))
    parts.push!("Z")
    out.push!("<path d=\"" + parts.join(" ") + "\" fill=\"" + _xml(fill) +
      "\" stroke=\"" + _xml(layer.stroke) + "\" stroke-width=\"" +
      _n(layer.stroke_width) + "\" opacity=\"" + _n(layer.opacity) +
      "\" vector-effect=\"non-scaling-stroke\">")
    out.push!("<title>" + _xml(value.to_str) + "</title>") if value != null
    out.push!("</path>")
  out.push!("</g>")
  out.join("")

def _mesh_face_value(layer, face, face_index):
  return null unless Array === layer.values
  return layer.values[face_index] unless layer.value_mode == :vertex
  values = face.map |vertex_index|: layer.values[vertex_index]
  numeric = values.select |value|: _number?(value)
  return null if numeric.count() == 0
  numeric.sum() * 1.0 / numeric.count()

def _render_line_layer(layer, figure, layout, index):
  rendered_points = []
  layer.data.each |point|:
    p = _screen_point(point, layout, figure.y_direction)
    rendered_points.push!(_n(p.x) + "," + _n(p.y))
  svg_line = ("<polyline class=\"layer line\" data-layer=\"" + index.to_str +
    "\" points=\"" + rendered_points.join(" ") + "\" fill=\"none\" stroke=\"" +
    _xml(layer.stroke) + "\" stroke-width=\"" + _n(layer.stroke_width) +
    "\" opacity=\"" + _n(layer.opacity) + "\" stroke-linejoin=\"round\" stroke-linecap=\"round\"/>")
  svg_line

def _render_points_layer(layer, figure, layout, index):
  out = ["<g class=\"layer points\" data-layer=\"" + index.to_str + "\">"]
  radius = layer.options[:radius]
  layer.data.each |point|:
    p = _screen_point(point, layout, figure.y_direction)
    out.push!("<circle cx=\"" + _n(p.x) + "\" cy=\"" + _n(p.y) +
      "\" r=\"" + _n(radius) + "\" fill=\"" + _xml(layer.fill) +
      "\" stroke=\"" + _xml(layer.stroke) + "\" stroke-width=\"" +
      _n(layer.stroke_width) + "\" opacity=\"" + _n(layer.opacity) + "\"/>")
  out.push!("</g>")
  out.join("")

def _render_annotation_line_layer(layer, figure, layout, index):
  points = _annotation_line_points(layer, layout[:bounds], figure.y_direction)
  first = _screen_point(points[0], layout, figure.y_direction)
  last = _screen_point(points[points.count() - 1], layout, figure.y_direction)
  dash = layer.options[:dash]
  dash_attribute = ""
  if dash.count() > 0:
    dash_text = dash.map |value|: _n(value)
    dash_attribute = " stroke-dasharray=\"" + dash_text.join(" ") + "\""
  out = ["<g class=\"layer annotation " + layer.kind.to_str +
    "\" data-layer=\"" + index.to_str + "\">"]
  out.push!("<line x1=\"" + _n(first.x) + "\" y1=\"" + _n(first.y) +
    "\" x2=\"" + _n(last.x) + "\" y2=\"" + _n(last.y) +
    "\" stroke=\"" + _xml(layer.stroke) + "\" stroke-width=\"" +
    _n(layer.stroke_width) + "\" opacity=\"" + _n(layer.opacity) + "\"" +
    dash_attribute + " vector-effect=\"non-scaling-stroke\"/>")
  out.push!(_render_annotation_label(layer, points, figure, layout)) if layer.label != null
  out.push!("</g>")
  out.join("")

def _render_annotation_point_layer(layer, figure, layout, index):
  point = _screen_point(layer.data, layout, figure.y_direction)
  out = ["<g class=\"layer annotation point\" data-layer=\"" +
    index.to_str + "\">"]
  out.push!("<circle cx=\"" + _n(point.x) + "\" cy=\"" + _n(point.y) +
    "\" r=\"" + _n(layer.options[:radius]) + "\" fill=\"" +
    _xml(layer.fill) + "\" stroke=\"" + _xml(layer.stroke) +
    "\" stroke-width=\"" + _n(layer.stroke_width) + "\" opacity=\"" +
    _n(layer.opacity) + "\"/>")
  out.push!(_render_annotation_label(layer, [layer.data], figure, layout)) if layer.label != null
  out.push!("</g>")
  out.join("")

def _render_annotation_label(layer, points, figure, layout):
  position = _annotation_label_screen(layer, points, layout, figure.y_direction)
  return "" unless _annotation_label_fits(layer, position, layout)
  anchor = "middle"
  anchor = "start" if position[2] == 0
  anchor = "end" if position[2] == 2
  ("<text class=\"annotation-label\" x=\"" + _n(position[0]) +
    "\" y=\"" + _n(position[1]) + "\" text-anchor=\"" + anchor +
    "\" dominant-baseline=\"hanging\" font-family=\"system-ui,sans-serif\"" +
    " font-size=\"" + _n(layer.options[:label_size]) + "\" fill=\"" +
    _xml(layer.options[:label_color]) + "\">" + _xml(layer.label.to_str) +
    "</text>")

def _polygon_path(shape, layout, y_direction):
  paths = []
  shape.rings.each |ring|:
    parts = []
    ring.each_with_index |point, index|:
      p = _screen_point(point, layout, y_direction)
      command = if index == 0 then "M" else "L"
      parts.push!(command + _n(p.x) + " " + _n(p.y))
    parts.push!("Z")
    paths.push!(parts.join(" "))
  paths.join(" ")

def _tooltip(id, value, properties):
  parts = []
  parts.push!(id.to_str) if id != null
  parts.push!("value: " + value.to_str) if value != null
  if (Map === properties or StrictMap === properties) and properties.count() > 0:
    properties.each |key, item|: parts.push!(key.to_str + ": " + item.to_str)
  return null if parts.count() == 0
  parts.join("; ")

def _tick(value):
  return value.to_str if Math.abs(value) < 0.001 or Math.abs(value) >= 1000000
  rounded = Math.round(value * 1000000) / 1000000
  rounded.to_str

def _n(value):
  value.to_str

def _xml(value):
  text = value.to_str
  text = text.replace("&", "&amp;")
  text = text.replace("<", "&lt;")
  text = text.replace(">", "&gt;")
  text = text.replace("\"", "&quot;")
  text.replace("'", "&#39;")

def _pick(map, key, fallback):
  if map.has_key?(key) then map[key] else fallback

def _format_from_path(path):
  if path.ends_with?(".svg"):
    :svg
  elif path.ends_with?(".png"):
    :png
  else:
    raise ArgumentError("cannot infer output format; use .svg or .png")

def _write_text_file(path, contents):
  fs.write_text(path, contents)

def _write_bytes_file(path, contents):
  fs.write_bytes(path, contents)
