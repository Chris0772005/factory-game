shader_type spatial;
// String-light bulb glass (MultiMesh, same sway as env_lights). Drawn in the
// transparent pass (ALPHA = 1) so the ink outline pass does not ring the
// glowing bulbs. INSTANCE_CUSTOM r = fraction along span, g = phase,
// ba = across-span direction; each bulb also swings a little on its own.
render_mode diffuse_burley, specular_schlick_ggx, depth_draw_always, shadows_disabled;

#include "res://shaders/env_common.gdshaderinc"

uniform vec4 glass : source_color = vec4(1.0, 0.886, 0.659, 1.0);
uniform vec4 emission_color : source_color = vec4(1.0, 0.816, 0.541, 1.0);
uniform float energy = 2.5;
uniform float amp = 0.03;

void vertex() {
	float phase = INSTANCE_CUSTOM.g * 6.283;
	vec2 perp = INSTANCE_CUSTOM.ba * 2.0 - 1.0;
	vec3 off = env_string_sway(TIME, INSTANCE_CUSTOM.r, phase, perp, amp);
	// Own pendulum swing, growing with the distance below the socket.
	float swing = sin(TIME * 3.3 + INSTANCE_CUSTOM.r * 40.0 + phase) * 0.12 * max(-VERTEX.y, 0.0);
	off += vec3(perp.x, 0.0, perp.y) * swing;
	float s2 = dot(MODEL_MATRIX[0].xyz, MODEL_MATRIX[0].xyz);
	VERTEX += (vec4(off, 0.0) * MODEL_MATRIX).xyz / s2;
}

void fragment() {
	float rim = 1.0 - abs(dot(NORMAL, VIEW));
	ALBEDO = glass.rgb;
	EMISSION = emission_color.rgb * energy * (0.75 + 0.25 * (1.0 - rim));
	ROUGHNESS = 0.99;
	ALPHA = 1.0;
}
