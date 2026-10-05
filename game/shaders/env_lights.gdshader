shader_type spatial;
// String-light cable and bulb sockets. Cable tube: UV.x = fraction along the
// span, COLOR.g = span phase, COLOR.ba = across-span direction (* 0.5 + 0.5).
// Sockets (MultiMesh): INSTANCE_CUSTOM r = fraction, g = phase, ba = across.
// Transparent pass (ALPHA = 1) keeps the thin cables out of the ink outline.
render_mode diffuse_burley, specular_schlick_ggx, depth_draw_always;

#include "res://shaders/env_common.gdshaderinc"

uniform vec4 color : source_color = vec4(0.23, 0.2, 0.19, 1.0);
uniform bool instanced = false;
uniform float amp = 0.03;

void vertex() {
	float t = instanced ? INSTANCE_CUSTOM.r : UV.x;
	float phase = (instanced ? INSTANCE_CUSTOM.g : COLOR.g) * 6.283;
	vec2 perp = (instanced ? INSTANCE_CUSTOM.ba : COLOR.ba) * 2.0 - 1.0;
	vec3 off = env_string_sway(TIME, t, phase, perp, amp);
	float s2 = dot(MODEL_MATRIX[0].xyz, MODEL_MATRIX[0].xyz);
	VERTEX += (vec4(off, 0.0) * MODEL_MATRIX).xyz / s2;
}

void fragment() {
	ALBEDO = color.rgb;
	ROUGHNESS = 0.55;
	SPECULAR = 0.4;
	ALPHA = 1.0;
}
