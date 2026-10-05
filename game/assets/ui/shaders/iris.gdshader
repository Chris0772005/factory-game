shader_type canvas_item;
// Scene transition: an ink iris closing on the screen centre with a thin molten rim.
// progress 0 = clear, 1 = fully covered.

uniform float progress : hint_range(0.0, 1.0) = 0.0;
uniform vec4 ink : source_color = vec4(0.122, 0.106, 0.176, 1.0);
uniform vec4 rim_hot : source_color = vec4(1.0, 0.824, 0.478, 1.0);
uniform vec4 rim : source_color = vec4(1.0, 0.416, 0.102, 1.0);
uniform vec2 center = vec2(0.5, 0.5);

void fragment() {
	vec2 px = 1.0 / SCREEN_PIXEL_SIZE;
	vec2 p = (SCREEN_UV - center) * px / px.y;
	float max_r = length(max(center, 1.0 - center) * px / px.y) + 0.02;
	float r = (1.0 - progress) * max_r;
	float d = length(p) - r;
	float edge = 1.5 / px.y;
	float cover = smoothstep(-edge, edge, d);
	// Molten rim just inside the ink, fading as the iris closes completely.
	float band = 1.0 - smoothstep(0.0, 0.018, abs(d + 0.012));
	float rim_k = band * (1.0 - smoothstep(0.85, 1.0, progress)) * step(0.001, progress);
	vec3 rim_col = mix(rim.rgb, rim_hot.rgb, 1.0 - smoothstep(0.0, 0.012, abs(d + 0.012)));
	vec3 col = mix(rim_col, ink.rgb, cover);
	float a = max(cover, rim_k);
	COLOR = vec4(col, a * step(0.0005, progress));
}
