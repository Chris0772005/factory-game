extends Node
## Title screen: a live factory turns in the background; play solo, host or join.

const LEVEL := "res://scenes/backyard.tscn"

var _camera: Camera3D
var _angle := 0.0
var _ip: LineEdit
var _status: Label


func _ready() -> void:
	var bg: GameWorld = load(LEVEL).instantiate()
	bg.attract_mode = true
	add_child(bg)
	_camera = Camera3D.new()
	_camera.fov = 50
	add_child(_camera)
	_camera.add_child(OutlinePass.create())
	_build_ui()


func _process(delta: float) -> void:
	_angle += delta * 0.08
	var pos := Vector3(sin(_angle) * 13.0, 7.5, cos(_angle) * 13.0)
	_camera.look_at_from_position(pos, Vector3(0, 0.5, 1.5))


func _build_ui() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.theme = UITheme.get_theme()
	layer.add_child(root)
	var shade := ColorRect.new()
	shade.set_anchors_preset(Control.PRESET_FULL_RECT)
	shade.color = Color(0.1, 0.08, 0.15, 0.25)
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(shade)
	var col := VBoxContainer.new()
	col.position = Vector2(110, 120)
	col.add_theme_constant_override("separation", 18)
	root.add_child(col)
	var title := Label.new()
	title.text = "MOLTEN MATES"
	title.add_theme_font_override("font", UITheme.font(700))
	title.add_theme_font_size_override("font_size", 104)
	title.add_theme_constant_override("outline_size", 22)
	col.add_child(title)
	var sub := Label.new()
	sub.text = "Zeichne es. Gieß es. Zerschlag die Form."
	sub.add_theme_color_override("font_color", UITheme.ACCENT)
	col.add_child(sub)
	col.add_child(_spacer(20))
	col.add_child(_button("Solo spielen", _on_solo))
	col.add_child(_button("Spiel hosten", _on_host))
	var join_row := HBoxContainer.new()
	join_row.add_theme_constant_override("separation", 12)
	_ip = LineEdit.new()
	_ip.text = "127.0.0.1"
	_ip.custom_minimum_size = Vector2(260, 0)
	join_row.add_child(_button("Beitreten", _on_join))
	join_row.add_child(_ip)
	col.add_child(join_row)
	col.add_child(_button("Beenden", func(): get_tree().quit()))
	_status = Label.new()
	_status.add_theme_font_size_override("font_size", 24)
	_status.text = Network.last_message
	Network.last_message = ""
	col.add_child(_status)


func _button(text: String, cb: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(360, 0)
	b.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	b.pressed.connect(cb)
	return b


func _spacer(h: float) -> Control:
	var c := Control.new()
	c.custom_minimum_size.y = h
	return c


func _on_solo() -> void:
	get_tree().change_scene_to_file(LEVEL)


func _on_host() -> void:
	var err := Network.host()
	if err != OK:
		_status.text = "Hosten fehlgeschlagen (%s)" % error_string(err)
		return
	get_tree().change_scene_to_file(LEVEL)


func _on_join() -> void:
	var err := Network.join(_ip.text.strip_edges())
	if err != OK:
		_status.text = "Verbindung fehlgeschlagen (%s)" % error_string(err)
		return
	get_tree().change_scene_to_file(LEVEL)
