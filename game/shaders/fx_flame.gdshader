shader_type spatial;
// Flame on an upright billboard quad: a soft, glowing body torn into wisps by
// two layers of rising turbulence, deep red at the edges, orange, then a
// yellow-white core. Additive and HDR, so overlapping tongues build up to a
// bright heart and bloom. No textures.
render_mode unshaded, blend_add, depth_draw_never, cull_disabled, shadows_disabled;

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

void fragment() {
	float y = 1.0 - UV.y;
	float x = UV.x * 2.0 - 1.0;
	float t = TIME * speed + seed * 13.7;
	// Slow billows and fast licks, both rising.
	float n1 = fx_fbm(vec3(x * 1.6 + seed * 5.0, y * 2.2 - t * 2.3, t * 0.4));
	float n2 = fx_fbm(vec3(x * 4.2 - seed * 3.0, y * 5.4 - t * 4.4, t * 0.7 + seed));
	x += ((n1 - 0.5) * 1.25 + (n2 - 0.5) * 0.5 + sin(t * 2.3 + y * 4.0) * 0.08) * (0.2 + y);
	float width = 0.78 * pow(max(1.0 - y, 0.0), 0.7) * (0.7 + 0.6 * n1);
	float body = clamp(1.0 - abs(x) / max(width, 0.001), 0.0, 1.0);
	float base = smoothstep(0.0, 0.1, y);
	float tip = 1.0 - smoothstep(0.5, 1.0, y + (n2 - 0.5) * 0.45);
	// Wisps: the licks eat holes into the flame towards its tip.
	float d = body * tip * base * mix(1.0, 0.45 + 1.1 * n2, clamp(y * 1.4, 0.0, 1.0));
	float h = clamp(heat, 0.0, 1.0);
	float core = smoothstep(0.38, 0.9, d);
	vec3 col = mix(vec3(0.9, 0.1, 0.01), vec3(1.0, 0.42, 0.05), smoothstep(0.04, 0.4, d));
	col = mix(col, vec3(1.0, 0.8, 0.36), core);
	col = mix(col, vec3(1.0, 0.95, 0.8), smoothstep(0.78, 1.0, d) * h);
	float a = smoothstep(0.015, 0.45, d);
	ALBEDO = col * energy * (0.24 + 0.6 * h) * (0.45 + 1.0 * core);
	ALPHA = a * smoothstep(0.0, 0.08, h);
}
