shader_type spatial;
// Garage floor: sealed concrete slabs with saw-cut joints, trowel swirls, fine
// aggregate, a worn walkway sheen, and stains placed by the level (oil under
// the car, soot round the furnace, moulding sand at the molds, rust rings
// under barrels). Outside the door line it turns into a cracked driveway of
// grey pavers with moss in the gaps.
render_mode diffuse_burley, specular_schlick_ggx;

#include "res://shaders/env_common.gdshaderinc"
#include "res://shaders/env_photo.gdshaderinc"

uniform vec4 concrete : source_color = vec4(0.63, 0.59, 0.54, 1.0);
uniform vec4 concrete_dark : source_color = vec4(0.44, 0.41, 0.38, 1.0);
uniform vec4 oil : source_color = vec4(0.16, 0.15, 0.16, 1.0);
uniform vec4 soot : source_color = vec4(0.17, 0.15, 0.14, 1.0);
uniform vec4 sand : source_color = vec4(0.78, 0.65, 0.45, 1.0);
uniform vec4 rust : source_color = vec4(0.45, 0.27, 0.17, 1.0);
uniform vec4 paver : source_color = vec4(0.55, 0.54, 0.53, 1.0);
uniform vec4 moss : source_color = vec4(0.25, 0.33, 0.19, 1.0);
uniform vec4 line_paint : source_color = vec4(0.85, 0.66, 0.18, 1.0);
// Painted bay line (world x) from the back wall to the door; < -50 disables it.
uniform float bay_line_x = -100.0;
uniform float bay_line_from_z = -1.0;
// Slab grid (m) and the door line (world z) beyond which the driveway starts.
uniform float slab = 3.0;
uniform float door_z = 4.4;
// Stains: xy = world xz, z = radius, w = kind (0 oil, 1 soot, 2 sand, 3 rust).
uniform vec4 stains[12];
uniform int stain_count = 0;

varying vec3 wpos;

void vertex() {
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

float joint(vec2 xz, float size, float width) {
	vec2 f = abs(fract(xz / size + 0.5) - 0.5) * size;
	return 1.0 - smoothstep(width * 0.5, width, min(f.x, f.y));
}

void fragment() {
	vec2 xz = wpos.xz;
	float blot = env_fbm(xz * 0.45);
	float fine = env_noise(xz * 9.0);
	float grain = env_noise(xz * 37.0);
	vec3 col;
	float h;
	float rough;
	if (xz.y < door_z) {
		// Interior concrete: big soft value blotches, trowel arcs, aggregate.
		col = mix(concrete_dark.rgb, concrete.rgb, smoothstep(0.2, 0.8, blot));
		col *= 1.0 + (env_fbm(xz * 0.12 + 5.0) - 0.5) * 0.25;
		float swirl = sin(length(fract(xz * 0.6) - 0.5) * 22.0 + env_noise(xz * 0.8) * 6.0);
		col *= 1.0 + swirl * 0.015 + (fine - 0.5) * 0.08 + (grain - 0.5) * 0.07;
		vec3 agg = env_voronoi(xz * 26.0);
		float stone = (1.0 - smoothstep(0.08, 0.16, agg.x)) * step(0.72, agg.y);
		col = mix(col, concrete_dark.rgb * (0.8 + agg.y * 0.4), stone * 0.35);
		// Saw-cut joints, slightly dirty along their edges.
		float j = joint(xz + vec2(0.0, 0.4), slab, 0.012);
		float jdirt = joint(xz + vec2(0.0, 0.4), slab, 0.09);
		col *= 1.0 - jdirt * 0.08 - j * 0.45;
		// Hairline cracks.
		vec3 cv = env_voronoi(xz * 0.9 + 7.0);
		float crack = (1.0 - smoothstep(0.0, 0.012, cv.z - cv.x)) * smoothstep(0.55, 0.8, env_fbm(xz * 0.7 + 3.0));
		col *= 1.0 - crack * 0.35;
		// Worn, scuffed paint line marking the parking bay.
		float line = (1.0 - smoothstep(0.045, 0.055, abs(xz.x - bay_line_x))) * step(bay_line_from_z, xz.y);
		line *= smoothstep(0.25, 0.55, env_noise(xz * 7.0) + blot * 0.3);
		col = mix(col, line_paint.rgb * (0.85 + fine * 0.2), line * 0.85);
		// Decades of boots: a darker, polished band between the stations.
		float wear = smoothstep(0.35, 0.75, env_fbm(xz * 0.3 + 17.0));
		col *= 1.0 - wear * 0.1;
		h = (fine - 0.5) * 0.3 + stone * 0.4 - j * 1.5 - crack * 0.6;
		rough = 0.82 - smoothstep(0.4, 0.9, blot) * 0.1 - wear * 0.12 - line * 0.2;
	} else {
		// Driveway pavers (20 x 10 cm bond), sandy joints with moss.
		vec2 b = xz * vec2(3.0, 6.0);
		b.x += step(1.0, mod(floor(b.y), 2.0)) * 0.5;
		vec2 f = fract(b);
		float id = env_hash12(floor(b));
		float gap = clamp(step(f.x, 0.035) + step(f.y, 0.06), 0.0, 1.0);
		col = paver.rgb * (0.9 + id * 0.12) * (0.88 + blot * 0.2) * (0.95 + fine * 0.08);
		vec3 gap_col = mix(paver.rgb * 0.62, moss.rgb, smoothstep(0.5, 0.75, env_fbm(xz * 1.3)) * 0.7);
		col = mix(col, gap_col, gap * 0.8);
		h = (1.0 - gap) * 0.6 + id * 0.15;
		rough = 0.9;
		// Wet tyre tracks leading in.
		float track = (1.0 - smoothstep(0.08, 0.18, abs(abs(xz.x + 4.3) - 0.72))) * smoothstep(door_z, door_z + 5.0, xz.y + 4.5);
		col *= 1.0 - track * 0.18;
	}
	// Level stains.
	float wet = 0.0;
	// Fixed bound, no `continue`: some drivers (lavapipe) crash on a uniform
	// loop bound with an early continue.
	// Noise for the stain edges is shared by all stains (one lookup, not twelve).
	float edge_n = env_fbm(xz * 2.2) - 0.5;
	float speck = step(0.62, env_noise(xz * 48.0));
	for (int i = 0; i < 12; i++) {
		if (i < stain_count) {
			vec4 s = stains[i];
			float d = length(xz - s.xy) / s.z + edge_n * 0.55;
			float k = 1.0 - smoothstep(0.55, 1.0, d);
			if (k > 0.0) {
				if (s.w < 0.5) {
					col = mix(col, oil.rgb, k * 0.75);
					wet = max(wet, k);
				} else if (s.w < 1.5) {
					col = mix(col, soot.rgb * (0.85 + grain * 0.4), k * 0.7);
				} else if (s.w < 2.5) {
					// Spilled moulding sand: a grainy, lighter crust with loose specks.
					col = mix(col, sand.rgb * (0.9 + grain * 0.2), k * (0.55 + speck * 0.3));
					h += k * speck * 0.4;
					rough = mix(rough, 0.97, k);
				} else {
					float ring = 1.0 - smoothstep(0.0, 0.08, abs(d - 0.75));
					col = mix(col, rust.rgb, max(ring, k * 0.3) * 0.6);
				}
			}
		}
	}
	ALBEDO = col;
	ROUGHNESS = mix(rough, 0.25, wet);
	SPECULAR = mix(0.35, 0.6, wet);
	NORMAL = env_bump(VERTEX, NORMAL, h * 0.004, 1.0);
	// Photo detail over the designed surface (env_photo.gdshaderinc).
	vec3 ph_a = ALBEDO;
	float ph_r = ROUGHNESS;
	NORMAL = env_photo_world(ph_concrete_d, ph_concrete_n, ph_concrete_arm, wpos, NORMAL, INV_VIEW_MATRIX, VIEW_MATRIX, 0.45, 1.0, ph_a, ph_r);
	ALBEDO = ph_a;
	ROUGHNESS = ph_r;
}
