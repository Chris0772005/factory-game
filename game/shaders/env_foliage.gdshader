shader_type spatial;
// Stylized foliage blobs (tree crowns, bushes, hedges): low-poly spheres
// pushed out into lumps by world noise, shaded with a soft wrap and a
// top-lit gradient, broken into leaf clumps by a Voronoi pattern, with
// light shining through at the rim and a slow sway that grows with height.
render_mode diffuse_lambert_wrap, specular_schlick_ggx;

#include "res://shaders/env_common.gdshaderinc"

uniform vec4 top_color : source_color = vec4(0.42, 0.62, 0.36, 1.0);
uniform vec4 bottom_color : source_color = vec4(0.18, 0.35, 0.27, 1.0);
uniform vec4 tint : source_color = vec4(1.0, 1.0, 1.0, 1.0);
uniform float lumps = 0.16;
uniform float clump_scale = 2.6;
// Sway: metres of motion per metre above `sway_base` (world y).
uniform float sway = 0.012;
uniform float sway_base = 0.0;

varying vec3 v_world;
varying vec3 v_normal_world;

void vertex() {
	vec3 wp = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	float n = env_fbm(wp.xz * 1.1 + wp.y * 0.9) + env_noise(wp.xy * 2.3 + wp.z) * 0.35;
	VERTEX += NORMAL * (n - 0.6) * lumps;
	float h = max(wp.y - sway_base, 0.0);
	vec2 wave = vec2(sin(TIME * 0.9 + wp.x * 0.25 + wp.y * 0.3), cos(TIME * 0.7 + wp.z * 0.3)) * sway * h;
	float s2 = dot(MODEL_MATRIX[0].xyz, MODEL_MATRIX[0].xyz);
	VERTEX += (vec4(wave.x, 0.0, wave.y, 0.0) * MODEL_MATRIX).xyz / s2;
	v_world = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	v_normal_world = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
}

void fragment() {
	vec3 wn = normalize(v_normal_world);
	vec3 v = env_voronoi(v_world.xz * clump_scale + v_world.y * clump_scale * 0.7);
	float clump = smoothstep(0.0, 0.75, v.x);
	float t = smoothstep(-0.7, 0.9, wn.y + (v.y - 0.5) * 0.4);
	vec3 c = mix(bottom_color.rgb, top_color.rgb, t) * tint.rgb;
	c *= 1.05 - clump * 0.3;
	c *= 0.92 + env_noise(v_world.xz * 7.0 + v_world.y * 5.0) * 0.16;
	ALBEDO = c;
	ROUGHNESS = 0.92;
	SPECULAR = 0.2;
	BACKLIGHT = vec3(0.2, 0.26, 0.1) * (1.0 - clump * 0.5);
	NORMAL = env_bump(VERTEX, NORMAL, -clump * 0.03, 1.0);
}
