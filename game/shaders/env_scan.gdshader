shader_type spatial;
// A surface straight from a photo scan (Poly Haven, CC0, see CREDITS.md): its colour, normal and
// occlusion-roughness-metal maps, laid on from three sides in world space, so the sets' plain boxes
// need no UVs and bricks run level round a corner. The scan keeps its own colours (a tint can shift
// them); a slow drift in brightness hides the repeat, and walls can be darker and damper at the foot.
// The project's graphics standard (TECH_SPEC Modul Y) asks for these in place of drawn patterns.
render_mode diffuse_burley, specular_schlick_ggx;

#include "res://shaders/env_common.gdshaderinc"
#include "res://shaders/env_cutaway.gdshaderinc"

uniform sampler2D albedo_map : source_color, repeat_enable, filter_linear_mipmap_anisotropic;
uniform sampler2D normal_map : repeat_enable, filter_linear_mipmap_anisotropic;
uniform sampler2D arm_map : repeat_enable, filter_linear_mipmap_anisotropic;
// Edge length of one repeat of the scan in metres, and a shift of the pattern (in repeats).
uniform float tile = 2.0;
uniform vec3 shift = vec3(0.0);
// A factor on the scan's colours (not a colour itself: values above 1 brighten). With `grey` at 1 the
// scan gives only its light and dark and the tint is the paint (a red sheet repainted grey).
uniform vec3 tint = vec3(1.0);
uniform float grey : hint_range(0.0, 1.0) = 0.0;
uniform float normal_strength = 1.0;
uniform float roughness_scale = 1.0;
uniform float occlusion = 1.0;
// How far the brightness drifts over a few metres (0 = none).
uniform float drift = 0.14;
// Dirt at the foot of a wall: strength, and the height (m) up to which it reaches.
uniform float foot = 0.0;
uniform float foot_height = 0.7;
// Hall walls dissolve around the line of sight of the orbit camera (env_cutaway), as the drawn walls do.
uniform bool cutaway = false;

varying vec3 world_pos;
varying vec3 world_nrm;

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	world_nrm = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
}

void fragment() {
	if (cutaway) {
		env_cutaway(world_pos, CAMERA_POSITION_WORLD, FRAGCOORD.xy);
	}
	vec3 n = normalize(world_nrm);
	vec3 w = pow(abs(n), vec3(8.0));
	w /= w.x + w.y + w.z;
	vec3 p = world_pos / tile + shift;
	// V runs down the image: with it turned over, the scans stand upright on walls and the green of
	// their normal maps (up in the image) points up the wall, as the blend below takes it.
	vec2 ux = vec2(p.z, -p.y);
	vec2 uy = vec2(p.x, -p.z);
	vec2 uz = vec2(p.x, -p.y);
	// A flat face looks along one axis only: read just the sides that count (three reads instead of
	// nine). The footprints are taken before the branches, so filtering stays right.
	vec2 gxa = dFdx(ux);
	vec2 gxb = dFdy(ux);
	vec2 gya = dFdx(uy);
	vec2 gyb = dFdy(uy);
	vec2 gza = dFdx(uz);
	vec2 gzb = dFdy(uz);
	vec3 col = vec3(0.0);
	vec3 arm = vec3(0.0);
	vec3 bumped = vec3(0.0);
	// Each side's bump is tilted onto the surface and the sides are blended ("whiteout" blend).
	if (w.x > 0.004) {
		col += textureGrad(albedo_map, ux, gxa, gxb).rgb * w.x;
		arm += textureGrad(arm_map, ux, gxa, gxb).rgb * w.x;
		vec3 t = textureGrad(normal_map, ux, gxa, gxb).xyz * 2.0 - 1.0;
		bumped += vec3(t.xy * normal_strength + n.zy, abs(t.z) * n.x).zyx * w.x;
	}
	if (w.y > 0.004) {
		col += textureGrad(albedo_map, uy, gya, gyb).rgb * w.y;
		arm += textureGrad(arm_map, uy, gya, gyb).rgb * w.y;
		vec3 t = textureGrad(normal_map, uy, gya, gyb).xyz * 2.0 - 1.0;
		bumped += vec3(t.xy * normal_strength + n.xz, abs(t.z) * n.y).xzy * w.y;
	}
	if (w.z > 0.004) {
		col += textureGrad(albedo_map, uz, gza, gzb).rgb * w.z;
		arm += textureGrad(arm_map, uz, gza, gzb).rgb * w.z;
		vec3 t = textureGrad(normal_map, uz, gza, gzb).xyz * 2.0 - 1.0;
		bumped += vec3(t.xy * normal_strength + n.xy, abs(t.z) * n.z) * w.z;
	}
	bumped = normalize(bumped);
	float slow = env_fbm(world_pos.xz * 0.11 + world_pos.y * 0.23) * 0.65 + env_noise(world_pos.xz * 0.47 + world_pos.y * 0.31 + 13.0) * 0.35;
	col = mix(col, vec3(dot(col, vec3(0.2126, 0.7152, 0.0722))), grey);
	col *= tint * (1.0 + drift * (slow - 0.5) * 2.0);
	float rough = clamp(arm.g * roughness_scale, 0.04, 1.0);
	if (foot > 0.0) {
		float low = (1.0 - smoothstep(0.0, foot_height, world_pos.y + (slow - 0.5) * 0.5)) * foot * (1.0 - abs(n.y));
		col *= 1.0 - 0.45 * low;
		rough = mix(rough, min(rough, 0.55), low * 0.5);
	}
	ALBEDO = col;
	ROUGHNESS = rough;
	METALLIC = arm.b;
	AO = mix(1.0, arm.r, occlusion);
	AO_LIGHT_AFFECT = 0.35;
	NORMAL = normalize((VIEW_MATRIX * vec4(bumped, 0.0)).xyz);
}
