shader_type spatial;
// General stylized surface for procedural set pieces (Art Bible 5.2):
// top-to-bottom gradient, world-space macro noise and grain, darker ground
// contact, optional rust/dirt patches and metal. Vertex COLOR.r (seed from
// EnvMesh.merge) shifts each piece's tone a little.
render_mode diffuse_burley, specular_schlick_ggx;

#include "res://shaders/env_common.gdshaderinc"

uniform vec4 base_color : source_color = vec4(0.6, 0.58, 0.55, 1.0);
uniform vec4 stain_color : source_color = vec4(0.36, 0.25, 0.18, 1.0);
// World heights where the gradient starts and ends.
uniform float grad_bottom = 0.0;
uniform float grad_top = 2.0;
uniform float gradient : hint_range(0.0, 1.0) = 0.2;
uniform float macro : hint_range(0.0, 0.5) = 0.1;
uniform float grain : hint_range(0.0, 0.5) = 0.06;
uniform float variation : hint_range(0.0, 0.5) = 0.08;
// Rust / stain patches (0 = none).
uniform float stains : hint_range(0.0, 1.0) = 0.0;
uniform float metallic_base : hint_range(0.0, 1.0) = 0.0;
uniform float roughness_base : hint_range(0.0, 1.0) = 0.8;
uniform float contact_dark : hint_range(0.0, 1.0) = 0.3;
uniform float noise_scale = 1.0;
uniform float bump = 0.0;

varying vec3 v_world;
varying float v_seed;

void vertex() {
	v_world = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	v_seed = fract(COLOR.r * 7.31 + env_hash13(floor(MODEL_MATRIX[3].xyz * 13.7) + 0.5));
}

void fragment() {
	vec3 p = v_world * noise_scale;
	float m = env_fbm(p.xz * 0.45 + p.y * 0.6) - 0.5;
	float g = env_noise(p.xy * 9.0 + p.z * 7.0) - 0.5;
	vec3 c = base_color.rgb * (1.0 + (v_seed - 0.5) * variation * 2.0);
	c *= mix(1.0 - gradient, 1.0, smoothstep(grad_bottom, grad_top, v_world.y));
	c *= 1.0 + m * macro * 2.0 + g * grain * 2.0;
	float st = 0.0;
	if (stains > 0.0) {
		st = smoothstep(0.55, 0.75, env_fbm(p.xz * 1.4 + p.y * 2.1 + v_seed * 7.0) + (stains - 0.5) * 0.5);
		c = mix(c, stain_color.rgb * (0.8 + g), st);
	}
	c *= mix(1.0 - contact_dark, 1.0, smoothstep(0.0, 0.18, v_world.y));
	ALBEDO = c;
	METALLIC = metallic_base * (1.0 - st);
	ROUGHNESS = clamp(roughness_base + g * 0.15 + st * 0.2, 0.0, 1.0);
	SPECULAR = 0.35;
	if (bump > 0.0) {
		NORMAL = env_bump(VERTEX, NORMAL, (m + g * 0.4) * bump * 0.01, 1.0);
	}
}
