class_name CoinIcon
extends Control
## Drawn gold coin (rim, face gradient, embossed ring and a sparkle) for the money
## counter and the coins that fly into it. `spin()` flips it once on its vertical axis.

@export var radius := 24.0:
	set(value):
		radius = value
		custom_minimum_size = Vector2.ONE * (radius * 2.0 + 6.0)
		queue_redraw()

var _spin := 1.0
var _spin_t := 1.0
var _spin_duration := 0.45


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	custom_minimum_size = Vector2.ONE * (radius * 2.0 + 6.0)


## One full flip over `duration` seconds (the coin narrows, shows its edge, comes back).
func spin(duration := 0.45) -> void:
	_spin_t = 0.0
	set_process(true)
	_spin_duration = duration


func _ready() -> void:
	set_process(_spin_t < 1.0)


func _process(delta: float) -> void:
	_spin_t = minf(1.0, _spin_t + delta / _spin_duration)
	_spin = cos(_spin_t * TAU)
	queue_redraw()
	if _spin_t >= 1.0:
		_spin = 1.0
		set_process(false)


func _draw() -> void:
	var c := size * 0.5
	var r := radius
	var squash := maxf(0.08, absf(_spin))
	var back := _spin < 0.0
	draw_set_transform(c, 0.0, Vector2(squash, 1.0))
	# Ink outline + edge thickness (darker lip under the face).
	draw_circle(Vector2(0, 2.5), r + 3.0, UITheme.INK, true, -1.0, true)
	draw_circle(Vector2.ZERO, r + 3.0, UITheme.INK, true, -1.0, true)
	draw_circle(Vector2(0, 2.0), r, Color("#a8700c"), true, -1.0, true)
	var rim := UITheme.ACCENT_DARK if not back else Color("#b47a10")
	draw_circle(Vector2.ZERO, r, rim, true, -1.0, true)
	# Face: warm gradient faked with offset discs (lighter towards the top-left).
	var face := r * 0.8
	draw_circle(Vector2.ZERO, face, UITheme.COIN.darkened(0.08), true, -1.0, true)
	draw_circle(Vector2(-face * 0.08, -face * 0.1), face * 0.9, UITheme.COIN, true, -1.0, true)
	draw_circle(Vector2(-face * 0.22, -face * 0.28), face * 0.5, UITheme.COIN.lightened(0.18), true, -1.0, true)
	# Embossed inner ring and a little anvil-ish bar mark.
	draw_arc(Vector2.ZERO, face * 0.72, 0.0, TAU, 40, Color(UITheme.ACCENT_DARK, 0.85), maxf(1.5, r * 0.08), true)
	var bar := Rect2(Vector2(-face * 0.36, -face * 0.12), Vector2(face * 0.72, face * 0.24))
	draw_rect(bar, Color(UITheme.ACCENT_DARK, 0.9), true)
	draw_rect(Rect2(Vector2(-face * 0.14, bar.end.y), Vector2(face * 0.28, face * 0.26)), Color(UITheme.ACCENT_DARK, 0.9), true)
	# Rim highlight + sparkle.
	draw_arc(Vector2.ZERO, r - 1.5, PI * 1.05, PI * 1.55, 16, Color(1, 1, 1, 0.55), maxf(1.5, r * 0.09), true)
	draw_set_transform(Vector2.ZERO)
	if squash > 0.6:
		_sparkle(c + Vector2(r * 0.42, -r * 0.5) * Vector2(squash, 1.0), r * 0.32)


func _sparkle(at: Vector2, s: float) -> void:
	var pts := PackedVector2Array()
	for i in 8:
		var a := i * TAU / 8.0
		var l := s if i % 2 == 0 else s * 0.28
		pts.append(at + Vector2(cos(a), sin(a)) * l)
	draw_colored_polygon(pts, Color(1, 1, 0.95, 0.95))
