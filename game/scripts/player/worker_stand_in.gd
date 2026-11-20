class_name WorkerStandIn
extends Node3D
## A player's worker without a player, for pictures: it stands, moves on the spot, carries a
## stand-in load, digs with the bare hands or plays a short action, as the others would see a
## player do it. Used by the crew close-up and by the levels' art checks. Faces +Z.

## Physics steps before a short action starts, so the worker stands settled.
const WARM_UP := 60

## The player colour whose worker this is.
var color := Color("#3e7bd6")
## What the worker does: `vel` (m/s forwards, on the spot), `air` (in a jump), `hold` (where the
## load is held, in the worker's own space) with `box`, `pot` or `hammer` (which stand-in load) or
## `find` (a kind of find from the scrap, as ScrapModels shapes it), `working` (digging with the
## bare hands), `action` (one of PlayerModel.ACTIONS, held at `at` of its length), `pose` (frozen
## in the pose of a worker caught by the metal).
var state := {}
## Share of a short action's length at which it is held (0..1).
var at := 0.5
var model: PlayerModel

var _tick := 0


func _ready() -> void:
	# A copy: the loads write their handles into the state.
	state = state.duplicate(true)
	model = PlayerModel.new()
	model.suit_color = color
	if state.get("pose", false):
		model.apply_pose(PlayerModel.panic_pose())
	add_child(model)
	_add_load()


## Stand-ins for what the worker carries (the real things need a running round).
func _add_load() -> void:
	if not state.has("hold"):
		return
	var spot: Vector3 = state.hold
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color("#7a5a3c")
	mat.roughness = 0.8
	if state.has("find"):
		var kind: StringName = state.find
		var info: Dictionary = FoundryRules.JUNK.get(kind, FoundryRules.HOT.get(kind, FoundryRules.SCRAP.get(kind, {})))
		if not info.is_empty() and ScrapModels.has(kind):
			_add_mesh(ScrapModels.mesh(kind), ScrapModels.material(info.color, kind), spot)
	elif state.get("box", false):
		var box := BoxMesh.new()
		box.size = Vector3(0.3, 0.3, 0.3)
		_add_mesh(box, mat, spot)
	elif state.get("pot", false):
		# The crucible: `hold` is its base; its two handles stick out sideways.
		var pot := CylinderMesh.new()
		pot.top_radius = Crucible.RADIUS
		pot.bottom_radius = Crucible.RADIUS * 0.8
		pot.height = Crucible.HEIGHT
		_add_mesh(pot, mat, spot + Vector3(0, Crucible.HEIGHT * 0.5, 0))
		var reach := CrucibleArt.LUG_X + CrucibleArt.HANDLE_LEN * 0.65
		state.grips = [spot + Vector3(-reach, CrucibleArt.BAND_Y, 0), spot + Vector3(reach, CrucibleArt.BAND_Y, 0)]
		for grip: Vector3 in state.grips:
			var knob := SphereMesh.new()
			knob.radius = 0.025
			knob.height = 0.05
			_add_mesh(knob, mat, grip)
	elif state.get("hammer", false):
		# The sledgehammer stands upright in the hands, head up.
		var shaft := CylinderMesh.new()
		shaft.top_radius = 0.018
		shaft.bottom_radius = 0.018
		shaft.height = 0.8
		_add_mesh(shaft, mat, spot + Vector3(0, 0.4, 0))
		var head := BoxMesh.new()
		head.size = Vector3(0.1, 0.1, 0.22)
		_add_mesh(head, mat, spot + Vector3(0, 0.8, 0))
		state.grips = [spot + Vector3(0, HammerArt.GRIP_LOW, 0), spot + Vector3(0, HammerArt.GRIP_HIGH, 0)]
		state.on_handle = true


func _add_mesh(mesh: Mesh, mat: Material, spot: Vector3) -> void:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = mat
	mi.position = spot
	add_child(mi)


func _physics_process(delta: float) -> void:
	if state.get("pose", false):
		return
	var on_floor: bool = not state.get("air", false)
	var velocity := global_transform.basis.z * float(state.get("vel", 0.0))
	if not on_floor:
		velocity.y = 2.0
	var holding := state.has("hold")
	var grips: Array[Vector3] = []
	for grip: Vector3 in state.get("grips", []):
		grips.append(global_transform * grip)
	model.grips = grips
	model.grips_on_handle = state.get("on_handle", false)
	model.working = state.get("working", false)
	var step := delta
	if state.has("action"):
		var action: StringName = state.action
		if _tick == WARM_UP:
			model.play_action(action)
		elif _tick > WARM_UP + int(at * float(PlayerModel.ACTIONS[action]) * 60.0):
			# Held there for the picture.
			step = 0.00001
	model.animate(step, velocity, on_floor, holding, global_transform * (state.hold as Vector3) if holding else Vector3.ZERO)
	_tick += 1
