shader_type spatial;
// String-light bulb glass (MultiMesh, same sway as env_lights). Drawn in the
// transparent pass (ALPHA = 1) so the ink outline pass does not ring the
// glowing bulbs. INSTANCE_CUSTOM r = fraction along span, g = phase,
// ba = across-span direction; each bulb also swings a little on its own.
render_mode diffuse_burley, specular_schlick_ggx, depth_draw_always, shadows_disabled;

#include "res://shaders/env_common.gdshaderinc"

// Dark glass: the glow comes from EMISSION only, so the nearby string-light
// omnis and the sun cannot light the bulbs up past the melt.
uniform vec4 glass : source_color = vec4(0.3, 0.26, 0.2, 1.0);
uniform vec4 emission_color : source_color = vec4(1.0, 0.78, 0.49, 1.0);
// Below the Art Bible's 2.5: at 2.5 the bulbs measured brighter than the melt
// in the wide shot, and the hierarchy rule (6.1) wins.
uniform float energy = 1.1;
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
