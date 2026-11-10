class_name HallCrane
extends ChainHoist
## The Eisenhalle's overhead travelling crane. Same controls as the bell
## foundry's chain hoist (carry the pendant, the crane follows you), but its
## hook carries the teeming ladle for good: F lowers the ladle to pouring
## height, F again hoists it for travel. While it hangs low the bridge creeps
## at half speed for fine positioning, and the ladle's handwheel can be
## cranked (Ladle). A tipped ladle will not hoist.

## Ladle base height while pouring: the lip clears a mold box, the
## mold line's pouring box and the casting pit's rim.
const POUR_BASE := 0.85
## Ladle base height while travelling: over the workers' heads.
const TRAVEL_BASE := 2.35

var ladle: Ladle


func _ready() -> void:
	hook_top = TRAVEL_BASE + Ladle.HANG
	hook_low = POUR_BASE + Ladle.HANG
	girder = Vector2(0.62, 0.42)
	capacity_label = "MAX 20 t"
	super()
	ladle = Ladle.new()
	ladle.name = "Ladle"
	add_child(ladle)
	_place_ladle()


func pendant_rest() -> Vector3:
	return global_transform * Vector3(trolley_x - Ladle.RADIUS - 0.9, 1.25, bridge_z + 0.3)


func press() -> void:
	match hook:
		Hook.UP:
			hook = Hook.LOWERING
			Sfx.play(&"pickup", hook_position(), -6.0)
		Hook.LOW:
			if ladle.upright():
				hook = Hook.LIFTING
				Sfx.play(&"pickup", hook_position(), -6.0)


func hint() -> String:
	match hook:
		Hook.UP:
			return "[F] Pfanne absenken"
		Hook.LOW:
			return "[F] Pfanne anheben" if ladle.upright() else "Pfanne erst aufrichten (Kurbel loslassen)"
		Hook.LOWERING:
			return "Pfanne senkt sich…"
		Hook.LIFTING:
			return "Pfanne hebt an…"
	return ""


func drive_speed() -> float:
	return SPEED * (0.5 if hook == Hook.LOW else 1.0)


func _hook_step(delta: float) -> void:
	match hook:
		Hook.LOWERING:
			hook_y = move_toward(hook_y, hook_low, HOOK_SPEED * delta)
			if hook_y <= hook_low + 0.001:
				hook = Hook.LOW
				Sfx.play(&"hammer_clank", hook_position(), -10.0)
		Hook.LIFTING:
			hook_y = move_toward(hook_y, hook_top, HOOK_SPEED * delta)
			if hook_y >= hook_top - 0.001:
				hook = Hook.UP


func _physics_process(delta: float) -> void:
	super(delta)
	_place_ladle()


func _place_ladle() -> void:
	if ladle == null:
		return
	ladle.position = Vector3(trolley_x, hook_y - Ladle.HANG, bridge_z)
	ladle.lowered = hook == Hook.LOW
