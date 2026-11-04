class_name OrdersPanel
extends PanelContainer
## Compact list of the open orders (OrderBoard) on the right edge of the HUD.
## Hidden in levels without an order board.

var world: GameWorld
var _rows: Array[Label] = []
var _board: OrderBoard


func _ready() -> void:
	theme_type_variation = &"HudPill"
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_preset(Control.PRESET_CENTER_RIGHT)
	position = Vector2(-400, -150)
	custom_minimum_size = Vector2(360, 0)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 4)
	add_child(col)
	var title := Label.new()
	title.text = "AUFTRÄGE"
	title.add_theme_font_size_override("font_size", 18)
	title.add_theme_color_override("font_color", UITheme.ACCENT)
	col.add_child(title)
	for i in OrderBoard.SLOTS:
		var l := Label.new()
		l.add_theme_font_size_override("font_size", 20)
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		col.add_child(l)
		_rows.append(l)
	visible = false


func _process(_delta: float) -> void:
	if _board == null or not is_instance_valid(_board):
		_board = get_tree().get_first_node_in_group(&"order_boards") as OrderBoard
		if _board:
			_board.changed.connect(_refresh)
			_refresh()
	visible = _board != null


func _refresh() -> void:
	for i in _rows.size():
		var t := OrderBoard.template(_board.slots[i]) if i < _board.slots.size() else {}
		_rows[i].text = "• %s – %s  (+%d $)" % [t.title, t.need, t.reward] if not t.is_empty() else "• neuer Auftrag kommt gleich…"
		_rows[i].modulate.a = 1.0 if not t.is_empty() else 0.5
