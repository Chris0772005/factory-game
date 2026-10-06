// Worker's leather apron (WorkerGear.apron_mesh): dark, matte, mottled leather
// with a painted top-to-bottom gradient, a darker rolled hem with pale
// stitching and small steel rivets. Vertex colours: r = hem, g = position
// across the hem (stitch row at 0.5), b = rivet. UV = arc lengths in rig
// units (x across, y down from the bib's top edge), stable under skinning.
shader_type spatial;
render_mode diffuse_lambert_wrap, specular_schlick_ggx, cull_disabled;

#include "res://shaders/env_common.gdshaderinc"

uniform vec4 leather_color : source_color = vec4(0.353, 0.275, 0.212, 1.0);
uniform vec4 stitch_color : source_color = vec4(0.79, 0.7, 0.56, 1.0);
uniform vec4 rivet_color : source_color = vec4(0.557, 0.588, 0.612, 1.0);
uniform float roughness_value : hint_range(0.0, 1.0) = 0.85;
uniform float rim_amount : hint_range(0.0, 1.0) = 0.15;

void fragment() {
	// Macro mottling, fine grain and a few scuffs.
	float mottle = env_fbm(UV * 9.0);
	float grain = env_noise(UV * vec2(70.0, 120.0)) - 0.5;
	float scuff = smoothstep(0.72, 0.9, env_noise(UV * vec2(14.0, 5.0) + 7.3));
	vec3 c = leather_color.rgb * (0.84 + mottle * 0.3 + grain * 0.1);
	c = mix(c, c * 1.35 + vec3(0.02, 0.015, 0.01), scuff * 0.35);
	// Painted gradient: the bib catches the light, the hanging flap is in shade.
	c *= mix(1.1, 0.8, clamp(UV.y * 1.25, 0.0, 1.0));
	float hem = COLOR.r;
	c *= mix(1.0, 0.74, hem);
	// Running stitch down the middle of every hem and strap.
	float row = abs(COLOR.g - 0.5);
	float dash = step(0.42, fract((UV.x + UV.y) * 55.0));
	float stitch = hem * (1.0 - smoothstep(0.07, 0.15, row)) * dash;
	c = mix(c, stitch_color.rgb, stitch * 0.7);
	float rivet = COLOR.b;
	c = mix(c, rivet_color.rgb, rivet);
	ALBEDO = c;
	ROUGHNESS = mix(clamp(roughness_value + grain * 0.1 - scuff * 0.08, 0.0, 1.0), 0.45, rivet);
	METALLIC = rivet * 0.7;
	SPECULAR = 0.3;
	RIM = rim_amount;
	RIM_TINT = 0.6;
}
