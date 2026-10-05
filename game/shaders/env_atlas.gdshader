shader_type spatial;
// KayKit gradient-atlas props restyled for the yard (Art Bible 5.1/5.2):
// the pack's painted atlas as albedo, a tint (e.g. to calm saturated
// barrels), world-space macro noise and grain so repeated props never look
// identical, darker ground contact and rougher, less plastic surfaces.
render_mode diffuse_burley, specular_schlick_ggx;

#include "res://shaders/env_common.gdshaderinc"

uniform sampler2D atlas : source_color, filter_linear_mipmap, repeat_enable;
uniform vec4 tint : source_color = vec4(1.0, 1.0, 1.0, 1.0);
// 0 = keep atlas colours, 1 = fully desaturated before tinting.
uniform float desaturate : hint_range(0.0, 1.0) = 0.0;
uniform float macro : hint_range(0.0, 0.5) = 0.08;
uniform float grain : hint_range(0.0, 0.5) = 0.05;
uniform float dirt : hint_range(0.0, 1.0) = 0.25;
uniform float roughness_base : hint_range(0.0, 1.0) = 0.78;
uniform float metallic_base : hint_range(0.0, 1.0) = 0.0;

varying vec3 v_world;

void vertex() {
	v_world = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	vec3 a = texture(atlas, UV).rgb;
	float l = dot(a, vec3(0.299, 0.587, 0.114));
	vec3 c = mix(a, vec3(l), desaturate) * tint.rgb;
	float m = env_fbm(v_world.xz * 0.6 + v_world.y * 0.8) - 0.5;
	float g = env_noise(v_world.xy * 11.0 + v_world.z * 9.0) - 0.5;
	c *= 1.0 + m * macro * 2.0 + g * grain * 2.0;
	// Grime that collects low down and in patches.
	float grime = (1.0 - smoothstep(0.0, 0.35, v_world.y)) * 0.6 + smoothstep(0.6, 0.85, env_fbm(v_world.xz * 2.2 + v_world.y * 3.0)) * 0.4;
	c *= 1.0 - grime * dirt * 0.45;
	ALBEDO = c;
	ROUGHNESS = clamp(roughness_base + g * 0.12, 0.0, 1.0);
	METALLIC = metallic_base;
	SPECULAR = 0.35;
}
