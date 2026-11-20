class_name FpMaterials
## Cloth and leather of the worker's own arms and legs in first person: photo scans (Poly Haven, CC0;
## tools/fp_textures.py) that stay on the part they cover. The picture is laid on in each part's own
## space, three ways round, so a turning hand does not swim through it.

const DIR := "res://assets/textures/pbr/"
## The grey maps' mean (linear light), as tools/fp_textures.py prints it: a colour divided by it
## comes out as that colour.
const MEAN := {"cloth": 0.2002, "leather": 0.52}
## Repeats per metre (the weave of the cloth reads as fine denim at arm's length at this size).
const TILE := {"cloth": 5.5, "leather": 4.5}

static var _made := {}


## Washed denim (`kind` "cloth") or leather (`kind` "leather") in `colour`. `relief` scales the
## scan's bumps, `two_sided` shows the inside of an open sleeve as well.
static func scan(kind: String, colour: Color, relief := 1.0, two_sided := false) -> StandardMaterial3D:
	var key := "%s_%s_%.2f_%s" % [kind, colour.to_html(false), relief, two_sided]
	if _made.has(key):
		return _made[key]
	var mat := StandardMaterial3D.new()
	var want := colour.srgb_to_linear()
	var factor := 1.0 / float(MEAN[kind])
	mat.albedo_color = Color(want.r * factor, want.g * factor, want.b * factor).linear_to_srgb()
	mat.albedo_texture = load(DIR + kind + "_d.jpg")
	mat.normal_enabled = true
	mat.normal_texture = load(DIR + kind + "_n.jpg")
	mat.normal_scale = relief
	var arm := load(DIR + kind + "_arm.jpg") as Texture2D
	mat.roughness_texture = arm
	mat.roughness_texture_channel = BaseMaterial3D.TEXTURE_CHANNEL_GREEN
	mat.ao_enabled = true
	mat.ao_texture = arm
	mat.ao_texture_channel = BaseMaterial3D.TEXTURE_CHANNEL_RED
	mat.uv1_triplanar = true
	mat.uv1_scale = Vector3.ONE * float(TILE[kind])
	mat.uv1_triplanar_sharpness = 4.0
	if two_sided:
		mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	_made[key] = mat
	return mat
