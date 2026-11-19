extends Node
## Saves a screenshot and quits when started with `-- --shot=<path> [--frames=N] [--scale=0.6]`.
## Used to check visuals from the command line without a GPU. `--scale` renders the 3D picture at
## that share of the size (a quick check takes a third of the time at 0.6).

var _path := ""
var _frames := 30
var _scale := 1.0


func _ready() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--shot="):
			_path = arg.trim_prefix("--shot=")
		elif arg.begins_with("--frames="):
			_frames = int(arg.trim_prefix("--frames="))
		elif arg.begins_with("--scale="):
			_scale = clampf(float(arg.trim_prefix("--scale=")), 0.25, 1.0)
	if _path.is_empty():
		set_process(false)


func _process(_delta: float) -> void:
	if _scale < 1.0:
		# The game's graphics settings set the scale when a level starts: hold ours.
		get_tree().root.scaling_3d_scale = _scale
		get_tree().root.scaling_3d_mode = Viewport.SCALING_3D_MODE_BILINEAR
	_frames -= 1
	if _frames > 0:
		return
	var img := get_viewport().get_texture().get_image()
	img.save_png(_path)
	print("Saved screenshot: ", _path)
	get_tree().quit()
