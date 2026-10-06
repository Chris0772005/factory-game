class_name DrawPad
extends Control
## Full-screen drawing UI for the pattern bench: a paper canvas with chunky ink,
## undo/clear/done, an optional countdown and a live 3D preview of the cast.
## Mouse/touch draw with the left button; gamepad: left stick moves a cursor,
## A draws, B undoes, Y clears, Start finishes, Back cancels. Esc cancels,
## Ctrl+Z undoes, Enter finishes.

signal finished(drawing: Drawing)
signal cancelled

@export var time_limit := 30.0
## Stroke width relative to the canvas (see Drawing.brush).
@export var brush := 0.06
## Material for the live cast preview; a plain bronze look if unset.
@export var preview_material: Material:
	set(value):
		preview_material = value
		if _preview_mesh:
			_preview_mesh.material_override = value if value else _default_metal()

const BACKDROP_SHADER := preload("res://assets/ui/shaders/backdrop_blur.gdshader")
const CURSOR_SPEED := 0.75
const SIDE_WIDTH := 420.0
const WARN_TIME := 5.0
const PREVIEW_COLOR := Color("#c98a4a")
const HINT_MOUSE := "Linke Maustaste: zeichnen   ·   Strg+Z: zurück   ·   Esc: abbrechen"
const HINT_PAD := "A: zeichnen   ·   B: zurück   ·   Y: löschen   ·   Start: fertig"
const HINT_FULL := "Das Blatt ist voll!   ·   Rückgängig, Löschen oder Fertig"

var drawing := Drawing.new()
var prompt := ""
## Seconds left on the countdown.
var time_left := 0.0

var _active := false
var _preview_dirty := false
var _spin := 0.0
var _stroke := PackedVector2Array()
var _pad_cursor := Vector2(0.5, 0.5)
var _pad_device := -1
var _pad_drawing := false
var _mouse_mode := Input.MOUSE_MODE_VISIBLE
var _canvas: _Canvas
var _prompt_label: Label
var _timer_label: Label
var _timer_panel: PanelContainer
var _preview_mesh: MeshInstance3D
var _preview_pivot: Node3D
var _preview_hint: Label
var _preview_tween: Tween
var _stats_label: Label
var _hint_label: Label
var _undo_button: Button
var _clear_button: Button
var _done_button: Button


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	theme = UITheme.get_theme()
	mouse_filter = Control.MOUSE_FILTER_STOP
	_build_ui()
	resized.connect(_layout)
	_layout()
	_prompt_label.text = prompt
	_refresh()
	_update_timer()
	if not _active:
		visible = false
		set_process(false)


## Shows the pad with a fresh drawing, e.g. open("Zeichne: einen Gartenzwerg").
func open(prompt_text: String) -> void:
	prompt = prompt_text
	drawing = Drawing.new()
	drawing.brush = brush
	_stroke.clear()
	_pad_drawing = false
	time_left = time_limit
	if not _active:
		_mouse_mode = Input.mouse_mode
	_active = true
	if is_node_ready():
		_prompt_label.text = prompt
		_timer_panel.visible = time_limit > 0.0
		_refresh()
		_update_timer()
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	visible = true
	set_process(true)
	modulate.a = 0.0
	create_tween().tween_property(self, "modulate:a", 1.0, 0.15)


## Hides the pad without emitting anything.
func close() -> void:
	_active = false
	visible = false
	set_process(false)
	Input.mouse_mode = _mouse_mode


func _exit_tree() -> void:
	if _active:
		close()


## Adds a stroke in [0,1]² canvas space as if it had been drawn (replays, demos).
func add_stroke(points: PackedVector2Array) -> void:
	drawing.add_stroke(points)
	_refresh()


func undo() -> void:
	drawing.remove_last_stroke()
	_refresh()


func clear() -> void:
	drawing.clear()
	_refresh()


## Emits `finished` with the drawing and closes; does nothing while empty.
func finish() -> void:
	_end_stroke()
	if not _active or drawing.is_empty():
		return
	close()
	finished.emit(drawing)


func cancel() -> void:
	if _active:
		close()
		cancelled.emit()


func _process(delta: float) -> void:
	if _preview_dirty:
		_rebuild_preview()
	_update_gamepad(delta)
	if time_limit > 0.0:
		time_left = maxf(0.0, time_left - delta)
		_update_timer()
		if time_left <= 0.0:
			_time_up()
			return
	if _preview_pivot:
		_spin += delta
		_preview_pivot.rotation.y = sin(_spin * 0.9) * 0.45


func _input(event: InputEvent) -> void:
	if not _active:
		return
	if event is InputEventKey and event.pressed and not event.echo:
		match event.keycode:
			KEY_ESCAPE:
				cancel()
			KEY_Z when event.ctrl_pressed or event.meta_pressed:
				undo()
			KEY_ENTER, KEY_KP_ENTER:
				finish()
			_:
				return
		get_viewport().set_input_as_handled()
	elif event is InputEventJoypadButton:
		_use_gamepad(event.device)
		match event.button_index:
			JOY_BUTTON_A:
				_pad_drawing = event.pressed
				if event.pressed:
					_begin_stroke(_pad_cursor)
				else:
					_end_stroke()
			JOY_BUTTON_B when event.pressed:
				undo()
			JOY_BUTTON_Y when event.pressed:
				clear()
			JOY_BUTTON_START when event.pressed:
				finish()
			JOY_BUTTON_BACK when event.pressed:
				cancel()
		get_viewport().set_input_as_handled()
	elif event is InputEventJoypadMotion and absf(event.axis_value) > 0.3:
		_use_gamepad(event.device)
	elif event is InputEventMouseMotion and _pad_device >= 0:
		_pad_device = -1
		_update_hint()


func _use_gamepad(device: int) -> void:
	if _pad_device < 0:
		_canvas.hover = _pad_cursor
		_canvas.queue_redraw()
	_pad_device = device
	_update_hint()


func _update_hint() -> void:
	var full := drawing.is_full()
	_hint_label.text = HINT_FULL if full else (HINT_PAD if _pad_device >= 0 else HINT_MOUSE)
	_hint_label.add_theme_color_override("font_color", UITheme.ACCENT if full else UITheme.PAPER.darkened(0.25))


## Out of time: whatever is on the paper gets cast; an empty page cancels.
func _time_up() -> void:
	_end_stroke()
	if drawing.is_empty():
		cancel()
	else:
		finish()


func _update_gamepad(delta: float) -> void:
	if _pad_device < 0:
		return
	var stick := Vector2(Input.get_joy_axis(_pad_device, JOY_AXIS_LEFT_X), Input.get_joy_axis(_pad_device, JOY_AXIS_LEFT_Y))
	if stick.length() < 0.15:
		return
	stick = stick.limit_length(1.0)
	_pad_cursor = (_pad_cursor + stick * stick.length() * CURSOR_SPEED * delta).clamp(Vector2.ZERO, Vector2.ONE)
	_canvas.hover = _pad_cursor
	if _pad_drawing:
		_extend_stroke(_pad_cursor)
	_canvas.queue_redraw()


func _begin_stroke(p: Vector2) -> void:
	_end_stroke()
	if drawing.is_full():
		return
	_stroke = PackedVector2Array([p])
	_canvas.queue_redraw()


func _extend_stroke(p: Vector2) -> void:
	if _stroke.is_empty():
		return
	var min_step := 0.004
	if p.distance_to(_stroke[-1]) >= min_step:
		_stroke.append(p)
		_canvas.queue_redraw()


func _end_stroke() -> void:
	if _stroke.is_empty():
		return
	var points := _stroke
	_stroke = PackedVector2Array()
	add_stroke(points)


## Updates buttons and ink after the drawing changed; the cast preview is
## rebuilt once on the next frame, however many changes came in.
func _refresh() -> void:
	if not is_node_ready():
		return
	var empty := drawing.is_empty()
	_undo_button.disabled = empty
	_clear_button.disabled = empty
	_done_button.disabled = empty
	_preview_hint.visible = empty
	_update_hint()
	_canvas.queue_redraw()
	_preview_dirty = true


func _rebuild_preview() -> void:
	_preview_dirty = false
	var res := CastMeshBuilder.build(drawing, 0.6, 0.08)
	_preview_mesh.mesh = res.mesh
	_stats_label.text = "" if drawing.is_empty() else "Metallbedarf: %s l" % ("%.1f" % (res.volume * 1000.0)).replace(".", ",")
	if _preview_tween:
		_preview_tween.kill()
	if not drawing.is_empty():
		_preview_mesh.scale = Vector3.ONE * 0.9
		_preview_tween = create_tween()
		_preview_tween.tween_property(_preview_mesh, "scale", Vector3.ONE, 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func _update_timer() -> void:
	var secs := ceili(time_left)
	_timer_label.text = "%d:%02d" % [floori(secs / 60.0), secs % 60]
	var warn := time_left <= WARN_TIME
	_timer_label.add_theme_color_override("font_color", Color("#ff6b57") if warn else UITheme.PAPER)
	var pulse := 1.0 + (0.12 * maxf(0.0, 1.0 - fmod(WARN_TIME - time_left, 1.0) * 3.0) if warn else 0.0)
	_timer_panel.pivot_offset = _timer_panel.size * 0.5
	_timer_panel.scale = Vector2.ONE * pulse


func _layout() -> void:
	if not _canvas:
		return
	var side := minf(size.y - 250.0, size.x - SIDE_WIDTH - 140.0)
	side = clampf(side, 280.0, 1000.0)
	_canvas.custom_minimum_size = Vector2(side, side)


func _build_ui() -> void:
	# Frosted glass over the live yard (Art Bible 12: the bench stays visible,
	# softly out of focus) instead of a flat dark sheet.
	var shade := ColorRect.new()
	shade.color = Color(0.08, 0.06, 0.12, 0.78)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var frost := ShaderMaterial.new()
	frost.shader = BACKDROP_SHADER
	frost.set_shader_parameter(&"blur_lod", 2.6)
	frost.set_shader_parameter(&"darken", 0.42)
	shade.material = frost
	add_child(shade)
	var col := VBoxContainer.new()
	col.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	col.alignment = BoxContainer.ALIGNMENT_CENTER
	col.add_theme_constant_override("separation", 22)
	add_child(col)
	col.add_child(_build_header())
	var body := HBoxContainer.new()
	body.alignment = BoxContainer.ALIGNMENT_CENTER
	body.add_theme_constant_override("separation", 32)
	col.add_child(body)
	_canvas = _Canvas.new()
	_canvas.pad = self
	_canvas.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	body.add_child(_canvas)
	body.add_child(_build_side())
	_hint_label = Label.new()
	_hint_label.text = HINT_MOUSE
	_hint_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_hint_label.add_theme_font_size_override("font_size", 20)
	_hint_label.add_theme_color_override("font_color", UITheme.PAPER.darkened(0.25))
	_hint_label.add_theme_constant_override("outline_size", 0)
	col.add_child(_hint_label)


func _build_header() -> Control:
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 28)
	_prompt_label = Label.new()
	_prompt_label.text = prompt
	_prompt_label.add_theme_font_override("font", UITheme.font(700))
	_prompt_label.add_theme_font_size_override("font_size", 58)
	_prompt_label.add_theme_constant_override("outline_size", 16)
	row.add_child(_prompt_label)
	_timer_panel = PanelContainer.new()
	var pill := StyleBoxFlat.new()
	pill.bg_color = UITheme.INK
	pill.set_corner_radius_all(30)
	pill.content_margin_left = 26
	pill.content_margin_right = 26
	pill.content_margin_top = 4
	pill.content_margin_bottom = 6
	pill.border_color = UITheme.ACCENT
	pill.set_border_width_all(4)
	_timer_panel.add_theme_stylebox_override("panel", pill)
	_timer_panel.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_timer_label = Label.new()
	_timer_label.add_theme_font_override("font", UITheme.font(700))
	_timer_label.add_theme_font_size_override("font_size", 46)
	_timer_label.add_theme_constant_override("outline_size", 0)
	_timer_label.custom_minimum_size.x = 110
	_timer_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_timer_panel.add_child(_timer_label)
	_timer_panel.visible = time_limit > 0.0
	row.add_child(_timer_panel)
	return row


func _build_side() -> Control:
	var side := VBoxContainer.new()
	side.custom_minimum_size.x = SIDE_WIDTH
	side.add_theme_constant_override("separation", 16)
	var panel := PanelContainer.new()
	side.add_child(panel)
	var inner := VBoxContainer.new()
	inner.add_theme_constant_override("separation", 6)
	panel.add_child(inner)
	var title := Label.new()
	title.text = "So wird dein Guss"
	title.add_theme_font_size_override("font_size", 26)
	title.add_theme_color_override("font_color", UITheme.ACCENT)
	inner.add_child(title)
	var holder := Control.new()
	holder.custom_minimum_size = Vector2(SIDE_WIDTH - 36, SIDE_WIDTH - 36)
	inner.add_child(holder)
	var view := SubViewportContainer.new()
	view.stretch = true
	view.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	holder.add_child(view)
	view.add_child(_build_preview())
	_preview_hint = Label.new()
	_preview_hint.text = "Zeichne etwas!"
	_preview_hint.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_preview_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_preview_hint.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_preview_hint.add_theme_color_override("font_color", UITheme.PAPER.darkened(0.3))
	_preview_hint.add_theme_constant_override("outline_size", 0)
	holder.add_child(_preview_hint)
	_stats_label = Label.new()
	_stats_label.add_theme_font_size_override("font_size", 22)
	_stats_label.add_theme_constant_override("outline_size", 0)
	_stats_label.add_theme_color_override("font_color", UITheme.PAPER.darkened(0.15))
	inner.add_child(_stats_label)
	var spacer := Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	side.add_child(spacer)
	_undo_button = _button("Rückgängig", undo, false)
	_clear_button = _button("Löschen", clear, false)
	_done_button = _button("Fertig", finish, true)
	for b in [_undo_button, _clear_button, _done_button]:
		side.add_child(b)
	return side


func _build_preview() -> SubViewport:
	var vp := SubViewport.new()
	vp.own_world_3d = true
	vp.msaa_3d = Viewport.MSAA_4X
	vp.render_target_update_mode = SubViewport.UPDATE_WHEN_VISIBLE
	var env := Environment.new()
	var sky := Sky.new()
	var sky_mat := ProceduralSkyMaterial.new()
	sky_mat.sky_top_color = Color("#8fb4d8")
	sky_mat.sky_horizon_color = Color("#f6dcb8")
	sky_mat.ground_horizon_color = Color("#f6dcb8")
	sky_mat.ground_bottom_color = Color("#5a4636")
	sky.sky_material = sky_mat
	env.sky = sky
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color("#2a2338")
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.reflected_light_source = Environment.REFLECTION_SOURCE_SKY
	env.tonemap_mode = Environment.TONE_MAPPER_AGX
	var we := WorldEnvironment.new()
	we.environment = env
	vp.add_child(we)
	var sun := DirectionalLight3D.new()
	sun.light_energy = 1.3
	sun.shadow_enabled = true
	sun.rotation_degrees = Vector3(-60, 30, 0)
	vp.add_child(sun)
	var rim := DirectionalLight3D.new()
	rim.light_color = Color("#ffd29a")
	rim.light_energy = 0.8
	rim.rotation_degrees = Vector3(-25, 160, 0)
	vp.add_child(rim)
	var plinth := MeshInstance3D.new()
	var cyl := CylinderMesh.new()
	cyl.top_radius = 0.44
	cyl.bottom_radius = 0.46
	cyl.height = 0.06
	plinth.mesh = cyl
	# Rammed foundry sand, like the mold bed the pattern goes into.
	plinth.material_override = WorldBuilder.material(Color("#b8955f"), 0.95)
	plinth.position.y = -0.07
	vp.add_child(plinth)
	_preview_pivot = Node3D.new()
	vp.add_child(_preview_pivot)
	_preview_mesh = MeshInstance3D.new()
	_preview_mesh.material_override = preview_material if preview_material else _default_metal()
	_preview_pivot.add_child(_preview_mesh)
	var cam := Camera3D.new()
	cam.fov = 34
	vp.add_child(cam)
	cam.look_at_from_position(Vector3(0, 1.36, 1.1), Vector3(0, -0.07, 0.04))
	return vp


## Polished bronze from the real cast-metal shader (studio reflections, no crust).
func _default_metal() -> Material:
	var metal := MetalMaterial.create(&"bronze")
	metal.set_shader_parameter(&"crust", 0.0)
	return metal


func _button(text: String, cb: Callable, primary: bool) -> Button:
	var b := Button.new()
	b.text = text
	b.focus_mode = Control.FOCUS_NONE
	b.pressed.connect(cb)
	if not primary:
		var normal := _flat(UITheme.PAPER, UITheme.PAPER.darkened(0.25))
		b.add_theme_stylebox_override("normal", normal)
		b.add_theme_stylebox_override("hover", _flat(Color.WHITE, UITheme.PAPER.darkened(0.25)))
		b.add_theme_stylebox_override("pressed", _flat(UITheme.PAPER.darkened(0.12), UITheme.PAPER.darkened(0.35)))
		b.add_theme_stylebox_override("disabled", _flat(UITheme.PAPER.darkened(0.45), UITheme.PAPER.darkened(0.55)))
		b.add_theme_font_size_override("font_size", 28)
	else:
		b.add_theme_stylebox_override("disabled", _flat(UITheme.ACCENT.darkened(0.45), UITheme.ACCENT_DARK.darkened(0.5)))
		b.add_theme_font_size_override("font_size", 40)
	b.add_theme_color_override("font_disabled_color", UITheme.INK.lightened(0.25))
	return b


func _flat(bg: Color, border: Color) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	sb.set_corner_radius_all(18)
	sb.border_color = border
	sb.border_width_bottom = 6
	sb.content_margin_top = 10
	sb.content_margin_bottom = 12
	sb.content_margin_left = 24
	sb.content_margin_right = 24
	return sb


## The paper: draws the ink and turns mouse/touch input into strokes.
class _Canvas:
	extends Control

	var pad: DrawPad
	var hover := Vector2(-1, -1)
	var _paper := StyleBoxFlat.new()

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_STOP
		mouse_default_cursor_shape = Control.CURSOR_CROSS
		_paper.bg_color = UITheme.PAPER
		_paper.set_corner_radius_all(28)
		_paper.shadow_color = Color(0, 0, 0, 0.35)
		_paper.shadow_size = 18
		_paper.shadow_offset = Vector2(0, 8)
		_paper.border_color = UITheme.PAPER.darkened(0.12)
		_paper.set_border_width_all(4)
		mouse_exited.connect(func():
			hover = Vector2(-1, -1)
			queue_redraw())

	## Area that [0,1]² maps to: the paper minus a margin of half a brush.
	func ink_rect() -> Rect2:
		var m := size.x * (0.03 + pad.brush * 0.5)
		return Rect2(Vector2(m, m), size - Vector2(m, m) * 2.0)

	func to_canvas(p: Vector2) -> Vector2:
		var r := ink_rect()
		return r.position + p * r.size

	func to_drawing(p: Vector2) -> Vector2:
		var r := ink_rect()
		return ((p - r.position) / r.size).clamp(Vector2.ZERO, Vector2.ONE)

	func _gui_input(event: InputEvent) -> void:
		if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
			if event.pressed:
				pad._begin_stroke(to_drawing(event.position))
			else:
				pad._end_stroke()
			accept_event()
		elif event is InputEventMouseMotion:
			hover = to_drawing(event.position)
			if event.button_mask & MOUSE_BUTTON_MASK_LEFT:
				pad._extend_stroke(hover)
			queue_redraw()

	func _draw() -> void:
		draw_style_box(_paper, Rect2(Vector2.ZERO, size))
		var r := ink_rect()
		var dot := UITheme.PAPER.darkened(0.09)
		for i in range(1, 12):
			for j in range(1, 12):
				draw_circle(r.position + r.size * Vector2(i, j) / 12.0, 2.5, dot, true, -1.0, true)
		var width := pad.brush * r.size.x
		for s in pad.drawing.strokes:
			_draw_ink(s, width, UITheme.INK)
		_draw_ink(pad._stroke, width, UITheme.INK)
		if hover.x >= 0.0:
			var c := to_canvas(hover)
			draw_arc(c, width * 0.5, 0.0, TAU, 40, Color(UITheme.INK, 0.55), 2.5, true)
			if pad._pad_device >= 0:
				draw_circle(c, 4.0, UITheme.ACCENT_DARK, true, -1.0, true)

	func _draw_ink(points: PackedVector2Array, width: float, color: Color) -> void:
		if points.is_empty():
			return
		var pts := PackedVector2Array()
		for p in points:
			pts.append(to_canvas(p))
		# Segments plus discs give round caps and joins.
		for i in pts.size():
			draw_circle(pts[i], width * 0.5, color, true, -1.0, true)
			if i > 0:
				draw_line(pts[i - 1], pts[i], color, width, true)
