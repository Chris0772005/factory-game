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

signal emptied(pieces: int, pay: int)

var count := 0
var worth := 0
var _fill: MeshInstance3D
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
	var steel := StationKit.metal("skip_body", {steel_color = Color("#4a5a52"), paint = 0.92, paint_color = Color("#3f6a54"), rust = 0.5,
		dents = 0.6, metallic_steel = 0.5})
	var pieces := []
	var hx := SIZE.x * 0.5
	var hz := SIZE.z * 0.5
	pieces.append(EnvMesh.piece(EnvMesh.box(Vector3(SIZE.x - 0.5, 0.08, SIZE.z)), Transform3D(Basis(), Vector3(0, 0.12, 0))))
	for s: float in [-1.0, 1.0]:
		pieces.append(EnvMesh.piece(EnvMesh.box(Vector3(SIZE.x, SIZE.y - 0.1, 0.07)), Transform3D(Basis(), Vector3(0, SIZE.y * 0.5 + 0.05, s * hz))))
		# Sloped ends like a builder's skip.
		pieces.append(EnvMesh.piece(EnvMesh.box(Vector3(0.07, SIZE.y + 0.12, SIZE.z)), Transform3D(Basis(Vector3.BACK, s * 0.32), Vector3(s * (hx - 0.2), SIZE.y * 0.5 + 0.05, 0))))
		pieces.append(EnvMesh.piece(EnvMesh.box(Vector3(SIZE.x + 0.1, 0.09, 0.12)), Transform3D(Basis(), Vector3(0, SIZE.y + 0.03, s * hz))))
		for x: float in [-0.9, 0.0, 0.9]:
			pieces.append(EnvMesh.piece(EnvMesh.box(Vector3(0.09, SIZE.y - 0.2, 0.05)), Transform3D(Basis(), Vector3(x, SIZE.y * 0.5 + 0.05, s * (hz + 0.05)))))
	for x: float in [-1.0, 1.0]:
		pieces.append(EnvMesh.piece(EnvMesh.box(Vector3(0.14, 0.1, SIZE.z + 0.1)), Transform3D(Basis(), Vector3(x, 0.05, 0))))
	StationKit.add_merged(self, pieces, steel)
	_fill = MeshInstance3D.new()
	_fill.mesh = EnvMesh.box(Vector3(SIZE.x - 0.7, 0.3, SIZE.z - 0.16), 0.08)
	_fill.material_override = StationKit.metal("skip_load", {steel_color = Color("#6f6a66"), rust = 0.75, dents = 1.0, metallic_steel = 0.6, roughness_steel = 0.65})
	add_child(_fill)
	_label = StationKit.label(self, "", Transform3D(Basis(), Vector3(0, SIZE.y * 0.62, SIZE.z * 0.5 + 0.045)), 96, Color("#e8e2d0"), 800, 0.003)


func _update_look() -> void:
	if _fill:
		var k := clampf(float(count) / CAPACITY, 0.0, 1.0)
		_fill.visible = count > 0
		_fill.position.y = lerpf(0.25, SIZE.y - 0.1, k)
	if _label:
		_label.text = "%d / %d" % [count, CAPACITY]
