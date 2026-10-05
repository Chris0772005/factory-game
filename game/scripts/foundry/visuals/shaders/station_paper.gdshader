shader_type spatial;
// Paper notes, sketch sheets and photos (UV 0..1 over the sheet, UV.y = 0 at
// the top/pinned edge): fibrous paper with darker edges, optional ruled or
// blueprint grid lines, and a gentle flutter of the free bottom corners.
render_mode cull_disabled, diffuse_lambert_wrap, specular_schlick_ggx;

#include "res://shaders/env_common.gdshaderinc"

instance uniform vec4 paper : source_color = vec4(0.96, 0.93, 0.86, 1.0);
instance uniform vec4 ink : source_color = vec4(0.36, 0.45, 0.62, 1.0);
// 0 plain, 1 ruled lines, 2 blueprint grid, 3 photo (dark image + white border).
instance uniform float pattern = 0.0;
instance uniform float phase = 0.0;
uniform float flutter = 0.0035;

varying vec2 v_uv;

void vertex() {
	float free = UV.y * UV.y * (0.4 + 0.6 * abs(UV.x - 0.5) * 2.0);
	float w = sin(TIME * 2.3 + phase * 6.283 + UV.x * 2.0) * 0.6 + sin(TIME * 3.9 + phase * 11.0) * 0.4;
	VERTEX += NORMAL * w * flutter * free;
	v_uv = UV;
}

void fragment() {
	vec2 uv = v_uv;
	vec3 c = paper.rgb * (0.95 + env_noise(uv * vec2(90.0, 120.0) + phase * 5.0) * 0.08);
	float edge = min(min(uv.x, 1.0 - uv.x), min(uv.y, 1.0 - uv.y));
	c *= mix(0.86, 1.0, smoothstep(0.0, 0.06, edge));
	int pat = int(pattern + 0.5);
	if (pat == 1) {
		float l = 1.0 - smoothstep(0.0, 0.012, abs(fract(uv.y * 9.0) - 0.5) * 2.0 * 0.5 - 0.48);
		l *= step(0.18, uv.y);
		c = mix(c, ink.rgb, l * 0.35);
	} else if (pat == 2) {
		vec2 g = abs(fract(uv * vec2(10.0, 7.0)) - 0.5);
		float grid = 1.0 - smoothstep(0.46, 0.49, max(g.x, g.y));
		c = mix(c, ink.rgb, grid * 0.4);
	} else if (pat == 3) {
		float inside = step(0.07, uv.x) * step(uv.x, 0.93) * step(0.07, uv.y) * step(uv.y, 0.78);
		vec3 img = mix(ink.rgb * 0.5, ink.rgb, smoothstep(0.2, 0.75, uv.y + env_fbm(uv * 4.0 + phase) * 0.3));
		float blob = 1.0 - smoothstep(0.12, 0.16, length((uv - vec2(0.5, 0.48)) * vec2(1.0, 1.3)));
		img = mix(img, vec3(0.95, 0.55, 0.25), blob * 0.8);
		c = mix(c, img, inside);
	}
	ALBEDO = c;
	ROUGHNESS = 0.9;
	SPECULAR = 0.25;
	BACKLIGHT = c * 0.25;
}
