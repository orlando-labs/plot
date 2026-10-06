# Sputnik Plot: проект API

Статус: спецификация v1; полигональное 2D-ядро, статический 3D-профиль, SVG и
PNG backend реализованы.

Реализованный geometry-first профиль описан в `README.md`. В него входят
неизменяемые `Figure`, произвольные полигоны с отверстиями, `Feature`, индексные
mesh/triangulation, face- и vertex-valued heatmap, матричные heatmap, карты с
identity/Web Mercator-проекцией, композиция с линиями и точками, диагностика,
оси, палитры, colorbar, SVG и встроенный PNG export. Статический 3D-профиль
включает неизменяемые `Figure3D`/`ViewState3D`, поверхности и произвольные
индексные mesh, линии, точки, изолинии, прозрачные асимптотические плоскости,
перспективную и ортографическую камеры. Остальные растровые форматы и PDF из
полной спецификации оставлены точками расширения и явно отклоняются.

Реализовано для 2D: `figure.view(x: [xmin, xmax], y: [ymin, ymax])` возвращает
новую `Figure` с выбранным диапазоном данных. Обе пары необязательны; пропущенная
ось сохраняет текущий диапазон. Границы конечные и возрастающие. Это не crop
готового изображения: SVG/PNG пересчитывают координаты, оси и деления,
ограничивают геометрию областью построения и выводят только целиком помещающиеся
подписи аннотаций. Слои и исходный объект сохраняются.

macOS notebook поддерживает интерактивный вариант этого контракта при
`notebook.show(figure)`: выделение прямоугольника, ввод границ X/Y, сброс и
экспорт текущего вида. `Figure.notebook_scene()` — версионированный инертный
снимок для host-адаптера, не исполняемый код. Масштаб UI не меняет переменную
Sputnik и не сохраняется в проект; для воспроизводимости используйте `view`
в коде. Для `Figure3D.view(ViewState3D)` сохраняется отдельная семантика камеры.

`plot` — декларативный модуль построения графиков для Sputnik. Его основная цель — дать хороший результат при минимальном количестве параметров, сохранив точный контроль над компоновкой, размерами, стилем и форматом вывода.

```sputnik
plot.figure().line(data)
```

Это должно быть законченным, визуально пригодным графиком, а не заготовкой, которую обязательно нужно настраивать.

## 1. Основные принципы

1. **Минимальный вызов должен выглядеть хорошо.** Оси, отступы, деления, сетка, цвета, диапазоны и плотность элементов выбираются автоматически.
2. **API декларативный и чейнящийся.** `Figure` хранит спецификацию изображения. Методы возвращают новую спецификацию и не изменяют исходный объект.
3. **Нет глобальной текущей оси или текущей фигуры.** Все операции начинаются с конкретного значения `Figure`.
4. **Данные принимаются в естественном виде.** Поддерживаются Sputnik-массивы, пары, записи, `Map`, таблицы, tensor/numerical array объекты и явные адаптеры.
5. **Размер по умолчанию определяется средой.** Notebook-like host передаёт доступный viewport; обычный скрипт получает разумный desktop-профиль.
6. **Экран и печать — явные профили представления.** Физический размер и DPI не смешиваются с логическими экранными пикселями.
7. **Эффект не означает мутацию receiver.** `save`, `show`, `render` и `bytes` не получают суффикс `!`, поскольку не изменяют `Figure`.

## 2. Самая простая полноценная программа

```sputnik
package examples.parabola

import plot

export main

def main():
    points = (-100..100).map |n|:
        x = n / 10
        [x, x * x]

    plot.figure()
        .line(points)
        .title(tex: "y = x^2")
        .x(label: plot.tex("x"))
        .y(label: plot.tex("y"))
        .show()
```

Для notebook-like среды достаточно последнего выражения:

```sputnik
plot.figure().line([0, 1, 4, 9, 16])
```

Оно означает `x = 0..4`, `y = data` и отображается через rich-display протокол host-приложения.

## 3. Базовая модель

Публичные концепции модуля:

- `Figure` — неизменяемая спецификация всей фигуры.
- `Panel` — область с собственными координатами, осями и слоями.
- `Layer` — один визуальный слой: линия, точки, столбцы, свечи и так далее.
- `Grid` — размещение панелей.
- `DataView` — унифицированное представление массива, таблицы или tensor-объекта.
- `Theme` — типографика, фон, оси, сетка и общие визуальные правила.
- `Palette` — дискретная или непрерывная шкала цветов.
- `RichText` — обычный текст и TeX-фрагменты.
- `Rendered` — готовое представление и метаданные рендера.

Все конфигурирующие методы `Figure`, `Panel` и `Layer` функциональны:

```sputnik
base = plot.figure().theme(:sputnik)
small = base.screen(width: 800, height: 500)
print = base.print(width: 160, height: 100, unit: :mm, dpi: 300)
```

`base` после этих вызовов не изменяется.

## 4. Создание и размер фигуры

```sputnik
plot.figure(
    size: :auto,
    theme: :sputnik,
    palette: :auto,
    background: :auto
) -> Figure
```

Удобные методы размера:

```sputnik
figure.auto_size()
figure.viewport()
figure.screen(width: 1280, height: 720)
figure.screen(width: 1280, height: 720, density: 2)
figure.print(width: 160, height: 100, unit: :mm, dpi: 300)
figure.print(width: 6.5, height: 4, unit: :in, dpi: 300)
figure.preset(:notebook)
figure.preset(:slide_16x9)
figure.preset(:paper_half)
```

### 4.1. Семантика `:auto`

Физический размер разрешается только во время показа или рендера. Приоритет источников:

1. Явно заданный `screen`, `print` или `preset`.
2. Доступная область, переданная notebook/app host.
3. Параметры дисплея среды, если они доступны без взаимодействия с пользователем.
4. Desktop-дефолт для обычного скрипта.

Для notebook/app фигура вписывается в ширину контентной области, сохраняет разумное соотношение сторон и учитывает device pixel ratio. Host может передать минимальный и максимальный допустимый размер.

Если viewport неизвестен:

- интерактивный просмотр: `1120 × 700` логических пикселей;
- растровый export без явного размера: `1440 × 900` физических пикселей;
- векторный export сохраняет логический размер и не зависит от DPI, кроме растеризованных слоёв.

Эти значения являются профилями темы и могут эволюционировать без изменения семантики API.

## 5. Автоматически хороший результат

Любой основной метод графика обязан выдавать пригодный результат без последующей настройки:

```sputnik
plot.figure().line(data)
plot.figure().points(data)
plot.figure().bar(data)
plot.figure().hist(data)
plot.figure().ohlc(data)
plot.figure().heatmap(data)
```

Общие автоматические правила:

- контрастная, colorblind-safe палитра;
- читаемые поля вокруг области построения;
- не более разумного числа делений осей;
- форматирование чисел, дат и времени по типу данных и диапазону;
- небольшое расширение непрерывного диапазона, чтобы данные не прилипали к рамке;
- легенда появляется только при наличии именованных серий или визуального encoding;
- пропущенные значения образуют разрыв линии и исключаются из агрегаций;
- порядок категорий сохраняет порядок данных, если пользователь не задал сортировку;
- плотность данных адаптируется к числу экранных пикселей без изменения исходного набора;
- применённое упрощение и все неоднозначные inference-решения попадают в метаданные рендера.

Частные правила:

- `line`: хорошо различимая толщина; markers появляются у коротких рядов и скрываются у плотных.
- `points`: автоматически подбираются размер и прозрачность с учётом количества точек.
- `bar`: числовая ось по умолчанию включает ноль; ширина и интервалы вычисляются автоматически.
- `hist`: `bins: :auto` выбирает устойчивое число интервалов по размеру и распределению выборки.
- `ohlc`: рост и падение различаются не только цветом, но также яркостью и контуром.
- `heatmap`: автоматически добавляется непрерывная цветовая шкала и подходящая colorbar.

Автоматическая оптимизация влияет только на представление. Например, экранная линия может использовать pixel-aware min/max sampling, но domain, tooltip и export с достаточным разрешением опираются на исходные данные.

## 6. Источники данных

### 6.1. Нативные массивы

Один числовой массив трактуется как значения `y`:

```sputnik
plot.figure().line([1, 4, 9, 16])
plot.figure().hist([1.2, 1.7, 2.1, 2.2])
```

Массив пар трактуется как `(x, y)`:

```sputnik
plot.figure().line([[0, 0], [1, 1], [2, 4], [3, 9]])
```

Можно передать координаты отдельно:

```sputnik
plot.figure().line(x: xs, y: ys)
plot.figure().points(x: xs, y: ys, color: groups)
```

Длины параллельных массивов должны совпадать. Несовпадение является ошибкой валидации, а не молчаливым усечением.

### 6.2. Записи, `Map` и табличные строки

```sputnik
plot.figure().line(rows, x: :date, y: :price)
plot.figure().points(rows, x: :height, y: :weight, color: :group)
plot.figure().line(rows, x: 0, y: 1)
```

`Selector` может быть:

- `Symbol` — именованное поле, свойство или map-key;
- `Str` — точное строковое имя/key;
- `Int` — индекс массива, tuple или tensor-столбца;
- функция — вычисляемое значение строки.

Именованный selector не зависит от того, хранится строка как record, объект или `Map`, если источник однозначно предоставляет такое поле.

### 6.3. Inference для основных форм

`line(data)` использует следующие правила по порядку:

| Форма данных | Интерпретация |
|---|---|
| `Array<Number>` | `x = index`, `y = value` |
| `Array<[x, y]>` | `x = item[0]`, `y = item[1]` |
| строки с `x`, `y` | `x = :x`, `y = :y` |
| строки с `time/date` и `value` | время по горизонтали, value по вертикали |

`ohlc(data)` ищет:

| Канал | Имена | Индексный fallback |
|---|---|---:|
| x | `time`, `date`, `datetime`, `timestamp` | 0 |
| open | `open`, `o` | 1 |
| high | `high`, `h` | 2 |
| low | `low`, `l` | 3 |
| close | `close`, `c` | 4 |
| volume | `volume`, `vol` | 5, необязателен |

Явно заданные selectors всегда имеют приоритет над inference.

## 7. Tensor и numerical array совместимость

Сторонняя числовая библиотека не обязана зависеть от `plot`. Объект может быть распознан структурно по стандартным именам.

### 7.1. Порядок классификации

1. Явный `plot_data()` или `to_plot_data()`.
2. Table-like протокол: `columns`/`column`/`schema`.
3. Tensor-like протокол: `shape` или эквивалент плюс числовой индексный доступ.
4. Нативные Sputnik collections, tuples, records и `Map`.

Table-like проверяется раньше tensor-like, потому что dataframe часто тоже имеет `shape`.

### 7.2. Минимальный tensor-like протокол

Объект считается кандидатом в numerical array, если он предоставляет:

- `shape` как property или метод без аргументов; также распознаются `dims` и `dimensions`;
- результат формы — конечный массив неотрицательных целых размерностей;
- чтение элемента через `get(...)`, `at(...)` или `[]`;
- числовой `dtype`/`element_type` либо числовые значения при безопасной пробе.

Дополнительно могут использоваться:

- `ndim` или `rank`;
- `dtype` или `element_type`;
- `strides` и `order`;
- `device` для диагностики host/GPU размещения.

Один лишь метод `size` не делает объект tensor-like: такое имя слишком часто встречается у обычных коллекций.

### 7.3. Интерпретация размерностей

| Shape | `line` | `points` | `heatmap` |
|---|---|---|---|
| `[n]` | index/value | index/value | ошибка без явного преобразования |
| `[n, 2]` | столбцы x/y | столбцы x/y | матрица `n × 2` |
| `[n, m]`, `m != 2` | каждый столбец — серия по индексу строки | нужны selectors | матрица значений |
| rank > 2 | нужен явный slice/reduce | нужен явный slice/reduce | нужен явный slice/reduce |

Явная интерпретация снимает неоднозначность:

```sputnik
plot.figure().line(tensor, as: :values)
plot.figure().line(tensor, as: :pairs)
plot.figure().line(tensor, as: :columns)
plot.figure().points(tensor, x: 0, y: 1, color: 2)
plot.figure().heatmap(tensor, as: :matrix)
```

Если форма `[n, 2]` автоматически принята за пары, решение записывается в `Rendered.diagnostics`. В stdout ничего не печатается.

### 7.4. Явный адаптер

Библиотека может предоставить `plot_data() -> DataView`. Концептуально доступны два конструктора:

```sputnik
plot.DataView.tensor(
    source,
    shape: source.shape(),
    dtype: source.dtype(),
    get: source.method(:get)
)

plot.DataView.buffer(
    source.buffer(),
    shape: source.shape(),
    dtype: source.dtype(),
    strides: source.strides(),
    order: :row_major
)
```

`DataView.buffer` позволяет backend использовать contiguous memory без обязательного копирования. Backend обязан учитывать lifetime источника, `dtype`, strides и endianness.

По умолчанию `DataView` заимствует источник, а значения читаются во время рендера. Для воспроизводимого снимка:

```sputnik
frozen = figure.snapshot_data()
```

Это возвращает новую `Figure` с собственным snapshot и не изменяет исходную.

GPU tensor без host-readable доступа должен предоставить адаптер, который явно выполняет или разрешает transfer. Неожиданное скрытое копирование большого device-buffer не выполняется.

## 8. Типы графиков v1

Сокращённые сигнатуры; `null` означает «вывести или определить автоматически».

```sputnik
Figure.line(data = null, x: null, y: null, color: null, group: null) -> Figure
Figure.points(data = null, x: null, y: null, color: null, size: null, group: null) -> Figure
Figure.bar(data = null, x: null, y: null, fill: null, group: null) -> Figure
Figure.area(data = null, x: null, y: null, fill: null, group: null) -> Figure
Figure.hist(data, value: null, bins: :auto, fill: null) -> Figure
Figure.density(data, value: null, fill: null) -> Figure
Figure.ohlc(data, x: null, open: null, high: null, low: null, close: null, volume: null) -> Figure
Figure.heatmap(data, x: null, y: null, value: null, cell: :square, bins: :auto, reduce: :mean) -> Figure
Figure.hexbin(data, x: null, y: null, value: null, bins: :auto, reduce: :count) -> Figure
```

Каждый метод также принимает block для настройки созданного слоя:

```sputnik
plot.figure()
    .line(points) |line|:
        line.color(:sputnik).width(2).label("series A")
```

Block получает неизменяемый `Layer`; его чейнинг формирует итоговую спецификацию слоя.

## 9. Heatmap: квадратные и hex-ячейки

Матрица чисел непосредственно создаёт квадратную heatmap:

```sputnik
plot.figure().heatmap(matrix)
```

Строковые данные могут задавать координаты и значение:

```sputnik
plot.figure().heatmap(samples, x: :x, y: :y, value: :temperature)
plot.figure().heatmap(samples, x: 0, y: 1, value: 2, cell: :square)
```

Hexagonal binning задаётся через `cell: :hex`:

```sputnik
plot.figure().heatmap(
    samples,
    x: :x,
    y: :y,
    value: :temperature,
    cell: :hex,
    reduce: :mean
)
```

Короткая форма для подсчёта плотности:

```sputnik
plot.figure().hexbin(samples, x: :x, y: :y)
```

Семантика:

- `heatmap(matrix)` — строка и столбец являются координатами, элемент является fill-value;
- `cell: :square` — прямоугольные bins или явно заданные ячейки;
- `cell: :hex` — точки в декартовых координатах агрегируются по шестиугольным bins;
- `hexbin(...)` эквивалентен `heatmap(..., cell: :hex, reduce: :count)`;
- допустимые reducers v1: `:count`, `:sum`, `:mean`, `:min`, `:max`, `:median`;
- `bins: :auto` зависит от viewport и числа наблюдений; явное число или пара фиксируют разрешение.

## 10. Grid и панели

Без grid все слои добавляются в единственную корневую панель:

```sputnik
plot.figure()
    .line(actual)
    .line(predicted)
```

Grid с автоматическим размещением заполняется слева направо, сверху вниз:

```sputnik
plot.figure()
    .grid(cols: 2)
    .line(series)
    .hist(values)
    .ohlc(candles)
```

Количество строк растёт по мере необходимости. Каждый основной plot-вызов без выбранной панели занимает следующую свободную ячейку.

Явное размещение:

```sputnik
plot.figure()
    .grid(rows: 2, cols: 2)
    .at(0, 0)
    .line(actual)
    .line(predicted)
    .at(0, 1)
    .hist(errors)
    .at(1, 0, span_cols: 2)
    .ohlc(candles)
```

`at` возвращает новую фигуру с выбранной панелью. Выбор остаётся активным до следующего `at` или `next`, поэтому несколько слоёв можно наложить друг на друга.

```sputnik
figure.next().points(other_data)
```

Именованные области:

```sputnik
plot.figure()
    .grid(areas: [
        [:main, :side],
        [:main, :side]
    ])
    .at(:main).ohlc(candles)
    .at(:side).hist(volume)
```

Размеры tracks при необходимости задаются явно:

```sputnik
.grid(cols: [3.fr, 1.fr], rows: [:auto, 220.px], gap: 12.px)
```

Общие оси задаются на grid:

```sputnik
.grid(rows: 2, cols: 1, share_x: true)
```

## 11. Заголовки, подписи и TeX

Plain text никогда не интерпретируется как TeX неявно.

```sputnik
figure.title("Parabola")
figure.title(tex: "y = x^2")
figure.subtitle("Experiment 7")
figure.caption("Source: simulation")
```

Тот же `RichText` используется для подписей осей, легенд и annotations:

```sputnik
figure.x(label: plot.tex("x"))
figure.y(label: plot.tex("f(x) = x^2"))
```

Реализованные служебные линии и точечные annotations:

```sputnik
figure.vline(x, label: "asymptote", dash: [7, 5])
figure.hline(y, label: "threshold")
figure.guide([x1, y1], [x2, y2], label: "trend", label_at: :middle)
figure.annotate([x, y], "peak", dx: 8, dy: -12)
```

`vline` и `hline` растягиваются по итоговому domain соответствующей оси и не
расширяют перпендикулярную ось. `guide` задаёт произвольный отрезок в data
coordinates. `label_at` принимает `:start`, `:middle` или `:end`; `dx`/`dy`
задаются в экранных пикселях. Пунктир `dash` — массив чередующихся длин штриха
и пробела. Одинаковая семантика поддерживается SVG и PNG backend.

Смешанный текст:

```sputnik
figure.title(plot.text("Parabola: ").tex("y = x^2"))
```

`plot.tex(source)` создаёт структурированный math-фрагмент. Минимальный TeX-профиль v1 поддерживает степени, индексы, греческие символы, дроби, корни, суммы и интегралы. Результат должен одинаково компоноваться в растровом и векторном backend.

Ошибка разбора TeX является диагностикой/ошибкой валидации. Сырой TeX не должен молча появляться в готовом изображении.

## 12. Оси, шкалы и легенды

```sputnik
figure.x(label: "Date", scale: :time)
figure.y(label: "Price", scale: :linear)
figure.y(scale: :log, domain: [1, 10_000])
figure.color(label: "Group", palette: :sputnik)
figure.fill(label: "Temperature", palette: :viridis)
figure.legend(position: :right)
```

Базовые шкалы v1:

- `:linear`, `:log`, `:symlog`, `:sqrt`;
- `:time`, `:utc`;
- `:category`, `:ordinal`;
- `:auto`.

Пользовательская настройка может быть общей для фигуры или локальной для панели, выбранной через `at`.

## 13. Темы и палитры

```sputnik
figure.theme(:sputnik)
figure.theme(:notebook)
figure.theme(:journal)

figure.palette(:sputnik)
figure.palette(:okabe_ito)
figure.palette(:viridis)
figure.palette(:magma)
figure.palette(:balance)
```

Категории палитр:

- categorical: `:sputnik`, `:okabe_ito`;
- sequential: `:sunrise`, `:viridis`, `:magma`;
- diverging: `:balance`;
- semantic OHLC: `:market` с обязательным различием не только по hue.

`:auto` выбирает категорию палитры по encoding: discrete, sequential или diverging. Все встроенные темы обязаны сохранять контраст на светлом и тёмном фоне, оставаться различимыми при распространённых формах цветовой слепоты и иметь приемлемое grayscale-представление.

Пользовательские палитры:

```sputnik
figure.palette(plot.palette(["#16697a", "#ffa62b", "#489fb5"]))
```

## 14. Отображение, render и сохранение

```sputnik
figure.show() -> Null
figure.render(format: :png) -> Rendered
figure.bytes(format: :png) -> Bytes
figure.text(format: :svg) -> Str
figure.save("parabola.png") -> Null
figure.save("parabola", format: :png) -> Null
```

`bytes` всегда требует явный формат. Это и есть API получения изображения как бинарной строки:

```sputnik
png: Bytes = figure.bytes(format: :png)
webp: Bytes = figure.bytes(format: :webp)
pdf: Bytes = figure.bytes(format: :pdf)
```

`text` предназначен только для текстовых форматов, прежде всего SVG. Вызов `text(format: :png)` является ошибкой.

`save(path)` определяет формат по расширению. При наличии `format`:

- расширение может отсутствовать;
- если расширение конфликтует с `format`, возвращается ошибка вместо молчаливого выбора.

Целевые форматы v1:

- `:png` — lossless raster;
- `:webp` — compact raster;
- `:svg` — векторный web/document формат;
- `:pdf` — печать и публикации.

В текущем реализованном профиле `Figure` поддерживает SVG и PNG, а `Figure3D`
— PNG. WebP и PDF остаются точками расширения и сейчас отклоняются с
`UnsupportedFormatError`.

`Rendered` предоставляет:

```sputnik
rendered.format
rendered.mime
rendered.bytes
rendered.width
rendered.height
rendered.diagnostics
rendered.metadata
```

`show` использует rich-display host, встроенное окно или системный viewer. В headless-среде возвращается понятная `PlotDisplayUnavailable`, предлагающая `save` или `bytes`.

Ни один из этих методов не изменяет `Figure`, поэтому суффикс `!` не используется.

## 15. Диагностика и ошибки

```sputnik
figure.validate() -> Array<plot.Diagnostic>
```

Ошибками считаются:

- несовпадающие длины x/y/encoding arrays;
- отсутствующий selector;
- несовместимый dtype;
- неверная или изменившаяся shape;
- rank > 2 без явного slice/reduce;
- конфликт output format и расширения;
- невалидный TeX;
- отрицательный физический размер или DPI.

Предупреждениями считаются неоднозначные, но безопасные решения inference и визуальные упрощения больших данных. Они доступны через `validate` и `Rendered.diagnostics`, но не засоряют stdout.

## 16. Итоговая семантика коротких выражений

```sputnik
plot.figure().line(data)
```

- создаёт одну панель;
- распознаёт нативный массив, строки, таблицу или tensor-like объект;
- выводит x/y либо использует индекс;
- выбирает оси, domain, ticks, сетку, цвет и размер;
- при показе подстраивается под viewport;
- в notebook отображается как последнее значение.

```sputnik
plot.figure().grid(cols: 2).line(a).hist(b).ohlc(c)
```

- создаёт auto-growing grid;
- помещает три законченных графика по ячейкам row-major;
- согласует тему и палитры всей фигуры;
- вычисляет итоговый размер при показе или render.

```sputnik
plot.figure().heatmap(matrix)
```

- для rank-2 numerical array строит квадратную heatmap;
- использует индексы строк/столбцов как координаты;
- подбирает sequential palette и показывает colorbar.

Это ядро API v1: короткий путь остаётся действительно коротким, а явная настройка наращивается тем же чейнингом без перехода к другой модели программирования.

## 17. Реализованный статический 3D-профиль

3D-фигура отделена от 2D-фигуры типом, чтобы не размывать семантику координат,
камеры и backend:

```sputnik
figure = plot.figure3d(width: 1120, height: 760)
  .surface(z, x: xs, y: ys, preset: :surface_mesh)
  .camera(preset: :isometric)
  .axes(x_label: "X", y_label: "Y", z_label: "Z")
  .title("Surface")

figure.render(format: :png) -> Rendered
figure.bytes(format: :png) -> Bytes
figure.save("surface.png") -> Null
```

### 17.1. Геометрические слои

```sputnik
figure.surface(z, x: xs, y: ys,
  preset: :surface,
  palette: :viridis,
  opacity: 1,
  edge_color: "#334155",
  edge_width: 0.8,
  levels: 10,
  contour_color: "#ffffff",
  contour_width: 1.5,
  shading: :smooth)

figure.mesh3d(vertices, faces,
  values: null,
  value_mode: :vertex,
  preset: :surface)

figure.line3d(points, stroke: "#d97706", stroke_width: 2.5)
figure.points3d(points, fill: "#b91c1c", radius: 4)
```

`surface` принимает прямоугольную матрицу `z`; `x` и `y` могут быть опущены,
тогда используются индексы. `mesh3d` принимает произвольные грани и
триангулирует каждую грань веером. Значения цвета относятся к вершинам или
граням согласно `value_mode`.

Пресеты представления:

- `:surface` — заполненная поверхность;
- `:surface_mesh` — поверхность с рёбрами;
- `:wireframe` и alias `:mesh` — только рёбра;
- `:contours` — только изолинии;
- `:surface_contours` — поверхность с изолиниями;
- `:points` — вершины как точки.

### 17.2. Асимптотические и технические плоскости

```sputnik
figure
  .asymptote_plane(:x, 0,
    label: "x = 0",
    fill: "#ef4444",
    stroke: "#991b1b",
    stroke_width: 1.2,
    opacity: 0.18)
  .asymptote_plane(:z, 0, label: "z = 0", opacity: 0.16)
```

Ось — `:x`, `:y` или `:z`. Размер плоскости разрешается по итоговым bounds
всей сцены. Значение прозрачности по умолчанию — `0.18`; backend сначала
рендерит непрозрачную геометрию с записью depth, затем смешивает прозрачные
плоскости с учётом уже заполненного depth buffer.

### 17.3. Камера и неизменяемый view state

```sputnik
view = plot.view3d(:three_quarter)
view = view.rotated(azimuth: 15, elevation: -5)
view = view.zoomed(1.2)
view = view.targeted([0, 0, 1])

figure = figure.view(view)
figure = figure.camera(
  azimuth: -45,
  elevation: 28,
  roll: 0,
  distance: :auto,
  target: :auto,
  projection: :perspective,
  fov: 42,
  ortho_scale: :auto)
```

Пресеты камеры: `:isometric`, `:three_quarter`, `:presentation`, `:top`,
`:front`, `:back`, `:left`, `:right`. `ViewState3D` входит в спецификацию
`Figure3D`, не изменяется на месте и не зависит от конкретного renderer.

`figure.scene()` возвращает backend-neutral `Scene3D` с разрешённой камерой,
bounds, командами и метаданными. Это заранее закладывает границу будущего
интерактивного адаптера: манипулятор или клавиатура должны строить новый
`ViewState3D`, а host — запрашивать следующий кадр. Notebook-адаптер и event
loop в текущую реализацию намеренно не входят.

### 17.4. Особенности PNG renderer

Нативный 3D renderer использует правую систему координат с `z` вверх,
перспективную или ортографическую проекцию, z-buffer, барицентрическую
растеризацию треугольников, flat/smooth/unlit shading, отдельный прозрачный
проход, depth-aware рёбра, линии, точки, подписи и изолинии. Он не зависит от
GPU API или сторонней графической библиотеки, поэтому PNG доступен «из
коробки» в native-сборке пакета.
