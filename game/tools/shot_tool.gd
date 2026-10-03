extends Node
## Saves a screenshot and quits when started with `-- --shot=<path> [--frames=N]`.
## Used to check visuals from the command line without a GPU.

var _path := ""
var _frames := 30


func _ready() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--shot="):
			_path = arg.trim_prefix("--shot=")
		elif arg.begins_with("--frames="):
			_frames = int(arg.trim_prefix("--frames="))
	if _path.is_empty():
		set_process(false)


func _process(_delta: float) -> void:
	_frames -= 1
	if _frames > 0:
		return
	var img := get_viewport().get_texture().get_image()
	img.save_png(_path)
	print("Saved screenshot: ", _path)
	get_tree().quit()
