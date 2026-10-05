shader_type spatial;
// Fired clay and clay-graphite (crucible shell, furnace lining, fire bricks):
// mottled body with a pale clay glaze that ran down in drips, fine crazing
// cracks, soot, and a heat glow that climbs from `glow_from` (object y,
// hottest) towards `glow_to`. Cold surfaces stay dark so only melt and fire
// are hot accents (Art Bible 4.3: graphite #3A3436, roughness 0.85).
render_mode diffuse_burley, specular_schlick_ggx;

#include "res://shaders/env_common.gdshaderinc"
#include "res://shaders/fx_common.gdshaderinc"

uniform vec4 body_color : source_color = vec4(0.227, 0.204, 0.212, 1.0);
uniform vec4 glaze_color : source_color = vec4(0.55, 0.5, 0.46, 1.0);
uniform vec4 soot_color : source_color = vec4(0.09, 0.08, 0.08, 1.0);
uniform float glaze : hint_range(0.0, 1.0) = 0.4;
// Object y where glaze drips start (they run down from here).
uniform float glaze_top = 0.42;
uniform float cracks : hint_range(0.0, 1.0) = 0.4;
uniform float soot : hint_range(0.0, 1.0) = 0.0;
uniform float soot_from = 0.0;
uniform float soot_to = 0.5;
uniform float roughness_base : hint_range(0.0, 1.0) = 0.85;
// 0 = cold, 1 = glowing hot (driven per frame from the station).
uniform float heat : hint_range(0.0, 1.0) = 0.0;
uniform float glow_from = 0.0;
uniform float glow_to = 0.4;
uniform float glow_scale = 1.0;
// Radial glow for the furnace mouth rim (above the glow range): hotter towards
// the axis inside this radius.
uniform float glow_radius = 0.0;
uniform float noise_scale = 1.0;
// Brick courses: 0 = off, otherwise course height (m) of a running bond.
uniform float brick_course = 0.0;
uniform vec4 mortar_color : source_color = vec4(0.78, 0.71, 0.6, 1.0);
// Darkens surfaces facing the axis (the inside of a pot) and keeps glaze off them.
uniform float inner_dark : hint_range(0.0, 1.0) = 0.0;

varying vec3 v_obj;
varying vec3 v_nobj;
varying float v_seed;

void vertex() {
	v_obj = VERTEX;
	v_nobj = NORMAL;
	v_seed = COLOR.r;
}

void fragment() {
	vec3 p = v_obj * noise_scale + v_seed * 11.0;
	float ang = atan(v_obj.x, v_obj.z);
	float macro = env_fbm(p.xz * 4.0 + p.y * 3.0) - 0.5;
	float grain = env_noise(p.xy * 70.0 + p.z * 53.0) - 0.5;
	vec3 c = body_color.rgb * (1.0 + macro * 0.3 + grain * 0.12 + (v_seed - 0.5) * 0.12);
	float rough = roughness_base + grain * 0.1;

	float inside = inner_dark * step(dot(v_nobj.xz, v_obj.xz), -1e-5);
	// Glaze: patches, plus drips running down from the rim.
	if (glaze > 0.0 && inside < 0.5) {
		float drip_col = env_noise(vec2(ang * 9.0, v_seed * 5.0));
		float drip_len = mix(0.04, 0.22, drip_col);
		float drip = (1.0 - smoothstep(drip_len - 0.03, drip_len, glaze_top - v_obj.y)) * smoothstep(0.55, 0.7, drip_col);
		float patch = smoothstep(0.55, 0.72, env_fbm(p.xz * 6.0 + p.y * 5.0 + 4.0));
		float g = clamp(max(drip, patch) * glaze, 0.0, 1.0);
		c = mix(c, glaze_color.rgb * (0.85 + macro * 0.4 + grain * 0.2), g);
		rough = mix(rough, 0.55, g);
	}

	// Bricks (furnace skirt): staggered courses, mortar joints, per-brick tone.
	if (brick_course > 0.0) {
		float row = floor(v_obj.y / brick_course);
		float along = ang * 0.48 / brick_course * 0.5 + row * 0.5;
		float col = floor(along);
		float id = env_hash12(vec2(row, col) + v_seed * 3.0);
		c *= 0.86 + id * 0.28;
		vec2 f = vec2(fract(along), fract(v_obj.y / brick_course));
		float joint = 1.0 - smoothstep(0.02, 0.05, min(min(f.x, 1.0 - f.x) * 2.0, min(f.y, 1.0 - f.y)));
		c = mix(c, mortar_color.rgb * (0.85 + grain * 0.3), joint);
	}

	// Crazing: fine dark crack network.
	float crack_mask = 0.0;
	if (cracks > 0.0) {
		vec3 v = env_voronoi(vec2(ang * 3.2, (v_obj.y + length(v_obj.xz)) * 9.0) * noise_scale + v_seed * 7.0);
		crack_mask = (1.0 - smoothstep(0.0, 0.06, v.z - v.x)) * cracks;
		crack_mask *= smoothstep(0.35, 0.6, env_fbm(p.xy * 5.0 + 9.0));
		c *= 1.0 - crack_mask * 0.55;
	}

	if (soot > 0.0) {
		float sy = v_obj.y + macro * 0.1;
		float s = soot_to >= soot_from ? smoothstep(soot_from, soot_to, sy) : 1.0 - smoothstep(soot_to, soot_from, sy);
		s *= soot;
		s *= 0.7 + env_fbm(p.xz * 8.0 + p.y * 4.0) * 0.6;
		c = mix(c, soot_color.rgb, clamp(s, 0.0, 1.0));
	}

	c *= 1.0 - inside;
	ALBEDO = c;
	ROUGHNESS = clamp(rough, 0.0, 1.0);
	SPECULAR = 0.35;

	if (heat > 0.0) {
		float h = glow_to >= glow_from ? 1.0 - smoothstep(glow_from, glow_to, v_obj.y) : smoothstep(glow_to, glow_from, v_obj.y);
		if (glow_radius > 0.0 && v_obj.y > max(glow_to, glow_from)) {
			h = max(h, 1.0 - smoothstep(glow_radius * 0.9, glow_radius * 1.2, length(v_obj.xz)));
		}
		float flick = 0.85 + 0.15 * env_noise(vec2(TIME * 1.7, v_obj.y * 4.0 + ang));
		float t = clamp(heat * h * (0.75 + macro * 0.6) * flick + crack_mask * heat * h * 0.4, 0.0, 1.0);
		EMISSION = fx_heat_color(t * 0.8) * fx_heat_energy(t * 0.8) * glow_scale;
		ALBEDO = mix(ALBEDO, ALBEDO * 0.5, t);
	}
	NORMAL = env_bump(VERTEX, NORMAL, (macro * 0.6 + grain * 0.3 - crack_mask * 0.5) * 0.0015, 1.0);
}
