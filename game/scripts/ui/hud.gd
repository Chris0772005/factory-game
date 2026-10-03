class_name HUD
extends CanvasLayer
## In-game overlay: money counter that rolls up, plus floating "+$" popups.

var world: GameWorld
var _shown := 0.0
var _label: Label
var _hint: Label
var _bump := 0.0


func _ready() -> void:
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.theme = UITheme.get_theme()
	add_child(root)
	var panel := PanelContainer.new()
	panel.position = Vector2(28, 24)
	root.add_child(panel)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	panel.add_child(row)
	var coin := Label.new()
	coin.text = "$"
	coin.add_theme_color_override("font_color", UITheme.ACCENT)
	coin.add_theme_font_size_override("font_size", 44)
	row.add_child(coin)
	_label = Label.new()
	_label.add_theme_font_size_override("font_size", 44)
	_label.custom_minimum_size.x = 160
	row.add_child(_label)
	_hint = Label.new()
	_hint.add_theme_font_size_override("font_size", 30)
	_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_hint.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	_hint.position = Vector2(-600, -110)
	_hint.size = Vector2(1200, 60)
	root.add_child(_hint)
	if world:
		world.money_changed.connect(func(_m): _bump = 1.0)


func _process(delta: float) -> void:
	if not world:
		return
	_shown = lerpf(_shown, float(world.money), 1.0 - exp(-8.0 * delta))
	if absf(_shown - world.money) < 0.5:
		_shown = world.money
	_label.text = _format(int(round(_shown)))
	_bump = maxf(0.0, _bump - delta * 5.0)
	_label.scale = Vector2.ONE * (1.0 + _bump * 0.15)
	_label.pivot_offset = _label.size * Vector2(0.0, 0.5)
	var me := world.local_player()
	_hint.text = me.current_hint() if me else ""


static func _format(n: int) -> String:
	var s := str(absi(n))
	var out := ""
	while s.length() > 3:
		out = "." + s.substr(s.length() - 3) + out
		s = s.substr(0, s.length() - 3)
	return ("-" if n < 0 else "") + s + out


## Floating world-space popup, e.g. "+5" above a seller.
static func popup(parent: Node3D, pos: Vector3, text: String, color := UITheme.ACCENT) -> void:
	var l := Label3D.new()
	l.text = text
	l.font = UITheme.font(700)
	l.font_size = 96
	l.outline_size = 24
	l.modulate = color
	l.outline_modulate = UITheme.INK
	l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	l.no_depth_test = true
	l.pixel_size = 0.004
	parent.add_child(l)
	l.global_position = pos
	var tw := l.create_tween().set_parallel()
	tw.tween_property(l, "global_position", pos + Vector3(0, 1.4, 0), 1.1).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	tw.tween_property(l, "modulate:a", 0.0, 0.5).set_delay(0.6)
	tw.chain().tween_callback(l.queue_free)
