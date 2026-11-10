shader_type spatial;
// Conveyor belt rubber: dark, slightly worn, with chevron cleats that run
// along +U by `offset` (metres). UV.x = metres along the belt, UV.y = 0..1 across.
uniform float offset = 0.0;
uniform vec4 rubber : source_color = vec4(0.07, 0.07, 0.075, 1.0);
uniform vec4 worn : source_color = vec4(0.16, 0.15, 0.14, 1.0);

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

void fragment() {
	float u = UV.x - offset;
	float across = abs(UV.y - 0.5) * 2.0;
	// Chevron cleats every 0.18 m, raised in the normal and a touch lighter.
	float c = fract((u + across * 0.07) / 0.18);
	float cleat = smoothstep(0.0, 0.06, c) * (1.0 - smoothstep(0.16, 0.22, c)) * (1.0 - smoothstep(0.86, 0.92, across));
	float grain = hash(floor(vec2(u * 90.0, UV.y * 60.0)));
	float wear = smoothstep(0.55, 0.0, across) * 0.6;
	vec3 col = mix(rubber.rgb, worn.rgb, wear * (0.5 + 0.5 * grain));
	col = mix(col, col * 1.6 + 0.02, cleat * 0.5);
	ALBEDO = col;
	ROUGHNESS = 0.85 - cleat * 0.15;
	METALLIC = 0.0;
}
