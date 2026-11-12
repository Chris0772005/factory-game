shader_type spatial;
// Worked iron and sheet steel for the foundry stations (Art Bible 5.3 "kaltes
// Werkzeugmetall"): chipped paint over bare steel, rust blooms, a soot
// gradient from a height, temper colours from heat (straw -> purple -> blue)
// and hammer dents in the normal. Object space, so carried tools keep their
// pattern; vertex COLOR.r (EnvMesh.merge seed) varies every piece.
render_mode diffuse_burley, specular_schlick_ggx;

#include "res://shaders/env_common.gdshaderinc"
#include "res://shaders/env_photo.gdshaderinc"
#include "res://shaders/env_cutaway.gdshaderinc"

uniform vec4 paint_color : source_color = vec4(0.29, 0.38, 0.42, 1.0);
uniform vec4 steel_color : source_color = vec4(0.3, 0.3, 0.31, 1.0);
uniform vec4 rust_color : source_color = vec4(0.47, 0.27, 0.17, 1.0);
uniform vec4 soot_color : source_color = vec4(0.1, 0.09, 0.09, 1.0);
// 0 = bare metal, 1 = fully painted (chips show the steel underneath).
uniform float paint : hint_range(0.0, 1.0) = 0.0;
uniform float rust : hint_range(0.0, 1.0) = 0.2;
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
uniform float dents : hint_range(0.0, 1.0) = 0.3;
uniform float noise_scale = 1.0;
// Workshop dust settles on faces that look up; grime runs down the sides
// and gathers near the floor; edges and corners are rubbed bare. Together
// they take the factory-fresh look off every machine.
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
	vec3 p = v_obj * noise_scale + v_seed * 13.0;
	float macro = env_fbm(p.xz * 3.1 + p.y * 2.3) - 0.5;
	float grain = env_noise(p.xy * 61.0 + p.z * 47.0) - 0.5;
	vec3 steel = steel_color.rgb * (1.0 + macro * 0.25 + grain * 0.12);
	vec3 c = steel;
	float metal = metallic_steel;
	float rough = roughness_steel + grain * 0.1;

	// Rounded edges and corners (where the normal turns quickly) are rubbed.
	float curve = clamp(length(fwidth(normalize(v_nobj))) * 6.0 - 0.04, 0.0, 1.0) * edge_wear;
	// Paint with chips: noisy mask, a bright primer rim around each chip.
	float chip_n = env_fbm(p.xy * 9.0 + p.z * 7.0 + 3.0) * 0.7 + env_noise(p.zy * 23.0) * 0.3;
	chip_n -= curve * (0.25 + grain * 0.5);
	float keep = smoothstep(1.0 - paint - 0.04, 1.0 - paint + 0.04, chip_n + 0.12);
	float rim = smoothstep(0.0, 0.05, keep) * (1.0 - smoothstep(0.05, 0.3, keep));
	vec3 pc = paint_color.rgb * (1.0 + macro * 0.2 + grain * 0.06);
	c = mix(c, pc, keep);
	c = mix(c, c * 1.35 + 0.05, rim * paint);
	metal = mix(metal, 0.0, keep);
	rough = mix(rough, roughness_paint + grain * 0.08, keep);

	// Rust blooms, mostly where paint is gone and low down.
	float rn = env_fbm(p.xz * 5.3 + p.y * 6.1 + 17.0) + (1.0 - keep) * 0.18;
	float r = smoothstep(0.62, 0.78, rn + rust * 0.35 - 0.2) * rust;
	c = mix(c, rust_color.rgb * (0.8 + grain * 0.6 + macro * 0.4), r);
	metal = mix(metal, 0.05, r);
	rough = mix(rough, 0.88, r);

	// Bare steel on worn edges catches the light.
	float bare = curve * (1.0 - keep) * (1.0 - r);
	c = mix(c, c * 1.5 + 0.04, bare * 0.6);
	rough = mix(rough, 0.3, bare * 0.5);

	// Heat colours: straw, bronze, purple, blue, then grey towards the top.
	if (temper > 0.0) {
		float t = clamp((v_obj.y - temper_bottom) / max(temper_top - temper_bottom, 1e-3), 0.0, 1.0);
		t += (macro + grain * 0.3) * 0.25;
		vec3 tc = mix(vec3(0.78, 0.62, 0.34), vec3(0.58, 0.36, 0.2), smoothstep(0.15, 0.35, t));
		tc = mix(tc, vec3(0.38, 0.22, 0.4), smoothstep(0.35, 0.55, t));
		tc = mix(tc, vec3(0.2, 0.3, 0.55), smoothstep(0.55, 0.75, t));
		tc = mix(tc, vec3(0.32, 0.32, 0.34), smoothstep(0.8, 1.0, t));
		float band = smoothstep(-0.05, 0.1, t) * temper * (1.0 - keep * 0.8);
		c = mix(c, tc * (0.75 + macro * 0.5) * steel_color.rgb * 2.4, band);
	}

	// Soot rising from the heat source.
	if (soot > 0.0) {
		float s = smoothstep(soot_bottom, soot_top, v_obj.y + macro * 0.12);
		s *= 0.75 + env_fbm(p.xz * 7.0 + p.y * 3.0) * 0.5;
		s = clamp(s * soot, 0.0, 1.0);
		c = mix(c, soot_color.rgb, s);
		metal = mix(metal, 0.1, s);
		rough = mix(rough, 0.9, s);
	}

	// Grime: dark streaks running down the sides, heavier near the floor.
	if (grime > 0.0) {
		float side = 1.0 - abs(v_nworld.y);
		// Object space, so carried things keep their dirt where it is.
		float streak = env_noise(vec2(dot(p.xz, vec2(37.0, 29.0)), p.y * 2.2));
		float blotch = env_fbm(p.xz * 2.3 + p.y * 1.7 + 41.0);
		float g = (smoothstep(0.35, 0.8, streak) * 0.9 * side + smoothstep(0.55, 0.9, blotch) * 0.28) * grime;
		g = clamp(g, 0.0, 0.7);
		c = mix(c, c * vec3(0.34, 0.3, 0.26) + vec3(0.012, 0.01, 0.008), g);
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
		float face = smoothstep(polish_x - 0.004, polish_x + 0.002, abs(v_obj.x)) * step(0.6, abs(v_nobj.x));
		c = mix(c, vec3(0.62, 0.62, 0.64) * (1.0 + grain * 0.2), face);
		metal = mix(metal, 0.95, face);
		rough = mix(rough, 0.22, face);
	}

	ALBEDO = c;
	METALLIC = clamp(metal, 0.0, 1.0);
	ROUGHNESS = clamp(rough, 0.05, 1.0);
	SPECULAR = 0.4;
	if (dents > 0.0) {
		vec3 dv = env_voronoi(p.xy * 14.0 + p.z * 9.0);
		float h = smoothstep(0.0, 0.6, dv.x) * dents + grain * 0.3;
		NORMAL = env_bump(VERTEX, NORMAL, h * 0.0012, 1.0);
	}
	// Real scratches, pitting and rust grain from a scan, travelling with the part.
	vec3 ph_a = ALBEDO;
	float ph_r = ROUGHNESS;
	NORMAL = env_photo_object(ph_metal_d, ph_metal_n, ph_metal_arm, v_obj + v_seed * 3.0, NORMAL, INV_VIEW_MATRIX, VIEW_MATRIX, MODEL_MATRIX, 1.3, mix(0.38, 0.1, keep), ph_a, ph_r);
	ALBEDO = ph_a;
	ROUGHNESS = ph_r;
}
