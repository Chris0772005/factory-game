shader_type spatial;
// Molten metal stream: hot core, cooler rim, emission streaks flowing along UV.y
// (arc length in metres) and a wobbling surface. UV2.x carries the local radius.
// Transparent pass so the ink outline ignores it (no depth/normal writes).
render_mode unshaded, blend_mix, depth_draw_never, cull_back, shadows_disabled;

#include "res://shaders/fx_common.gdshaderinc"

uniform float temperature : hint_range(0.0, 1.0) = 0.95;
uniform float energy = 1.0;
uniform float flow_speed = 3.0;
uniform float wobble = 0.18;

void vertex() {
	float w = fx_noise(vec3(UV.x * 4.0, UV.y * 9.0 - TIME * flow_speed * 3.0, 0.0)) - 0.5;
	VERTEX += NORMAL * UV2.x * w * wobble * 2.0;
}

void fragment() {
	float facing = clamp(dot(NORMAL, VIEW), 0.0, 1.0);
	float along = UV.y - TIME * flow_speed;
	float streak = fx_noise(vec3(UV.x * 7.0, along * 5.0, 3.0));
	float fine = fx_noise(vec3(UV.x * 18.0, along * 14.0, 9.0));
	float core = pow(facing, 0.7);
	float glint = fx_glint_lines(vec3(UV.x * 5.0, along * 2.5, 7.0)) * core;
	float t = temperature * mix(0.6, 1.04, core) * (0.92 + 0.1 * streak + 0.04 * fine) + 0.1 * glint;
	vec3 col = fx_heat_color(t) * fx_heat_energy(t) * energy * (1.0 + 0.5 * glint);
	// Darker skin streaks on the cooler rim sell the "thick liquid" read.
	col *= mix(1.0, 0.55 + 0.45 * streak, 1.0 - core);
	ALBEDO = col;
	ALPHA = smoothstep(0.0, 0.35, facing);
}
