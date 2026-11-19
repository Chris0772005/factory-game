class_name ScrapSkip
extends Node3D
## The skip by the hall door. The excavator loads it, a bucket can be tipped
## in with F. Without a truck Kowalski sends his cart for it (F at the skip,
## he keeps a fifth); with the truck it is hauled away by itself when full
## and pays wholesale. Hot goods never go in. Host counts, peers mirror.

const GROUP := &"scrap_skips"
const SIZE := Vector3(3.2, 1.25, 1.9)
const CAPACITY := 60
const CART_SHARE := 0.8
const TRUCK_SHARE := 1.2
const MODEL := "res://assets/models/machinery/skip.glb"

signal emptied(pieces: int, pay: int)

var count := 0
var worth := 0
var _fill: Node3D
var _label: Label3D


func _init() -> void:
	name = "ScrapSkip"


func _ready() -> void:
	physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
	add_to_group(GROUP)
	add_to_group(&"interactable")
	for s: float in [-1.0, 1.0]:
		StationKit.box_collider(self, Vector3(SIZE.x, SIZE.y, 0.1), Transform3D(Basis(), Vector3(0, SIZE.y * 0.5, s * SIZE.z * 0.5)))
		StationKit.box_collider(self, Vector3(0.1, SIZE.y, SIZE.z), Transform3D(Basis(), Vector3(s * SIZE.x * 0.5, SIZE.y * 0.5, 0)))
	StationKit.box_collider(self, Vector3(SIZE.x, 0.1, SIZE.z), Transform3D(Basis(), Vector3(0, 0.05, 0)))
	_build_art()
	_update_look()


func is_full() -> bool:
	return count >= CAPACITY


func room() -> int:
	return CAPACITY - count


## Host: pieces go in; returns how many fitted.
func add(kinds: Array) -> int:
	var n := 0
	for k: StringName in kinds:
		if count >= CAPACITY or FoundryRules.is_hot(k):
			break
		count += 1
		worth += FoundryRules.raw_price(k)
		n += 1
	if n > 0:
		_changed()
		Sfx.play(&"scrap_clatter", global_position + Vector3(0, SIZE.y, 0), -4.0, 0.2)
	return n


## Host: the load leaves; pays `share` of its worth.
func haul(share: float) -> int:
	var world := get_tree().get_first_node_in_group(&"world") as GameWorld
	if world == null or count == 0:
		return 0
	var pay := roundi(worth * share)
	var pieces := count
	count = 0
	worth = 0
	_changed()
	world.add_money(pay)
	world.popup_all(interact_point() + Vector3(0, 0.6, 0), "+%d $ · %d Teile" % [pay, pieces], UITheme.ACCENT)
	Missions.report(get_tree(), &"scrap_sold", pieces)
	emptied.emit(pieces, pay)
	return pay


func _changed() -> void:
	_update_look()
	if Network.is_online() and multiplayer.is_server():
		_sync.rpc(count, worth)


@rpc("authority", "call_remote", "reliable")
func _sync(c: int, w: int) -> void:
	count = c
	worth = w
	_update_look()


func interact_point() -> Vector3:
	return global_position + Vector3(0, SIZE.y, 0)


func _has_truck() -> bool:
	var world := get_tree().get_first_node_in_group(&"world") as GameWorld
	return world != null and world.has_upgrade(&"truck")


func hint(_player: Node) -> String:
	var load_text := "Mulde %d/%d · %d $" % [count, CAPACITY, worth]
	if count == 0:
		return "Mulde leer – der Bagger lädt sie, oder Eimer hineinkippen"
	if _has_truck():
		return "%s · der LKW holt sie, wenn sie voll ist" % load_text
	return "%s · [F] von Kowalski abholen lassen (%d $)" % [load_text, roundi(worth * CART_SHARE)]


func interact(_player: Node) -> void:
	if Network.is_sim_authority() and not _has_truck():
		haul(CART_SHARE)


func _build_art() -> void:
	if not StationKit.visual():
		return
	# The skip itself: a chain-lift skip, yellow paint gone to rust (tools/blender/skip.py -> skip.glb,
	# from a CC-BY model, see CREDITS.md), 3.2 m long along X and standing on the ground. Mud round its foot.
	var packed := load(MODEL) as PackedScene
	if packed:
		var model := packed.instantiate() as Node3D
		add_child(model)
		VehicleFinish.apply(model, {mud = 0.45, mud_height = 0.2, dust = 0.25})
	# The scrap in it: the skip is 2.5 x 1.1 m at its floor and 3.0 x 1.76 m a metre up, under the rim.
	_fill = ScrapLoadArt.pile(Vector2(2.5, 1.1), Vector2(3.0, 1.76), 1.0, 0.42, 23)
	add_child(_fill)
	# Chalked on the long side, which leans out a little.
	_label = StationKit.label(self, "", Transform3D(Basis(Vector3.RIGHT, 0.134), Vector3(0, 0.66, 0.875)), 96, Color("#e8e2d0"), 800, 0.003)


func _update_look() -> void:
	if _fill:
		_fill.visible = count > 0
		# The pieces lie where they are; the pile shows from the floor up as the skip fills.
		ScrapLoadArt.reveal(_fill, clampf(float(count) / CAPACITY, 0.0, 1.0))
	if _label:
		_label.text = "%d / %d" % [count, CAPACITY]
