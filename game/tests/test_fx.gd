extends Node
## Foundry FX checks (headless): alloy materials, effect lifecycles, auto-free.


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
	_test_alloys()
	_test_materials()
	await _test_bursts()
	await _test_pour_stream()
	await _test_furnace_fire()
	Engine.time_scale = 1.0
	_check(_log.errors.is_empty(), "no engine or script errors (%d)" % _log.errors.size())
	for e in _log.errors:
		print("    ", e)
	OS.remove_logger(_log)
	print("TESTS %s (%d failures)" % ["PASSED" if _failures == 0 else "FAILED", _failures])
	get_tree().quit(1 if _failures else 0)


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


func _test_materials() -> void:
	for id in Alloys.ids():
		var mat := MetalMaterial.create(id)
		var ok := mat is ShaderMaterial and mat.shader != null and mat.shader.resource_path == MetalMaterial.SHADER_PATH
		ok = ok and mat.get_shader_parameter(&"base_color") == Alloys.get_alloy(id).color
		_check(ok, "MetalMaterial.create(%s)" % id)
	var mat := MetalMaterial.create(&"bronze")
	MetalMaterial.set_temperature(mat, 1.7)
	_check(is_equal_approx(MetalMaterial.get_temperature(mat), 1.0), "temperature is clamped to 1")
	MetalMaterial.set_fill(mat, -0.02)
	_check(mat.get_shader_parameter(&"use_fill") == true and is_equal_approx(mat.get_shader_parameter(&"fill_level"), -0.02), "set_fill enables the cut")
	MetalMaterial.set_fill(mat, 0.0, false)
	_check(mat.get_shader_parameter(&"use_fill") == false, "set_fill can disable the cut")
	MetalMaterial.set_defects(mat, 0.4)
	_check(is_equal_approx(mat.get_shader_parameter(&"defect_amount"), 0.4), "set_defects")
	var other := MetalMaterial.create(&"bronze")
	_check(other != mat and other.get_shader_parameter(&"noise_seed") != mat.get_shader_parameter(&"noise_seed"), "each piece gets its own material and noise seed")
	var fallback := MetalMaterial.create(&"unobtainium")
	_check(fallback.get_shader_parameter(&"base_color") == Alloys.get_alloy(&"alu").color, "unknown alloy falls back to aluminium")
	_check(Alloys.get_alloy(&"verdigris").get("patina", 0.0) > 0.0, "verdigris carries a patina")


func _test_bursts() -> void:
	var spawned: Array[FxBurst] = [
		FoundryFX.sand_burst(_world, Vector3(0, 0.5, 0), 1.0),
		FoundryFX.sand_burst(_world, Vector3(1, 0.5, 0), 2.0),
		FoundryFX.steam_puff(_world, Vector3(2, 0.5, 0), 1.5),
		FoundryFX.sparks(_world, Vector3(3, 0.5, 0), 40),
		FoundryFX.dust(_world, Vector3(4, 0.0, 0)),
		FoundryFX.sparks(self, Vector3(5, 0.5, 0), 5),
	]
	for i in 20:
		spawned.append(FoundryFX.sparks(_world, Vector3(i * 0.1, 1, 0), 10))
	await get_tree().process_frame
	var all_live := spawned.all(func(fx: FxBurst) -> bool: return is_instance_valid(fx) and fx.is_inside_tree())
	_check(all_live, "all %d bursts are in the tree" % spawned.size())
	var emitters := spawned[0].get_children().filter(func(n: Node) -> bool: return n is GPUParticles3D)
	_check(emitters.size() >= 2 and emitters.all(func(p: GPUParticles3D) -> bool: return p.one_shot and p.emitting), "sand burst starts one-shot chunk and dust emitters")
	_check(spawned[1].get_child(0).amount > spawned[0].get_child(0).amount, "bigger sand burst throws more chunks")
	_check(spawned[3].global_position.is_equal_approx(Vector3(3, 0.5, 0)), "burst sits at the requested global position")
	_check(spawned[3].light != null and spawned[3].light.light_energy > 0.0, "sparks flash a light")
	await _wait(0.6)
	_check(spawned[3].light.light_energy == 0.0, "spark flash has faded")
	_check(spawned[2].lifetime > spawned[2].get_child(0).lifetime, "steam waits for its slowest puff before freeing")
	await _wait(3.4)
	var freed := spawned.filter(func(fx: Variant) -> bool: return not is_instance_valid(fx)).size()
	_check(freed == spawned.size(), "all bursts freed themselves (%d/%d)" % [freed, spawned.size()])


func _test_pour_stream() -> void:
	var stream := PourStream.new()
	_world.add_child(stream)
	var from := Vector3(-0.3, 1.4, 0.0)
	var to := Vector3(0.2, 0.4, 0.1)
	stream.set_endpoints(from, to)
	await _wait(0.2)
	_check(not stream.visible and not stream.is_pouring(), "flow 0 keeps the stream hidden")
	stream.flow = 1.0
	await _wait(0.1)
	_check(stream.visible and stream._head < 1.0, "the front is still falling right after the pour starts")
	await _wait(0.6)
	var aabb := stream._mesh.get_aabb().grow(0.01)
	_check(stream.visible and aabb.has_point(from) and aabb.has_point(to), "stream mesh spans lip to impact")
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
	_check(not stream.visible and not stream._sparks.emitting, "flow 0 lets the tail fall and hides the stream")
	stream.queue_free()


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
	fire.heat = 0.0
	_check(not fire._light.visible and not flames[0].visible, "heat 0 puts the fire out")
	fire.queue_free()
	await get_tree().process_frame


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
