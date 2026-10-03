shader_type spatial;
// Full-screen edge detection on depth + normals for an ink outline look.
render_mode unshaded, depth_draw_never, depth_test_disabled, cull_disabled, fog_disabled;

uniform sampler2D depth_tex : hint_depth_texture, filter_nearest;
uniform sampler2D normal_tex : hint_normal_roughness_texture, filter_nearest;
uniform vec4 line_color : source_color = vec4(0.13, 0.11, 0.16, 1.0);
uniform float thickness = 1.4;
uniform float depth_threshold = 0.06;
uniform float normal_threshold = 0.45;
uniform float max_distance = 80.0;

void vertex() {
	POSITION = vec4(VERTEX.xy, 1.0, 1.0);
}

float linear_depth(vec2 uv, mat4 inv_proj) {
	float d = texture(depth_tex, uv).r;
	vec4 v = inv_proj * vec4(uv * 2.0 - 1.0, d, 1.0);
	return -v.z / v.w;
}

void fragment() {
	vec2 px = thickness / VIEWPORT_SIZE;
	float d0 = linear_depth(SCREEN_UV, INV_PROJECTION_MATRIX);
	vec3 n0 = texture(normal_tex, SCREEN_UV).xyz * 2.0 - 1.0;
	float edge = 0.0;
	vec2 offs[4] = vec2[](vec2(px.x, 0.0), vec2(-px.x, 0.0), vec2(0.0, px.y), vec2(0.0, -px.y));
	for (int i = 0; i < 4; i++) {
		vec2 uv = SCREEN_UV + offs[i];
		float d = linear_depth(uv, INV_PROJECTION_MATRIX);
		vec3 n = texture(normal_tex, uv).xyz * 2.0 - 1.0;
		float dd = abs(d - d0) / max(d0, 0.001);
		if (dd > depth_threshold) edge = 1.0;
		if (1.0 - dot(n, n0) > normal_threshold) edge = max(edge, 0.85);
	}
	float fade = 1.0 - smoothstep(max_distance * 0.6, max_distance, d0);
	ALBEDO = line_color.rgb;
	ALPHA = edge * fade * line_color.a;
}
