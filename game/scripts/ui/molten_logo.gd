class_name MoltenLogo
extends Control
## "MOLTEN MATES" title treatment (Art Bible 12): stacked Lilita One lettering with a
## molten-metal gradient (#FFD27A → #FF6A1A), a thick ink outline, a dark extruded
## drop, a warm pulsing glow and rising embers. A shine sweeps across every few seconds
## and the letters wobble like liquid. `play_intro()` drops the two words in.

const SHADER := preload("res://assets/ui/shaders/molten_text.gdshader")
const LINES: Array[String] = ["MOLTEN", "MATES"]
const FONT_SIZE := 168
const OUTLINE := 22
const LINE_STEP := 146.0
## The second line sits a little to the right, the whole logo tilts slightly.
const INDENT := 92.0
const TILT := -3.5

var _labels: Array[Label] = []
var _glow: TextureRect
var _embers: CPUParticles2D
var _t := 0.0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var font := UITheme.display_font()
	var width := 0.0
	for i in LINES.size():
		width = maxf(width, font.get_string_size(LINES[i], HORIZONTAL_ALIGNMENT_LEFT, -1, FONT_SIZE).x + INDENT * i)
	custom_minimum_size = Vector2(width + OUTLINE * 2.0, LINE_STEP * (LINES.size() - 1) + FONT_SIZE * 1.15)
	size = custom_minimum_size
	pivot_offset = size * 0.5
	rotation = deg_to_rad(TILT)

	_glow = TextureRect.new()
	var grad := Gradient.new()
	grad.offsets = PackedFloat32Array([0.0, 0.45, 1.0])
	grad.colors = PackedColorArray([Color(UITheme.MOLTEN, 0.62), Color(UITheme.MOLTEN_DEEP, 0.3), Color(UITheme.MOLTEN_DEEP, 0.0)])
	var tex := GradientTexture2D.new()
	tex.gradient = grad
	tex.fill = GradientTexture2D.FILL_RADIAL
	tex.fill_from = Vector2(0.5, 0.5)
	tex.fill_to = Vector2(1.0, 0.5)
	tex.width = 256
	tex.height = 128
	_glow.texture = tex
	_glow.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_glow.stretch_mode = TextureRect.STRETCH_SCALE
	_glow.size = size * Vector2(1.5, 1.7)
	_glow.position = (size - _glow.size) * 0.5
	_glow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var add := CanvasItemMaterial.new()
	add.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	_glow.material = add
	add_child(_glow)

	_embers = CPUParticles2D.new()
	_embers.amount = 34
	_embers.lifetime = 2.6
	_embers.preprocess = 2.6
	_embers.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	_embers.emission_rect_extents = Vector2(size.x * 0.45, 20.0)
	_embers.position = Vector2(size.x * 0.5, size.y * 0.9)
	_embers.direction = Vector2(0.15, -1.0)
	_embers.spread = 18.0
	_embers.gravity = Vector2(0, -12.0)
	_embers.initial_velocity_min = 30.0
	_embers.initial_velocity_max = 75.0
	_embers.scale_amount_min = 3.0
	_embers.scale_amount_max = 6.5
	var ramp := Gradient.new()
	ramp.offsets = PackedFloat32Array([0.0, 0.15, 0.6, 1.0])
	ramp.colors = PackedColorArray([Color(UITheme.MOLTEN_HOT, 0.0), Color(UITheme.MOLTEN_HOT, 0.95),
		Color(UITheme.MOLTEN, 0.7), Color(UITheme.MOLTEN_DEEP, 0.0)])
	_embers.color_ramp = ramp
	var ember_mat := CanvasItemMaterial.new()
	ember_mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	_embers.material = ember_mat
	add_child(_embers)

	for i in LINES.size():
		var l := Label.new()
		l.text = LINES[i]
		l.add_theme_font_override("font", font)
		l.add_theme_font_size_override("font_size", FONT_SIZE)
		l.add_theme_color_override("font_color", Color.WHITE)
		l.add_theme_color_override("font_outline_color", UITheme.INK)
		l.add_theme_constant_override("outline_size", OUTLINE)
		l.add_theme_color_override("font_shadow_color", Color("#4a1606"))
		l.add_theme_constant_override("shadow_offset_x", 0)
		l.add_theme_constant_override("shadow_offset_y", 12)
		l.add_theme_constant_override("shadow_outline_size", OUTLINE + 2)
		var mat := ShaderMaterial.new()
		mat.shader = SHADER
		# Lilita One caps span ~22 %…80 % of the line box at this size.
		var line_h := font.get_height(FONT_SIZE)
		mat.set_shader_parameter(&"glyph_top", line_h * 0.2)
		mat.set_shader_parameter(&"glyph_bottom", line_h * 0.8)
		mat.set_shader_parameter(&"wobble", 1.6)
		l.material = mat
		l.position = Vector2(OUTLINE + INDENT * i, LINE_STEP * i)
		l.pivot_offset = Vector2(width * 0.5, line_h * 0.8)
		add_child(l)
		_labels.append(l)


## Drops the words in one after the other with a squash on landing.
func play_intro(delay := 0.0) -> void:
	for i in _labels.size():
		var l := _labels[i]
		var rest := l.position
		l.position = rest + Vector2(0, -220)
		l.modulate.a = 0.0
		var d := delay + i * 0.16
		var tw := l.create_tween()
		tw.tween_interval(d)
		tw.set_parallel()
		tw.tween_property(l, "modulate:a", 1.0, 0.12)
		tw.tween_property(l, "position", rest, 0.42).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		tw.chain().tween_property(l, "scale", Vector2(1.06, 0.9), 0.07).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		tw.chain().tween_property(l, "scale", Vector2.ONE, 0.45).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
	_glow.modulate.a = 0.0
	var g := _glow.create_tween()
	g.tween_interval(delay + 0.3)
	g.tween_property(_glow, "modulate:a", 1.0, 0.6)


func _process(delta: float) -> void:
	_t += delta
	# Slow breathing of the glow and a hint of scale, like heat shimmer.
	if _glow.modulate.a > 0.99 or _t > 2.0:
		_glow.modulate.a = 0.82 + sin(_t * 1.3) * 0.18
	scale = Vector2.ONE * (1.0 + sin(_t * 0.9) * 0.008)
