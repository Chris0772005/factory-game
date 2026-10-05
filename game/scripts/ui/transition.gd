class_name Transition
extends CanvasLayer
## Scene transitions: an ink iris with a molten rim closes over the screen, the scene
## changes underneath, and the iris opens again once the new scene has settled.
## Lives on the root viewport, so it survives scene changes. Blocks input while covered.
##   Transition.change_scene(path)   cover → change_scene_to_file → reveal
##   Transition.cover(callback)      cover, then call `callback` (e.g. Network.leave)
##   Transition.reveal()             open from fully covered (menus call this on _ready)

const SHADER := preload("res://assets/ui/shaders/iris.gdshader")
const COVER_TIME := 0.38
const REVEAL_TIME := 0.5

static var _instance: Transition

var _rect: ColorRect
var _mat: ShaderMaterial
var _tween: Tween
var _progress := 0.0
var _reveal_on_change := false


static func instance() -> Transition:
	if _instance and is_instance_valid(_instance):
		return _instance
	var tree := Engine.get_main_loop() as SceneTree
	_instance = Transition.new()
	_instance.name = "Transition"
	tree.root.add_child.call_deferred(_instance)
	return _instance


## True while the screen is (partly) covered.
static func busy() -> bool:
	return _instance != null and is_instance_valid(_instance) and _instance._progress > 0.001


static func change_scene(path: String) -> void:
	var t := instance()
	t._cover.call_deferred(func() -> void:
		t._reveal_on_change = true
		t.get_tree().change_scene_to_file(path)
	)


static func cover(callback: Callable) -> void:
	instance()._cover.call_deferred(callback)


## Opens the iris. When nothing is covering the screen yet, starts from fully covered.
static func reveal() -> void:
	var t := instance()
	if t._progress < 0.5:
		t._set_progress(1.0)
	t._open.call_deferred()


func _init() -> void:
	layer = 120
	process_mode = Node.PROCESS_MODE_ALWAYS
	_rect = ColorRect.new()
	_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	_mat = ShaderMaterial.new()
	_mat.shader = SHADER
	_rect.material = _mat
	_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_rect)
	_set_progress(0.0)


func _ready() -> void:
	get_tree().scene_changed.connect(_on_scene_changed)


func _cover(callback: Callable) -> void:
	if _tween:
		_tween.kill()
	_rect.mouse_filter = Control.MOUSE_FILTER_STOP
	_tween = create_tween()
	_tween.tween_method(_set_progress, _progress, 1.0, COVER_TIME * (1.0 - _progress) + 0.01) \
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	_tween.tween_interval(0.05)
	_tween.tween_callback(callback)


func _on_scene_changed() -> void:
	if not _reveal_on_change:
		return
	_reveal_on_change = false
	# Give the new scene two frames to build before opening (first frames can hitch).
	await get_tree().process_frame
	await get_tree().process_frame
	_open()


func _open() -> void:
	if _tween:
		_tween.kill()
	_tween = create_tween()
	_tween.tween_method(_set_progress, _progress, 0.0, REVEAL_TIME).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	_tween.tween_callback(func() -> void: _rect.mouse_filter = Control.MOUSE_FILTER_IGNORE)


func _set_progress(p: float) -> void:
	_progress = p
	_mat.set_shader_parameter(&"progress", p)
	_rect.visible = p > 0.0005
