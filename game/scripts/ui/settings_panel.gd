class_name SettingsPanel
extends VBoxContainer
## Options page shared by the pause menu and the title screen: master volume, mouse
## sensitivity, screen shake, fullscreen, graphics preset (EnvQuality) and its
## details (SSAO, shadows, 3D render scale). Changes apply live and are saved to
## user://settings.cfg when the page closes. Works with mouse and gamepad focus.

signal back_requested

var _rows: Array[Control] = []
var _quality_buttons: Array[Button] = []
var _ssao: Button
var _shadows: Button
var _scale_slider: HSlider
var _scale_value: Label
var _note: Label


func _ready() -> void:
	add_theme_constant_override("separation", 14)
	var title := Label.new()
	title.text = "Einstellungen"
	title.theme_type_variation = &"H2"
	add_child(title)
	_section("Audio & Steuerung")
	_slider("Gesamtlautstärke", 0.0, 1.0, GameSettings.master_volume, _on_volume)
	_slider("Maus-Empfindlichkeit", 0.3, 2.5, GameSettings.mouse_sensitivity, _on_sensitivity)
	var shake := _slider("Kamerawackeln", 0.0, 1.0, GameSettings.screen_shake, _on_shake)
	shake.drag_ended.connect(func(_changed: bool) -> void: Juice.shake(0.45, 0.3))
	_section("Grafik")
	_toggle("Vollbild", GameSettings.fullscreen, _on_fullscreen)
	var segs := HBoxContainer.new()
	segs.add_theme_constant_override("separation", 8)
	var group := ButtonGroup.new()
	for i in GameSettings.QUALITY_NAMES.size():
		var b := Button.new()
		b.text = GameSettings.QUALITY_NAMES[i]
		b.theme_type_variation = &"SegmentButton"
		b.toggle_mode = true
		b.button_group = group
		b.button_pressed = i == GameSettings.current_quality()
		b.custom_minimum_size.x = 132
		b.pressed.connect(_on_quality.bind(i))
		UITheme.juice_button(b)
		segs.add_child(b)
		_quality_buttons.append(b)
	_row("Qualität", segs, _quality_buttons[GameSettings.current_quality()])
	_ssao = _toggle("Umgebungsverdeckung (SSAO)", GameSettings.ssao, _on_ssao)
	_shadows = _toggle("Schatten", GameSettings.shadows, _on_shadows)
	_scale_slider = _slider("3D-Auflösung", 0.5, 1.0, GameSettings.render_scale, _on_render_scale)
	_scale_value = _scale_slider.get_parent().get_child(_scale_slider.get_index() + 1) as Label
	_note = Label.new()
	_note.theme_type_variation = &"Small"
	_note.text = "Gras, Lichter und Nebel der Qualitätsstufe greifen beim nächsten Laden des Levels."
	_note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_note.custom_minimum_size.x = 640
	_note.modulate.a = 0.0
	add_child(_note)
	var back := Button.new()
	back.text = "Zurück"
	back.theme_type_variation = &"SecondaryButton"
	back.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	back.custom_minimum_size.x = 260
	back.pressed.connect(func() -> void: back_requested.emit())
	UITheme.juice_button(back)
	add_child(back)
	_rows.append(back)


## Saves and gives focus back; call when the page closes.
func commit() -> void:
	GameSettings.save()


## Focuses the first control (gamepad navigation).
func focus_first() -> void:
	for r in _rows:
		if r.focus_mode != Control.FOCUS_NONE:
			r.grab_focus()
			return


func _unhandled_input(event: InputEvent) -> void:
	if is_visible_in_tree() and event.is_action_pressed(&"ui_cancel"):
		back_requested.emit()
		get_viewport().set_input_as_handled()


func _on_volume(v: float) -> void:
	GameSettings.master_volume = v
	GameSettings.apply_audio()


func _on_sensitivity(v: float) -> void:
	GameSettings.mouse_sensitivity = v


func _on_shake(v: float) -> void:
	GameSettings.screen_shake = v


func _on_fullscreen(on: bool) -> void:
	GameSettings.fullscreen = on
	GameSettings.apply_window()


func _on_ssao(on: bool) -> void:
	GameSettings.ssao = on
	GameSettings.apply_graphics(get_tree())


func _on_shadows(on: bool) -> void:
	GameSettings.shadows = on
	GameSettings.apply_graphics(get_tree())


func _on_render_scale(v: float) -> void:
	GameSettings.render_scale = v
	GameSettings.apply_graphics(get_tree())


func _on_quality(level: int) -> void:
	GameSettings.set_quality(level)
	GameSettings.apply_graphics(get_tree())
	_ssao.set_pressed_no_signal(GameSettings.ssao)
	_shadows.set_pressed_no_signal(GameSettings.shadows)
	_refresh_toggle(_ssao)
	_refresh_toggle(_shadows)
	_scale_slider.set_value_no_signal(GameSettings.render_scale)
	_scale_value.text = _percent(GameSettings.render_scale)
	var tw := _note.create_tween()
	tw.tween_property(_note, "modulate:a", 1.0, 0.2)


func _section(text: String) -> void:
	var l := Label.new()
	l.text = text.to_upper()
	l.theme_type_variation = &"Small"
	l.add_theme_color_override("font_color", UITheme.ACCENT)
	l.add_theme_font_override("font", UITheme.font(700))
	add_child(l)


func _row(text: String, control: Control, focus: Control = null) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 18)
	var l := Label.new()
	l.text = text
	l.custom_minimum_size.x = 330
	l.add_theme_font_size_override("font_size", UITheme.SIZE_HINT)
	l.add_theme_constant_override("outline_size", 0)
	row.add_child(l)
	row.add_child(control)
	add_child(row)
	_rows.append(focus if focus else control)
	return row


func _slider(text: String, lo: float, hi: float, value: float, on_change: Callable) -> HSlider:
	var s := HSlider.new()
	s.min_value = lo
	s.max_value = hi
	s.step = 0.01
	s.value = value
	s.custom_minimum_size = Vector2(300, 36)
	s.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var row := _row(text, s)
	var v := Label.new()
	v.text = _percent(value)
	v.custom_minimum_size.x = 80
	v.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	v.add_theme_font_size_override("font_size", UITheme.SIZE_HINT)
	v.add_theme_color_override("font_color", UITheme.MUTED)
	v.add_theme_constant_override("outline_size", 0)
	row.add_child(v)
	s.value_changed.connect(func(x: float) -> void:
		v.text = _percent(x)
		on_change.call(x)
	)
	s.drag_ended.connect(func(_changed: bool) -> void: Sfx.play_ui(&"pop", -10.0))
	return s


func _toggle(text: String, value: bool, on_change: Callable) -> Button:
	var b := Button.new()
	b.theme_type_variation = &"ToggleButton"
	b.toggle_mode = true
	b.button_pressed = value
	b.custom_minimum_size.x = 132
	_refresh_toggle(b)
	b.toggled.connect(func(on: bool) -> void:
		_refresh_toggle(b)
		on_change.call(on)
	)
	UITheme.juice_button(b)
	_row(text, b)
	return b


func _refresh_toggle(b: Button) -> void:
	b.text = "AN" if b.button_pressed else "AUS"


static func _percent(v: float) -> String:
	return "%d %%" % roundi(v * 100.0)
