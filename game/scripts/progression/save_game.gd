class_name SaveGame
## Host-side save file: money, upgrades and the gallery of best castings.

const PATH := "user://molten_mates_save.json"
const VERSION := 1


static func save(world: GameWorld) -> void:
	var data := {
		version = VERSION,
		money = world.money,
		upgrades = world.upgrades.to_save() if world.upgrades else [],
	}
	var f := FileAccess.open(PATH, FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify(data))


static func load_into(world: GameWorld) -> bool:
	if not FileAccess.file_exists(PATH):
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
