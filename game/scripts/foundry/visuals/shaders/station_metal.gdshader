shader_type spatial;
// Worked iron and sheet steel for the foundry stations (Art Bible 5.3 "kaltes
// Werkzeugmetall"): chipped paint over bare steel, rust blooms, a soot
// gradient from a height, temper colours from heat (straw -> purple -> blue)
// and hammer dents in the normal. Object space, so carried tools keep their
// pattern; vertex COLOR.r (EnvMesh.merge seed) varies every piece.
render_mode diffuse_burley, specular_schlick_ggx;

#include "res://shaders/env_common.gdshaderinc"

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
// Polished striking faces: bare, bright steel where |object x| > this (0 = off).
uniform float polish_x = 0.0;

varying vec3 v_obj;
varying vec3 v_nobj;
varying float v_seed;

void vertex() {
	v_obj = VERTEX;
	v_nobj = NORMAL;
	v_seed = COLOR.r;
}

void fragment() {
	vec3 p = v_obj * noise_scale + v_seed * 13.0;
	float macro = env_fbm(p.xz * 3.1 + p.y * 2.3) - 0.5;
	float grain = env_noise(p.xy * 61.0 + p.z * 47.0) - 0.5;
	vec3 steel = steel_color.rgb * (1.0 + macro * 0.25 + grain * 0.12);
	vec3 c = steel;
	float metal = metallic_steel;
	float rough = roughness_steel + grain * 0.1;

	// Paint with chips: noisy mask, a bright primer rim around each chip.
	float chip_n = env_fbm(p.xy * 9.0 + p.z * 7.0 + 3.0) * 0.7 + env_noise(p.zy * 23.0) * 0.3;
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
}
