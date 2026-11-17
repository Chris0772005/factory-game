class_name UpgradeShop
extends Control
## Overlay listing all upgrades with buy buttons.

signal closed

var upgrades: Upgrades
var world: GameWorld
var _list: GridContainer
var _money: Label


func _ready() -> void:
	theme = UITheme.get_theme()
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var shade := ColorRect.new()
	shade.color = Color(0.02, 0.022, 0.026, 0.95)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(shade)
	var frame := MarginContainer.new()
	frame.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "right"]:
		frame.add_theme_constant_override("margin_" + side, 150)
	frame.add_theme_constant_override("margin_top", 80)
	frame.add_theme_constant_override("margin_bottom", 70)
	add_child(frame)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 18)
	frame.add_child(col)
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 24)
	col.add_child(head)
	var title := Label.new()
	title.text = "AUSBAU"
	title.add_theme_font_override("font", UITheme.font(700))
	title.add_theme_font_size_override("font_size", 46)
	title.add_theme_color_override("font_color", UITheme.ACCENT)
	title.add_theme_constant_override("outline_size", 0)
	head.add_child(title)
	var sub := Label.new()
	sub.text = "Werkstatt-Katalog"
	sub.theme_type_variation = &"Muted"
	sub.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sub.size_flags_vertical = Control.SIZE_SHRINK_END
	head.add_child(sub)
	_money = Label.new()
	_money.add_theme_font_override("font", UITheme.font(700))
	_money.add_theme_font_size_override("font_size", 40)
	_money.add_theme_constant_override("outline_size", 0)
	head.add_child(_money)
	var rule := ColorRect.new()
	rule.color = Color(UITheme.PAPER, 0.14)
	rule.custom_minimum_size = Vector2(0, 1)
	col.add_child(rule)
	# Later halls offer twenty-odd upgrades: the grid scrolls, newest first.
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	col.add_child(scroll)
	_list = GridContainer.new()
	_list.columns = 3
	_list.add_theme_constant_override("h_separation", 14)
	_list.add_theme_constant_override("v_separation", 14)
	_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(_list)
	var foot := HBoxContainer.new()
	col.add_child(foot)
	var hint := Label.new()
	hint.text = "ESC  Schließen"
	hint.theme_type_variation = &"Muted"
	hint.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	foot.add_child(hint)
	var close := Button.new()
	close.text = "Schließen"
	close.theme_type_variation = &"SecondaryButton"
	close.pressed.connect(func(): closed.emit())
	foot.add_child(close)
	upgrades.changed.connect(_refresh)
	world.money_changed.connect(func(_m): _refresh())
	_refresh()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed(&"ui_cancel"):
		closed.emit()
		get_viewport().set_input_as_handled()


## This hall's upgrades first, then older ones still to buy, bought ones last.
func _ordered() -> Array:
	var tier := world.upgrade_tier()
	var entries := Upgrades.catalog_for(tier, world.is_scrap_hall()).filter(func(u: Dictionary) -> bool: return upgrades.offered(u) or upgrades.has(u.id))
	var rank := func(u: Dictionary) -> int:
		return (2 if upgrades.has(u.id) else 0) + (0 if int(u.get("tier", 0)) == tier else 1)
	var out := []
	for r in 4:
		for u in entries:
			if rank.call(u) == r:
				out.append(u)
	return out


func _refresh() -> void:
	_money.text = "%s $" % HUD._format(world.money)
	for c in _list.get_children():
		c.queue_free()
	for u in _ordered():
		_list.add_child(_card(u))


## One upgrade: name, what it does, price. Owned ones are dimmed and ticked,
## affordable ones carry the amber bar.
func _card(u: Dictionary) -> Control:
	var owned := upgrades.has(u.id)
	var can := not owned and upgrades.can_buy(u.id)
	var card := PanelContainer.new()
	var box := UITheme.panel_box(3, 16)
	box.bg_color = Color(0.085, 0.09, 0.1, 0.96) if not owned else Color(0.06, 0.064, 0.07, 0.8)
	box.set_border_width_all(0)
	box.border_width_top = 3
	box.border_color = UITheme.ACCENT if can else Color(UITheme.PAPER, 0.12 if not owned else 0.06)
	card.add_theme_stylebox_override("panel", box)
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	card.custom_minimum_size = Vector2(0, 178)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 6)
	card.add_child(col)
	var name_l := Label.new()
	name_l.text = String(u.name).to_upper()
	name_l.add_theme_font_override("font", UITheme.font(700))
	name_l.add_theme_font_size_override("font_size", 26)
	name_l.add_theme_constant_override("outline_size", 0)
	name_l.add_theme_color_override("font_color", UITheme.PAPER if not owned else UITheme.MUTED)
	col.add_child(name_l)
	var desc := Label.new()
	desc.text = u.desc
	desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	desc.add_theme_font_size_override("font_size", 20)
	desc.add_theme_constant_override("outline_size", 0)
	desc.add_theme_color_override("font_color", UITheme.MUTED)
	desc.size_flags_vertical = Control.SIZE_EXPAND_FILL
	col.add_child(desc)
	var row := HBoxContainer.new()
	col.add_child(row)
	var price := Label.new()
	price.text = "IM BESITZ" if owned else "%s $" % HUD._format(int(u.cost))
	price.add_theme_font_override("font", UITheme.font(700))
	price.add_theme_font_size_override("font_size", 28)
	price.add_theme_constant_override("outline_size", 0)
	price.add_theme_color_override("font_color", UITheme.GOOD if owned else (UITheme.ACCENT if can else UITheme.MUTED))
	price.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(price)
	if not owned:
		var btn := Button.new()
		btn.text = "Kaufen"
		btn.add_theme_font_size_override("font_size", 24)
		btn.disabled = not can
		btn.pressed.connect(func(): upgrades.request_buy(u.id))
		row.add_child(btn)
	return card
