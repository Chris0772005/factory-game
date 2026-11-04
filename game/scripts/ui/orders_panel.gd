class_name OrdersPanel
extends PanelContainer
## Compact list of the open orders (OrderBoard) in the bottom-right corner:
## per order a title with its bonus and a small line with what it needs.
## Hidden in levels without an order board.

var world: GameWorld
var _titles: Array[Label] = []
var _needs: Array[Label] = []
var _board: OrderBoard


func _ready() -> void:
	theme_type_variation = &"HudPill"
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	offset_left = -470
	offset_right = -36
	offset_bottom = -36
	offset_top = -36
	grow_horizontal = Control.GROW_DIRECTION_BEGIN
	grow_vertical = Control.GROW_DIRECTION_BEGIN
	custom_minimum_size = Vector2(434, 0)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 0)
	add_child(col)
	var title := Label.new()
	title.text = "AUFTRÄGE"
	title.add_theme_font_size_override("font_size", 16)
	title.add_theme_color_override("font_color", UITheme.ACCENT)
	col.add_child(title)
	for i in OrderBoard.SLOTS:
		var t := Label.new()
		t.add_theme_font_size_override("font_size", 19)
		t.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		col.add_child(t)
		_titles.append(t)
		var n := Label.new()
		n.add_theme_font_size_override("font_size", 15)
		n.add_theme_color_override("font_color", Color("#cfc4b4"))
		col.add_child(n)
		_needs.append(n)
	visible = false


func _process(_delta: float) -> void:
	if _board == null or not is_instance_valid(_board):
		_board = get_tree().get_first_node_in_group(&"order_boards") as OrderBoard
		if _board:
			_board.changed.connect(_refresh)
			_refresh()
	visible = _board != null


func _refresh() -> void:
	for i in _titles.size():
		var t := OrderBoard.template(_board.slots[i]) if i < _board.slots.size() else {}
		if t.is_empty():
			_titles[i].text = "Neuer Auftrag kommt gleich…"
			_needs[i].text = ""
			_titles[i].modulate.a = 0.5
		else:
			_titles[i].text = "%s  +%d $" % [t.title, t.reward]
			_needs[i].text = t.need
			_titles[i].modulate.a = 1.0
