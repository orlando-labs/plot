#include "runtime/sputnik_ext.h"

#include <math.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

typedef struct {
  double x;
  double y;
} PlotPoint;

typedef struct {
  PlotPoint *points;
  size_t count;
} PlotRing;

typedef struct {
  uint8_t r;
  uint8_t g;
  uint8_t b;
  uint8_t a;
} PlotColor;

typedef struct {
  int width;
  int height;
  uint8_t *pixels;
  int clip_left, clip_top, clip_right, clip_bottom;
} PlotCanvas;

static double clamp_double(double value, double low, double high) {
  if (value < low) return low;
  if (value > high) return high;
  return value;
}

static int value_number(SputnikCtx *cx, SputnikValue value, double *out) {
  int64_t integer = 0;
  if (sputnik_as_int(cx, value, &integer)) {
    *out = (double)integer;
    return 1;
  }
  return sputnik_as_float(cx, value, out);
}

static int list_number(SputnikCtx *cx, SputnikValue list, size_t index,
                       double *out) {
  if (!sputnik_is_list(cx, list) || index >= sputnik_list_len(cx, list)) return 0;
  return value_number(cx, sputnik_list_at(cx, list, index), out);
}

static int hex_digit(char value) {
  if (value >= '0' && value <= '9') return value - '0';
  if (value >= 'a' && value <= 'f') return value - 'a' + 10;
  if (value >= 'A' && value <= 'F') return value - 'A' + 10;
  return -1;
}

static int parse_color(SputnikCtx *cx, SputnikValue value, PlotColor *out) {
  const char *text = NULL;
  size_t length = 0;
  if (!sputnik_str_view(cx, value, &text, &length)) return 0;
  if (length == 4 && text[0] == '#') {
    int r = hex_digit(text[1]);
    int g = hex_digit(text[2]);
    int b = hex_digit(text[3]);
    if (r < 0 || g < 0 || b < 0) return 0;
    *out = (PlotColor){(uint8_t)(r * 17), (uint8_t)(g * 17),
                       (uint8_t)(b * 17), 255};
    return 1;
  }
  if ((length == 7 || length == 9) && text[0] == '#') {
    int values[8];
    size_t i;
    for (i = 0; i < length - 1; ++i) {
      values[i] = hex_digit(text[i + 1]);
      if (values[i] < 0) return 0;
    }
    out->r = (uint8_t)(values[0] * 16 + values[1]);
    out->g = (uint8_t)(values[2] * 16 + values[3]);
    out->b = (uint8_t)(values[4] * 16 + values[5]);
    out->a = length == 9 ? (uint8_t)(values[6] * 16 + values[7]) : 255;
    return 1;
  }
  if (length == 4 && memcmp(text, "none", 4) == 0) {
    *out = (PlotColor){0, 0, 0, 0};
    return 1;
  }
  if (length == 11 && memcmp(text, "transparent", 11) == 0) {
    *out = (PlotColor){0, 0, 0, 0};
    return 1;
  }
  return 0;
}

static void blend_pixel(PlotCanvas *canvas, int x, int y, PlotColor color,
                        double opacity) {
  uint8_t *pixel;
  double alpha;
  double inverse;
  if (x < 0 || y < 0 || x >= canvas->width || y >= canvas->height) return;
  if (x < canvas->clip_left || y < canvas->clip_top || x >= canvas->clip_right || y >= canvas->clip_bottom) return;
  alpha = clamp_double(opacity, 0.0, 1.0) * ((double)color.a / 255.0);
  if (alpha <= 0.0) return;
  pixel = canvas->pixels + ((size_t)y * (size_t)canvas->width + (size_t)x) * 4;
  inverse = 1.0 - alpha;
  pixel[0] = (uint8_t)clamp_double(color.r * alpha + pixel[0] * inverse, 0, 255);
  pixel[1] = (uint8_t)clamp_double(color.g * alpha + pixel[1] * inverse, 0, 255);
  pixel[2] = (uint8_t)clamp_double(color.b * alpha + pixel[2] * inverse, 0, 255);
  pixel[3] = (uint8_t)clamp_double(255.0 * alpha + pixel[3] * inverse, 0, 255);
}

static double point_segment_distance(double px, double py, PlotPoint a,
                                     PlotPoint b) {
  double dx = b.x - a.x;
  double dy = b.y - a.y;
  double length2 = dx * dx + dy * dy;
  double t = length2 <= 1e-12 ? 0.0 : ((px - a.x) * dx + (py - a.y) * dy) / length2;
  double x;
  double y;
  t = clamp_double(t, 0.0, 1.0);
  x = a.x + t * dx;
  y = a.y + t * dy;
  return hypot(px - x, py - y);
}

static void draw_segment(PlotCanvas *canvas, PlotPoint a, PlotPoint b,
                         PlotColor color, double width, double opacity) {
  double radius = width > 0.0 ? width / 2.0 : 0.5;
  int min_x = (int)clamp_double(floor(fmin(a.x, b.x) - radius - 1.0), canvas->clip_left, canvas->clip_right);
  int max_x = (int)clamp_double(ceil(fmax(a.x, b.x) + radius + 1.0), canvas->clip_left - 1, canvas->clip_right - 1);
  int min_y = (int)clamp_double(floor(fmin(a.y, b.y) - radius - 1.0), canvas->clip_top, canvas->clip_bottom);
  int max_y = (int)clamp_double(ceil(fmax(a.y, b.y) + radius + 1.0), canvas->clip_top - 1, canvas->clip_bottom - 1);
  int y;
  for (y = min_y; y <= max_y; ++y) {
    int x;
    for (x = min_x; x <= max_x; ++x) {
      double distance = point_segment_distance(x + 0.5, y + 0.5, a, b);
      double coverage = clamp_double(radius + 0.75 - distance, 0.0, 1.0);
      if (coverage > 0.0) blend_pixel(canvas, x, y, color, opacity * coverage);
    }
  }
}

static void draw_dashed_segment(PlotCanvas *canvas, PlotPoint a, PlotPoint b,
                                PlotColor color, double width, double opacity,
                                const double *dash, size_t dash_count) {
  double dx;
  double dy;
  double length;
  double position = 0.0;
  size_t dash_index = 0;
  int drawing = 1;
  if (dash_count == 0) {
    draw_segment(canvas, a, b, color, width, opacity);
    return;
  }
  dx = b.x - a.x;
  dy = b.y - a.y;
  length = hypot(dx, dy);
  if (!isfinite(length) || length <= 1e-12) return;
  // Limit dash traversal to the visible segment, preserving its phase. A
  // narrow data view may project endpoints millions of pixels off-screen.
  {
    double start = 0, finish = 1, cycle = 0, phase;
    const double margin = fmax(width, 1) + 1;
    double p[4] = {-dx, dx, -dy, dy};
    double q[4] = {a.x - canvas->clip_left + margin, canvas->clip_right - a.x + margin,
                   a.y - canvas->clip_top + margin, canvas->clip_bottom - a.y + margin};
    size_t j;
    for (j = 0; j < 4; ++j) {
      if (p[j] == 0) { if (q[j] < 0) return; }
      else if (p[j] < 0) start = fmax(start, q[j] / p[j]);
      else finish = fmin(finish, q[j] / p[j]);
    }
    if (finish <= start) return;
    for (j = 0; j < dash_count; ++j) {
      if (!isfinite(dash[j]) || dash[j] < 0.1) return;
      cycle += dash[j];
    }
    if (dash_count % 2) cycle *= 2;
    position = start * length;
    phase = fmod(position, cycle);
    while (phase >= dash[dash_index]) {
      phase -= dash[dash_index]; dash_index = (dash_index + 1) % dash_count; drawing = !drawing;
    }
    // Shift to the beginning of the current dash; clipped pixels are ignored.
    position -= phase;
    length *= finish;
  }
  while (position < length) {
    double step = dash[dash_index];
    double finish;
    PlotPoint start_point;
    PlotPoint finish_point;
    if (step <= 0.0) return;
    finish = fmin(position + step, length);
    if (finish <= position) return; // Unresolvable dash at extreme coordinates.
    start_point.x = a.x + dx * position / hypot(dx, dy);
    start_point.y = a.y + dy * position / hypot(dx, dy);
    finish_point.x = a.x + dx * finish / hypot(dx, dy);
    finish_point.y = a.y + dy * finish / hypot(dx, dy);
    if (drawing)
      draw_segment(canvas, start_point, finish_point, color, width, opacity);
    position = finish;
    dash_index = (dash_index + 1) % dash_count;
    drawing = !drawing;
  }
}

static int point_in_ring(double x, double y, const PlotRing *ring) {
  int inside = 0;
  size_t i;
  size_t j;
  if (ring->count < 3) return 0;
  j = ring->count - 1;
  for (i = 0; i < ring->count; ++i) {
    PlotPoint a = ring->points[i];
    PlotPoint b = ring->points[j];
    if (((a.y > y) != (b.y > y)) &&
        (x < (b.x - a.x) * (y - a.y) / (b.y - a.y) + a.x)) {
      inside = !inside;
    }
    j = i;
  }
  return inside;
}

static void draw_polygon(PlotCanvas *canvas, PlotRing *rings, size_t ring_count,
                         PlotColor fill, PlotColor stroke, double stroke_width,
                         double opacity) {
  double min_x = 1e30;
  double min_y = 1e30;
  double max_x = -1e30;
  double max_y = -1e30;
  size_t r;
  for (r = 0; r < ring_count; ++r) {
    size_t i;
    for (i = 0; i < rings[r].count; ++i) {
      PlotPoint p = rings[r].points[i];
      if (p.x < min_x) min_x = p.x;
      if (p.x > max_x) max_x = p.x;
      if (p.y < min_y) min_y = p.y;
      if (p.y > max_y) max_y = p.y;
    }
  }
  if (fill.a > 0 && min_x <= max_x) {
    int first_x = (int)clamp_double(floor(min_x), canvas->clip_left, canvas->clip_right);
    int last_x = (int)clamp_double(ceil(max_x), canvas->clip_left - 1, canvas->clip_right - 1);
    int first_y = (int)clamp_double(floor(min_y), canvas->clip_top, canvas->clip_bottom);
    int last_y = (int)clamp_double(ceil(max_y), canvas->clip_top - 1, canvas->clip_bottom - 1);
    int y;
    for (y = first_y; y <= last_y; ++y) {
      int x;
      for (x = first_x; x <= last_x; ++x) {
        int inside = 0;
        for (r = 0; r < ring_count; ++r) {
          if (point_in_ring(x + 0.5, y + 0.5, &rings[r])) inside = !inside;
        }
        if (inside) blend_pixel(canvas, x, y, fill, opacity);
      }
    }
  }
  if (stroke.a > 0 && stroke_width > 0.0) {
    for (r = 0; r < ring_count; ++r) {
      size_t i;
      for (i = 0; i < rings[r].count; ++i) {
        PlotPoint a = rings[r].points[i];
        PlotPoint b = rings[r].points[(i + 1) % rings[r].count];
        draw_segment(canvas, a, b, stroke, stroke_width, opacity);
      }
    }
  }
}

static void draw_circle(PlotCanvas *canvas, PlotPoint center, double radius,
                        PlotColor fill, PlotColor stroke, double stroke_width,
                        double opacity) {
  double outer = radius + stroke_width / 2.0;
  int min_x = (int)clamp_double(floor(center.x - outer - 1.0), canvas->clip_left, canvas->clip_right);
  int max_x = (int)clamp_double(ceil(center.x + outer + 1.0), canvas->clip_left - 1, canvas->clip_right - 1);
  int min_y = (int)clamp_double(floor(center.y - outer - 1.0), canvas->clip_top, canvas->clip_bottom);
  int max_y = (int)clamp_double(ceil(center.y + outer + 1.0), canvas->clip_top - 1, canvas->clip_bottom - 1);
  int y;
  for (y = min_y; y <= max_y; ++y) {
    int x;
    for (x = min_x; x <= max_x; ++x) {
      double distance = hypot(x + 0.5 - center.x, y + 0.5 - center.y);
      double fill_coverage = clamp_double(radius + 0.75 - distance, 0.0, 1.0);
      if (fill_coverage > 0.0) blend_pixel(canvas, x, y, fill, opacity * fill_coverage);
      if (stroke.a > 0 && stroke_width > 0.0) {
        double stroke_distance = fabs(distance - radius);
        double coverage = clamp_double(stroke_width / 2.0 + 0.75 - stroke_distance, 0.0, 1.0);
        if (coverage > 0.0) blend_pixel(canvas, x, y, stroke, opacity * coverage);
      }
    }
  }
}

static int read_points(SputnikCtx *cx, SputnikValue list, PlotPoint **points_out,
                       size_t *count_out) {
  size_t count;
  PlotPoint *points;
  size_t i;
  if (!sputnik_is_list(cx, list)) return 0;
  count = sputnik_list_len(cx, list);
  points = count == 0 ? NULL : (PlotPoint *)calloc(count, sizeof(PlotPoint));
  if (count > 0 && points == NULL) return 0;
  for (i = 0; i < count; ++i) {
    SputnikValue pair = sputnik_list_at(cx, list, i);
    if (!sputnik_is_list(cx, pair) || sputnik_list_len(cx, pair) < 2 ||
        !list_number(cx, pair, 0, &points[i].x) ||
        !list_number(cx, pair, 1, &points[i].y)) {
      free(points);
      return 0;
    }
  }
  *points_out = points;
  *count_out = count;
  return 1;
}

static int read_numbers(SputnikCtx *cx, SputnikValue list, double **values_out,
                        size_t *count_out) {
  size_t count;
  double *values;
  size_t i;
  if (!sputnik_is_list(cx, list)) return 0;
  count = sputnik_list_len(cx, list);
  values = count == 0 ? NULL : (double *)calloc(count, sizeof(double));
  if (count > 0 && values == NULL) return 0;
  for (i = 0; i < count; ++i) {
    if (!value_number(cx, sputnik_list_at(cx, list, i), &values[i]) ||
        values[i] <= 0.0) {
      free(values);
      return 0;
    }
  }
  *values_out = values;
  *count_out = count;
  return 1;
}

static void free_rings(PlotRing *rings, size_t count) {
  size_t i;
  if (rings == NULL) return;
  for (i = 0; i < count; ++i) free(rings[i].points);
  free(rings);
}

/* 5x7 bitmap glyphs. Lowercase is intentionally rendered as uppercase so the
 * built-in font remains compact and deterministic on every host. */
static void glyph_rows(char input, uint8_t rows[7]) {
  static const uint8_t digits[10][7] = {
      {14,17,19,21,25,17,14},{4,12,4,4,4,4,14},{14,17,1,2,4,8,31},
      {30,1,1,14,1,1,30},{2,6,10,18,31,2,2},{31,16,16,30,1,1,30},
      {14,16,16,30,17,17,14},{31,1,2,4,8,8,8},{14,17,17,14,17,17,14},
      {14,17,17,15,1,1,14}};
  static const uint8_t letters[26][7] = {
      {14,17,17,31,17,17,17},{30,17,17,30,17,17,30},{14,17,16,16,16,17,14},
      {30,17,17,17,17,17,30},{31,16,16,30,16,16,31},{31,16,16,30,16,16,16},
      {14,17,16,23,17,17,15},{17,17,17,31,17,17,17},{14,4,4,4,4,4,14},
      {7,2,2,2,18,18,12},{17,18,20,24,20,18,17},{16,16,16,16,16,16,31},
      {17,27,21,21,17,17,17},{17,25,21,19,17,17,17},{14,17,17,17,17,17,14},
      {30,17,17,30,16,16,16},{14,17,17,17,21,18,13},{30,17,17,30,20,18,17},
      {15,16,16,14,1,1,30},{31,4,4,4,4,4,4},{17,17,17,17,17,17,14},
      {17,17,17,17,17,10,4},{17,17,17,21,21,21,10},{17,17,10,4,10,17,17},
      {17,17,10,4,4,4,4},{31,1,2,4,8,16,31}};
  memset(rows, 0, 7);
  if (input >= 'a' && input <= 'z') input = (char)(input - 'a' + 'A');
  if (input >= '0' && input <= '9') {
    memcpy(rows, digits[input - '0'], 7);
    return;
  }
  if (input >= 'A' && input <= 'Z') {
    memcpy(rows, letters[input - 'A'], 7);
    return;
  }
  switch (input) {
    case '.': rows[6] = 4; break;
    case ',': rows[5] = 4; rows[6] = 8; break;
    case '-': rows[3] = 14; break;
    case '+': rows[2] = 4; rows[3] = 14; rows[4] = 4; break;
    case '=': rows[2] = 14; rows[4] = 14; break;
    case ':': rows[2] = 4; rows[5] = 4; break;
    case '/': rows[0]=1; rows[1]=2; rows[2]=2; rows[3]=4; rows[4]=8; rows[5]=8; rows[6]=16; break;
    case '(': rows[1]=2; rows[2]=4; rows[3]=4; rows[4]=4; rows[5]=2; break;
    case ')': rows[1]=8; rows[2]=4; rows[3]=4; rows[4]=4; rows[5]=8; break;
    case '^': rows[0]=4; rows[1]=10; break;
    default: break;
  }
}

static void draw_text(PlotCanvas *canvas, double x, double y, double size,
                      int align, PlotColor color, const char *text,
                      size_t length) {
  int scale = (int)floor(size / 8.0);
  int glyph_width;
  int total_width;
  int start_x;
  size_t index;
  if (scale < 1) scale = 1;
  glyph_width = 6 * scale;
  total_width = (int)length * glyph_width;
  start_x = (int)round(x);
  if (align == 1) start_x -= total_width / 2;
  if (align == 2) start_x -= total_width;
  for (index = 0; index < length; ++index) {
    uint8_t rows[7];
    int row;
    glyph_rows(text[index], rows);
    for (row = 0; row < 7; ++row) {
      int column;
      for (column = 0; column < 5; ++column) {
        if ((rows[row] & (1u << (4 - column))) != 0) {
          int sy;
          for (sy = 0; sy < scale; ++sy) {
            int sx;
            for (sx = 0; sx < scale; ++sx) {
              blend_pixel(canvas, start_x + (int)index * glyph_width + column * scale + sx,
                          (int)round(y) + row * scale + sy, color, 1.0);
            }
          }
        }
      }
    }
  }
}

static uint32_t crc32_update(uint32_t crc, const uint8_t *data, size_t length) {
  size_t i;
  crc = ~crc;
  for (i = 0; i < length; ++i) {
    int bit;
    crc ^= data[i];
    for (bit = 0; bit < 8; ++bit)
      crc = (crc >> 1) ^ (0xedb88320u & (uint32_t)(-(int32_t)(crc & 1u)));
  }
  return ~crc;
}

static void write_u32be(uint8_t *target, uint32_t value) {
  target[0] = (uint8_t)(value >> 24);
  target[1] = (uint8_t)(value >> 16);
  target[2] = (uint8_t)(value >> 8);
  target[3] = (uint8_t)value;
}

static size_t write_chunk(uint8_t *output, size_t offset, const char type[4],
                          const uint8_t *data, size_t length) {
  uint32_t crc;
  write_u32be(output + offset, (uint32_t)length);
  memcpy(output + offset + 4, type, 4);
  if (length > 0) memcpy(output + offset + 8, data, length);
  crc = crc32_update(0, output + offset + 4, length + 4);
  write_u32be(output + offset + 8 + length, crc);
  return offset + 12 + length;
}

static uint8_t *encode_png(const PlotCanvas *canvas, size_t *length_out) {
  size_t row_size = (size_t)canvas->width * 4 + 1;
  size_t raw_size = row_size * (size_t)canvas->height;
  size_t block_count = (raw_size + 65534) / 65535;
  size_t zlib_size = 2 + raw_size + block_count * 5 + 4;
  size_t png_size = 8 + 25 + 12 + zlib_size + 12;
  uint8_t *raw = (uint8_t *)malloc(raw_size);
  uint8_t *zlib = (uint8_t *)malloc(zlib_size);
  uint8_t *png = (uint8_t *)malloc(png_size);
  size_t y;
  size_t source = 0;
  size_t target = 0;
  uint32_t adler_a = 1;
  uint32_t adler_b = 0;
  size_t offset;
  uint8_t ihdr[13];
  if (raw == NULL || zlib == NULL || png == NULL) {
    free(raw); free(zlib); free(png);
    return NULL;
  }
  for (y = 0; y < (size_t)canvas->height; ++y) {
    raw[y * row_size] = 0;
    memcpy(raw + y * row_size + 1,
           canvas->pixels + y * (size_t)canvas->width * 4,
           (size_t)canvas->width * 4);
  }
  zlib[target++] = 0x78;
  zlib[target++] = 0x01;
  while (source < raw_size) {
    size_t remaining = raw_size - source;
    uint16_t length = (uint16_t)(remaining > 65535 ? 65535 : remaining);
    uint16_t inverse = (uint16_t)~length;
    size_t i;
    zlib[target++] = source + length == raw_size ? 1 : 0;
    zlib[target++] = (uint8_t)length;
    zlib[target++] = (uint8_t)(length >> 8);
    zlib[target++] = (uint8_t)inverse;
    zlib[target++] = (uint8_t)(inverse >> 8);
    memcpy(zlib + target, raw + source, length);
    for (i = 0; i < length; ++i) {
      adler_a = (adler_a + raw[source + i]) % 65521u;
      adler_b = (adler_b + adler_a) % 65521u;
    }
    target += length;
    source += length;
  }
  write_u32be(zlib + target, (adler_b << 16) | adler_a);
  target += 4;
  memcpy(png, "\x89PNG\r\n\x1a\n", 8);
  write_u32be(ihdr, (uint32_t)canvas->width);
  write_u32be(ihdr + 4, (uint32_t)canvas->height);
  ihdr[8] = 8; ihdr[9] = 6; ihdr[10] = 0; ihdr[11] = 0; ihdr[12] = 0;
  offset = write_chunk(png, 8, "IHDR", ihdr, 13);
  offset = write_chunk(png, offset, "IDAT", zlib, target);
  offset = write_chunk(png, offset, "IEND", NULL, 0);
  free(raw);
  free(zlib);
  *length_out = offset;
  return png;
}

static SputnikStatus render_command(SputnikCtx *cx, PlotCanvas *canvas,
                                  SputnikValue command) {
  int64_t kind = 0;
  size_t length;
  if (!sputnik_is_list(cx, command) || (length = sputnik_list_len(cx, command)) < 1 ||
      !sputnik_as_int(cx, sputnik_list_at(cx, command, 0), &kind)) {
    return sputnik_fault(cx, "ArgumentError", "invalid PNG drawing command");
  }
  if (kind == 1) {
    PlotColor fill, stroke;
    double stroke_width, opacity;
    SputnikValue rings_value;
    size_t ring_count;
    PlotRing *rings;
    size_t r;
    if (length != 6 || !parse_color(cx, sputnik_list_at(cx, command, 1), &fill) ||
        !parse_color(cx, sputnik_list_at(cx, command, 2), &stroke) ||
        !list_number(cx, command, 3, &stroke_width) ||
        !list_number(cx, command, 4, &opacity))
      return sputnik_fault(cx, "ArgumentError", "invalid PNG polygon command");
    rings_value = sputnik_list_at(cx, command, 5);
    if (!sputnik_is_list(cx, rings_value))
      return sputnik_fault(cx, "ArgumentError", "polygon rings must be a List");
    ring_count = sputnik_list_len(cx, rings_value);
    rings = ring_count == 0 ? NULL : (PlotRing *)calloc(ring_count, sizeof(PlotRing));
    if (ring_count > 0 && rings == NULL)
      return sputnik_fault(cx, "RuntimeError", "PNG renderer is out of memory");
    for (r = 0; r < ring_count; ++r) {
      if (!read_points(cx, sputnik_list_at(cx, rings_value, r),
                       &rings[r].points, &rings[r].count)) {
        free_rings(rings, ring_count);
        return sputnik_fault(cx, "ArgumentError", "invalid polygon points");
      }
    }
    draw_polygon(canvas, rings, ring_count, fill, stroke, stroke_width, opacity);
    free_rings(rings, ring_count);
    return SPUTNIK_OK;
  }
  if (kind == 2) {
    PlotColor color;
    double width, opacity;
    PlotPoint *points = NULL;
    size_t count = 0;
    double *dash = NULL;
    size_t dash_count = 0;
    size_t i;
    if ((length != 5 && length != 6) ||
        !parse_color(cx, sputnik_list_at(cx, command, 1), &color) ||
        !list_number(cx, command, 2, &width) ||
        !list_number(cx, command, 3, &opacity) ||
        !read_points(cx, sputnik_list_at(cx, command, 4), &points, &count))
      return sputnik_fault(cx, "ArgumentError", "invalid PNG polyline command");
    if (length == 6 && !read_numbers(cx, sputnik_list_at(cx, command, 5),
                                     &dash, &dash_count)) {
      free(points);
      return sputnik_fault(cx, "ArgumentError", "invalid PNG dash pattern");
    }
    for (i = 1; i < count; ++i)
      draw_dashed_segment(canvas, points[i - 1], points[i], color, width,
                          opacity, dash, dash_count);
    free(dash);
    free(points);
    return SPUTNIK_OK;
  }
  if (kind == 3) {
    PlotColor fill, stroke;
    double stroke_width, opacity, radius;
    PlotPoint *points = NULL;
    size_t count = 0;
    size_t i;
    if (length != 7 || !parse_color(cx, sputnik_list_at(cx, command, 1), &fill) ||
        !parse_color(cx, sputnik_list_at(cx, command, 2), &stroke) ||
        !list_number(cx, command, 3, &stroke_width) ||
        !list_number(cx, command, 4, &opacity) ||
        !list_number(cx, command, 5, &radius) ||
        !read_points(cx, sputnik_list_at(cx, command, 6), &points, &count))
      return sputnik_fault(cx, "ArgumentError", "invalid PNG circle command");
    for (i = 0; i < count; ++i)
      draw_circle(canvas, points[i], radius, fill, stroke, stroke_width, opacity);
    free(points);
    return SPUTNIK_OK;
  }
  if (kind == 4) {
    PlotColor color;
    double size, x, y, align_number;
    const char *text;
    size_t text_length;
    if (length != 7 || !parse_color(cx, sputnik_list_at(cx, command, 1), &color) ||
        !list_number(cx, command, 2, &size) || !list_number(cx, command, 3, &x) ||
        !list_number(cx, command, 4, &y) || !list_number(cx, command, 5, &align_number) ||
        !sputnik_str_view(cx, sputnik_list_at(cx, command, 6), &text, &text_length))
      return sputnik_fault(cx, "ArgumentError", "invalid PNG text command");
    draw_text(canvas, x, y, size, (int)align_number, color, text, text_length);
    return SPUTNIK_OK;
  }
  if (kind == 5) {
    double x, y, w, h;
    if (length != 5 || !list_number(cx, command, 1, &x) || !list_number(cx, command, 2, &y) ||
        !list_number(cx, command, 3, &w) || !list_number(cx, command, 4, &h) ||
        !isfinite(x) || !isfinite(y) || !isfinite(w) || !isfinite(h) || w < 0 || h < 0)
      return sputnik_fault(cx, "ArgumentError", "invalid PNG clip rectangle");
    canvas->clip_left = (int)clamp_double(ceil(x), 0, canvas->width);
    canvas->clip_top = (int)clamp_double(ceil(y), 0, canvas->height);
    canvas->clip_right = (int)clamp_double(ceil(x + w), canvas->clip_left, canvas->width);
    canvas->clip_bottom = (int)clamp_double(ceil(y + h), canvas->clip_top, canvas->height);
    return SPUTNIK_OK;
  }
  if (kind == 6 && length == 1) {
    canvas->clip_left = canvas->clip_top = 0;
    canvas->clip_right = canvas->width; canvas->clip_bottom = canvas->height;
    return SPUTNIK_OK;
  }
  return sputnik_fault(cx, "ArgumentError", "unknown PNG drawing command");
}

SputnikStatus sputnik_plot_render_png(SputnikCtx *cx, const SputnikValue *args,
                                  size_t argc, SputnikValue *out) {
  int64_t width64, height64;
  PlotColor background;
  PlotCanvas canvas;
  size_t pixel_count;
  size_t i;
  uint8_t *png;
  size_t png_length;
  SputnikValue commands;
  if (argc != 4 || !sputnik_as_int(cx, args[0], &width64) ||
      !sputnik_as_int(cx, args[1], &height64) || !parse_color(cx, args[2], &background) ||
      !sputnik_is_list(cx, args[3]))
    return sputnik_fault(cx, "ArgumentError", "render_png expects width, height, background, commands");
  if (width64 <= 0 || height64 <= 0 || width64 > 8192 || height64 > 8192 ||
      (uint64_t)width64 * (uint64_t)height64 > 64000000u)
    return sputnik_fault(cx, "ArgumentError", "PNG dimensions are outside the supported range");
  canvas.width = (int)width64;
  canvas.height = (int)height64;
  canvas.clip_left = canvas.clip_top = 0;
  canvas.clip_right = canvas.width; canvas.clip_bottom = canvas.height;
  pixel_count = (size_t)canvas.width * (size_t)canvas.height;
  canvas.pixels = (uint8_t *)malloc(pixel_count * 4);
  if (canvas.pixels == NULL)
    return sputnik_fault(cx, "RuntimeError", "PNG renderer is out of memory");
  for (i = 0; i < pixel_count; ++i) {
    canvas.pixels[i * 4] = background.r;
    canvas.pixels[i * 4 + 1] = background.g;
    canvas.pixels[i * 4 + 2] = background.b;
    canvas.pixels[i * 4 + 3] = background.a;
  }
  commands = args[3];
  for (i = 0; i < sputnik_list_len(cx, commands); ++i) {
    SputnikStatus status = render_command(cx, &canvas, sputnik_list_at(cx, commands, i));
    if (status != SPUTNIK_OK) {
      free(canvas.pixels);
      return status;
    }
  }
  png = encode_png(&canvas, &png_length);
  free(canvas.pixels);
  if (png == NULL)
    return sputnik_fault(cx, "RuntimeError", "PNG encoder is out of memory");
  *out = sputnik_make_bytes(cx, png, png_length);
  free(png);
  return SPUTNIK_OK;
}

/* -------------------------------------------------------------------------
 * Static 3D renderer. The Sputnik side owns the immutable Figure3D/Scene3D
 * specification. This backend consumes its versioned, backend-neutral scene,
 * projects triangles, resolves visibility with a depth buffer, and reuses the
 * same RGBA canvas and PNG encoder as the 2D backend.
 */

typedef struct {
  double x;
  double y;
  double z;
} PlotVec3;

typedef struct {
  double x;
  double y;
  double depth;
  int visible;
} PlotProjected3;

typedef struct {
  double azimuth;
  double elevation;
  double roll;
  double distance;
  PlotVec3 target;
  int orthographic;
  double fov;
  double ortho_scale;
  double padding;
  PlotVec3 position;
  PlotVec3 right;
  PlotVec3 up;
  PlotVec3 forward;
  double center_x;
  double center_y;
  double perspective_scale;
  double orthographic_scale_px;
  double near_plane;
} PlotCamera3;

static PlotVec3 vec3_sub(PlotVec3 a, PlotVec3 b) {
  PlotVec3 result = {a.x - b.x, a.y - b.y, a.z - b.z};
  return result;
}

static PlotVec3 vec3_add(PlotVec3 a, PlotVec3 b) {
  PlotVec3 result = {a.x + b.x, a.y + b.y, a.z + b.z};
  return result;
}

static PlotVec3 vec3_scale(PlotVec3 value, double scale) {
  PlotVec3 result = {value.x * scale, value.y * scale, value.z * scale};
  return result;
}

static double vec3_dot(PlotVec3 a, PlotVec3 b) {
  return a.x * b.x + a.y * b.y + a.z * b.z;
}

static PlotVec3 vec3_cross(PlotVec3 a, PlotVec3 b) {
  PlotVec3 result = {a.y * b.z - a.z * b.y,
                     a.z * b.x - a.x * b.z,
                     a.x * b.y - a.y * b.x};
  return result;
}

static PlotVec3 vec3_normalize(PlotVec3 value) {
  double length = sqrt(vec3_dot(value, value));
  if (length <= 1e-15) {
    PlotVec3 fallback = {0.0, 0.0, 1.0};
    return fallback;
  }
  return vec3_scale(value, 1.0 / length);
}

static int list_vec3(SputnikCtx *cx, SputnikValue value, PlotVec3 *out) {
  if (!sputnik_is_list(cx, value) || sputnik_list_len(cx, value) < 3) return 0;
  return list_number(cx, value, 0, &out->x) &&
         list_number(cx, value, 1, &out->y) &&
         list_number(cx, value, 2, &out->z);
}

static int read_vec3_list(SputnikCtx *cx, SputnikValue list, PlotVec3 **out,
                          size_t *count_out) {
  size_t count;
  PlotVec3 *values;
  size_t i;
  if (!sputnik_is_list(cx, list)) return 0;
  count = sputnik_list_len(cx, list);
  values = count == 0 ? NULL : (PlotVec3 *)calloc(count, sizeof(PlotVec3));
  if (count > 0 && values == NULL) return 0;
  for (i = 0; i < count; ++i) {
    if (!list_vec3(cx, sputnik_list_at(cx, list, i), &values[i])) {
      free(values);
      return 0;
    }
  }
  *out = values;
  *count_out = count;
  return 1;
}

static int setup_camera3(SputnikCtx *cx, SputnikValue values, int width,
                         int height, int has_title, PlotCamera3 *camera) {
  double projection_number;
  double degrees = 3.14159265358979323846 / 180.0;
  double azimuth;
  double elevation;
  double roll;
  PlotVec3 offset;
  PlotVec3 world_up = {0.0, 0.0, 1.0};
  PlotVec3 unrolled_right;
  PlotVec3 unrolled_up;
  double viewport_top;
  double viewport_bottom;
  double viewport_height;
  if (!sputnik_is_list(cx, values) || sputnik_list_len(cx, values) != 11 ||
      !list_number(cx, values, 0, &camera->azimuth) ||
      !list_number(cx, values, 1, &camera->elevation) ||
      !list_number(cx, values, 2, &camera->roll) ||
      !list_number(cx, values, 3, &camera->distance) ||
      !list_number(cx, values, 4, &camera->target.x) ||
      !list_number(cx, values, 5, &camera->target.y) ||
      !list_number(cx, values, 6, &camera->target.z) ||
      !list_number(cx, values, 7, &projection_number) ||
      !list_number(cx, values, 8, &camera->fov) ||
      !list_number(cx, values, 9, &camera->ortho_scale) ||
      !list_number(cx, values, 10, &camera->padding)) return 0;
  camera->orthographic = (int)projection_number;
  azimuth = camera->azimuth * degrees;
  elevation = camera->elevation * degrees;
  roll = camera->roll * degrees;
  offset.x = cos(elevation) * cos(azimuth) * camera->distance;
  offset.y = cos(elevation) * sin(azimuth) * camera->distance;
  offset.z = sin(elevation) * camera->distance;
  camera->position = vec3_add(camera->target, offset);
  camera->forward = vec3_normalize(vec3_sub(camera->target, camera->position));
  unrolled_right = vec3_cross(camera->forward, world_up);
  if (vec3_dot(unrolled_right, unrolled_right) <= 1e-12) {
    PlotVec3 alternate_up = {0.0, 1.0, 0.0};
    unrolled_right = vec3_cross(camera->forward, alternate_up);
  }
  unrolled_right = vec3_normalize(unrolled_right);
  unrolled_up = vec3_normalize(vec3_cross(unrolled_right, camera->forward));
  camera->right = vec3_add(vec3_scale(unrolled_right, cos(roll)),
                           vec3_scale(unrolled_up, sin(roll)));
  camera->up = vec3_add(vec3_scale(unrolled_up, cos(roll)),
                        vec3_scale(unrolled_right, -sin(roll)));
  viewport_top = camera->padding + (has_title ? 28.0 : 0.0);
  viewport_bottom = (double)height - camera->padding;
  viewport_height = viewport_bottom - viewport_top;
  if (viewport_height <= 1.0 || camera->distance <= 0.0 ||
      camera->ortho_scale <= 0.0) return 0;
  camera->center_x = width / 2.0;
  camera->center_y = (viewport_top + viewport_bottom) / 2.0;
  camera->perspective_scale = viewport_height /
      (2.0 * tan(camera->fov * degrees / 2.0));
  camera->orthographic_scale_px = viewport_height / camera->ortho_scale;
  camera->near_plane = fmax(camera->distance * 0.001, 1e-6);
  return 1;
}

static PlotProjected3 project3(const PlotCamera3 *camera, PlotVec3 point) {
  PlotVec3 relative = vec3_sub(point, camera->position);
  double view_x = vec3_dot(relative, camera->right);
  double view_y = vec3_dot(relative, camera->up);
  double view_z = vec3_dot(relative, camera->forward);
  PlotProjected3 result;
  result.depth = view_z;
  result.visible = view_z > camera->near_plane;
  if (camera->orthographic) {
    result.x = camera->center_x + view_x * camera->orthographic_scale_px;
    result.y = camera->center_y - view_y * camera->orthographic_scale_px;
  } else if (result.visible) {
    result.x = camera->center_x + view_x * camera->perspective_scale / view_z;
    result.y = camera->center_y - view_y * camera->perspective_scale / view_z;
  } else {
    result.x = result.y = 0.0;
  }
  return result;
}

static double normal_brightness3(PlotVec3 normal, int shading) {
  PlotVec3 light = vec3_normalize((PlotVec3){0.45, -0.55, 0.82});
  double brightness;
  if (shading == 0) return 1.0;
  normal = vec3_normalize(normal);
  brightness = 0.34 + 0.66 * fabs(vec3_dot(normal, light));
  if (shading == 2) brightness = 0.42 + 0.58 * fabs(vec3_dot(normal, light));
  return brightness;
}

static PlotColor scale_color3(PlotColor color, double brightness) {
  color.r = (uint8_t)clamp_double(color.r * brightness, 0.0, 255.0);
  color.g = (uint8_t)clamp_double(color.g * brightness, 0.0, 255.0);
  color.b = (uint8_t)clamp_double(color.b * brightness, 0.0, 255.0);
  return color;
}

static double edge_function3(double ax, double ay, double bx, double by,
                             double px, double py) {
  return (px - ax) * (by - ay) - (py - ay) * (bx - ax);
}

static void raster_triangle3(PlotCanvas *canvas, double *depth_buffer,
                             PlotProjected3 a, PlotProjected3 b,
                             PlotProjected3 c, PlotColor color,
                             double brightness_a, double brightness_b,
                             double brightness_c,
                             double opacity, int draw_color,
                             int write_depth) {
  double area;
  int min_x;
  int max_x;
  int min_y;
  int max_y;
  int y;
  if (!a.visible || !b.visible || !c.visible) return;
  area = edge_function3(a.x, a.y, b.x, b.y, c.x, c.y);
  if (fabs(area) <= 1e-12) return;
  min_x = (int)floor(fmin(a.x, fmin(b.x, c.x)));
  max_x = (int)ceil(fmax(a.x, fmax(b.x, c.x)));
  min_y = (int)floor(fmin(a.y, fmin(b.y, c.y)));
  max_y = (int)ceil(fmax(a.y, fmax(b.y, c.y)));
  if (min_x < 0) min_x = 0;
  if (min_y < 0) min_y = 0;
  if (max_x >= canvas->width) max_x = canvas->width - 1;
  if (max_y >= canvas->height) max_y = canvas->height - 1;
  for (y = min_y; y <= max_y; ++y) {
    int x;
    for (x = min_x; x <= max_x; ++x) {
      double px = x + 0.5;
      double py = y + 0.5;
      double w0 = edge_function3(b.x, b.y, c.x, c.y, px, py) / area;
      double w1 = edge_function3(c.x, c.y, a.x, a.y, px, py) / area;
      double w2 = 1.0 - w0 - w1;
      size_t index;
      double depth;
      if (w0 < -1e-9 || w1 < -1e-9 || w2 < -1e-9) continue;
      depth = w0 * a.depth + w1 * b.depth + w2 * c.depth;
      index = (size_t)y * (size_t)canvas->width + (size_t)x;
      if (depth >= depth_buffer[index]) continue;
      if (draw_color) {
        double brightness = w0 * brightness_a + w1 * brightness_b +
                            w2 * brightness_c;
        blend_pixel(canvas, x, y, scale_color3(color, brightness), opacity);
      }
      if (write_depth) depth_buffer[index] = depth;
    }
  }
}

static int triangle_indices3(SputnikCtx *cx, SputnikValue value, size_t limit,
                             size_t indices[3]) {
  size_t i;
  if (!sputnik_is_list(cx, value) || sputnik_list_len(cx, value) != 3) return 0;
  for (i = 0; i < 3; ++i) {
    int64_t index;
    if (!sputnik_as_int(cx, sputnik_list_at(cx, value, i), &index) || index < 0 ||
        (uint64_t)index >= (uint64_t)limit) return 0;
    indices[i] = (size_t)index;
  }
  return 1;
}

static int render_mesh3(SputnikCtx *cx, PlotCanvas *canvas, double *depth_buffer,
                        const PlotCamera3 *camera, SputnikValue command,
                        int transparent_pass) {
  SputnikValue vertices_value;
  SputnikValue triangles_value;
  SputnikValue colors_value;
  PlotVec3 *vertices = NULL;
  PlotVec3 *normals = NULL;
  PlotProjected3 *projected = NULL;
  size_t vertex_count = 0;
  size_t triangle_count;
  double opacity;
  PlotColor edge_color;
  double edge_width;
  double fill_number;
  double edge_number;
  double shading_number;
  size_t i;
  if (!sputnik_is_list(cx, command) || sputnik_list_len(cx, command) != 10 ||
      !list_number(cx, command, 4, &opacity)) return 0;
  if ((opacity < 0.999) != transparent_pass) return 1;
  vertices_value = sputnik_list_at(cx, command, 1);
  triangles_value = sputnik_list_at(cx, command, 2);
  colors_value = sputnik_list_at(cx, command, 3);
  if (!read_vec3_list(cx, vertices_value, &vertices, &vertex_count) ||
      !sputnik_is_list(cx, triangles_value) || !sputnik_is_list(cx, colors_value) ||
      sputnik_list_len(cx, triangles_value) != sputnik_list_len(cx, colors_value) ||
      !parse_color(cx, sputnik_list_at(cx, command, 5), &edge_color) ||
      !list_number(cx, command, 6, &edge_width) ||
      !list_number(cx, command, 7, &fill_number) ||
      !list_number(cx, command, 8, &edge_number) ||
      !list_number(cx, command, 9, &shading_number)) {
    free(vertices);
    return 0;
  }
  projected = vertex_count == 0 ? NULL :
      (PlotProjected3 *)calloc(vertex_count, sizeof(PlotProjected3));
  if (vertex_count > 0 && projected == NULL) { free(vertices); return 0; }
  for (i = 0; i < vertex_count; ++i) projected[i] = project3(camera, vertices[i]);
  triangle_count = sputnik_list_len(cx, triangles_value);
  if ((int)shading_number == 2 && vertex_count > 0) {
    normals = (PlotVec3 *)calloc(vertex_count, sizeof(PlotVec3));
    if (normals == NULL) { free(projected); free(vertices); return 0; }
    for (i = 0; i < triangle_count; ++i) {
      size_t indices[3];
      PlotVec3 face_normal;
      if (!triangle_indices3(cx, sputnik_list_at(cx, triangles_value, i),
                             vertex_count, indices)) {
        free(normals); free(projected); free(vertices); return 0;
      }
      face_normal = vec3_cross(vec3_sub(vertices[indices[1]], vertices[indices[0]]),
                               vec3_sub(vertices[indices[2]], vertices[indices[0]]));
      normals[indices[0]] = vec3_add(normals[indices[0]], face_normal);
      normals[indices[1]] = vec3_add(normals[indices[1]], face_normal);
      normals[indices[2]] = vec3_add(normals[indices[2]], face_normal);
    }
    for (i = 0; i < vertex_count; ++i) normals[i] = vec3_normalize(normals[i]);
  }
  for (i = 0; i < triangle_count; ++i) {
    size_t indices[3];
    PlotColor fill;
    double brightness_a = 1.0;
    double brightness_b = 1.0;
    double brightness_c = 1.0;
    int fill_enabled = (int)fill_number;
    if (!triangle_indices3(cx, sputnik_list_at(cx, triangles_value, i),
                           vertex_count, indices) ||
        !parse_color(cx, sputnik_list_at(cx, colors_value, i), &fill)) {
      free(normals); free(projected); free(vertices); return 0;
    }
    if ((int)shading_number == 1) {
      PlotVec3 face_normal = vec3_cross(
          vec3_sub(vertices[indices[1]], vertices[indices[0]]),
          vec3_sub(vertices[indices[2]], vertices[indices[0]]));
      brightness_a = normal_brightness3(face_normal, 1);
      brightness_b = brightness_a;
      brightness_c = brightness_a;
    } else if ((int)shading_number == 2) {
      brightness_a = normal_brightness3(normals[indices[0]], 2);
      brightness_b = normal_brightness3(normals[indices[1]], 2);
      brightness_c = normal_brightness3(normals[indices[2]], 2);
    }
    raster_triangle3(canvas, depth_buffer, projected[indices[0]],
                     projected[indices[1]], projected[indices[2]], fill,
                     brightness_a, brightness_b, brightness_c,
                     opacity, fill_enabled, !transparent_pass);
  }
  free(normals);
  free(projected);
  free(vertices);
  return 1;
}

static void blend_depth_disc3(PlotCanvas *canvas, double *depth_buffer,
                              const PlotCamera3 *camera, double x, double y,
                              double depth, double radius, PlotColor color,
                              double opacity, int depth_test) {
  int min_x = (int)floor(x - radius - 1.0);
  int max_x = (int)ceil(x + radius + 1.0);
  int min_y = (int)floor(y - radius - 1.0);
  int max_y = (int)ceil(y + radius + 1.0);
  double epsilon = camera->distance * 0.004;
  int py;
  for (py = min_y; py <= max_y; ++py) {
    int px;
    for (px = min_x; px <= max_x; ++px) {
      double distance;
      double coverage;
      size_t index;
      if (px < 0 || py < 0 || px >= canvas->width || py >= canvas->height) continue;
      distance = hypot(px + 0.5 - x, py + 0.5 - y);
      coverage = clamp_double(radius + 0.75 - distance, 0.0, 1.0);
      if (coverage <= 0.0) continue;
      index = (size_t)py * (size_t)canvas->width + (size_t)px;
      if (depth_test && depth > depth_buffer[index] + epsilon) continue;
      blend_pixel(canvas, px, py, color, opacity * coverage);
    }
  }
}

static void draw_depth_line3(PlotCanvas *canvas, double *depth_buffer,
                             const PlotCamera3 *camera, PlotProjected3 a,
                             PlotProjected3 b, PlotColor color, double width,
                             double opacity, int depth_test) {
  double dx;
  double dy;
  int steps;
  int step;
  if (!a.visible || !b.visible) return;
  dx = b.x - a.x;
  dy = b.y - a.y;
  steps = (int)ceil(fmax(fabs(dx), fabs(dy)));
  if (steps < 1) steps = 1;
  for (step = 0; step <= steps; ++step) {
    double ratio = step * 1.0 / steps;
    blend_depth_disc3(canvas, depth_buffer, camera, a.x + dx * ratio,
      a.y + dy * ratio, a.depth + (b.depth - a.depth) * ratio,
      fmax(width / 2.0, 0.6), color, opacity, depth_test);
  }
}

static int render_mesh_edges3(SputnikCtx *cx, PlotCanvas *canvas,
                              double *depth_buffer, const PlotCamera3 *camera,
                              SputnikValue command) {
  PlotVec3 *vertices = NULL;
  PlotProjected3 *projected = NULL;
  size_t vertex_count = 0;
  SputnikValue triangles;
  PlotColor color;
  double opacity, width, edge_number;
  size_t i;
  if (!sputnik_is_list(cx, command) || sputnik_list_len(cx, command) != 10 ||
      !list_number(cx, command, 4, &opacity) ||
      !parse_color(cx, sputnik_list_at(cx, command, 5), &color) ||
      !list_number(cx, command, 6, &width) ||
      !list_number(cx, command, 8, &edge_number)) return 0;
  if ((int)edge_number == 0) return 1;
  if (!read_vec3_list(cx, sputnik_list_at(cx, command, 1), &vertices,
                      &vertex_count)) return 0;
  triangles = sputnik_list_at(cx, command, 2);
  if (!sputnik_is_list(cx, triangles)) { free(vertices); return 0; }
  projected = vertex_count == 0 ? NULL :
      (PlotProjected3 *)calloc(vertex_count, sizeof(PlotProjected3));
  if (vertex_count > 0 && projected == NULL) { free(vertices); return 0; }
  for (i = 0; i < vertex_count; ++i) projected[i] = project3(camera, vertices[i]);
  for (i = 0; i < sputnik_list_len(cx, triangles); ++i) {
    size_t indices[3];
    int edge;
    if (!triangle_indices3(cx, sputnik_list_at(cx, triangles, i),
                           vertex_count, indices)) {
      free(projected); free(vertices); return 0;
    }
    for (edge = 0; edge < 3; ++edge)
      draw_depth_line3(canvas, depth_buffer, camera, projected[indices[edge]],
        projected[indices[(edge + 1) % 3]], color, width, opacity, 1);
  }
  free(projected);
  free(vertices);
  return 1;
}

static int render_lines3(SputnikCtx *cx, PlotCanvas *canvas, double *depth_buffer,
                         const PlotCamera3 *camera, SputnikValue command) {
  SputnikValue polylines;
  PlotColor color;
  double width, opacity, depth_number;
  size_t line_index;
  if (!sputnik_is_list(cx, command) || sputnik_list_len(cx, command) != 6 ||
      !parse_color(cx, sputnik_list_at(cx, command, 2), &color) ||
      !list_number(cx, command, 3, &width) ||
      !list_number(cx, command, 4, &opacity) ||
      !list_number(cx, command, 5, &depth_number)) return 0;
  polylines = sputnik_list_at(cx, command, 1);
  if (!sputnik_is_list(cx, polylines)) return 0;
  for (line_index = 0; line_index < sputnik_list_len(cx, polylines); ++line_index) {
    PlotVec3 *points = NULL;
    size_t count = 0;
    size_t i;
    if (!read_vec3_list(cx, sputnik_list_at(cx, polylines, line_index),
                        &points, &count)) return 0;
    for (i = 1; i < count; ++i)
      draw_depth_line3(canvas, depth_buffer, camera, project3(camera, points[i-1]),
        project3(camera, points[i]), color, width, opacity, (int)depth_number);
    free(points);
  }
  return 1;
}

static int render_points3(SputnikCtx *cx, PlotCanvas *canvas,
                          double *depth_buffer, const PlotCamera3 *camera,
                          SputnikValue command) {
  PlotVec3 *points = NULL;
  size_t count = 0;
  PlotColor fill, stroke;
  double stroke_width, radius, opacity;
  size_t i;
  if (!sputnik_is_list(cx, command) || sputnik_list_len(cx, command) != 7 ||
      !read_vec3_list(cx, sputnik_list_at(cx, command, 1), &points, &count) ||
      !parse_color(cx, sputnik_list_at(cx, command, 2), &fill) ||
      !parse_color(cx, sputnik_list_at(cx, command, 3), &stroke) ||
      !list_number(cx, command, 4, &stroke_width) ||
      !list_number(cx, command, 5, &radius) ||
      !list_number(cx, command, 6, &opacity)) {
    free(points); return 0;
  }
  for (i = 0; i < count; ++i) {
    PlotProjected3 projected = project3(camera, points[i]);
    if (!projected.visible) continue;
    blend_depth_disc3(canvas, depth_buffer, camera, projected.x, projected.y,
      projected.depth, radius + stroke_width, stroke, opacity, 1);
    blend_depth_disc3(canvas, depth_buffer, camera, projected.x, projected.y,
      projected.depth, radius, fill, opacity, 1);
  }
  free(points);
  return 1;
}

static int render_label3(SputnikCtx *cx, PlotCanvas *canvas,
                         const PlotCamera3 *camera, SputnikValue command) {
  PlotVec3 point;
  PlotProjected3 projected;
  PlotColor color;
  double size, dx, dy, align_number;
  const char *text;
  size_t text_length;
  if (!sputnik_is_list(cx, command) || sputnik_list_len(cx, command) != 8 ||
      !list_vec3(cx, sputnik_list_at(cx, command, 1), &point) ||
      !parse_color(cx, sputnik_list_at(cx, command, 2), &color) ||
      !list_number(cx, command, 3, &size) ||
      !list_number(cx, command, 4, &dx) ||
      !list_number(cx, command, 5, &dy) ||
      !list_number(cx, command, 6, &align_number) ||
      !sputnik_str_view(cx, sputnik_list_at(cx, command, 7), &text, &text_length)) return 0;
  projected = project3(camera, point);
  if (projected.visible)
    draw_text(canvas, projected.x + dx, projected.y + dy, size,
              (int)align_number, color, text, text_length);
  return 1;
}

SputnikStatus sputnik_plot_render_3d_png(SputnikCtx *cx, const SputnikValue *args,
                                     size_t argc, SputnikValue *out) {
  int64_t width64, height64;
  PlotColor background;
  SputnikValue scene;
  SputnikValue camera_value;
  SputnikValue commands;
  SputnikValue title_value;
  const char *title;
  size_t title_length;
  PlotCanvas canvas;
  PlotCamera3 camera;
  size_t pixel_count;
  double *depth_buffer;
  size_t i;
  uint8_t *png;
  size_t png_length;
  if (argc != 4 || !sputnik_as_int(cx, args[0], &width64) ||
      !sputnik_as_int(cx, args[1], &height64) ||
      !parse_color(cx, args[2], &background) || !sputnik_is_list(cx, args[3]))
    return sputnik_fault(cx, "ArgumentError", "render_3d_png expects width, height, background, scene");
  if (width64 <= 0 || height64 <= 0 || width64 > 8192 || height64 > 8192 ||
      (uint64_t)width64 * (uint64_t)height64 > 64000000u)
    return sputnik_fault(cx, "ArgumentError", "3D PNG dimensions are outside the supported range");
  scene = args[3];
  if (sputnik_list_len(cx, scene) != 4)
    return sputnik_fault(cx, "ArgumentError", "invalid Scene3D payload");
  camera_value = sputnik_list_at(cx, scene, 0);
  commands = sputnik_list_at(cx, scene, 2);
  title_value = sputnik_list_at(cx, scene, 3);
  if (!sputnik_is_list(cx, commands) ||
      !sputnik_str_view(cx, title_value, &title, &title_length) ||
      !setup_camera3(cx, camera_value, (int)width64, (int)height64,
                     title_length > 0, &camera))
    return sputnik_fault(cx, "ArgumentError", "invalid Scene3D camera or commands");
  canvas.width = (int)width64;
  canvas.height = (int)height64;
  canvas.clip_left = canvas.clip_top = 0;
  canvas.clip_right = canvas.width; canvas.clip_bottom = canvas.height;
  pixel_count = (size_t)canvas.width * (size_t)canvas.height;
  canvas.pixels = (uint8_t *)malloc(pixel_count * 4);
  depth_buffer = (double *)malloc(pixel_count * sizeof(double));
  if (canvas.pixels == NULL || depth_buffer == NULL) {
    free(canvas.pixels); free(depth_buffer);
    return sputnik_fault(cx, "RuntimeError", "3D PNG renderer is out of memory");
  }
  for (i = 0; i < pixel_count; ++i) {
    canvas.pixels[i * 4] = background.r;
    canvas.pixels[i * 4 + 1] = background.g;
    canvas.pixels[i * 4 + 2] = background.b;
    canvas.pixels[i * 4 + 3] = background.a;
    depth_buffer[i] = 1e300;
  }
  /* Opaque depth/color pass, then transparent surfaces. */
  for (int pass = 0; pass < 2; ++pass) {
    for (i = 0; i < sputnik_list_len(cx, commands); ++i) {
      SputnikValue command = sputnik_list_at(cx, commands, i);
      int64_t kind;
      if (!sputnik_is_list(cx, command) || sputnik_list_len(cx, command) < 1 ||
          !sputnik_as_int(cx, sputnik_list_at(cx, command, 0), &kind)) goto invalid_scene;
      if (kind == 1 && !render_mesh3(cx, &canvas, depth_buffer, &camera,
                                     command, pass == 1)) goto invalid_scene;
    }
  }
  /* Mesh edges and explicit lines/points use the opaque depth buffer. */
  for (i = 0; i < sputnik_list_len(cx, commands); ++i) {
    SputnikValue command = sputnik_list_at(cx, commands, i);
    int64_t kind;
    if (!sputnik_as_int(cx, sputnik_list_at(cx, command, 0), &kind)) goto invalid_scene;
    if (kind == 1 && !render_mesh_edges3(cx, &canvas, depth_buffer, &camera, command)) goto invalid_scene;
    if (kind == 2 && !render_lines3(cx, &canvas, depth_buffer, &camera, command)) goto invalid_scene;
    if (kind == 3 && !render_points3(cx, &canvas, depth_buffer, &camera, command)) goto invalid_scene;
  }
  /* Labels are screen-space billboards and intentionally remain readable. */
  for (i = 0; i < sputnik_list_len(cx, commands); ++i) {
    SputnikValue command = sputnik_list_at(cx, commands, i);
    int64_t kind;
    if (!sputnik_as_int(cx, sputnik_list_at(cx, command, 0), &kind)) goto invalid_scene;
    if (kind == 4 && !render_label3(cx, &canvas, &camera, command)) goto invalid_scene;
  }
  if (title_length > 0) {
    PlotColor title_color = {17, 24, 39, 255};
    draw_text(&canvas, canvas.width / 2.0, 18, 20, 1, title_color,
              title, title_length);
  }
  png = encode_png(&canvas, &png_length);
  free(depth_buffer);
  free(canvas.pixels);
  if (png == NULL)
    return sputnik_fault(cx, "RuntimeError", "3D PNG encoder is out of memory");
  *out = sputnik_make_bytes(cx, png, png_length);
  free(png);
  return SPUTNIK_OK;

invalid_scene:
  free(depth_buffer);
  free(canvas.pixels);
  return sputnik_fault(cx, "ArgumentError", "invalid Scene3D drawing command");
}
