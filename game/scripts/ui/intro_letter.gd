class_name IntroLetter
extends Control
## The first thing a new game shows: Onkel Heinz's letter on paper. It says
## why you are here, how the foundry earns money (four steps) and where it
## leads, then points at the yellow arrow. One button, then the yard.

signal closed

const STEPS := [["1", "Schrott sammeln", "Im Schrottberg wühlen"], ["2", "Einschmelzen", "Ofen füllen, Blasebalg treten"],
	["3", "Gießen", "Modell zeichnen, Form füllen"], ["4", "Verkaufen", "Ab in die Verkaufskiste"]]


## Opens the letter for a brand-new game (nothing dug, nothing sold, no money).
static func open_if_new(world: GameWorld) -> void:
	if world == null or world.attract_mode or world.money > 0 or DisplayServer.get_name() == "headless":
		return
	var guide := world.get_tree().get_first_node_in_group(&"guides") as Guide
	if guide == null or guide.index > 0 or int(guide.stats.get("digs", 0)) > 0:
		return
	if not world.get_tree().get_first_node_in_group(&"scrap_piles") or world.upgrade_tier() > 0:
		return
	var shot := false
	for arg in OS.get_cmdline_user_args():
		shot = shot or arg.begins_with("--shot=")
	if shot and not "--intro" in OS.get_cmdline_user_args():
		return
	var me := world.local_player()
	if me:
		me.ui_locked = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	var layer := CanvasLayer.new()
	layer.name = "IntroLayer"
	layer.layer = 18
	world.add_child(layer)
	var letter := IntroLetter.new()
	layer.add_child(letter)
	letter.closed.connect(func() -> void:
		layer.queue_free()
		var p := world.local_player()
		if p:
			p.ui_locked = false
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED)


func _ready() -> void:
	theme = UITheme.get_theme()
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var shade := ColorRect.new()
	shade.color = Color(0.06, 0.04, 0.07, 0.72)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(shade)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(center)
	var paper := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color("#f6ead2")
	sb.border_color = Color("#d9c49a")
	sb.set_border_width_all(3)
	sb.set_corner_radius_all(10)
	sb.shadow_color = Color(0, 0, 0, 0.45)
	sb.shadow_size = 28
	sb.shadow_offset = Vector2(0, 10)
	sb.content_margin_left = 56
	sb.content_margin_right = 56
	sb.content_margin_top = 40
	sb.content_margin_bottom = 40
	paper.add_theme_stylebox_override("panel", sb)
	paper.custom_minimum_size = Vector2(980, 0)
	paper.rotation_degrees = -0.8
	center.add_child(paper)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 14)
	paper.add_child(col)
	var ink := Color("#3a2c22")
	col.add_child(_text("Mein Junge,", 40, ink, StationKit.hand_font()))
	col.add_child(_text("meine alte Hinterhof-Gießerei gehört jetzt dir. Viel ist es nicht: ein Ofen, ein Haufen Schrott und zwei Formkästen. Aber daraus machst du Geld. So geht's:", 30, ink, StationKit.hand_font()))
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 14)
	col.add_child(row)
	for step: Array in STEPS:
		var card := PanelContainer.new()
		var cb := StyleBoxFlat.new()
		cb.bg_color = Color("#ecd9b4")
		cb.set_corner_radius_all(12)
		cb.content_margin_left = 14
		cb.content_margin_right = 14
		cb.content_margin_top = 12
		cb.content_margin_bottom = 12
		card.add_theme_stylebox_override("panel", cb)
		card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(card)
		var c := VBoxContainer.new()
		c.add_theme_constant_override("separation", 0)
		card.add_child(c)
		c.add_child(_text(step[0], 44, Color("#c2571a"), UITheme.display_font()))
		c.add_child(_text(step[1], 26, ink, UITheme.font(700)))
		c.add_child(_text(step[2], 19, Color("#6b5847"), UITheme.font(500)))
	col.add_child(_text("Vom Geld kaufst du Werkzeug, dann Maschinen – bis die Hallen von allein laufen. Und eines Tages gießt du die Kaiserglocke für den Dom.", 30, ink, StationKit.hand_font()))
	col.add_child(_text("Folge dem gelben Pfeil ▼. Oben rechts steht immer, was jetzt dran ist.", 30, Color("#a2461a"), StationKit.hand_font()))
	col.add_child(_text("Dein Onkel Heinz", 36, ink, StationKit.hand_font(), HORIZONTAL_ALIGNMENT_RIGHT))
	var button := Button.new()
	button.text = "Los geht's"
	button.custom_minimum_size = Vector2(280, 64)
	button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	UITheme.juice_button(button)
	button.pressed.connect(func() -> void: closed.emit())
	col.add_child(button)
	button.grab_focus.call_deferred()
	UITheme.pop_in(paper)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed(&"interact") or event.is_action_pressed(&"ui_accept"):
		get_viewport().set_input_as_handled()
		closed.emit()


func _text(t: String, size: int, color: Color, font: Font, align := HORIZONTAL_ALIGNMENT_LEFT) -> Label:
	var l := Label.new()
	l.text = t
	l.add_theme_font_override("font", font)
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	l.add_theme_constant_override("outline_size", 0)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.horizontal_alignment = align
	return l
