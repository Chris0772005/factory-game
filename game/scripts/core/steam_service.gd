extends Node
## Autoload "SteamService": everything Steam, in one place, and only if the
## GodotSteam GDExtension is installed (res://addons/godotsteam). Without
## it - tests, CI, a build run outside Steam - every call is a no-op.
##
## App ID: project setting `steam/app_id` (480 = Valve's test app "Spacewar"
## until the game has its own). Not yet tested against a running Steam client.

## Achievement ids as they must be created in Steamworks.
const ACHIEVEMENTS := {
	first_cast = "ACH_FIRST_CAST",
	garage = "ACH_GARAGE",
	bell_foundry = "ACH_BELL_FOUNDRY",
	iron_hall = "ACH_IRON_HALL",
	full_auto = "ACH_FULL_AUTO",
	find_book = "ACH_FIND_BOOK",
	kaiser_bell = "ACH_KAISER_BELL",
}

var active := false
var persona := ""
var _steam: Object
var _check := 0.0
var _done := {}


func _ready() -> void:
	if not ClassDB.class_exists(&"Steam") or not Engine.has_singleton("Steam") or DisplayServer.get_name() == "headless":
		set_process(false)
		return
	_steam = Engine.get_singleton("Steam")
	var app_id: int = ProjectSettings.get_setting("steam/app_id", 480)
	var result: Variant = _steam.call(&"steamInitEx", app_id, true)
	active = typeof(result) == TYPE_DICTIONARY and int((result as Dictionary).get("status", 1)) == 0
	if not active:
		push_warning("Steam not available: %s" % str(result))
		set_process(false)
		return
	persona = str(_steam.call(&"getPersonaName"))
	if GameSettings.player_name.is_empty():
		GameSettings.player_name = persona.substr(0, 16)


## Unlocks an achievement by its key in ACHIEVEMENTS (once per run).
func unlock(key: StringName) -> void:
	if not active or _done.has(key) or not ACHIEVEMENTS.has(key):
		return
	_done[key] = true
	_steam.call(&"setAchievement", ACHIEVEMENTS[key])
	_steam.call(&"storeStats")


## Which achievements the current game state has earned (pure, testable).
static func earned(world: GameWorld) -> Array[StringName]:
	var out: Array[StringName] = []
	if world == null:
		return out
	var guide := world.get("guide") as Guide
	if guide and guide.stats.sold >= 1:
		out.append(&"first_cast")
	if guide and guide.stats.great_bell >= 1:
		out.append(&"kaiser_bell")
	if world.has_upgrade(&"garage"):
		out.append(&"garage")
	if world.has_upgrade(&"bell_foundry"):
		out.append(&"bell_foundry")
	if world.has_upgrade(&"iron_hall"):
		out.append(&"iron_hall")
	if [&"conveyor", &"robot_arm", &"auto_bellows", &"auto_rammer", &"auto_pour", &"auto_breaker", &"auto_ship"].all(func(id: StringName) -> bool: return world.has_upgrade(id)):
		out.append(&"full_auto")
	var book := world.get("find_book") as FindBook
	if book and book.found.size() >= FindBook.total():
		out.append(&"find_book")
	return out


func _process(delta: float) -> void:
	_check += delta
	if _check < 2.0:
		return
	_check = 0.0
	for key in earned(get_tree().get_first_node_in_group(&"world") as GameWorld):
		unlock(key)
