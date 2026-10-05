shader_type spatial;
// Stylized wood for boards, posts and planks: grain stretched along the board
// axis, darker streaks and the odd knot, per-board tint, silver-grey
// weathering, a darker damp foot near the ground and optional peeling paint.
// Per-piece data comes from vertex COLOR (written by EnvMesh.merge):
// r = random seed, gba = grain axis in mesh space (* 0.5 + 0.5).
// MultiMesh boards add their instance position to the seed.
render_mode diffuse_burley, specular_schlick_ggx;

#include "res://shaders/env_common.gdshaderinc"

uniform vec4 base_color : source_color = vec4(0.549, 0.416, 0.306, 1.0);
uniform vec4 grain_color : source_color = vec4(0.36, 0.25, 0.18, 1.0);
uniform vec4 weather_color : source_color = vec4(0.56, 0.53, 0.50, 1.0);
uniform float weathering : hint_range(0.0, 1.0) = 0.35;
uniform float variation : hint_range(0.0, 0.5) = 0.12;
uniform float grain_strength : hint_range(0.0, 1.0) = 0.55;
uniform vec4 paint_color : source_color = vec4(0.247, 0.498, 0.525, 1.0);
// 0 = bare wood, 1 = fully painted; in between paint flakes off at random.
uniform float paint : hint_range(0.0, 1.0) = 0.0;
uniform float roughness_base : hint_range(0.0, 1.0) = 0.82;

varying vec3 v_local;
varying vec3 v_world;
varying float v_seed;
varying vec3 v_axis;

void vertex() {
	v_local = VERTEX;
	v_world = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	v_seed = fract(COLOR.r * 7.31 + env_hash13(floor(MODEL_MATRIX[3].xyz * 13.7) + 0.5));
	v_axis = normalize(COLOR.gba * 2.0 - 1.0 + vec3(0.0, 1e-4, 0.0));
}

void fragment() {
	float along = dot(v_local, v_axis);
	vec3 side = v_local - v_axis * along;
	float across = side.x + side.y * 0.7 + side.z * 1.3;
	vec2 g = vec2(across * 26.0 + v_seed * 31.0, along * 1.6 + v_seed * 17.0);
	float warp = env_noise(g * vec2(0.3, 0.8)) * 2.0;
	float streak = env_noise(vec2(g.x + warp, g.y * 0.5));
	float fine = env_noise(vec2(g.x * 3.0 + warp, g.y * 4.0));
	float lines = smoothstep(0.55, 0.85, streak) * 0.7 + smoothstep(0.6, 0.9, fine) * 0.3;
	// Knots: rare dark ovals.
	vec2 kp = vec2(across * 14.0, along * 3.0) + v_seed * 9.0;
	vec3 kv = env_voronoi(kp);
	float knot = (1.0 - smoothstep(0.04, 0.12, kv.x)) * step(0.96, kv.y);

	vec3 c = base_color.rgb * (1.0 + (v_seed - 0.5) * variation * 2.0);
	c *= mix(vec3(1.0), vec3(1.04, 0.99, 0.94), fract(v_seed * 5.3));
	c = mix(c, grain_color.rgb, lines * grain_strength + knot * 0.5);
	// Weathering: silver-grey patches, stronger towards the top of a board.
	float w = smoothstep(0.35, 0.75, env_fbm(v_world.xz * 0.9 + v_world.y * 1.3 + v_seed * 5.0)) * weathering;
	c = mix(c, weather_color.rgb * (0.9 + lines * 0.2), w);
	// Paint that flakes off along the grain.
	if (paint > 0.0) {
		float flake = env_fbm(vec2(across * 9.0, along * 2.5) + v_seed * 13.0);
		float keep = smoothstep(1.0 - paint - 0.08, 1.0 - paint + 0.08, flake + 0.2);
		vec3 pc = paint_color.rgb * (0.92 + env_noise(v_world.xy * 4.0 + v_world.z) * 0.12);
		c = mix(c, pc, keep);
	}
	// Damp, dirty foot.
	c *= mix(0.62, 1.0, smoothstep(0.0, 0.3, v_world.y));
	c *= 0.95 + env_noise(v_world.xz * 3.0 + v_world.y * 5.0) * 0.1;
	ALBEDO = c;
	ROUGHNESS = clamp(roughness_base + lines * 0.08 - paint * 0.15, 0.0, 1.0);
	SPECULAR = 0.3;
	NORMAL = env_bump(VERTEX, NORMAL, (lines + knot) * 0.0012, 1.0);
}
