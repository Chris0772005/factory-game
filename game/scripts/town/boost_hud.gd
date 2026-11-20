class_name BoostHud
extends CanvasLayer
## What the crew still has in it from the diner: a pill at the bottom left for each thing, with
## what it does and the time left. Nothing shows while nothing is on.

var _root: VBoxContainer
var _pills := {}


func _ready() -> void:
	layer = 2
	var frame := Control.new()
	frame.set_anchors_preset(Control.PRESET_FULL_RECT)
	frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	frame.theme = UITheme.get_theme()
	add_child(frame)
	_root = VBoxContainer.new()
	_root.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	_root.grow_vertical = Control.GROW_DIRECTION_BEGIN
	_root.position = Vector2(HUD.SAFE.x, -HUD.SAFE.y)
	_root.alignment = BoxContainer.ALIGNMENT_END
	_root.add_theme_constant_override(&"separation", 8)
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	frame.add_child(_root)


func _process(_delta: float) -> void:
	var boost := get_parent() as CrewBoost
	if boost == null:
		return
	for kind: StringName in CrewBoost.MENU:
		var seconds := float(boost.left.get(kind, 0.0))
		if seconds <= 0.0:
			if _pills.has(kind):
				(_pills[kind] as Control).queue_free()
				_pills.erase(kind)
			continue
		if not _pills.has(kind):
			_pills[kind] = _pill(kind)
		var label := (_pills[kind] as Control).get_meta(&"time") as Label
		label.text = "%d:%02d" % [int(seconds) / 60, int(seconds) % 60]


func _pill(kind: StringName) -> Control:
	var item: Dictionary = CrewBoost.MENU[kind]
	var pill := PanelContainer.new()
	pill.theme_type_variation = &"HudPill"
	pill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var row := HBoxContainer.new()
	row.add_theme_constant_override(&"separation", 10)
	pill.add_child(row)
	var title := Label.new()
	title.text = String(item.name).to_upper()
	title.add_theme_font_override(&"font", UITheme.font(700))
	title.add_theme_font_size_override(&"font_size", 24)
	title.add_theme_color_override(&"font_color", UITheme.ACCENT)
	row.add_child(title)
	var what := Label.new()
	what.text = String(item.text)
	what.add_theme_font_size_override(&"font_size", 22)
	what.add_theme_color_override(&"font_color", UITheme.PAPER)
	row.add_child(what)
	var time := Label.new()
	time.add_theme_font_override(&"font", UITheme.font(700))
	time.add_theme_font_size_override(&"font_size", 24)
	time.add_theme_color_override(&"font_color", UITheme.PAPER)
	row.add_child(time)
	pill.set_meta(&"time", time)
	_root.add_child(pill)
	return pill
