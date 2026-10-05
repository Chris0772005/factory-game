shader_type spatial;
// Full-screen edge detection on depth + normals for an ink outline look
// (Art Bible 5.4): the line takes the darkened colour of the surface under it,
// mixed with ink, instead of flat black; it is 1 px at 1080p and scales with
// the viewport height. Normal creases (bevels, planks, tiles) fade out sooner
// than silhouettes, so small detail does not break up into dotted lines in the
// distance; everything fades out between `fade_start` and `fade_end`.
// Pixels with roughness > 0.98 (bulbs, grass: the "no outline" marker) never
// get a line and never cause one.
render_mode unshaded, depth_draw_never, depth_test_disabled, cull_disabled, fog_disabled;

uniform sampler2D depth_tex : hint_depth_texture, filter_nearest;
uniform sampler2D normal_tex : hint_normal_roughness_texture, filter_nearest;
uniform sampler2D screen_tex : hint_screen_texture, filter_linear;
/// Ink the line colour is pulled towards (#2A2135).
uniform vec4 line_color : source_color = vec4(0.165, 0.129, 0.208, 1.0);
/// How much of the darkened scene colour shows in the line (0 = pure ink).
uniform float scene_tint : hint_range(0.0, 1.0) = 0.5;
uniform float scene_darken : hint_range(0.0, 1.0) = 0.35;
uniform float opacity : hint_range(0.0, 1.0) = 0.85;
/// Sample offset in pixels at 1080p.
uniform float thickness = 1.0;
uniform float depth_threshold = 0.06;
uniform float normal_threshold = 0.6;
/// Silhouette lines fade out over this distance range (metres).
uniform float fade_start = 18.0;
uniform float fade_end = 35.0;
/// Crease (normal) lines fade out over this nearer range.
uniform float crease_fade_start = 11.0;
uniform float crease_fade_end = 22.0;

void vertex() {
	POSITION = vec4(VERTEX.xy, 1.0, 1.0);
}

float linear_depth(vec2 uv, mat4 inv_proj) {
	float d = texture(depth_tex, uv).r;
	vec4 v = inv_proj * vec4(uv * 2.0 - 1.0, d, 1.0);
	return -v.z / v.w;
}

void fragment() {
	vec2 px = max(1.0, VIEWPORT_SIZE.y / 1080.0) * thickness / VIEWPORT_SIZE;
	float d0 = linear_depth(SCREEN_UV, INV_PROJECTION_MATRIX);
	vec4 nr0 = texture(normal_tex, SCREEN_UV);
	vec3 n0 = nr0.xyz * 2.0 - 1.0;
	float silhouette = 0.0;
	float crease = 0.0;
	if (nr0.a <= 0.98) {
		vec2 offs[4] = vec2[](vec2(px.x, 0.0), vec2(-px.x, 0.0), vec2(0.0, px.y), vec2(0.0, -px.y));
		for (int i = 0; i < 4; i++) {
			vec2 uv = SCREEN_UV + offs[i];
			vec4 nr = texture(normal_tex, uv);
			if (nr.a > 0.98) {
				continue;
			}
			float d = linear_depth(uv, INV_PROJECTION_MATRIX);
			if (abs(d - d0) / max(d0, 0.001) > depth_threshold) {
				silhouette = 1.0;
			}
			vec3 n = nr.xyz * 2.0 - 1.0;
			if (1.0 - dot(n, n0) > normal_threshold) {
				crease = 0.85;
			}
		}
	}
	crease *= 1.0 - smoothstep(crease_fade_start, crease_fade_end, d0);
	float edge = max(silhouette, crease) * (1.0 - smoothstep(fade_start, fade_end, d0));
	vec3 scene = texture(screen_tex, SCREEN_UV).rgb;
	ALBEDO = mix(line_color.rgb, scene * scene_darken, scene_tint);
	ALPHA = edge * opacity;
}
