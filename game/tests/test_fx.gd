extends Node
## Foundry FX checks (headless): spec API, alloy materials, effect lifecycles,
## auto-free, collision setup and a showcase smoke run.


## Collects engine errors so the test can fail on any of them.
class ErrorLog extends Logger:
	var errors: Array[String] = []
	var _mutex := Mutex.new()

	func _log_error(function: String, file: String, line: int, code: String, rationale: String,
			_editor_notify: bool, error_type: int, _script_backtraces: Array[ScriptBacktrace]) -> void:
		if error_type == ERROR_TYPE_WARNING:
			return
		_mutex.lock()
		errors.append("%s (%s:%d %s)" % [rationale if rationale else code, file, line, function])
		_mutex.unlock()

	func _log_message(_message: String, _error: bool) -> void:
		pass


var _failures := 0
var _log := ErrorLog.new()
var _world: Node3D


func _ready() -> void:
	OS.add_logger(_log)
	_world = Node3D.new()
	add_child(_world)
	_run.call_deferred()


func _run() -> void:
	Engine.time_scale = 4.0
	_test_spec_api()
	_test_alloys()
	_test_materials()
	await _test_bursts()
	await _test_burst_placement()
	await _test_pour_stream()
	await _test_furnace_fire()
	await _test_showcase()
	Engine.time_scale = 1.0
	_check(_log.errors.is_empty(), "no engine or script errors (%d)" % _log.errors.size())
	for e in _log.errors:
		print("    ", e)
	OS.remove_logger(_log)
	print("TESTS %s (%d failures)" % ["PASSED" if _failures == 0 else "FAILED", _failures])
	get_tree().quit(1 if _failures else 0)


## Names and arities from docs/TECH_SPEC.md (Modul B).
func _test_spec_api() -> void:
	_check_method(MetalMaterial, &"create", 1)
	_check_method(MetalMaterial, &"set_temperature", 2)
	_check_method(MetalMaterial, &"set_fill", 2, 3)
	_check_method(FoundryFX, &"sand_burst", 2, 3)
	_check_method(FoundryFX, &"steam_puff", 2, 3)
	_check_method(FoundryFX, &"sparks", 2, 3)
	_check_method(FoundryFX, &"dust", 2)
	_check_method(PourStream, &"set_endpoints", 2)
	var stream := PourStream.new()
	var fire := FurnaceFire.new()
	_check(stream is Node3D and stream.flow == 0.0 and fire is Node3D and fire.heat == 0.0, "PourStream.flow and FurnaceFire.heat start at 0")
	stream.free()
	fire.free()
	var shader: Shader = load(MetalMaterial.SHADER_PATH)
	var uniforms := shader.get_shader_uniform_list().map(func(u: Dictionary) -> String: return u.name)
	for u in ["base_color", "roughness", "temperature", "fill_level", "use_fill", "defect_amount"]:
		_check(u in uniforms, "metal.gdshader has uniform %s" % u)


func _test_alloys() -> void:
	var ids := Alloys.ids()
	for id in [&"alu", &"brass", &"bronze", &"iron", &"gold", &"rotgold", &"verdigris"]:
		_check(id in ids, "alloy table has %s" % id)
	for id in ids:
		var a := Alloys.get_alloy(id)
		var ok: bool = a.name is String and a.color is Color and a.roughness is float and a.value_mult > 0.0
		_check(ok, "%s has name, colour, roughness, value (%s)" % [id, a.name])
	_check(Alloys.display_name(&"brass") == "Messing", "German display names")
	_check(Alloys.value_mult(&"gold") > Alloys.value_mult(&"iron"), "gold is worth more than iron")
	_check(Alloys.get_alloy("bronze") == Alloys.TABLE[&"bronze"], "String ids work as well as StringNames")


func _test_materials() -> void:
	for id in Alloys.ids():
		var alloy_mat := MetalMaterial.create(id)
		var ok := alloy_mat is ShaderMaterial and alloy_mat.shader != null and alloy_mat.shader.resource_path == MetalMaterial.SHADER_PATH
		ok = ok and alloy_mat.get_shader_parameter(&"base_color") == Alloys.get_alloy(id).color
		_check(ok, "MetalMaterial.create(%s)" % id)
	var mat := MetalMaterial.create(&"bronze")
	MetalMaterial.set_temperature(mat, 1.7)
	_check(is_equal_approx(MetalMaterial.get_temperature(mat), 1.0), "temperature is clamped to 1")
	MetalMaterial.set_temperature(mat, -0.5)
	_check(MetalMaterial.get_temperature(mat) == 0.0, "temperature is clamped to 0")
	MetalMaterial.set_fill(mat, -0.02)
	_check(mat.get_shader_parameter(&"use_fill") == true and is_equal_approx(mat.get_shader_parameter(&"fill_level"), -0.02), "set_fill enables the cut")
	MetalMaterial.set_fill(mat, 0.0, false)
	_check(mat.get_shader_parameter(&"use_fill") == false, "set_fill can disable the cut")
	MetalMaterial.set_defects(mat, 0.4)
	_check(is_equal_approx(mat.get_shader_parameter(&"defect_amount"), 0.4), "set_defects")
	var other := MetalMaterial.create(&"bronze")
	_check(other != mat, "each piece gets its own material")
	var seed_a: Vector3 = MetalMaterial.create(&"iron", 42).get_shader_parameter(&"noise_seed")
	var seed_b: Vector3 = MetalMaterial.create(&"gold", 42).get_shader_parameter(&"noise_seed")
	var seed_c: Vector3 = MetalMaterial.create(&"iron", 43).get_shader_parameter(&"noise_seed")
	_check(seed_a == seed_b and seed_a != seed_c, "noise seed is deterministic per piece seed (same on every peer)")
	_check(other.get_shader_parameter(&"noise_seed") == mat.get_shader_parameter(&"noise_seed"), "default seed is deterministic too")
	var fallback := MetalMaterial.create(&"unobtainium")
	_check(fallback.get_shader_parameter(&"base_color") == Alloys.get_alloy(&"alu").color, "unknown alloy falls back to aluminium")
	_check(Alloys.get_alloy(&"verdigris").get("patina", 0.0) > 0.0, "verdigris carries a patina")
	var switched := MetalMaterial.create(&"bronze", 5)
	MetalMaterial.set_alloy(switched, &"verdigris")
	var green := Alloys.get_alloy(&"verdigris")
	_check(switched.get_shader_parameter(&"base_color") == green.color and is_equal_approx(switched.get_shader_parameter(&"roughness"), green.roughness)
		and switched.get_shader_parameter(&"patina_amount") > 0.0 and switched.get_meta(&"alloy") == &"verdigris", "set_alloy switches colour, roughness and patina")
	MetalMaterial.set_alloy(switched, &"gold")
	_check(switched.get_shader_parameter(&"patina_amount") == 0.0, "set_alloy clears the patina again")


func _test_bursts() -> void:
	var nodes_before := Performance.get_monitor(Performance.OBJECT_NODE_COUNT)
	var spawned: Array[FxBurst] = [
		FoundryFX.sand_burst(_world, Vector3(0, 0.5, 0), 1.0),
		FoundryFX.sand_burst(_world, Vector3(1, 0.5, 0), 2.0),
		FoundryFX.steam_puff(_world, Vector3(2, 0.5, 0), 1.5),
		FoundryFX.sparks(_world, Vector3(3, 0.5, 0), 40),
		FoundryFX.dust(_world, Vector3(4, 0.0, 0)),
		FoundryFX.sparks(self, Vector3(5, 0.5, 0), 5),
		FoundryFX.sparks(_world, Vector3(6, 0.5, 0), 0),
		FoundryFX.sand_burst(_world, Vector3(7, 0.5, 0), 0.0),
		FoundryFX.steam_puff(_world, Vector3(8, 0.5, 0), -1.0),
	]
	for i in 20:
		spawned.append(FoundryFX.sparks(_world, Vector3(i * 0.1, 1, 0), 10))
	await get_tree().process_frame
	var all_live := spawned.all(func(fx: FxBurst) -> bool: return is_instance_valid(fx) and fx.is_inside_tree())
	_check(all_live, "all %d bursts are in the tree (zero and negative sizes too)" % spawned.size())
	var emitters := spawned[0].get_children().filter(func(n: Node) -> bool: return n is GPUParticles3D)
	_check(emitters.size() >= 2 and emitters.all(func(p: GPUParticles3D) -> bool: return p.one_shot and p.emitting), "sand burst starts one-shot chunk and dust emitters")
	_check(spawned[1].get_child(0).amount > spawned[0].get_child(0).amount, "bigger sand burst throws more chunks")
	_check(spawned[3].global_position.is_equal_approx(Vector3(3, 0.5, 0)), "burst sits at the requested global position")
	_check(spawned[3].light != null and spawned[3].light.light_energy > 0.0, "sparks flash a light")
	_check(_collides(spawned[0]), "sand clods collide with the scene height map, which leaves out FX geometry")
	_check(_collides(spawned[3]), "sparks collide with the scene height map, which leaves out FX geometry")
	await _wait(0.6)
	_check(spawned[3].light.light_energy == 0.0, "spark flash has faded")
	_check(spawned[2].lifetime > spawned[2].get_child(0).lifetime, "steam waits for its slowest puff before freeing")
	await _wait(3.4)
	var freed := spawned.filter(func(fx: Variant) -> bool: return not is_instance_valid(fx)).size()
	_check(freed == spawned.size(), "all bursts freed themselves (%d/%d)" % [freed, spawned.size()])
	var leaked := Performance.get_monitor(Performance.OBJECT_NODE_COUNT) - nodes_before
	_check(leaked == 0, "no nodes left behind by bursts (%d)" % leaked)


## True when every emitter of `fx` is hit by its height-field collider and the
## collider ignores effect geometry when it renders the height map.
func _collides(fx: FxBurst) -> bool:
	var fields := fx.get_children().filter(func(n: Node) -> bool: return n is GPUParticlesCollisionHeightField3D)
	if fields.size() != 1:
		return false
	var hf: GPUParticlesCollisionHeightField3D = fields[0]
	if hf.heightfield_mask & FoundryFX.FX_LAYER:
		return false
	for p in fx.get_children():
		if p is GPUParticles3D and not (p.layers & hf.cull_mask):
			return false
	return true


func _test_burst_placement() -> void:
	var holder := Node3D.new()
	holder.position = Vector3(3, 1, -2)
	holder.rotation = Vector3(0.4, 1.2, 0.0)
	holder.scale = Vector3.ONE * 2.5
	_world.add_child(holder)
	var fx := FoundryFX.dust(holder, Vector3(1, 0.2, 1))
	var plain := Node.new()
	_world.add_child(plain)
	var fx2 := FoundryFX.steam_puff(plain, Vector3(-1, 0.5, 2))
	await get_tree().process_frame
	_check(fx.global_position.is_equal_approx(Vector3(1, 0.2, 1)), "burst under a moved, rotated, scaled parent keeps its global position")
	_check(fx.global_basis.is_equal_approx(Basis.IDENTITY), "burst does not inherit the parent's scale or rotation")
	_check(fx2.global_position.is_equal_approx(Vector3(-1, 0.5, 2)), "burst under a plain Node uses the position as global")
	holder.queue_free()
	plain.queue_free()
	await get_tree().process_frame


func _test_pour_stream() -> void:
	var stream := PourStream.new()
	_world.add_child(stream)
	var from := Vector3(-0.3, 1.4, 0.0)
	var to := Vector3(0.2, 0.4, 0.1)
	stream.set_endpoints(from, to)
	await _wait(0.2)
	_check(not stream._tube.visible and not stream.is_pouring(), "flow 0 keeps the stream hidden")
	stream.flow = 3.0
	_check(stream.flow == 1.0, "flow is clamped to 1")
	await _wait(0.1)
	_check(stream._tube.visible and stream._head < 1.0, "the front is still falling right after the pour starts")
	await _wait(0.6)
	var aabb := stream._mesh.get_aabb().grow(0.01)
	_check(stream._tube.visible and aabb.has_point(from) and aabb.has_point(to), "stream mesh spans lip to impact")
	_check(stream._sparks.emitting and stream._light.visible, "impact sparks and glow light are on")
	var thick := aabb.size.z
	stream.flow = 0.2
	await _wait(0.5)
	_check(stream._mesh.get_aabb().size.z < thick, "lower flow gives a thinner stream")
	stream.set_endpoints(from + Vector3(0, 0.5, 0), to)
	await _wait(0.05)
	_check(stream._mesh.get_aabb().grow(0.01).has_point(from + Vector3(0, 0.5, 0)), "moving an endpoint rebuilds the stream")
	stream.flow = 0.0
	await _wait(0.8)
	_check(not stream._tube.visible and not stream._sparks.emitting and not stream._light.visible, "flow 0 lets the tail fall and hides the stream")
	_check(stream.visible and stream._sparks.is_visible_in_tree(), "sparks still in flight stay visible after the tail lands")
	# Degenerate geometry: straight down and zero length must not produce NaNs.
	stream.flow = 1.0
	stream.set_endpoints(Vector3(1, 2, 1), Vector3(1, 0.5, 1))
	await _wait(0.9)
	var down := stream._mesh.get_aabb()
	_check(down.size.is_finite() and down.size.y > 1.4, "vertical pour builds a finite tube")
	stream.set_endpoints(Vector3(1, 1, 1), Vector3(1, 1, 1))
	await _wait(0.1)
	_check(stream._mesh.get_aabb().position.is_finite(), "zero-length pour stays finite")
	stream.queue_free()
	await get_tree().process_frame


func _test_furnace_fire() -> void:
	var fire := FurnaceFire.new()
	_world.add_child(fire)
	_check(not fire._light.visible and not fire._embers.emitting, "cold furnace shows no fire")
	fire.heat = 0.8
	await _wait(0.2)
	var flames := fire.get_children().filter(func(n: Node) -> bool: return n is MeshInstance3D and n.visible)
	_check(flames.size() >= 3 and fire._light.visible and fire._light.light_energy > 0.5, "hot furnace shows flames and light")
	_check(fire._embers.emitting, "hot furnace emits embers")
	var tall: float = flames[0].scale.y
	fire.heat = 0.3
	await _wait(0.1)
	_check(flames[0].scale.y < tall, "lower heat gives smaller flames")
	fire.heat = 5.0
	_check(fire.heat == 1.0, "heat is clamped to 1")
	fire.heat = -1.0
	_check(fire.heat == 0.0 and not fire._light.visible and not flames[0].visible, "heat 0 puts the fire out")
	fire.queue_free()
	await get_tree().process_frame


## Runs the showcase through two effect loops: every effect path runs once
## without errors and nothing piles up.
func _test_showcase() -> void:
	var scene: PackedScene = load("res://scenes/fx_showcase.tscn")
	var showcase := scene.instantiate()
	add_child(showcase)
	await _wait(2.6)
	var first := Performance.get_monitor(Performance.OBJECT_NODE_COUNT)
	await _wait(2.5)
	var second := Performance.get_monitor(Performance.OBJECT_NODE_COUNT)
	_check(second <= first + 4, "showcase loops without piling up nodes (%d -> %d)" % [first, second])
	showcase.queue_free()
	await get_tree().process_frame
	_check(MetalMaterial.environment_brightness == 1.0, "showcase restores the metal environment brightness")


func _check_method(script: Script, method: StringName, min_args: int, max_args := -1) -> void:
	if max_args < 0:
		max_args = min_args
	for m in script.get_script_method_list():
		if m.name == method:
			var total: int = m.args.size()
			var required: int = total - m.default_args.size()
			_check(required <= min_args and total >= max_args, "%s.%s(%d..%d args)" % [script.get_global_name(), method, required, total])
			return
	_check(false, "%s.%s exists" % [script.get_global_name(), method])


## Waits `seconds` of game time.
func _wait(seconds: float) -> void:
	var t := 0.0
	while t < seconds:
		await get_tree().process_frame
		t += get_process_delta_time()


func _check(ok: bool, label: String) -> void:
	print(("  ok   " if ok else "  FAIL ") + label)
	if not ok:
		_failures += 1
