shader_type spatial;
// Laundry on the line (subdivided PlaneMesh, UV.y = 0 at the pegs): the free
// edge flutters in the breeze, pegged edge stays put. Colour per piece via
// the instance uniform `cloth`, with a stripe option and soft fabric shading.
render_mode cull_disabled, diffuse_lambert_wrap, specular_schlick_ggx;

#include "res://shaders/env_common.gdshaderinc"

instance uniform vec4 cloth : source_color = vec4(0.9, 0.88, 0.82, 1.0);
instance uniform vec4 stripe : source_color = vec4(0.9, 0.88, 0.82, 1.0);
instance uniform float phase = 0.0;
uniform float flutter = 0.07;
// Up to four workers (xyz feet, w reach); the cloth swings away from them.
uniform vec4 trample[4];

void vertex() {
	float free = UV.y * UV.y;
	float w = sin(TIME * 2.2 + UV.x * 3.5 + phase * 6.283) * 0.6 + sin(TIME * 3.7 + UV.x * 7.0 + UV.y * 2.0 + phase * 11.0) * 0.4;
	VERTEX += NORMAL * w * flutter * free;
	VERTEX.y += abs(w) * flutter * 0.2 * free;
	vec3 world = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	vec3 n_world = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
	for (int i = 0; i < 4; i++) {
		float r = trample[i].w;
		if (r > 0.0 && world.y > trample[i].y - 0.2 && world.y < trample[i].y + 2.1) {
			vec2 away = world.xz - trample[i].xz;
			float d = length(away);
			float push = 1.0 - smoothstep(r * 0.25, r, d);
			// Swing to the side the worker is not on, and ride up over the shoulder.
			float side = dot(n_world.xz, away) >= 0.0 ? 1.0 : -1.0;
			float amount = push * (0.15 + 0.85 * free);
			VERTEX += NORMAL * side * amount * 0.55;
			VERTEX.y += amount * amount * 0.22;
		}
	}
}

void fragment() {
	float band = step(0.5, fract(UV.x * 4.0 + 0.25)) * step(0.15, UV.y);
	vec3 c = mix(cloth.rgb, stripe.rgb, band);
	c *= 0.9 + env_noise(UV * vec2(40.0, 60.0)) * 0.1;
	c *= mix(0.8, 1.0, smoothstep(0.0, 0.12, UV.y));
	ALBEDO = c;
	ROUGHNESS = 0.95;
	BACKLIGHT = c * 0.35;
}
