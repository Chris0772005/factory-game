extends Node
## Title screen: the real backyard at dusk turns behind the menu (MenuCamera), the
## molten MOLTEN MATES logo drops in, and the menu column slides in. Play solo, host
## or join; settings open in a card over the yard. Scene changes run through the
## iris Transition; every button has hover/press motion and UI sounds.

const LEVEL := "res://scenes/backyard.tscn"
const COLUMN_X := 112.0

var _camera: Camera3D
var _ip: LineEdit
var _status: Label
var _status_pill: PanelContainer
var _root: Control
var _logo: MoltenLogo
var _column: VBoxContainer
var _first: Button
var _buttons: Array[Button] = []
var _settings_layer: Control
var _settings: SettingsPanel
var _busy := false


func _ready() -> void:
	var bg: GameWorld = load(LEVEL).instantiate()
	bg.attract_mode = true
	add_child(bg)
	_camera = MenuCamera.new()
	add_child(_camera)
	_camera.add_child(OutlinePass.create())
	_build_ui()
	Transition.reveal()
	_intro()
	if DisplayServer.get_name() != "headless":
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	Juice.device_changed.connect(_on_device_changed)


func _build_ui() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)
	_root = Control.new()
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.theme = UITheme.get_theme()
	layer.add_child(_root)
	_root.add_child(_scrim(Vector2(0, 0), Vector2(1180, 1080), Vector2(0, 0.5), Vector2(1, 0.5), 0.78))
	_root.add_child(_scrim(Vector2(0, 760), Vector2(1920, 320), Vector2(0.5, 1), Vector2(0.5, 0), 0.55))

	_logo = MoltenLogo.new()
	_logo.position = Vector2(COLUMN_X - 26.0, 64.0)
	_root.add_child(_logo)

	_column = VBoxContainer.new()
	_column.position = Vector2(COLUMN_X, 452)
	_column.add_theme_constant_override("separation", 14)
	_root.add_child(_column)
	var tag := Label.new()
	tag.name = "Tagline"
	tag.text = "Zeichne es. Gieß es. Zerschlag die Form."
	tag.add_theme_font_override("font", UITheme.font(700))
	tag.add_theme_font_size_override("font_size", UITheme.SIZE_TEXT + 2)
	tag.add_theme_color_override("font_color", UITheme.MOLTEN_HOT)
	tag.add_theme_constant_override("outline_size", 10)
	_column.add_child(tag)
	_column.add_child(_spacer(18))
	_first = _button("Solo spielen", &"BigButton", _on_solo)
	_button("Spiel hosten", &"SecondaryButton", _on_host)
	var join_row := HBoxContainer.new()
	join_row.add_theme_constant_override("separation", 12)
	var join := _button("Beitreten", &"SecondaryButton", _on_join, join_row)
	join.custom_minimum_size.x = 250
	_ip = LineEdit.new()
	_ip.text = "127.0.0.1"
	_ip.placeholder_text = "IP-Adresse"
	_ip.custom_minimum_size = Vector2(240, 0)
	_ip.add_theme_font_size_override("font_size", 28)
	_ip.text_submitted.connect(func(_t: String) -> void: _on_join())
	join_row.add_child(_ip)
	_column.add_child(join_row)
	_button("Einstellungen", &"SecondaryButton", _open_settings)
	_button("Beenden", &"SecondaryButton", func() -> void: get_tree().quit())

	_status_pill = PanelContainer.new()
	_status_pill.theme_type_variation = &"HudPill"
	_status = Label.new()
	_status.add_theme_font_size_override("font_size", UITheme.SIZE_HINT - 2)
	_status.add_theme_color_override("font_color", UITheme.BAD.lightened(0.35))
	_status.add_theme_constant_override("outline_size", 0)
	_status_pill.add_child(_status)
	_status_pill.visible = false
	_column.add_child(_status_pill)
	if not Network.last_message.is_empty():
		_show_status(Network.last_message)
	Network.last_message = ""

	var footer := Label.new()
	footer.name = "Footer"
	footer.text = "Koop-Gießerei für 1–4 Spieler  ·  v0.1"
	footer.theme_type_variation = &"Small"
	footer.position = Vector2(COLUMN_X, 1080 - 54 - 30)
	_root.add_child(footer)


func _intro() -> void:
	_logo.play_intro(0.2)
	var tag := _column.get_node(^"Tagline") as Label
	tag.modulate.a = 0.0
	var tw := tag.create_tween()
	tw.tween_interval(0.7)
	tw.tween_property(tag, "modulate:a", 1.0, 0.35)
	# Buttons slide in from the left, staggered (after the container has laid them out).
	await get_tree().process_frame
	for i in _buttons.size():
		var b := _buttons[i]
		var target := b.position
		b.modulate.a = 0.0
		b.position = target + Vector2(-70, 0)
		var bt := b.create_tween().set_parallel()
		bt.tween_property(b, "position", target, 0.38).set_delay(0.62 + i * 0.06).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		bt.tween_property(b, "modulate:a", 1.0, 0.2).set_delay(0.62 + i * 0.06)
	_ip.modulate.a = 0.0
	_ip.create_tween().tween_property(_ip, "modulate:a", 1.0, 0.3).set_delay(0.9)
	var footer := _root.get_node(^"Footer") as Label
	footer.modulate.a = 0.0
	footer.create_tween().tween_property(footer, "modulate:a", 1.0, 0.5).set_delay(1.1)
	if Juice.using_gamepad:
		_first.grab_focus()


func _button(text: String, variation: StringName, cb: Callable, parent: Control = null) -> Button:
	var b := Button.new()
	b.text = text
	b.theme_type_variation = variation
	b.custom_minimum_size = Vector2(420 if variation == &"BigButton" else 380, 0)
	b.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	b.pressed.connect(func() -> void:
		if not _busy:
			cb.call()
	)
	UITheme.juice_button(b)
	(parent if parent else _column).add_child(b)
	_buttons.append(b)
	return b


func _scrim(pos: Vector2, size: Vector2, from: Vector2, to: Vector2, alpha: float) -> TextureRect:
	var grad := Gradient.new()
	grad.offsets = PackedFloat32Array([0.0, 0.55, 1.0])
	grad.colors = PackedColorArray([Color(UITheme.INK, alpha), Color(UITheme.INK, alpha * 0.45), Color(UITheme.INK, 0.0)])
	var tex := GradientTexture2D.new()
	tex.gradient = grad
	tex.fill_from = from
	tex.fill_to = to
	tex.width = 64
	tex.height = 64
	var r := TextureRect.new()
	r.texture = tex
	r.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	r.stretch_mode = TextureRect.STRETCH_SCALE
	r.position = pos
	r.size = size
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return r


func _spacer(h: float) -> Control:
	var c := Control.new()
	c.custom_minimum_size.y = h
	return c


func _show_status(text: String) -> void:
	_status.text = text
	_status_pill.visible = true
	UITheme.pop_in(_status_pill, 0.9)


func _on_device_changed(pad: bool) -> void:
	if pad and get_viewport().gui_get_focus_owner() == null:
		if _settings_layer and _settings_layer.visible:
			_settings.focus_first()
		else:
			_first.grab_focus()


# --- Settings -----------------------------------------------------------------

func _open_settings() -> void:
	if _settings_layer == null:
		_settings_layer = Control.new()
		_settings_layer.set_anchors_preset(Control.PRESET_FULL_RECT)
		var dim := ColorRect.new()
		dim.color = Color(UITheme.INK, 0.55)
		dim.set_anchors_preset(Control.PRESET_FULL_RECT)
		_settings_layer.add_child(dim)
		var card := PanelContainer.new()
		card.name = "Card"
		card.theme_type_variation = &"CardPanel"
		card.position = Vector2(1920 - 96 - 820, 120)
		card.custom_minimum_size = Vector2(820, 0)
		_settings_layer.add_child(card)
		_settings = SettingsPanel.new()
		_settings.back_requested.connect(_close_settings)
		card.add_child(_settings)
		_root.add_child(_settings_layer)
	_settings_layer.visible = true
	_settings_layer.modulate.a = 0.0
	_settings_layer.create_tween().tween_property(_settings_layer, "modulate:a", 1.0, 0.15)
	UITheme.pop_in(_settings_layer.get_node(^"Card"), 0.0, Vector2(60, 0))
	_settings.focus_first.call_deferred()


func _close_settings() -> void:
	_settings.commit()
	var tw := _settings_layer.create_tween()
	tw.tween_property(_settings_layer, "modulate:a", 0.0, 0.14)
	tw.tween_callback(func() -> void: _settings_layer.visible = false)
	if Juice.using_gamepad:
		_first.grab_focus()


# --- Starting a game ------------------------------------------------------------

func _start(path: String) -> void:
	_busy = true
	Transition.change_scene(path)


func _on_solo() -> void:
	_start(LEVEL)


func _on_host() -> void:
	var err := Network.host()
	if err != OK:
		_show_status("Hosten fehlgeschlagen (%s)" % error_string(err))
		return
	_start(LEVEL)


func _on_join() -> void:
	var err := Network.join(_ip.text.strip_edges())
	if err != OK:
		_show_status("Verbindung fehlgeschlagen (%s)" % error_string(err))
		return
	_start(LEVEL)
