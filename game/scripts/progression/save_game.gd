class_name SaveGame
## Host-side save file: money, upgrades and the gallery of best castings.
##
## Only real play sessions touch the file. Tests (scenes under `res://tests/`),
## showcase/screenshot runs (`--shot=`), attract-mode menu backgrounds and runs
## started with `-- --no-save` neither read nor write it, so they always start
## from a fresh install's state (0 $, no upgrades) and never leak into the
## player's progress. Showcase scenes can also set `disabled` themselves.

const PATH := "user://molten_mates_save.json"
const VERSION := 1

## Set by scenes that stage the world (showcases, tools) before building a level.
static var disabled := false


## True when this run may read and write the save file.
static func is_active() -> bool:
	if disabled:
		return false
	for arg in OS.get_cmdline_user_args():
		if arg == "--no-save" or arg.begins_with("--shot="):
			return false
	var tree := Engine.get_main_loop() as SceneTree
	if tree and tree.current_scene and tree.current_scene.scene_file_path.begins_with("res://tests/"):
		return false
	return true


static func save(world: GameWorld) -> void:
	if not is_active():
		return
	var data := {
		version = VERSION,
		money = world.money,
		upgrades = world.upgrades.to_save() if world.upgrades else [],
	}
	var f := FileAccess.open(PATH, FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify(data))


static func load_into(world: GameWorld) -> bool:
	if not is_active() or not FileAccess.file_exists(PATH):
		return false
	var f := FileAccess.open(PATH, FileAccess.READ)
	var data = JSON.parse_string(f.get_as_text()) if f else null
	if typeof(data) != TYPE_DICTIONARY or data.get("version", 0) != VERSION:
		return false
	world.money = int(data.get("money", 0))
	world.money_changed.emit(world.money)
	if world.upgrades:
		world.upgrades.load_save(data.get("upgrades", []))
	return true


static func reset() -> void:
	if FileAccess.file_exists(PATH):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(PATH))
