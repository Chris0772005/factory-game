shader_type spatial;
// Chalkboard slate (UV 0..1 over the board): matte green-black with the
// pale haze of half-wiped chalk, eraser arcs and a few stray scribbles.
// Text and doodles are Label3D chalk on top.
render_mode diffuse_burley, specular_schlick_ggx;

#include "res://shaders/env_common.gdshaderinc"

uniform vec4 slate : source_color = vec4(0.17, 0.21, 0.2, 1.0);
uniform vec4 chalk : source_color = vec4(0.88, 0.88, 0.84, 1.0);
uniform float haze : hint_range(0.0, 1.0) = 0.35;

varying vec2 v_uv;

void vertex() {
	v_uv = UV;
}

void fragment() {
	vec2 uv = v_uv;
	float n = env_fbm(uv * vec2(6.0, 4.0));
	float grain = env_noise(uv * 400.0) - 0.5;
	vec3 c = slate.rgb * (0.9 + n * 0.25 + grain * 0.08);
	// Wiped chalk: broad haze plus eraser arcs.
	float arcs = sin(length(uv - vec2(0.2, 1.3)) * 38.0 + n * 3.0) * 0.5 + 0.5;
	float h = smoothstep(0.45, 0.85, n) * 0.6 + smoothstep(0.75, 0.95, arcs) * 0.25 * smoothstep(0.3, 0.6, n);
	c = mix(c, chalk.rgb, clamp(h * haze, 0.0, 1.0) * 0.35);
	// Stray scribbles near the bottom.
	float s = abs(sin(uv.x * 70.0 + sin(uv.x * 11.0) * 2.0) * 0.012 + 0.9 - uv.y + sin(uv.x * 7.0) * 0.015);
	float scribble = (1.0 - smoothstep(0.0015, 0.004, s)) * step(0.55, uv.x) * step(uv.x, 0.85);
	c = mix(c, chalk.rgb, scribble * 0.5);
	ALBEDO = c;
	ROUGHNESS = 0.92;
	SPECULAR = 0.2;
}
