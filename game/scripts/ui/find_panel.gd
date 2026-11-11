class_name FindPanel
extends PanelContainer
## HUD pill beside the money: income over the last minute ("≈ 190 $/min",
## once money comes in) and the Fundbuch count with one dot per treasure
## (lit when found). Hidden while both are empty.

var world: GameWorld
var _rate: Label
var _gains: Array = []            ## [seconds, amount]
var _last := -1
var _clock := 0.0

var _book: FindBook
var _label: Label
var _dots: Array[ColorRect] = []


func _ready() -> void:
	theme_type_variation = &"HudPill"
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_preset(Control.PRESET_TOP_LEFT)
	offset_left = 300
	offset_top = 64
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	add_child(row)
	_rate = Label.new()
	_rate.add_theme_font_size_override("font_size", 20)
	row.add_child(_rate)
	_label = Label.new()
	_label.add_theme_font_size_override("font_size", 20)
	_label.add_theme_color_override("font_color", UITheme.ACCENT)
	row.add_child(_label)
	for i in FindBook.total():
		var dot := ColorRect.new()
		dot.custom_minimum_size = Vector2(12, 12)
		dot.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		row.add_child(dot)
		_dots.append(dot)
	visible = false


func _process(delta: float) -> void:
	_clock += delta
	if world:
		if _last >= 0 and world.money > _last:
			_gains.append([_clock, world.money - _last])
		_last = world.money
	while not _gains.is_empty() and _clock - float(_gains[0][0]) > 60.0:
		_gains.pop_front()
	var sum := 0
	for g: Array in _gains:
		sum += int(g[1])
	_rate.visible = _gains.size() >= 2
	_rate.text = "≈ %d $/min" % sum
	if _book == null or not is_instance_valid(_book):
		_book = get_tree().get_first_node_in_group(&"find_books") as FindBook
	var n := _book.found.size() if _book else 0
	_label.visible = n > 0
	for d in _dots:
		d.visible = n > 0
	visible = n > 0 or _rate.visible
	if n > 0:
		_label.text = "FUNDBUCH %d/%d" % [n, FindBook.total()]
		for i in _dots.size():
			_dots[i].color = Color("#ffcf3f") if i < n else Color(1, 1, 1, 0.18)
