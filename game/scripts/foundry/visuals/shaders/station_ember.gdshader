shader_type spatial;
// Charcoal bed in the furnace: dark chunks with pale ash on top and glowing
// cracks that breathe with the heat. Vertex COLOR.r (EnvMesh.merge seed)
// gives every chunk its own crack pattern and flicker phase.
render_mode diffuse_burley, specular_schlick_ggx;

#include "res://shaders/env_common.gdshaderinc"
#include "res://shaders/fx_common.gdshaderinc"

uniform vec4 coal_color : source_color = vec4(0.075, 0.068, 0.07, 1.0);
uniform vec4 ash_color : source_color = vec4(0.52, 0.49, 0.47, 1.0);
uniform float heat : hint_range(0.0, 1.0) = 0.0;
uniform float glow_scale = 1.0;

varying vec3 v_obj;
varying vec3 v_nobj;
varying float v_seed;

void vertex() {
	v_obj = VERTEX;
	v_nobj = NORMAL;
	v_seed = COLOR.r;
}

void fragment() {
	vec3 p = v_obj * 26.0 + v_seed * 19.0;
	vec3 v = env_voronoi(p.xz + p.y * 0.8);
	float crack = 1.0 - smoothstep(0.0, 0.09, v.z - v.x);
	float n = env_fbm(p.xy * 0.7 + p.z * 0.5);
	float ash = smoothstep(0.35, 0.85, v_nobj.y + (n - 0.5) * 0.9) * (1.0 - heat * 0.6);
	vec3 c = mix(coal_color.rgb * (0.8 + n * 0.5), ash_color.rgb * (0.85 + n * 0.3), ash * 0.75);
	ALBEDO = c;
	ROUGHNESS = 0.9;
	SPECULAR = 0.3;
	if (heat > 0.0) {
		float flick = 0.7 + 0.3 * sin(TIME * (2.0 + v_seed * 3.0) + v_seed * 40.0) * env_noise(vec2(TIME * 0.8, v_seed * 9.0));
		// A blown bed glows through, not only along the cracks: the furnace mouth
		// reads as a hot orange bowl from the high game camera.
		float body = (0.12 + smoothstep(0.45, 0.8, n) * 0.5) * smoothstep(0.4, 0.9, heat);
		float t = clamp(heat * (crack * 0.95 + body) * flick * (1.0 - ash * 0.55), 0.0, 1.0);
		EMISSION = fx_heat_color(t * 0.92) * fx_heat_energy(t * 0.92) * glow_scale;
	}
	NORMAL = env_bump(VERTEX, NORMAL, (n - crack * 0.6) * 0.002, 1.0);
}
