shader_type spatial;
// Moulding sand in the flask (Art Bible 5.3 "Formsand"): fine grain with dark
// and light specks, raked furrows when fresh, lumpy loose sand after a pattern
// went in, round rammer stamps that appear with every ram, a compacted lip
// around each imprint, darker damp sand once rammed, scorched sand around the
// casting after a pour and a dull red glow while the metal is hot.
// The cavities (walls + floor) use the same shader with `is_cavity` on: dark
// parting dust, so the imprint reads from across the yard.
// Object space: the flask squashes and hops without the pattern swimming.
render_mode diffuse_burley, specular_schlick_ggx;

#include "res://shaders/env_common.gdshaderinc"
#include "res://shaders/fx_common.gdshaderinc"

uniform vec4 loose_color : source_color = vec4(0.84, 0.72, 0.53, 1.0);
uniform vec4 firm_color : source_color = vec4(0.6, 0.47, 0.32, 1.0);
uniform vec4 burnt_color : source_color = vec4(0.17, 0.14, 0.13, 1.0);
uniform vec4 cavity_color : source_color = vec4(0.33, 0.3, 0.29, 1.0);
// 0 = fluffy dry sand, 1 = rammed and damp.
uniform float firm : hint_range(0.0, 1.0) = 0.4;
uniform float rake : hint_range(0.0, 1.0) = 1.0;
uniform float loose : hint_range(0.0, 1.0) = 0.0;
// Fraction of the 30 rammer stamps that are visible.
uniform float stamps : hint_range(0.0, 1.0) = 0.0;
uniform float burn : hint_range(0.0, 1.0) = 0.0;
uniform float glow : hint_range(0.0, 1.0) = 0.0;
uniform bool is_cavity = false;
uniform float bed_top = 0.45;
uniform vec2 bed_half = vec2(0.75, 0.55);
// R = distance to the nearest imprint edge / field_range (sand side only).
uniform sampler2D edge_field : filter_linear, repeat_disable, hint_default_white;
uniform float field_range = 0.1;
uniform float seed = 0.0;

varying vec3 v_obj;

void vertex() {
	v_obj = VERTEX;
}

void fragment() {
	vec2 p = v_obj.xz;
	vec2 fw = fwidth(p);
	float px = max(fw.x, fw.y);
	float fine = 1.0 - smoothstep(0.0025, 0.007, px);
	float g1 = env_noise(p * 90.0 + seed) - 0.5;
	float g2 = (env_noise(p * 240.0 + 7.0) - 0.5) * fine;
	float speck = env_hash12(floor(p * 150.0 + seed * 31.0));
	float dark_speck = step(0.95, speck) * fine;
	float light_speck = step(speck, 0.035) * fine;
	float macro = env_fbm(p * 4.5 + seed) - 0.5;
	vec2 uv = p / (bed_half * 2.0) + 0.5;
	float d = texture(edge_field, uv).r * field_range;

	float h = g1 * 0.25 + g2 * 0.35;
	vec3 base = mix(loose_color.rgb, firm_color.rgb, firm);
	base *= 1.0 + macro * 0.14 + g1 * 0.09 + g2 * 0.1;
	base *= 1.0 - dark_speck * 0.4;
	base = mix(base, base * 1.28, light_speck);
	float rough = mix(0.97, 0.8, firm) + g1 * 0.05;

	if (!is_cavity) {
		// Rake furrows across the box, wavering a little.
		if (rake > 0.0) {
			float z = p.y + sin(p.x * 4.0 + seed) * 0.012 + macro * 0.01;
			float rk = sin(z * 6.2832 * 24.0);
			float fade = 1.0 - smoothstep(0.004, 0.012, px);
			h += rk * rake * 0.9 * fade;
			base *= 1.0 + rk * rake * 0.035 * fade;
		}
		// Loose lumps after the pattern was buried.
		if (loose > 0.0) {
			vec3 v = env_voronoi(p * 34.0 + seed);
			float lump = 1.0 - smoothstep(0.0, 0.7, v.x);
			h += lump * loose * 1.1;
			base *= 1.0 + (lump - 0.5) * loose * 0.12 + loose * 0.05;
		}
		// Rammer stamps: shallow overlapping dents with a soft rim.
		int n = int(stamps * 26.0 + 0.5);
		float in_stamp = 0.0;
		for (int i = 0; i < 26; i++) {
			if (i >= n) {
				break;
			}
			vec2 r2 = env_hash22(vec2(float(i) * 7.13 + seed, 3.7 + seed));
			vec2 c = (r2 * 2.0 - 1.0) * (bed_half - vec2(0.06));
			float r = 0.04 + env_hash12(r2 * 9.1) * 0.03;
			float dd = length((p - c) * vec2(1.0, 1.0 + env_hash12(r2 * 3.3) * 0.25)) + macro * 0.01;
			float inside = 1.0 - smoothstep(r * 0.55, r, dd);
			float rim = exp(-pow((dd - r) / 0.008, 2.0));
			in_stamp = max(in_stamp, inside);
			h += -inside * 0.55 + rim * 0.22;
		}
		base *= 1.0 - in_stamp * 0.05;
		rough = mix(rough, rough - 0.06, in_stamp);
		// Compacted lip around each imprint.
		float lip = 1.0 - smoothstep(0.004, 0.016, d);
		h += lip * 0.8;
		base = mix(base, base * 1.12, lip * 0.8);
		// Scorch after the pour.
		if (burn > 0.0) {
			float sc = burn * (1.0 - smoothstep(0.0, 0.022 + macro * 0.04 + g1 * 0.008, d));
			base = mix(base, burnt_color.rgb * (1.0 + g1 * 0.3), clamp(sc, 0.0, 1.0) * 0.9);
			rough = mix(rough, 0.95, sc);
		}
		// Darker sand against the flask walls.
		float wd = min(bed_half.x - abs(p.x), bed_half.y - abs(p.y));
		base *= mix(0.62, 1.0, smoothstep(0.0, 0.06, wd));
	} else {
		base = cavity_color.rgb * (1.0 + g1 * 0.18 + macro * 0.1);
		base *= mix(0.55, 1.0, smoothstep(bed_top - 0.07, bed_top - 0.005, v_obj.y));
		rough = 0.9;
		if (burn > 0.0) {
			base = mix(base, burnt_color.rgb, burn * 0.6);
		}
	}

	ALBEDO = base;
	ROUGHNESS = clamp(rough, 0.0, 1.0);
	SPECULAR = 0.3;
	if (glow > 0.0) {
		// Dull red seep right at the imprint edge (well below the melt).
		float near = is_cavity ? smoothstep(bed_top - 0.025, bed_top, v_obj.y) : 1.0 - smoothstep(0.0, 0.014 + macro * 0.01, d);
		float t = glow * near * near * (0.85 + macro * 0.6);
		EMISSION = fx_heat_color(t * 0.4) * fx_heat_energy(t * 0.4) * 0.6;
	}
	NORMAL = env_bump(VERTEX, NORMAL, h * 0.0016, 1.0);
}
