class_name VehicleFinish
## The finish every vehicle and machine model gets in the game, so they share one look (the project's
## graphics standard, docs/TECH_SPEC.md Modul Y): paint under a clear coat that mirrors the sky, glass
## you can look through and that reflects, lamps that glow, and a layer of mud and dust that is thickest
## near the ground (shaders/vehicle_dirt.gdshader as an overlay on every mesh).
## Works on imported models by the names of their materials: paint*, glass*, chrome*, lamp*/lens*, rubber*.

const DIRT := preload("res://shaders/vehicle_dirt.gdshader")
const GLASS := Color(0.07, 0.09, 0.1, 0.3)

## opts:
##   mud (0..1, how muddy), mud_height (m, top of the caked zone), dust (0..1),
##   paint_gloss (0..1, clear coat), lamps (emission energy of lamp lenses),
##   repaint ({part of a material's name: Color}: that paint in a new colour, without its texture),
##   glass (Color with alpha: tint and how much it hides).
static func apply(root: Node3D, opts := {}) -> ShaderMaterial:
	var dirt := ShaderMaterial.new()
	dirt.shader = DIRT
	dirt.set_shader_parameter(&"amount", float(opts.get("mud", 0.75)))
	dirt.set_shader_parameter(&"mud_height", float(opts.get("mud_height", 1.25)))
	dirt.set_shader_parameter(&"dust", float(opts.get("dust", 0.35)))
	dirt.set_shader_parameter(&"ground", root.global_position.y if root.is_inside_tree() else 0.0)
	var gloss := float(opts.get("paint_gloss", 0.9))
	var repaint: Dictionary = opts.get("repaint", {})
	var glass: Color = opts.get("glass", GLASS)
	var seen := {}
	for node in root.find_children("*", "MeshInstance3D", true, false):
		var mi := node as MeshInstance3D
		if mi.mesh == null:
			continue
		var only_lamps := true
		var only_glass := true
		# Seats, dashboard and lining stay clean: mud does not get into the cab.
		var only_inside := true
		for s in mi.mesh.get_surface_count():
			var mat := mi.mesh.surface_get_material(s) as BaseMaterial3D
			var label := mat.resource_name.to_lower() if mat else ""
			var is_lamp := label.contains("lamp") or label.contains("lens")
			var is_glass := label.contains("glass")
			only_lamps = only_lamps and is_lamp
			only_glass = only_glass and is_glass
			only_inside = only_inside and (label.contains("seat") or label.contains("dash") or label.contains("lining"))
			if mat == null or seen.has(mat):
				continue
			seen[mat] = true
			if label.contains("paint"):
				mat.clearcoat_enabled = true
				mat.clearcoat = gloss
				mat.clearcoat_roughness = 0.06
				mat.metallic = 0.0
				for key: String in repaint:
					if label.contains(key):
						mat.albedo_texture = null
						mat.albedo_color = repaint[key]
			elif is_glass:
				mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
				mat.albedo_color = glass
				mat.albedo_texture = null
				mat.emission_enabled = false
				mat.roughness = 0.02
				mat.metallic = 0.0
				mat.metallic_specular = 1.0
				mat.cull_mode = BaseMaterial3D.CULL_DISABLED
			elif label.contains("chrome"):
				mat.metallic = 1.0
				mat.roughness = 0.06
			elif is_lamp:
				if not mat.emission_enabled:
					mat.emission_enabled = true
					mat.emission = mat.albedo_color
				mat.emission_energy_multiplier = float(opts.get("lamps", 2.5))
			elif label.contains("rubber"):
				mat.roughness = maxf(mat.roughness, 0.85)
		# Sunlight falls through the panes into the cab; lamps stay clean enough to shine.
		if only_glass:
			mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		var inside := only_inside or String(mi.name).contains("interior") or String(mi.name).contains("inside")
		if not only_lamps and not only_glass and not inside:
			mi.material_overlay = dirt
	return dirt


## The lamp materials of a model (each once), to switch them with the machine: see `light`.
static func lamps(root: Node3D) -> Array[BaseMaterial3D]:
	var out: Array[BaseMaterial3D] = []
	for node in root.find_children("*", "MeshInstance3D", true, false):
		var mi := node as MeshInstance3D
		if mi.mesh == null:
			continue
		for s in mi.mesh.get_surface_count():
			var mat := mi.mesh.surface_get_material(s) as BaseMaterial3D
			if mat == null or out.has(mat):
				continue
			var label := mat.resource_name.to_lower()
			if label.contains("lamp") or label.contains("lens"):
				out.append(mat)
	return out


## Lamps on (they glow and bloom) or off (a faint glint).
static func light(lamp_materials: Array[BaseMaterial3D], on: bool, energy := 6.0) -> void:
	for mat in lamp_materials:
		mat.emission_enabled = true
		mat.emission_energy_multiplier = energy if on else 0.25


## A lamp's beam: a spot light without shadows at `at`, shining along `toward` (both in `parent`'s frame).
static func beam(parent: Node3D, at: Vector3, toward: Vector3, energy := 6.0, reach := 22.0, angle := 36.0) -> SpotLight3D:
	var spot := SpotLight3D.new()
	spot.light_color = Color("#fff0d2")
	spot.light_energy = energy
	spot.spot_range = reach
	spot.spot_angle = angle
	spot.spot_attenuation = 1.2
	spot.shadow_enabled = false
	parent.add_child(spot)
	var up := Vector3.UP if absf(toward.normalized().dot(Vector3.UP)) < 0.95 else Vector3.FORWARD
	spot.transform = Transform3D(Basis.looking_at(toward, up), at)
	return spot
