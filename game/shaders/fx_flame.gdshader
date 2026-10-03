shader_type spatial;
// Stylised toon flame on an upright billboard quad: teardrop shape distorted by
// rising noise, three crisp colour bands, HDR so it blooms. No textures.
render_mode unshaded, blend_mix, depth_draw_never, cull_disabled, shadows_disabled;

#include "res://shaders/fx_common.gdshaderinc"

uniform float heat : hint_range(0.0, 1.0) = 1.0;
uniform float energy = 1.0;
uniform float speed = 1.0;
/// How much the flame leans towards the camera when seen from above.
uniform float camera_tilt = 0.45;
instance uniform float seed = 0.0;

void vertex() {
	vec3 center = MODEL_MATRIX[3].xyz;
	vec3 to_cam = INV_VIEW_MATRIX[3].xyz - center;
	vec3 flat_dir = normalize(vec3(to_cam.x, 0.0, to_cam.z) + vec3(0.0001, 0.0, 0.0));
	vec3 up = normalize(mix(vec3(0.0, 1.0, 0.0), INV_VIEW_MATRIX[1].xyz, camera_tilt));
	vec3 right = normalize(cross(up, flat_dir));
	vec3 fwd = cross(right, up);
	vec2 s = vec2(length(MODEL_MATRIX[0].xyz), length(MODEL_MATRIX[1].xyz));
	mat4 m = mat4(vec4(right * s.x, 0.0), vec4(up * s.y, 0.0), vec4(fwd, 0.0), vec4(center, 1.0));
	MODELVIEW_MATRIX = VIEW_MATRIX * m;
}

float band(float d, float edge) {
	float w = clamp(fwidth(d), 0.001, 0.08);
	return smoothstep(edge - w, edge + w, d);
}

void fragment() {
	float y = 1.0 - UV.y;
	float x = UV.x * 2.0 - 1.0;
	float t = TIME * speed + seed * 13.7;
	float n = fx_fbm(vec3(x * 1.4 + seed * 5.0, y * 2.0 - t * 2.1, t * 0.35));
	float licks = fx_noise(vec3(x * 3.2, y * 3.6 - t * 3.2, seed * 9.0 + t * 0.2));
	x += ((n - 0.5) * 1.1 + sin(t * 2.3 + y * 4.0) * 0.12) * y;
	float width = 0.92 * pow(max(1.0 - y, 0.0), 0.6);
	float bottom = max(0.18 - y, 0.0) / 0.18;
	float d = 1.0 - length(vec2(x / max(width, 0.001), bottom));
	d -= (licks - 0.45) * 0.9 * y * y;
	float h = clamp(heat, 0.0, 1.0);
	float outer = band(d, 0.0);
	float mid = band(d, mix(0.5, 0.3, h));
	float core = band(d, mix(0.8, 0.62, h));
	// Yellow at the base, redder towards the tips.
	float cool = 0.3 * y;
	vec3 col = fx_heat_color(0.4 + 0.08 * h - cool) * 0.9;
	col = mix(col, fx_heat_color(0.76 + 0.08 * h - cool) * 1.35, mid);
	col = mix(col, fx_heat_color(1.0 - 0.6 * cool) * (1.8 + 1.0 * h), core);
	ALBEDO = col * energy * (0.45 + 0.55 * h);
	ALPHA = outer * smoothstep(0.0, 0.08, h);
}
