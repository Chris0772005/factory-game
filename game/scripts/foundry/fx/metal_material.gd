class_name MetalMaterial
## Builds and drives cast-metal materials (res://shaders/metal.gdshader).
## Every piece gets its own material because temperature and fill differ per piece.

const SHADER_PATH := "res://shaders/metal.gdshader"

## Brightness of the stylised metal reflections for newly created materials:
## about 1 outdoors, lower for dim interiors.
static var environment_brightness := 1.0

static var _shader: Shader


## `piece_seed` places the procedural grain, crust cracks and defect spots.
## Derive it from synced piece data (e.g. `hash(design_code)` or a piece id)
## so every peer sees the same spots; equal seeds give identical patterns.
static func create(alloy_id: StringName, piece_seed := 0) -> ShaderMaterial:
	if _shader == null:
		_shader = load(SHADER_PATH)
	var mat := ShaderMaterial.new()
	mat.shader = _shader
	set_alloy(mat, alloy_id)
	mat.set_shader_parameter(&"noise_seed", _seed_offset(piece_seed))
	mat.set_shader_parameter(&"env_brightness", environment_brightness)
	return mat


## Switches an existing material to another alloy (colour, roughness, patina),
## e.g. when the melt in a mold turns out to be a different mix.
static func set_alloy(mat: ShaderMaterial, alloy_id: StringName) -> void:
	if not Alloys.has(alloy_id):
		push_warning("Unknown alloy '%s', using %s" % [alloy_id, Alloys.DEFAULT])
	var alloy := Alloys.get_alloy(alloy_id)
	mat.set_shader_parameter(&"base_color", alloy.color)
	mat.set_shader_parameter(&"roughness", alloy.roughness)
	mat.set_shader_parameter(&"patina_amount", alloy.get("patina", 0.0))
	mat.set_meta(&"alloy", alloy_id if Alloys.has(alloy_id) else Alloys.DEFAULT)


## Noise-space offset for a seed; PCG-based, so identical on every machine.
static func _seed_offset(piece_seed: int) -> Vector3:
	var rng := RandomNumberGenerator.new()
	rng.seed = piece_seed
	return Vector3(rng.randf(), rng.randf(), rng.randf()) * 50.0


## 0 = cold metal, 1 = white-hot liquid.
static func set_temperature(mat: ShaderMaterial, t: float) -> void:
	mat.set_shader_parameter(&"temperature", clampf(t, 0.0, 1.0))


static func get_temperature(mat: ShaderMaterial) -> float:
	var t: Variant = mat.get_shader_parameter(&"temperature")
	return t if t != null else 0.0


## `level` is an object-space Y: everything above it is cut away while enabled.
static func set_fill(mat: ShaderMaterial, level: float, enabled := true) -> void:
	mat.set_shader_parameter(&"fill_level", level)
	mat.set_shader_parameter(&"use_fill", enabled)


## 0 = flawless, 1 = heavily pitted with cold-shut blotches.
static func set_defects(mat: ShaderMaterial, amount: float) -> void:
	mat.set_shader_parameter(&"defect_amount", clampf(amount, 0.0, 1.0))
