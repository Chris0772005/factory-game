shader_type spatial;
// Still water in a tub or bucket: dark teal depth, a sky fresnel and slow
// ripples. `stir` (0..1) adds fast rings after a splash or a quench.
render_mode diffuse_burley, specular_schlick_ggx, depth_draw_opaque;

#include "res://shaders/env_common.gdshaderinc"

uniform vec4 deep : source_color = vec4(0.07, 0.16, 0.18, 1.0);
uniform vec4 shallow : source_color = vec4(0.18, 0.33, 0.34, 1.0);
uniform float stir : hint_range(0.0, 1.0) = 0.0;
uniform vec2 stir_center = vec2(0.0);

varying vec3 wpos;

void vertex() {
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	vec2 p = wpos.xz;
	float slow = env_noise(p * 3.0 + vec2(TIME * 0.11, -TIME * 0.07));
	float rings = sin(length(p - stir_center) * 60.0 - TIME * 14.0) * stir;
	float h = slow * 0.6 + rings * 0.4;
	float fres = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), 3.0);
	ALBEDO = mix(deep.rgb, shallow.rgb, slow * 0.5 + fres * 0.6);
	ROUGHNESS = 0.06;
	SPECULAR = 0.6;
	METALLIC = 0.0;
	NORMAL = env_bump(VERTEX, NORMAL, h * 0.004, 1.0);
}
