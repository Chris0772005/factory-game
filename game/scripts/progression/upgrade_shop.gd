class_name UpgradeShop
extends Control
## Overlay listing all upgrades with buy buttons.

signal closed

var upgrades: Upgrades
var world: GameWorld
var _list: VBoxContainer
var _money: Label


func _ready() -> void:
	theme = UITheme.get_theme()
	set_anchors_preset(Control.PRESET_FULL_RECT)
	var shade := ColorRect.new()
	shade.color = Color(0.05, 0.04, 0.08, 0.6)
	shade.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(shade)
	var panel := PanelContainer.new()
	panel.set_anchors_preset(Control.PRESET_CENTER)
	panel.custom_minimum_size = Vector2(980, 0)
	panel.position = Vector2(-490, -380)
	add_child(panel)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 14)
	panel.add_child(col)
	var head := HBoxContainer.new()
	col.add_child(head)
	var title := Label.new()
	title.text = "Werkstatt-Katalog"
	title.add_theme_font_size_override("font_size", 52)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(title)
	_money = Label.new()
	_money.add_theme_color_override("font_color", UITheme.ACCENT)
	_money.add_theme_font_size_override("font_size", 40)
	head.add_child(_money)
	_list = VBoxContainer.new()
	_list.add_theme_constant_override("separation", 10)
	col.add_child(_list)
	var close := Button.new()
	close.text = "Schließen"
	close.size_flags_horizontal = Control.SIZE_SHRINK_END
	close.pressed.connect(func(): closed.emit())
	col.add_child(close)
	upgrades.changed.connect(_refresh)
	world.money_changed.connect(func(_m): _refresh())
	_refresh()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed(&"ui_cancel"):
		closed.emit()
		get_viewport().set_input_as_handled()


func _refresh() -> void:
	_money.text = "%s $" % HUD._format(world.money)
	for c in _list.get_children():
		c.queue_free()
	for u in Upgrades.CATALOG:
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 16)
		var text := VBoxContainer.new()
		text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var name_l := Label.new()
		name_l.text = u.name
		name_l.add_theme_font_size_override("font_size", 32)
		var desc := Label.new()
		desc.text = u.desc
		desc.add_theme_font_size_override("font_size", 22)
		desc.add_theme_color_override("font_color", Color("#d9cfc0"))
		text.add_child(name_l)
		text.add_child(desc)
		row.add_child(text)
		var btn := Button.new()
		btn.custom_minimum_size = Vector2(220, 0)
		if upgrades.has(u.id):
			btn.text = "Gekauft"
			btn.disabled = true
		else:
			btn.text = "%d $" % u.cost
			btn.disabled = not upgrades.can_buy(u.id)
			btn.pressed.connect(func(): upgrades.request_buy(u.id))
		row.add_child(btn)
		_list.add_child(row)
