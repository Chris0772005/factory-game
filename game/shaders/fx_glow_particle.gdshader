shader_type spatial;
// Additive HDR particle for sparks (velocity-aligned streaks, emitter does the
// alignment) and embers (camera-facing dots). Colour and fade come from the
// particle COLOR; the bright head sits at the top of the quad.
render_mode unshaded, blend_add, depth_draw_never, cull_disabled, shadows_disabled, fog_disabled;

uniform bool billboard = false;
uniform float energy = 6.0;

void vertex() {
	if (billboard) {
		mat4 m = mat4(INV_VIEW_MATRIX[0], INV_VIEW_MATRIX[1], INV_VIEW_MATRIX[2], MODEL_MATRIX[3]);
		MODELVIEW_MATRIX = VIEW_MATRIX * m;
		VERTEX *= length(MODEL_MATRIX[0].xyz);
	}
}

void fragment() {
	vec2 c = UV * 2.0 - 1.0;
	float shape;
	if (billboard) {
		shape = 1.0 - smoothstep(0.2, 1.0, length(c));
	} else {
		float across = 1.0 - smoothstep(0.15, 1.0, abs(c.x));
		float along = mix(1.0, 0.0, UV.y) * (1.0 - smoothstep(0.75, 1.0, -c.y));
		shape = across * along;
	}
	ALBEDO = COLOR.rgb * energy * shape * COLOR.a;
	ALPHA = 1.0;
}
