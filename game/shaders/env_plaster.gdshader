shader_type spatial;
// Rendered house wall: large soft blotches, fine grain, rain streaks running
// down, grime near the ground and patches where the plaster has chipped off
// and shows the bricks underneath. Pattern in world space, picked by the
// world normal (walls facing x use z/y, walls facing z use x/y).
render_mode diffuse_burley, specular_schlick_ggx;

#include "res://shaders/env_common.gdshaderinc"

uniform vec4 plaster : source_color = vec4(0.890, 0.804, 0.690, 1.0);
uniform vec4 grime : source_color = vec4(0.52, 0.47, 0.44, 1.0);
uniform vec4 brick : source_color = vec4(0.710, 0.396, 0.290, 1.0);
uniform vec4 mortar : source_color = vec4(0.847, 0.765, 0.647, 1.0);
uniform float chips : hint_range(0.0, 1.0) = 0.6;
uniform float streaks : hint_range(0.0, 1.0) = 0.5;
// 1 = bare brickwork everywhere (chimneys, garden walls).
uniform float brickwork : hint_range(0.0, 1.0) = 0.0;

varying vec3 v_world;

void vertex() {
	v_world = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	vec3 wn = (INV_VIEW_MATRIX * vec4(NORMAL, 0.0)).xyz;
	vec2 uv = abs(wn.x) > 0.5 ? v_world.zy : v_world.xy;
	if (abs(wn.y) > 0.6) {
		uv = v_world.xz;
	}
	float blot = env_fbm(uv * 0.35);
	float fine = env_noise(uv * 14.0);
	float pores = env_noise(uv * 41.0);
	vec3 c = plaster.rgb * (0.9 + blot * 0.18) * (0.95 + fine * 0.07 + pores * 0.04);
	// Rain streaks: vertically stretched noise.
	float streak = env_noise(vec2(uv.x * 5.0, uv.y * 0.3)) * env_fbm(vec2(uv.x * 1.1, uv.y * 0.15 + 3.0));
	c = mix(c, grime.rgb, smoothstep(0.3, 0.65, streak) * 0.3 * streaks);
	// Grime and splash-back near the ground.
	c = mix(c, grime.rgb * 0.85, (1.0 - smoothstep(0.0, 1.1, v_world.y)) * 0.4);
	// Chipped plaster revealing bricks.
	float chipn = env_fbm(uv * 0.75 + 11.0) + fine * 0.06;
	float chip = max(smoothstep(0.735, 0.75, chipn) * chips, brickwork);
	float rim = max(smoothstep(0.715, 0.735, chipn) * chips - chip, 0.0);
	if (chip > 0.0) {
		vec2 b = uv * vec2(4.0, 11.8);
		b.x += step(1.0, mod(floor(b.y), 2.0)) * 0.5;
		vec2 f = fract(b);
		float line = clamp(step(f.x, 0.07) + step(f.y, 0.14), 0.0, 1.0);
		float id = env_hash12(floor(b));
		vec3 bc = mix(brick.rgb * (0.82 + id * 0.3), mortar.rgb * 0.9, line);
		c = mix(c, bc, chip);
	}
	c *= 1.0 + rim * 0.12;
	ALBEDO = c;
	ROUGHNESS = 0.9 - fine * 0.05;
	SPECULAR = 0.3;
	NORMAL = env_bump(VERTEX, NORMAL, (blot * 0.5 + fine * 0.3 + pores * 0.2) * 0.003 - chip * 0.008, 1.0);
}
