shader_type spatial;
// Stylized grass tufts for MultiMesh chunks. Blades take the lawn colour of
// the ground under their root (same env_lawn as the ground shader) so they
// melt into the turf, brighten towards the tip, sway in gusts and bend away
// from up to four workers (`trample`, set every frame by GrassField).
// Mesh: UV.y = 0 at the root, 1 at the tip. COLOR.a = 1 marks flower heads
// (COLOR.rgb is their colour). INSTANCE_CUSTOM: r = shade, g = dryness, b = phase.
// Drawn in the transparent pass (ALPHA = 1, depth_draw_always) so blades stay
// out of the depth/normal buffers the ink outline pass reads: otherwise every
// blade gets an outline. ROUGHNESS 0.99 is the Art Bible's "no outline" marker
// for when the outline pass learns to skip it (then the ALPHA line can go).
render_mode cull_disabled, diffuse_lambert_wrap, specular_disabled, depth_draw_always;

#include "res://shaders/env_common.gdshaderinc"

uniform vec4 grass_dark : source_color = vec4(0.165, 0.337, 0.251, 1.0);
uniform vec4 grass_mid : source_color = vec4(0.306, 0.541, 0.322, 1.0);
uniform vec4 grass_light : source_color = vec4(0.498, 0.690, 0.384, 1.0);
uniform vec4 tip_tint : source_color = vec4(0.62, 0.78, 0.46, 1.0);
uniform vec4 straw : source_color = vec4(0.62, 0.6, 0.4, 1.0);
uniform vec2 wind_dir = vec2(0.8, 0.6);
uniform float wind_strength = 1.0;
// Tip displacement in metres for a full gust.
uniform float sway = 0.05;
// xyz = worker position, w = radius (0 = slot unused).
uniform vec4 trample[4];

varying float v_tip;
varying vec3 v_lawn;
varying vec4 v_flower;
varying vec3 v_custom;

void vertex() {
	v_tip = UV.y;
	v_flower = COLOR;
	v_custom = INSTANCE_CUSTOM.rgb;
	vec3 root_pos = MODEL_MATRIX[3].xyz;
	// The turf colour is the same for the whole tuft: evaluated per vertex.
	v_lawn = env_lawn(root_pos.xz, grass_dark.rgb, grass_mid.rgb, grass_light.rgb);
	vec3 world = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	float gust = env_noise(world.xz * 0.3 - wind_dir * TIME * 0.65);
	float flutter = sin(TIME * 2.7 + dot(root_pos.xz, vec2(1.7, 2.3)) + INSTANCE_CUSTOM.b * 6.283);
	vec2 side = vec2(-wind_dir.y, wind_dir.x);
	vec2 bend = wind_dir * sway * wind_strength * (0.25 + gust * 1.4) + side * flutter * sway * 0.25;
	for (int i = 0; i < 4; i++) {
		float r = trample[i].w;
		if (r > 0.0) {
			vec2 away = world.xz - trample[i].xz;
			float push = 1.0 - smoothstep(r * 0.35, r, length(away));
			bend += normalize(away + vec2(1e-4)) * push * 0.18;
		}
	}
	float k = v_tip * v_tip;
	vec3 offset_world = vec3(bend.x, -dot(bend, bend) * 0.8, bend.y) * k;
	// World -> local for rotation + uniform scale instance transforms.
	float s2 = dot(MODEL_MATRIX[0].xyz, MODEL_MATRIX[0].xyz);
	VERTEX += (vec4(offset_world, 0.0) * MODEL_MATRIX).xyz / s2;
	// Mostly ground-up normals: tufts shade like the turf instead of like cards.
	NORMAL = normalize(mix(vec3(0.0, 1.0, 0.0), NORMAL, 0.2 + v_tip * 0.3));
}

void fragment() {
	vec3 lawn = v_lawn;
	vec3 root = mix(lawn, grass_dark.rgb, 0.5) * 0.8;
	vec3 tip = mix(lawn * 1.15, tip_tint.rgb, 0.25);
	vec3 c = mix(root, tip, smoothstep(0.0, 1.0, v_tip));
	c *= 0.86 + v_custom.r * 0.28;
	c = mix(c, straw.rgb * (0.7 + 0.4 * v_tip), v_custom.g * smoothstep(0.2, 1.0, v_tip));
	if (v_flower.a > 0.5) {
		c = v_flower.rgb;
	}
	ALBEDO = c;
	ROUGHNESS = 0.99;
	ALPHA = 1.0;
	BACKLIGHT = vec3(0.22, 0.28, 0.1) * v_tip;
	if (!FRONT_FACING) {
		NORMAL = -NORMAL;
	}
}
