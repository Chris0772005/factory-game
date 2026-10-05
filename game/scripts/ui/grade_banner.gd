class_name GradeBanner
extends Control
## Big celebratory ribbon for grades and reveals ("MAKELLOS!", "BRONZEFREUND!"):
## slams in (scale 0.3 → 1.12 → 1, wobble), bursts sparkles, a shine sweeps across,
## holds, then lifts away. Driven by HUD.banner(); one banner object per call.

signal finished

const HOLD := 1.5

var text := ""
var subtitle := ""
var color := UITheme.ACCENT

var _label: Label
var _sub: PanelContainer
var _half := Vector2(300, 62)
var _shine := -1.0
var _sparks: Array[Dictionary] = []
var _age := 0.0
var _exit: Tween


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_label = Label.new()
	_label.text = text
	_label.add_theme_font_override("font", UITheme.display_font())
	_label.add_theme_font_size_override("font_size", 92)
	_label.add_theme_color_override("font_color", UITheme.PAPER)
	_label.add_theme_color_override("font_outline_color", UITheme.INK)
	_label.add_theme_constant_override("outline_size", 18)
	_label.add_theme_color_override("font_shadow_color", Color(color.darkened(0.55), 0.9))
	_label.add_theme_constant_override("shadow_offset_x", 0)
	_label.add_theme_constant_override("shadow_offset_y", 7)
	_label.add_theme_constant_override("shadow_outline_size", 18)
	_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	add_child(_label)
	var text_w := UITheme.display_font().get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, 92).x
	_half = Vector2(maxf(240.0, text_w * 0.5 + 70.0), 64.0)
	if not subtitle.is_empty():
		_sub = PanelContainer.new()
		_sub.theme_type_variation = &"HudPill"
		var sub_label := Label.new()
		sub_label.text = subtitle
		sub_label.add_theme_font_override("font", UITheme.font(700))
		sub_label.add_theme_font_size_override("font_size", 30)
		sub_label.add_theme_constant_override("outline_size", 0)
		_sub.add_child(sub_label)
		add_child(_sub)
	size = Vector2(_half.x * 2.0 + 260.0, 360.0)
	pivot_offset = size * 0.5
	_label.size = Vector2(size.x, 140)
	_label.position = Vector2(0, size.y * 0.5 - 74.0)
	if _sub:
		_sub.reset_size()
		_sub.position = Vector2((size.x - _sub.size.x) * 0.5, size.y * 0.5 + _half.y + 30.0)
	_play()


func _play() -> void:
	scale = Vector2.ONE * 0.3
	rotation = deg_to_rad(-9.0)
	modulate.a = 0.0
	var intro := create_tween().set_parallel()
	intro.tween_property(self, "modulate:a", 1.0, 0.08)
	intro.tween_property(self, "scale", Vector2.ONE * 1.12, 0.18).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	intro.tween_property(self, "rotation", deg_to_rad(2.0), 0.18).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	intro.chain().tween_callback(_burst)
	intro.chain().tween_property(self, "scale", Vector2.ONE, 0.4).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
	intro.tween_property(self, "rotation", 0.0, 0.45).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
	var shine := create_tween()
	shine.tween_property(self, "_shine", 1.0, 0.55).from(0.0).set_delay(0.22).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN_OUT)
	_leave(HOLD, 0.28)
	Sfx.play_ui(&"pop", -4.0)


## Dismisses early (a newer banner is waiting), after at least 0.6 s on screen.
func hurry() -> void:
	_leave(maxf(0.0, 0.6 - _age), 0.18)


func _leave(delay: float, time: float) -> void:
	if _exit and _exit.is_valid():
		_exit.kill()
	_exit = create_tween().set_parallel()
	_exit.tween_property(self, "position:y", -46.0, time).as_relative().set_delay(delay) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
	_exit.tween_property(self, "modulate:a", 0.0, time * 0.85).set_delay(delay + time * 0.15)
	_exit.chain().tween_callback(func() -> void:
		finished.emit()
		queue_free()
	)


func _burst() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(text)
	var palette := [UITheme.PAPER, color.lightened(0.3), UITheme.ACCENT, UITheme.MOLTEN_HOT]
	for i in 28:
		var a := rng.randf() * TAU
		var speed := rng.randf_range(260.0, 620.0)
		_sparks.append({
			pos = size * 0.5 + Vector2(cos(a) * _half.x * 0.8, sin(a) * _half.y * 0.6),
			vel = Vector2(cos(a), sin(a) * 0.7 - 0.35) * speed,
			life = rng.randf_range(0.5, 0.95), age = 0.0, size = rng.randf_range(10.0, 22.0),
			spin = rng.randf_range(-6.0, 6.0), color = palette[i % palette.size()],
		})


func _process(delta: float) -> void:
	_age += delta
	for i in range(_sparks.size() - 1, -1, -1):
		var s: Dictionary = _sparks[i]
		s.age += delta
		if s.age >= s.life:
			_sparks.remove_at(i)
			continue
		s.vel *= 1.0 - minf(1.0, 3.2 * delta)
		s.vel.y += 520.0 * delta
		s.pos += s.vel * delta
	queue_redraw()


func _draw() -> void:
	var c := size * 0.5
	var hw := _half.x
	var hh := _half.y
	var dark := color.darkened(0.38)
	# Folded tails behind the band, with their notched ends.
	for side in [-1.0, 1.0]:
		var x0: float = side * (hw - 30.0)
		var x1: float = side * (hw + 92.0)
		var tail := PackedVector2Array([
			c + Vector2(x0, -hh + 34.0), c + Vector2(x1, -hh + 34.0), c + Vector2(x1 - side * 34.0, 34.0),
			c + Vector2(x1, hh + 34.0), c + Vector2(x0, hh + 34.0)])
		_poly_outlined(tail, dark, 5.0, Vector2(0, 8))
		var fold := PackedVector2Array([c + Vector2(side * (hw - 30.0), hh), c + Vector2(side * hw, hh), c + Vector2(side * (hw - 30.0), hh + 34.0)])
		draw_colored_polygon(fold, dark.darkened(0.4))
	# Main band: shadow, ink rim, colour fill, top highlight and bottom shade.
	var band := Rect2(c - _half, _half * 2.0)
	var drop := band.grow(5.0)
	_rounded(Rect2(drop.position + Vector2(0, 8), drop.size), 18, Color(0, 0, 0, 0.28))
	_rounded(band.grow(5.0), 18, UITheme.INK)
	_rounded(band, 14, color)
	_rounded(Rect2(band.position + Vector2(10, 8), Vector2(band.size.x - 20, band.size.y * 0.3)), 10, Color(color.lightened(0.35), 0.6))
	_rounded(Rect2(band.position + Vector2(0, band.size.y * 0.78), Vector2(band.size.x, band.size.y * 0.22)), 12, Color(dark, 0.45))
	# Shine sweep, clipped to the band.
	if _shine > 0.0 and _shine < 1.0:
		var x := lerpf(band.position.x - 160.0, band.end.x + 60.0, _shine)
		var shine := PackedVector2Array([Vector2(x, band.position.y), Vector2(x + 70.0, band.position.y),
			Vector2(x + 10.0, band.end.y), Vector2(x - 60.0, band.end.y)])
		for piece in Geometry2D.intersect_polygons(shine, _rect_poly(band.grow(-4.0))):
			draw_colored_polygon(piece, Color(1, 1, 1, 0.38))
	for s in _sparks:
		var k: float = 1.0 - s.age / s.life
		_star(s.pos, s.size * (0.4 + 0.6 * k), s.age * s.spin, Color(s.color, minf(1.0, k * 1.6)))


func _poly_outlined(pts: PackedVector2Array, fill: Color, width: float, shadow: Vector2) -> void:
	var sh := PackedVector2Array()
	for p in pts:
		sh.append(p + shadow)
	draw_colored_polygon(sh, Color(0, 0, 0, 0.25))
	draw_colored_polygon(pts, fill)
	var loop := pts.duplicate()
	loop.append(pts[0])
	draw_polyline(loop, UITheme.INK, width, true)


func _rounded(r: Rect2, radius: int, col: Color) -> void:
	var sb := StyleBoxFlat.new()
	sb.bg_color = col
	sb.set_corner_radius_all(radius)
	sb.anti_aliasing_size = 1.2
	draw_style_box(sb, r)


static func _rect_poly(r: Rect2) -> PackedVector2Array:
	return PackedVector2Array([r.position, Vector2(r.end.x, r.position.y), r.end, Vector2(r.position.x, r.end.y)])


func _star(at: Vector2, s: float, rot: float, col: Color) -> void:
	var pts := PackedVector2Array()
	for i in 8:
		var a := rot + i * TAU / 8.0
		var l := s if i % 2 == 0 else s * 0.36
		pts.append(at + Vector2(cos(a), sin(a)) * l)
	draw_colored_polygon(pts, col)
