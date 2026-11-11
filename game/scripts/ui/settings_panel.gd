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
var _pages: Array[VBoxContainer] = []
var _tabs: Array[Button] = []
var _page: VBoxContainer

const TABS := ["Spiel", "Ton", "Steuerung", "Grafik"]
const KEYS := [["W A S D", "Laufen"], ["Maus", "Umsehen"], ["Leertaste", "Springen"], ["Shift", "Rennen"], ["Linksklick / E", "Aufheben und ablegen"],
	["Rechtsklick / Q", "Werfen"], ["F", "Benutzen (gedrückt halten: weiterarbeiten)"], ["Esc", "Pause"]]


func _ready() -> void:
	add_theme_constant_override("separation", 18)
	custom_minimum_size.x = 1040
	var title := Label.new()
	title.text = "Einstellungen"
	title.theme_type_variation = &"H2"
	add_child(title)
	var body := HBoxContainer.new()
	body.add_theme_constant_override("separation", 22)
	add_child(body)
	# Left: the sections. Right: one card with the rows of the chosen section.
	var rail := VBoxContainer.new()
	rail.add_theme_constant_override("separation", 10)
	rail.custom_minimum_size.x = 220
	body.add_child(rail)
	var group := ButtonGroup.new()
	for i in TABS.size():
		var tab := Button.new()
		tab.text = TABS[i]
		tab.theme_type_variation = &"SegmentButton"
		tab.toggle_mode = true
		tab.button_group = group
		tab.button_pressed = i == 0
		tab.alignment = HORIZONTAL_ALIGNMENT_LEFT
		tab.custom_minimum_size = Vector2(220, 58)
		tab.pressed.connect(_show_page.bind(i))
		UITheme.juice_button(tab)
		rail.add_child(tab)
		_tabs.append(tab)
	var card := PanelContainer.new()
	var cb := StyleBoxFlat.new()
	cb.bg_color = Color(1, 1, 1, 0.045)
	cb.set_corner_radius_all(18)
	cb.set_content_margin_all(18)
	card.add_theme_stylebox_override("panel", cb)
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	card.custom_minimum_size.y = 470
	body.add_child(card)
	for i in TABS.size():
		var page := VBoxContainer.new()
		page.add_theme_constant_override("separation", 10)
		page.visible = i == 0
		card.add_child(page)
		_pages.append(page)

	_page = _pages[0]
	var name_edit := LineEdit.new()
	name_edit.text = GameSettings.player_name
	name_edit.placeholder_text = "Name im Koop"
	name_edit.max_length = 16
	name_edit.custom_minimum_size = Vector2(320, 0)
	name_edit.add_theme_font_size_override("font_size", 26)
	name_edit.text_changed.connect(func(t: String) -> void: GameSettings.player_name = t.strip_edges())
	_row("Name", name_edit, null, "So sehen dich deine Mitspieler")
	var shake := _slider("Kamerawackeln", 0.0, 1.0, GameSettings.screen_shake, _on_shake, "Wie stark Treffer und Abstiche das Bild rütteln")
	shake.drag_ended.connect(func(_changed: bool) -> void: Juice.shake(0.45, 0.3))

	_page = _pages[1]
	_slider("Gesamtlautstärke", 0.0, 1.0, GameSettings.master_volume, _on_volume, "Alles zusammen")
	_slider("Musik", 0.0, 1.0, GameSettings.music_volume, func(v: float) -> void: GameSettings.music_volume = v, "Nur die Hintergrundmusik")

	_page = _pages[2]
	_slider("Maus-Empfindlichkeit", 0.3, 2.5, GameSettings.mouse_sensitivity, _on_sensitivity, "Wie schnell sich der Blick dreht")
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 22)
	grid.add_theme_constant_override("v_separation", 8)
	for pair: Array in KEYS:
		var key := Label.new()
		key.text = pair[0]
		key.add_theme_font_size_override("font_size", UITheme.SIZE_SMALL)
		key.add_theme_color_override("font_color", UITheme.ACCENT)
		key.add_theme_constant_override("outline_size", 0)
		key.custom_minimum_size.x = 200
		grid.add_child(key)
		var what := Label.new()
		what.text = pair[1]
		what.add_theme_font_size_override("font_size", UITheme.SIZE_SMALL)
		what.add_theme_constant_override("outline_size", 0)
		grid.add_child(what)
	_page.add_child(_boxed(grid))

	_page = _pages[3]
	_toggle("Vollbild", GameSettings.fullscreen, _on_fullscreen)
	var segs := HBoxContainer.new()
	segs.add_theme_constant_override("separation", 8)
	var q_group := ButtonGroup.new()
	for i in GameSettings.QUALITY_NAMES.size():
		var b := Button.new()
		b.text = GameSettings.QUALITY_NAMES[i]
		b.theme_type_variation = &"SegmentButton"
		b.toggle_mode = true
		b.button_group = q_group
		b.button_pressed = i == GameSettings.current_quality()
		b.custom_minimum_size.x = 124
		b.pressed.connect(_on_quality.bind(i))
		UITheme.juice_button(b)
		segs.add_child(b)
		_quality_buttons.append(b)
	_row("Qualität", segs, _quality_buttons[GameSettings.current_quality()], "Ruckelt es? Eine Stufe runter")
	_ssao = _toggle("Weiche Schatten in Ecken", GameSettings.ssao, _on_ssao, "Umgebungsverdeckung (SSAO)")
	_shadows = _toggle("Schatten", GameSettings.shadows, _on_shadows)
	_scale_slider = _slider("3D-Auflösung", 0.5, 1.0, GameSettings.render_scale, _on_render_scale, "Weniger ist schneller, aber unschärfer")
	_scale_value = _scale_slider.get_meta(&"value_label") as Label
	_note = Label.new()
	_note.theme_type_variation = &"Small"
	_note.text = "Gras, Lichter und Nebel der Qualitätsstufe greifen beim nächsten Laden des Levels."
	_note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_note.custom_minimum_size.x = 640
	_note.modulate.a = 0.0
	_page.add_child(_note)

	var back := Button.new()
	back.text = "Zurück"
	back.theme_type_variation = &"SecondaryButton"
	back.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	back.custom_minimum_size.x = 260
	back.pressed.connect(func() -> void: back_requested.emit())
	UITheme.juice_button(back)
	add_child(back)
	_rows.append(back)


func _show_page(i: int) -> void:
	for k in _pages.size():
		_pages[k].visible = k == i


## A soft rounded box around one row.
func _boxed(content: Control) -> PanelContainer:
	var box := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0, 0, 0, 0.22)
	sb.set_corner_radius_all(14)
	sb.content_margin_left = 18
	sb.content_margin_right = 18
	sb.content_margin_top = 10
	sb.content_margin_bottom = 10
	box.add_theme_stylebox_override("panel", sb)
	box.add_child(content)
	return box


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


func _row(text: String, control: Control, focus: Control = null, note := "") -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 18)
	var names := VBoxContainer.new()
	names.add_theme_constant_override("separation", -2)
	names.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	names.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", UITheme.SIZE_HINT)
	l.add_theme_constant_override("outline_size", 0)
	names.add_child(l)
	if not note.is_empty():
		var n := Label.new()
		n.text = note
		n.add_theme_font_size_override("font_size", 18)
		n.add_theme_color_override("font_color", UITheme.MUTED)
		n.add_theme_constant_override("outline_size", 0)
		names.add_child(n)
	row.add_child(names)
	control.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(control)
	row.custom_minimum_size.y = 58
	_page.add_child(_boxed(row))
	_rows.append(focus if focus else control)
	return row


func _slider(text: String, lo: float, hi: float, value: float, on_change: Callable, note := "") -> HSlider:
	var s := HSlider.new()
	s.min_value = lo
	s.max_value = hi
	s.step = 0.01
	s.value = value
	s.custom_minimum_size = Vector2(300, 36)
	var row := _row(text, s, null, note)
	var v := Label.new()
	v.text = _percent(value)
	v.custom_minimum_size.x = 80
	v.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	v.add_theme_font_size_override("font_size", UITheme.SIZE_HINT)
	v.add_theme_color_override("font_color", UITheme.MUTED)
	v.add_theme_constant_override("outline_size", 0)
	row.add_child(v)
	s.set_meta(&"value_label", v)
	s.value_changed.connect(func(x: float) -> void:
		v.text = _percent(x)
		on_change.call(x)
	)
	s.drag_ended.connect(func(_changed: bool) -> void: Sfx.play_ui(&"pop", -10.0))
	return s


func _toggle(text: String, value: bool, on_change: Callable, note := "") -> Button:
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
	_row(text, b, null, note)
	return b


func _refresh_toggle(b: Button) -> void:
	b.text = "AN" if b.button_pressed else "AUS"


static func _percent(v: float) -> String:
	return "%d %%" % roundi(v * 100.0)
