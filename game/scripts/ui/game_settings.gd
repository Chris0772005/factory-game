class_name GameSettings
extends RefCounted
## Player options, persisted to user://settings.cfg and applied at boot by the
## Juice autoload: master volume, mouse sensitivity, screen shake, fullscreen
## and graphics (quality preset → EnvQuality, plus SSAO, shadows, 3D render scale).
## Headless runs and screenshot runs (`--shot=`) ignore the saved file so tests
## and renders stay deterministic.

const PATH := "user://settings.cfg"
const QUALITY_NAMES: Array[String] = ["Niedrig", "Mittel", "Hoch"]

static var master_volume := 0.8
## Multiplier on CameraRig.MOUSE_SENSITIVITY.
static var mouse_sensitivity := 1.0
## 0..1 scale on camera shake (accessibility; Art Bible 8.3 default 70 %).
static var screen_shake := 0.7
static var fullscreen := false
## EnvQuality.Level, or -1 for the detected default.
static var quality := -1
static var ssao := true
static var shadows := true
static var render_scale := 1.0

static var _hooked := false


## Reads user://settings.cfg (unless headless or rendering a screenshot).
static func load_saved() -> void:
	if not uses_saved_file():
		return
	var cfg := ConfigFile.new()
	if cfg.load(PATH) != OK:
		_defaults_for_quality(EnvQuality.level())
		return
	master_volume = clampf(cfg.get_value("audio", "master_volume", master_volume), 0.0, 1.0)
	mouse_sensitivity = clampf(cfg.get_value("controls", "mouse_sensitivity", mouse_sensitivity), 0.2, 3.0)
	screen_shake = clampf(cfg.get_value("controls", "screen_shake", screen_shake), 0.0, 1.0)
	fullscreen = cfg.get_value("video", "fullscreen", fullscreen)
	quality = clampi(cfg.get_value("video", "quality", quality), -1, 2)
	_defaults_for_quality(quality if quality >= 0 else EnvQuality.level())
	ssao = cfg.get_value("video", "ssao", ssao)
	shadows = cfg.get_value("video", "shadows", shadows)
	render_scale = clampf(cfg.get_value("video", "render_scale", render_scale), 0.5, 1.0)
	if quality >= 0 and not _quality_forced_by_cmdline():
		EnvQuality.set_level(quality as EnvQuality.Level)


static func save() -> void:
	if not uses_saved_file():
		return
	var cfg := ConfigFile.new()
	cfg.set_value("audio", "master_volume", master_volume)
	cfg.set_value("controls", "mouse_sensitivity", mouse_sensitivity)
	cfg.set_value("controls", "screen_shake", screen_shake)
	cfg.set_value("video", "fullscreen", fullscreen)
	cfg.set_value("video", "quality", quality)
	cfg.set_value("video", "ssao", ssao)
	cfg.set_value("video", "shadows", shadows)
	cfg.set_value("video", "render_scale", render_scale)
	cfg.save(PATH)


## False for headless runs and `--shot=` renders: they never read or write the file.
static func uses_saved_file() -> bool:
	if DisplayServer.get_name() == "headless":
		return false
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--shot="):
			return false
	return true


static func current_quality() -> int:
	return quality if quality >= 0 else EnvQuality.level()


## Picks a graphics preset: sets EnvQuality (grass, lights, SSIL, fog – takes full
## effect on the next level load) and the matching SSAO / shadow / render-scale values.
static func set_quality(level: int) -> void:
	quality = clampi(level, 0, 2)
	EnvQuality.set_level(quality as EnvQuality.Level)
	_defaults_for_quality(quality)


static func apply_all(tree: SceneTree) -> void:
	apply_audio()
	apply_window()
	apply_graphics(tree)


static func apply_audio() -> void:
	AudioServer.set_bus_volume_db(0, linear_to_db(maxf(master_volume, 0.0001)))
	AudioServer.set_bus_mute(0, master_volume <= 0.001)


static func apply_window() -> void:
	if DisplayServer.get_name() == "headless":
		return
	var mode := DisplayServer.window_get_mode()
	var is_full := mode == DisplayServer.WINDOW_MODE_FULLSCREEN or mode == DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN
	if fullscreen and not is_full:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
	elif not fullscreen and is_full:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)


## Applies SSAO, shadows and render scale to everything already in the tree and,
## through `node_added`, to lights and environments built later.
static func apply_graphics(tree: SceneTree) -> void:
	if tree == null:
		return
	var root := tree.root
	root.scaling_3d_scale = render_scale
	root.scaling_3d_mode = Viewport.SCALING_3D_MODE_FSR if render_scale < 0.99 else Viewport.SCALING_3D_MODE_BILINEAR
	# SSAO cost per preset (Art Bible 13): Deck half size / low, Medium half size, High full.
	match current_quality():
		EnvQuality.Level.LOW:
			RenderingServer.environment_set_ssao_quality(RenderingServer.ENV_SSAO_QUALITY_LOW, true, 0.5, 2, 50.0, 300.0)
		EnvQuality.Level.MEDIUM:
			RenderingServer.environment_set_ssao_quality(RenderingServer.ENV_SSAO_QUALITY_MEDIUM, true, 0.5, 2, 50.0, 300.0)
		_:
			RenderingServer.environment_set_ssao_quality(RenderingServer.ENV_SSAO_QUALITY_HIGH, false, 0.5, 2, 50.0, 300.0)
	for node in root.find_children("*", "WorldEnvironment", true, false):
		_apply_node(node)
	for node in root.find_children("*", "Light3D", true, false):
		_apply_node(node)
	if not _hooked:
		_hooked = true
		tree.node_added.connect(func(node: Node) -> void:
			if node is Light3D or node is WorldEnvironment:
				_apply_node.call_deferred(node)
		)


static func _apply_node(node: Node) -> void:
	if not is_instance_valid(node):
		return
	if node is WorldEnvironment:
		var env := (node as WorldEnvironment).environment
		if env:
			env.ssao_enabled = ssao and not EnvQuality.disabled("ssao")
	elif node is Light3D:
		var light := node as Light3D
		if not light.has_meta(&"mm_shadow"):
			light.set_meta(&"mm_shadow", light.shadow_enabled)
		light.shadow_enabled = shadows and bool(light.get_meta(&"mm_shadow"))


static func _defaults_for_quality(level: int) -> void:
	ssao = true
	shadows = true
	render_scale = 0.8 if level == EnvQuality.Level.LOW else 1.0


static func _quality_forced_by_cmdline() -> bool:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--quality="):
			return true
	return false
