class_name FinaleScreen
extends Control
## The ending: shown to everyone once the Kaiserglocke is delivered. A slow
## fade over the still running hall, the line from the bucket furnace to
## the cathedral bell, the crew, the credits, and "Weiterspielen" (the save
## carries on; series orders and new bells keep coming).

signal closed

var crew: Array[String] = []
## Skip the fade-in (screenshots).
var instant := false

var _shown := false


## Opens the finale on this peer (locks the local worker until closed).
static func open(world: GameWorld, crew_names: Array[String], skip_fade := false) -> void:
	if world.get_node_or_null(^"FinaleLayer"):
		return
	var me := world.local_player()
	if me:
		me.ui_locked = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	var layer := CanvasLayer.new()
	layer.name = "FinaleLayer"
	layer.layer = 20
	world.add_child(layer)
	var screen := FinaleScreen.new()
	screen.crew = crew_names
	screen.instant = skip_fade
	layer.add_child(screen)
	screen.closed.connect(func() -> void:
		layer.queue_free()
		var p := world.local_player()
		if p:
			p.ui_locked = false
		if DisplayServer.get_name() != "headless":
			Input.mouse_mode = Input.MOUSE_MODE_CAPTURED)


func _ready() -> void:
	theme = UITheme.get_theme()
	# Offsets too, not just anchors: under a CanvasLayer the rect is otherwise
	# empty and the column would centre on the top-left corner.
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var shade := ColorRect.new()
	shade.color = Color(0.05, 0.03, 0.04, 0.0)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(shade)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(center)
	var col := VBoxContainer.new()
	col.alignment = BoxContainer.ALIGNMENT_CENTER
	col.add_theme_constant_override("separation", 18)
	center.add_child(col)
	var lines: Array[Control] = []
	lines.append(_label("MOLTEN MATES", 110, UITheme.MOLTEN_HOT, true))
	lines.append(_label("Die Kaiserglocke läutet.", UITheme.SIZE_H2, UITheme.PAPER, true))
	lines.append(_label("Vom Eimerofen im Hinterhof über Garage und Glockengießerei\nbis zur größten Glocke der Stadt – gegossen von:", UITheme.SIZE_TEXT, UITheme.MUTED))
	lines.append(_label(" · ".join(crew) if not crew.is_empty() else "euch", UITheme.SIZE_H2, UITheme.ACCENT, true))
	lines.append(_label("Danke fürs Spielen!", UITheme.SIZE_TEXT, UITheme.PAPER))
	lines.append(_label("3D-Modelle: KayKit von Kay Lousberg und Kenney (CC0) · Schriften: Fredoka, Lilita One (OFL)\nGeräusche und Glockenklang: eigene Synthese · Engine: Godot", UITheme.SIZE_SMALL, UITheme.MUTED))
	var button := Button.new()
	button.text = "Weiterspielen"
	button.custom_minimum_size = Vector2(360, 72)
	button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	button.pressed.connect(func() -> void: closed.emit())
	UITheme.juice_button(button)
	lines.append(button)
	for c in lines:
		col.add_child(c)
		c.modulate.a = 0.0 if not instant else 1.0
	if instant:
		shade.color.a = 0.86
		_shown = true
		return
	var tw := create_tween()
	tw.tween_property(shade, "color:a", 0.86, 1.6)
	for i in lines.size():
		tw.tween_property(lines[i], "modulate:a", 1.0, 0.7).set_delay(0.35 if i > 0 else 0.2)
	tw.tween_callback(func() -> void:
		_shown = true
		button.grab_focus())


func _label(text: String, size: int, color: Color, display := false) -> Label:
	var l := Label.new()
	l.text = text
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	if display:
		l.add_theme_font_override("font", UITheme.display_font())
	return l


func _unhandled_input(event: InputEvent) -> void:
	if _shown and event.is_action_pressed(&"ui_cancel"):
		closed.emit()
		get_viewport().set_input_as_handled()
