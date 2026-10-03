shader_type spatial;
// Soft camera-facing puff for steam, smoke and dust. Uses the particle COLOR,
// a noisy round edge, fake top-lighting and depth fade against the scene so
// quads never show hard cuts where they meet geometry.
render_mode unshaded, blend_mix, depth_draw_never, cull_disabled, shadows_disabled;

#include "res://shaders/fx_common.gdshaderinc"

uniform sampler2D depth_tex : hint_depth_texture, filter_linear;
uniform float shade = 0.18;
uniform float edge_noise = 0.45;
uniform float depth_fade = 0.25;

varying vec2 v_screen_offset;
varying float v_seed;
varying float v_phase;

void vertex() {
	float a = INSTANCE_CUSTOM.x;
	vec2 corner = mat2(vec2(cos(a), sin(a)), vec2(-sin(a), cos(a))) * VERTEX.xy;
	v_screen_offset = corner * 2.0;
	v_seed = fract(a * 3.17);
	v_phase = INSTANCE_CUSTOM.y;
	mat4 m = mat4(INV_VIEW_MATRIX[0], INV_VIEW_MATRIX[1], INV_VIEW_MATRIX[2], MODEL_MATRIX[3]);
	MODELVIEW_MATRIX = VIEW_MATRIX * m;
	VERTEX = vec3(corner * length(MODEL_MATRIX[0].xyz), 0.0);
}

void fragment() {
	vec2 c = UV * 2.0 - 1.0;
	float n = fx_fbm(vec3(c * 1.6, v_seed * 40.0 + v_phase * 1.5));
	float r = length(c) + (n - 0.5) * edge_noise;
	float puff = 1.0 - smoothstep(0.15, 0.95, r);
	float scene = texture(depth_tex, SCREEN_UV).r;
	vec4 sv = INV_PROJECTION_MATRIX * vec4(SCREEN_UV * 2.0 - 1.0, scene, 1.0);
	float fade = clamp((-sv.z / sv.w + VERTEX.z) / depth_fade, 0.0, 1.0);
	float light = mix(1.0 - shade, 1.0, clamp(v_screen_offset.y * 1.6 + 0.5, 0.0, 1.0)) * (0.9 + 0.2 * n);
	ALBEDO = COLOR.rgb * light;
	ALPHA = COLOR.a * puff * fade;
}
