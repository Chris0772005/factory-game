shader_type spatial;
// Pleated leather of the foot bellows. The mesh is built flat ("closed");
// every vertex is turned about the hinge axis (parallel to object Z through
// `hinge` in object XY) by `open_angle` * UV.y, so the folds fan open and
// shut with the top board. UV.y: 0 = base board, 1 = top board; UV.x runs
// around the bellows (for stitches). Also used unhinged (open_angle 0) for
// grips and straps.
render_mode diffuse_lambert_wrap, specular_schlick_ggx, cull_disabled;

#include "res://shaders/env_common.gdshaderinc"

uniform vec4 leather_color : source_color = vec4(0.36, 0.22, 0.14, 1.0);
uniform vec4 stitch_color : source_color = vec4(0.82, 0.74, 0.6, 1.0);
uniform float open_angle = 0.0;
uniform vec2 hinge = vec2(0.0, 0.0);
uniform float stitches : hint_range(0.0, 1.0) = 1.0;
// Pleats between UV.y 0 and 1 (stitch rows sit on the crests).
uniform float pleats = 4.0;

varying vec3 v_obj;
varying vec2 v_uv;

void vertex() {
	float a = open_angle * UV.y;
	float c = cos(a);
	float s = sin(a);
	vec2 q = VERTEX.xy - hinge;
	VERTEX.xy = hinge + vec2(c * q.x - s * q.y, s * q.x + c * q.y);
	NORMAL.xy = vec2(c * NORMAL.x - s * NORMAL.y, s * NORMAL.x + c * NORMAL.y);
	v_obj = VERTEX;
	v_uv = UV;
}

void fragment() {
	vec3 p = v_obj * 40.0;
	float n = env_fbm(p.xz + p.y * 1.3);
	float wr = env_noise(vec2(v_uv.x * 60.0, v_uv.y * 9.0)) - 0.5;
	vec3 c = leather_color.rgb * (0.82 + n * 0.35 + wr * 0.12);
	// Crests are worn lighter, folds darker.
	float crest = 0.5 + 0.5 * cos((v_uv.y * pleats - 0.5) * 6.2832);
	c *= mix(0.72, 1.12, crest);
	float rough = 0.62 + wr * 0.1 - crest * 0.1;
	if (stitches > 0.0) {
		float row = abs(fract(v_uv.y * pleats) - 0.5) / pleats;
		float dash = step(0.45, fract(v_uv.x * 90.0));
		float st = (1.0 - smoothstep(0.002, 0.006, row)) * dash * stitches;
		c = mix(c, stitch_color.rgb, st * 0.8);
	}
	ALBEDO = c;
	ROUGHNESS = clamp(rough, 0.0, 1.0);
	SPECULAR = 0.4;
	NORMAL = env_bump(VERTEX, NORMAL, (n * 0.5 + wr) * 0.0012, 1.0);
}
