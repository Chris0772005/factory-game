class_name PauseMenu
extends Control
## Esc / Start menu over the live game: frosted backdrop, a card with Fortsetzen /
## Einstellungen / Verlassen, and a controls legend with key glyphs. Solo games pause
## the tree; online games keep running (the worker just stops taking input).
## "Verlassen" asks once more, then closes the iris and calls Network.leave().

signal opened
signal closed

const BLUR_SHADER := preload("res://assets/ui/shaders/backdrop_blur.gdshader")
const CONTROLS := [
	[&"move", "Laufen"], [&"sprint", "Sprinten"], [&"jump", "Springen"],
	[&"grab", "Greifen / Ablegen"], [&"throw", "Werfen"], [&"interact", "Benutzen (halten: gießen)"],
]

var world: GameWorld
var is_open := false
## Solo games pause the tree while the menu is open (screenshot runs turn it off).
var pause_tree := true

var _backdrop: ColorRect
var _blur: ShaderMaterial
var _card: PanelContainer
var _main: VBoxContainer
var _settings: SettingsPanel
var _legend: PanelContainer
var _resume: Button
var _leave: Button
var _leave_armed := false
var _paused_tree := false
var _locked_player: Player
var _tween: Tween
var _amount := 0.0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	visible = false
	_backdrop = ColorRect.new()
	_backdrop.set_anchors_preset(Control.PRESET_FULL_RECT)
	_blur = ShaderMaterial.new()
	_blur.shader = BLUR_SHADER
	_backdrop.material = _blur
	add_child(_backdrop)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(center)
	var layout := HBoxContainer.new()
	layout.add_theme_constant_override("separation", 28)
	center.add_child(layout)
	_card = PanelContainer.new()
	_card.theme_type_variation = &"CardPanel"
	_card.custom_minimum_size = Vector2(560, 0)
	layout.add_child(_card)
	_main = VBoxContainer.new()
	_main.add_theme_constant_override("separation", 16)
	_card.add_child(_main)
	var title := Label.new()
	title.text = "PAUSE"
	title.add_theme_font_override("font", UITheme.display_font())
	title.add_theme_font_size_override("font_size", 84)
	title.add_theme_constant_override("outline_size", 16)
	title.add_theme_color_override("font_color", Color.WHITE)
	title.add_theme_color_override("font_shadow_color", Color("#4a1606"))
	title.add_theme_constant_override("shadow_offset_y", 6)
	title.add_theme_constant_override("shadow_offset_x", 0)
	title.add_theme_constant_override("shadow_outline_size", 16)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var molten := ShaderMaterial.new()
	molten.shader = MoltenLogo.SHADER
	var line_h := UITheme.display_font().get_height(84)
	molten.set_shader_parameter(&"glyph_top", line_h * 0.2)
	molten.set_shader_parameter(&"glyph_bottom", line_h * 0.8)
	molten.set_shader_parameter(&"wobble", 1.0)
	title.material = molten
	_main.add_child(title)
	var sub := Label.new()
	sub.name = "Session"
	sub.theme_type_variation = &"Muted"
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_main.add_child(sub)
	_main.add_child(_spacer(10))
	_resume = _button("Fortsetzen", &"BigButton", close)
	_button("Einstellungen", &"SecondaryButton", _show_settings)
	_leave = _button("Verlassen", &"SecondaryButton", _on_leave)

	_legend = PanelContainer.new()
	_legend.theme_type_variation = &"CardPanel"
	_legend.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	layout.add_child(_legend)
	_build_legend()
	Juice.device_changed.connect(_on_device_changed)


func _unhandled_input(event: InputEvent) -> void:
	var toggle := false
	if event is InputEventKey and event.pressed and not event.echo and (event as InputEventKey).physical_keycode == KEY_ESCAPE:
		toggle = true
	elif event is InputEventJoypadButton and event.pressed and (event as InputEventJoypadButton).button_index == JOY_BUTTON_START:
		toggle = true
	elif is_open and event.is_action_pressed(&"ui_cancel"):
		toggle = true
	if not toggle:
		return
	if is_open:
		if _settings and _settings.visible:
			_hide_settings()
		else:
			close()
		get_viewport().set_input_as_handled()
	elif _can_open():
		open()
		get_viewport().set_input_as_handled()


func _can_open() -> bool:
	if Transition.busy():
		return false
	var me := world.local_player() if world else null
	return me == null or not me.ui_locked


func open() -> void:
	if is_open:
		return
	is_open = true
	Juice.menu_open = true
	visible = true
	_leave_armed = false
	_leave.text = "Verlassen"
	(_main.get_node(^"Session") as Label).text = _session_text()
	_locked_player = world.local_player() if world else null
	if _locked_player:
		_locked_player.ui_locked = true
	_paused_tree = pause_tree and not Network.is_online() and not _debug_no_pause()
	if _paused_tree:
		get_tree().paused = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_main.visible = true
	_legend.visible = true
	if _settings:
		_settings.visible = false
	_animate(true)
	UITheme.pop_in(_card, 0.02, Vector2(0, 30))
	UITheme.pop_in(_legend, 0.08, Vector2(0, 30))
	for i in _main.get_child_count():
		var c := _main.get_child(i)
		if c is Button:
			UITheme.pop_in(c, 0.06 + i * 0.035, Vector2(-24, 0))
	Sfx.play_ui(&"pop", -8.0)
	if Juice.using_gamepad:
		_resume.grab_focus.call_deferred()
	opened.emit()


func close() -> void:
	if not is_open:
		return
	is_open = false
	Juice.menu_open = false
	if _settings and _settings.visible:
		_settings.commit()
	if _paused_tree:
		get_tree().paused = false
		_paused_tree = false
	if is_instance_valid(_locked_player):
		_locked_player.ui_locked = false
	_locked_player = null
	if DisplayServer.get_name() != "headless":
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	var vp := get_viewport()
	var focus := vp.gui_get_focus_owner() if vp else null
	if focus:
		focus.release_focus()
	_animate(false)
	closed.emit()


func _exit_tree() -> void:
	if _paused_tree and is_inside_tree():
		get_tree().paused = false
	if is_open:
		Juice.menu_open = false


func _animate(show: bool) -> void:
	if _tween:
		_tween.kill()
	_tween = create_tween().set_parallel()
	_tween.tween_method(_set_amount, _amount, 1.0 if show else 0.0, 0.22 if show else 0.16) \
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	if not show:
		_tween.tween_property(_card, "modulate:a", 0.0, 0.12)
		_tween.tween_property(_legend, "modulate:a", 0.0, 0.12)
		_tween.chain().tween_callback(func() -> void: visible = false)


func _set_amount(a: float) -> void:
	_amount = a
	_blur.set_shader_parameter(&"amount", a)
	_backdrop.modulate.a = clampf(a * 1.5, 0.0, 1.0)


func _show_settings() -> void:
	if _settings == null:
		_settings = SettingsPanel.new()
		_settings.back_requested.connect(_hide_settings)
		_card.add_child(_settings)
	_main.visible = false
	_legend.visible = false
	_settings.visible = true
	_leave_armed = false
	UITheme.pop_in(_settings, 0.0, Vector2(40, 0))
	_settings.focus_first.call_deferred()


func _hide_settings() -> void:
	if _settings == null:
		return
	_settings.commit()
	_settings.visible = false
	_main.visible = true
	_legend.visible = true
	UITheme.pop_in(_main, 0.0, Vector2(-40, 0))
	UITheme.pop_in(_legend, 0.05)
	if Juice.using_gamepad:
		_resume.grab_focus.call_deferred()


func _on_leave() -> void:
	if not _leave_armed:
		_leave_armed = true
		_leave.text = "Wirklich verlassen?"
		_leave.add_theme_color_override("font_color", UITheme.BAD.lightened(0.25))
		Juice.punch(_leave, 0.06)
		get_tree().create_timer(3.0, true, false, true).timeout.connect(func() -> void:
			if is_instance_valid(_leave) and _leave_armed:
				_leave_armed = false
				_leave.text = "Verlassen"
				_leave.remove_theme_color_override("font_color")
		)
		return
	_leave.disabled = true
	if _paused_tree:
		get_tree().paused = false
		_paused_tree = false
	Transition.cover(func() -> void: Network.leave())


func _session_text() -> String:
	if not Network.is_online():
		return "Hinterhof · Solo"
	var players := get_tree().get_nodes_in_group(&"players").size()
	var role := "Host" if multiplayer.is_server() else "Gast"
	return "Hinterhof · %s · %d Spieler" % [role, players]


func _on_device_changed(_pad: bool) -> void:
	_build_legend()


## Controls overview with glyphs for the device used last (rebuilt when it changes).
func _build_legend() -> void:
	for c in _legend.get_children():
		_legend.remove_child(c)
		c.queue_free()
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 12)
	_legend.add_child(col)
	var head := Label.new()
	head.text = "STEUERUNG"
	head.theme_type_variation = &"Small"
	head.add_theme_color_override("font_color", UITheme.ACCENT)
	head.add_theme_font_override("font", UITheme.font(700))
	col.add_child(head)
	for entry in CONTROLS:
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 8)
		var keys := HBoxContainer.new()
		keys.add_theme_constant_override("separation", 4)
		keys.custom_minimum_size.x = 196
		if entry[0] == &"move":
			if Juice.using_gamepad:
				keys.add_child(KeyPrompt.pad_glyph("LS", 38.0))
			else:
				for k in ["W", "A", "S", "D"]:
					var cap := KeyPrompt.new()
					cap.cap = 38.0
					keys.add_child(cap.setup(k))
		else:
			keys.add_child(KeyPrompt.for_action(entry[0], 38.0))
		row.add_child(keys)
		var l := Label.new()
		l.text = entry[1]
		l.add_theme_font_size_override("font_size", UITheme.SIZE_HINT - 2)
		l.add_theme_constant_override("outline_size", 0)
		l.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		row.add_child(l)
		col.add_child(row)


func _button(text: String, variation: StringName, cb: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.theme_type_variation = variation
	b.custom_minimum_size = Vector2(440, 0)
	b.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	b.pressed.connect(cb)
	UITheme.juice_button(b)
	_main.add_child(b)
	return b


func _spacer(h: float) -> Control:
	var c := Control.new()
	c.custom_minimum_size.y = h
	return c


## Screenshot runs (`--ui=pause`) keep the tree running so the shot tool still ticks.
static func _debug_no_pause() -> bool:
	return "--ui=pause" in OS.get_cmdline_user_args()
