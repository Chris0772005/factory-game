class_name LawHud
extends CanvasLayer
## What the law thinks of the local player: the wanted level ("Fahndung",
## five pips, only while there is heat) under the money counter, and a
## warning at the top of the screen while an officer is getting suspicious
## or giving chase.

var _root: Control
var _heat_pill: PanelContainer
var _pips: Array[ColorRect] = []
var _warn: PanelContainer
var _warn_label: Label
var _warn_bar: ColorRect
var _warn_track: ColorRect
var _pulse := 0.0


func _ready() -> void:
	layer = 2
	_root = Control.new()
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.theme = UITheme.get_theme()
	add_child(_root)
	_heat_pill = PanelContainer.new()
	_heat_pill.theme_type_variation = &"HudPill"
	_heat_pill.position = HUD.SAFE + Vector2(0, 92)
	_heat_pill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(_heat_pill)
	var row := HBoxContainer.new()
	row.add_theme_constant_override(&"separation", 8)
	_heat_pill.add_child(row)
	var title := Label.new()
	title.text = "FAHNDUNG"
	title.add_theme_font_override(&"font", UITheme.font(700))
	title.add_theme_font_size_override(&"font_size", 24)
	title.add_theme_color_override(&"font_color", UITheme.PAPER)
	row.add_child(title)
	for i in 5:
		var pip := ColorRect.new()
		pip.custom_minimum_size = Vector2(16, 16)
		pip.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		row.add_child(pip)
		_pips.append(pip)
	_warn = PanelContainer.new()
	_warn.theme_type_variation = &"HudPill"
	_warn.set_anchors_preset(Control.PRESET_CENTER_TOP)
	_warn.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_warn.position.y = 150
	_warn.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(_warn)
	var col := VBoxContainer.new()
	col.add_theme_constant_override(&"separation", 6)
	_warn.add_child(col)
	_warn_label = Label.new()
	_warn_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_warn_label.add_theme_font_override(&"font", UITheme.font(700))
	_warn_label.add_theme_font_size_override(&"font_size", 30)
	col.add_child(_warn_label)
	_warn_track = ColorRect.new()
	_warn_track.color = Color(1, 1, 1, 0.16)
	_warn_track.custom_minimum_size = Vector2(420, 8)
	col.add_child(_warn_track)
	_warn_bar = ColorRect.new()
	_warn_bar.color = UITheme.BAD
	_warn_bar.size = Vector2(0, 8)
	_warn_track.add_child(_warn_bar)
	_heat_pill.visible = false
	_warn.visible = false


func _process(delta: float) -> void:
	var law := get_parent() as TownLaw
	if law == null:
		return
	var stars := law.stars()
	_heat_pill.visible = stars > 0
	for i in _pips.size():
		_pips[i].color = UITheme.BAD if i < stars else Color(1, 1, 1, 0.18)
	var world := get_tree().get_first_node_in_group(&"world") as GameWorld
	var me := world.local_player() if world else null
	var level := 0.0
	var chased := false
	if me:
		var id := String(me.name).to_int()
		for node in get_tree().get_nodes_in_group(PolicePatrol.GROUP):
			var cop := node as PolicePatrol
			if cop.watching == id:
				level = maxf(level, cop.alert)
				chased = chased or cop.state == PolicePatrol.State.CHASE
	_warn.visible = level > 0.05
	if not _warn.visible:
		return
	_pulse += delta * (9.0 if chased else 4.0)
	if chased:
		_warn_label.text = "POLIZEI! Lauf – oder lass die Ware fallen"
		_warn_label.add_theme_color_override(&"font_color", UITheme.BAD.lerp(UITheme.PAPER, 0.5 + 0.5 * sin(_pulse)))
	else:
		_warn_label.text = "Der Polizist schaut her – weg mit der Ware oder aus der Sicht"
		_warn_label.add_theme_color_override(&"font_color", UITheme.PAPER)
	_warn_bar.size = Vector2(_warn_track.size.x * clampf(level, 0.0, 1.0), 8)
