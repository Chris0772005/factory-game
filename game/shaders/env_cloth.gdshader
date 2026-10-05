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

void vertex() {
	float free = UV.y * UV.y;
	float w = sin(TIME * 2.2 + UV.x * 3.5 + phase * 6.283) * 0.6 + sin(TIME * 3.7 + UV.x * 7.0 + UV.y * 2.0 + phase * 11.0) * 0.4;
	VERTEX += NORMAL * w * flutter * free;
	VERTEX.y += abs(w) * flutter * 0.2 * free;
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
