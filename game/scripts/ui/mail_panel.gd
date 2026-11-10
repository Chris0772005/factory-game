class_name MailPanel
extends PanelContainer
## Bottom-left: the current letter from Onkel Heinz (Guide). A new letter
## pops open with its full text for a while, then folds down to the goal
## line, which stays on screen as the thing to do next.

const OPEN_FOR := 14.0

var world: GameWorld
var _guide: Guide
var _head: Label
var _text: Label
var _goal: Label
var _open := 0.0


func _ready() -> void:
	theme_type_variation = &"HudPill"
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	offset_left = 36
	offset_bottom = -36
	offset_top = -36
	grow_vertical = Control.GROW_DIRECTION_BEGIN
	custom_minimum_size = Vector2(520, 0)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 2)
	add_child(col)
	_head = Label.new()
	_head.text = "✉  POST VON ONKEL HEINZ"
	_head.add_theme_font_size_override("font_size", 16)
	_head.add_theme_color_override("font_color", UITheme.ACCENT)
	col.add_child(_head)
	_text = Label.new()
	_text.add_theme_font_size_override("font_size", 19)
	_text.add_theme_color_override("font_color", Color("#e9dfcf"))
	_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_text.custom_minimum_size = Vector2(500, 0)
	col.add_child(_text)
	_goal = Label.new()
	_goal.add_theme_font_size_override("font_size", 21)
	_goal.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_goal.custom_minimum_size = Vector2(500, 0)
	col.add_child(_goal)
	visible = false


func _process(delta: float) -> void:
	if _guide == null or not is_instance_valid(_guide):
		_guide = get_tree().get_first_node_in_group(&"guides") as Guide
		if _guide == null:
			visible = false
			return
		_guide.changed.connect(_on_changed)
		_on_changed(true)
	visible = true
	_open = maxf(0.0, _open - delta)
	_text.visible = _open > 0.0
	_head.text = "✉  POST VON ONKEL HEINZ" if _open > 0.0 else "ZIEL"


func _on_changed(new_letter: bool) -> void:
	var l := _guide.letter()
	_text.text = "„%s“" % l.text
	_goal.text = "➜ %s" % l.goal
	if new_letter:
		_open = OPEN_FOR
		Sfx.play_ui(&"pop")
		UITheme.pop_in(self)
