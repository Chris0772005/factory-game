shader_type spatial;
// Worked iron and sheet steel of the foundry stations, from photo scans (Poly Haven, CC0, see
// CREDITS.md; the project's graphics standard, TECH_SPEC Modul Y). The surface IS a scan, laid on
// from three sides in object space, so carried tools keep their pattern: its light and dark are
// repainted in the part's own paint or steel colour, its own rust stays rust, and a second scan of
// coarse rust takes over where the part is rusty. What a real workshop adds on top is kept from the
// drawn version, because it depends on the part and not on the photo: rubbed edges, a soot gradient
// from a height, temper colours from heat, dust on what looks up, grime down the sides.
// Vertex COLOR.r (EnvMesh.merge seed) shifts the scan for every piece.
render_mode diffuse_burley, specular_schlick_ggx;

#include "res://shaders/env_common.gdshaderinc"
#include "res://shaders/env_cutaway.gdshaderinc"

// The base scan (StationKit.metal picks it: painted sheet or bare sheet steel) and coarse rust.
uniform sampler2D albedo_map : source_color, repeat_enable, filter_linear_mipmap_anisotropic;
uniform sampler2D normal_map : repeat_enable, filter_linear_mipmap_anisotropic;
uniform sampler2D arm_map : repeat_enable, filter_linear_mipmap_anisotropic;
uniform sampler2D rust_map : source_color, repeat_enable, filter_linear_mipmap_anisotropic;
// Metres per repeat, the scans' mean colours and the base scan's mean roughness.
uniform float tile = 1.0;
uniform float rust_tile = 2.2;
uniform vec3 scan_mean = vec3(0.05);
uniform vec3 rust_mean = vec3(0.128, 0.043, 0.015);
uniform float rough_mean = 0.5;
// Where the base scan is rust itself: its redness (relative to its brightness) from..to.
uniform float own_from = 0.1;
uniform float own_to = 0.5;

uniform vec4 paint_color : source_color = vec4(0.29, 0.38, 0.42, 1.0);
uniform vec4 steel_color : source_color = vec4(0.3, 0.3, 0.31, 1.0);
uniform vec4 rust_color : source_color = vec4(0.47, 0.27, 0.17, 1.0);
uniform vec4 soot_color : source_color = vec4(0.1, 0.09, 0.09, 1.0);
// 0 = bare metal, 1 = fully painted (worn through on edges and, below 1, in patches).
uniform float paint : hint_range(0.0, 1.0) = 0.0;
uniform float rust : hint_range(0.0, 1.0) = 0.2;
// 1 = what grows on the metal is not iron rust but has the rust colour itself (verdigris on copper).
uniform float patina : hint_range(0.0, 1.0) = 0.0;
// Soot rises from `soot_bottom` to full strength at `soot_top` (object y).
uniform float soot : hint_range(0.0, 1.0) = 0.0;
uniform float soot_bottom = 0.3;
uniform float soot_top = 0.8;
// Heat discolouration band between `temper_bottom` and `temper_top`.
uniform float temper : hint_range(0.0, 1.0) = 0.0;
uniform float temper_bottom = 0.5;
uniform float temper_top = 0.8;
uniform float metallic_steel : hint_range(0.0, 1.0) = 0.7;
uniform float roughness_steel : hint_range(0.0, 1.0) = 0.42;
uniform float roughness_paint : hint_range(0.0, 1.0) = 0.62;
// Hammer dents (forged parts); sheet and castings leave it low.
uniform float dents : hint_range(0.0, 1.0) = 0.3;
uniform float noise_scale = 1.0;
// Workshop dust settles on faces that look up; grime runs down the sides; edges and corners are
// rubbed bare.
uniform float dust : hint_range(0.0, 1.0) = 0.45;
uniform vec4 dust_color : source_color = vec4(0.42, 0.37, 0.31, 1.0);
uniform float grime : hint_range(0.0, 1.0) = 0.4;
uniform float edge_wear : hint_range(0.0, 1.0) = 0.5;
// Polished striking faces: bare, bright steel where |object x| > this (0 = off).
uniform float polish_x = 0.0;

// Overhead parts (crane girders) dissolve in the camera's line of sight.
uniform bool cutaway = false;

varying vec3 v_obj;
varying vec3 v_nobj;
varying float v_seed;
varying vec3 v_world;
varying vec3 v_nworld;

void vertex() {
	v_obj = VERTEX;
	v_nobj = NORMAL;
	v_seed = COLOR.r;
	v_world = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	v_nworld = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
}

void fragment() {
	if (cutaway) {
		env_cutaway(v_world, CAMERA_POSITION_WORLD, FRAGCOORD.xy);
	}
	vec3 n = normalize(v_nobj);
	vec3 w = pow(abs(n), vec3(8.0));
	w /= w.x + w.y + w.z;
	// The scan, from three sides (a flat face reads one side only; the footprints are taken before the
	// branches, so filtering stays right). V runs down the image: turned over, the scan stands upright.
	vec3 q = (v_obj + v_seed * 3.7) / tile;
	vec2 ux = vec2(q.z, -q.y);
	vec2 uy = vec2(q.x, -q.z);
	vec2 uz = vec2(q.x, -q.y);
	vec2 gxa = dFdx(ux);
	vec2 gxb = dFdy(ux);
	vec2 gya = dFdx(uy);
	vec2 gyb = dFdy(uy);
	vec2 gza = dFdx(uz);
	vec2 gzb = dFdy(uz);
	float rs = tile / rust_tile;
	vec3 col = vec3(0.0);
	vec3 arm = vec3(0.0);
	vec3 rcol = vec3(0.0);
	vec3 bumped = vec3(0.0);
	if (w.x > 0.004) {
		col += textureGrad(albedo_map, ux, gxa, gxb).rgb * w.x;
		arm += textureGrad(arm_map, ux, gxa, gxb).rgb * w.x;
		rcol += textureGrad(rust_map, ux * rs + 0.37, gxa * rs, gxb * rs).rgb * w.x;
		vec3 t = textureGrad(normal_map, ux, gxa, gxb).xyz * 2.0 - 1.0;
		bumped += vec3(t.xy + n.zy, abs(t.z) * n.x).zyx * w.x;
	}
	if (w.y > 0.004) {
		col += textureGrad(albedo_map, uy, gya, gyb).rgb * w.y;
		arm += textureGrad(arm_map, uy, gya, gyb).rgb * w.y;
		rcol += textureGrad(rust_map, uy * rs + 0.37, gya * rs, gyb * rs).rgb * w.y;
		vec3 t = textureGrad(normal_map, uy, gya, gyb).xyz * 2.0 - 1.0;
		bumped += vec3(t.xy + n.xz, abs(t.z) * n.y).xzy * w.y;
	}
	if (w.z > 0.004) {
		col += textureGrad(albedo_map, uz, gza, gzb).rgb * w.z;
		arm += textureGrad(arm_map, uz, gza, gzb).rgb * w.z;
		rcol += textureGrad(rust_map, uz * rs + 0.37, gza * rs, gzb * rs).rgb * w.z;
		vec3 t = textureGrad(normal_map, uz, gza, gzb).xyz * 2.0 - 1.0;
		bumped += vec3(t.xy + n.xy, abs(t.z) * n.z) * w.z;
	}
	bumped = normalize(bumped);

	const vec3 LUM = vec3(0.2126, 0.7152, 0.0722);
	float bright = dot(col, LUM);
	// The scan's light and dark around its own average: what the paint and the steel are shaded by.
	float shade = clamp(bright / max(dot(scan_mean, LUM), 0.01), 0.4, 1.8);
	// Where the scan itself is rust (redder than it is bright).
	float own = smoothstep(own_from, own_to, (col.r - 0.5 * (col.g + col.b)) / (bright + 0.02));

	vec3 p = v_obj * noise_scale + v_seed * 13.0;
	float macro = env_fbm(p.xz * 3.1 + p.y * 2.3) - 0.5;
	float grain = env_noise(p.xy * 61.0 + p.z * 47.0) - 0.5;
	// Rounded edges and corners (where the normal turns quickly) are rubbed.
	float curve = clamp(length(fwidth(n)) * 6.0 - 0.04, 0.0, 1.0) * edge_wear;

	// The coat of paint: whole at 1, thin coats are worn through in large soft patches that follow
	// the scan's own darker, rougher places; always gone on rubbed edges.
	float coat = 0.0;
	if (paint > 0.0) {
		float patch = env_fbm(p.xy * 2.3 + p.z * 1.9 + 3.0) * 0.75 + (shade - 1.0) * 0.35 + 0.2;
		coat = smoothstep(1.0 - paint - 0.1, 1.0 - paint + 0.1, patch + step(0.995, paint));
		coat *= 1.0 - curve * 0.85;
	}
	vec3 steel = steel_color.rgb * shade * (1.0 + macro * 0.12);
	vec3 painted = paint_color.rgb * mix(1.0, shade, 0.85) * (1.0 + macro * 0.08);
	vec3 c = mix(steel, painted, coat);
	float metal = mix(metallic_steel, 0.0, coat);
	float rough = mix(roughness_steel, roughness_paint, coat) + (arm.g - rough_mean) * 0.7;

	// Rust: the scan's own spots and runs, and coarse rust where the part as a whole is rusty
	// (more where the paint is gone and on edges; the rust scan's own structure breaks the border up).
	float how = clamp(rust * 2.5, 0.0, 1.0);
	float spots = own * how;
	c = mix(c, mix(col, rust_color.rgb * shade, 0.5) * 0.7, spots);
	float rshade = dot(rcol, LUM) / max(dot(rust_mean, LUM), 0.01);
	float rn = env_fbm(p.xz * 2.1 + p.y * 2.6 + 17.0) * 0.75 + (rshade - 1.0) * 0.3 + (1.0 - coat) * 0.1 + curve * 0.06;
	float r = smoothstep(0.78 - rust * 0.6, 0.94 - rust * 0.6, rn) * step(0.001, rust);
	// (The scan is a saturated orange in full light: real rust on a tool is darker and duller.)
	vec3 rusty = rcol * mix(vec3(1.0), rust_color.rgb / max(rust_mean * 3.2, vec3(0.03)), 0.45);
	rusty = mix(rusty, vec3(dot(rusty, LUM)), 0.3) * 0.62;
	rusty = mix(rusty, rust_color.rgb * mix(1.0, rshade, 0.7), patina);
	c = mix(c, rusty, r);
	float rusted = max(spots, r);
	metal = mix(metal, 0.04, rusted);
	rough = mix(rough, 0.88, rusted);

	// Bare steel on worn edges catches the light.
	float bare = curve * (1.0 - coat) * (1.0 - rusted);
	c = mix(c, c * 1.45 + 0.03, bare * 0.6);
	rough = mix(rough, 0.3, bare * 0.5);

	// Heat colours: straw, bronze, purple, blue, then grey towards the top.
	if (temper > 0.0) {
		float t = clamp((v_obj.y - temper_bottom) / max(temper_top - temper_bottom, 1e-3), 0.0, 1.0);
		t += (macro + grain * 0.3) * 0.25;
		vec3 tc = mix(vec3(0.78, 0.62, 0.34), vec3(0.58, 0.36, 0.2), smoothstep(0.15, 0.35, t));
		tc = mix(tc, vec3(0.38, 0.22, 0.4), smoothstep(0.35, 0.55, t));
		tc = mix(tc, vec3(0.2, 0.3, 0.55), smoothstep(0.55, 0.75, t));
		tc = mix(tc, vec3(0.32, 0.32, 0.34), smoothstep(0.8, 1.0, t));
		float band = smoothstep(-0.05, 0.1, t) * temper * (1.0 - coat * 0.8);
		c = mix(c, tc * (0.75 + macro * 0.5) * steel_color.rgb * 2.4 * shade, band);
	}

	// Soot rising from the heat source.
	if (soot > 0.0) {
		float s = smoothstep(soot_bottom, soot_top, v_obj.y + macro * 0.12);
		s *= 0.75 + env_fbm(p.xz * 7.0 + p.y * 3.0) * 0.5;
		s = clamp(s * soot, 0.0, 1.0);
		c = mix(c, soot_color.rgb * (0.7 + shade * 0.3), s);
		metal = mix(metal, 0.1, s);
		rough = mix(rough, 0.9, s);
	}

	// Grime: dark runs down the sides and soft blotches (the scan brings its own fine dirt).
	if (grime > 0.0) {
		float side = 1.0 - abs(v_nworld.y);
		// Object space, so carried things keep their dirt where it is.
		float streak = env_noise(vec2(dot(p.xz, vec2(37.0, 29.0)), p.y * 2.2));
		float blotch = env_fbm(p.xz * 2.3 + p.y * 1.7 + 41.0);
		float g = (smoothstep(0.5, 0.9, streak) * 0.45 * side + smoothstep(0.55, 0.9, blotch) * 0.25) * grime;
		g = clamp(g, 0.0, 0.6);
		c = mix(c, c * vec3(0.4, 0.36, 0.32) + vec3(0.012, 0.01, 0.008), g);
		rough = mix(rough, 0.85, g);
		metal = mix(metal, metal * 0.4, g);
	}
	// Dust on everything that faces up.
	if (dust > 0.0) {
		float up = smoothstep(0.55, 0.95, v_nworld.y);
		float dn = env_fbm(p.xz * 6.0 + 9.0);
		float d = up * dust * (0.55 + dn * 0.6);
		c = mix(c, dust_color.rgb * (0.85 + grain * 0.3), clamp(d, 0.0, 0.85));
		rough = mix(rough, 0.95, d);
		metal = mix(metal, 0.0, d * 0.8);
	}

	if (polish_x > 0.0) {
		float face = smoothstep(polish_x - 0.004, polish_x + 0.002, abs(v_obj.x)) * step(0.6, abs(n.x));
		c = mix(c, vec3(0.62, 0.62, 0.64) * (1.0 + grain * 0.2), face);
		metal = mix(metal, 0.95, face);
		rough = mix(rough, 0.22, face);
	}

	ALBEDO = c;
	METALLIC = clamp(metal, 0.0, 1.0);
	ROUGHNESS = clamp(rough, 0.05, 1.0);
	SPECULAR = 0.4;
	AO = mix(1.0, arm.r, 0.8);
	AO_LIGHT_AFFECT = 0.3;
	// The scan's relief, turned from the object into view space; hammer dents on top.
	NORMAL = normalize((VIEW_MATRIX * vec4(normalize(mat3(MODEL_MATRIX) * bumped), 0.0)).xyz);
	if (dents > 0.0) {
		vec3 dv = env_voronoi(p.xy * 14.0 + p.z * 9.0);
		float h = smoothstep(0.0, 0.6, dv.x) * dents;
		NORMAL = env_bump(VERTEX, NORMAL, h * 0.0008, 1.0);
	}
}
