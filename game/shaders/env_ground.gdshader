shader_type spatial;
// Backyard ground: lawn, worn dirt, gravel, moulding sand and furnace soot,
// blended by a small zone mask painted from the level layout (R dirt,
// G gravel, B soot, A sand). Edges are broken up with noise so no zone ever
// has a straight border; pebbles and gravel get a bump normal. A second mask
// (R trodden walkways, G damp, B puddles) adds packed, darker, smoother
// paths between the stations, soil crumbs everywhere else on the dirt,
// damp patches and mirror-smooth puddles that catch the dusk sky.
render_mode diffuse_burley, specular_schlick_ggx;

#include "res://shaders/env_common.gdshaderinc"

uniform sampler2D zone_mask : filter_linear, repeat_disable;
uniform sampler2D detail_mask : filter_linear, repeat_disable;
// xy = world x/z of the mask's first texel corner, zw = covered size in metres.
uniform vec4 mask_rect = vec4(-14.0, -10.0, 28.0, 20.0);
uniform vec4 grass_dark : source_color = vec4(0.165, 0.337, 0.251, 1.0);
uniform vec4 grass_mid : source_color = vec4(0.306, 0.541, 0.322, 1.0);
uniform vec4 grass_light : source_color = vec4(0.498, 0.690, 0.384, 1.0);
uniform vec4 dirt_dark : source_color = vec4(0.39, 0.305, 0.235, 1.0);
uniform vec4 dirt_mid : source_color = vec4(0.58, 0.465, 0.355, 1.0);
uniform vec4 dirt_light : source_color = vec4(0.72, 0.60, 0.46, 1.0);
uniform vec4 gravel_dark : source_color = vec4(0.42, 0.40, 0.38, 1.0);
uniform vec4 gravel_light : source_color = vec4(0.72, 0.68, 0.61, 1.0);
uniform vec4 sand_loose : source_color = vec4(0.890, 0.776, 0.565, 1.0);
uniform vec4 sand_rammed : source_color = vec4(0.722, 0.584, 0.373, 1.0);
uniform vec4 soot_color : source_color = vec4(0.165, 0.145, 0.141, 1.0);
uniform vec4 trodden_color : source_color = vec4(0.43, 0.345, 0.275, 1.0);
uniform vec4 puddle_color : source_color = vec4(0.10, 0.10, 0.13, 1.0);
uniform float bump_strength = 1.0;
// Outside this radius around the yard centre the lawn darkens into the night.
uniform float far_fade_start = 18.0;

varying vec3 wpos;

void vertex() {
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

vec4 zones(vec2 xz) {
	vec2 uv = (xz - mask_rect.xy) / mask_rect.zw;
	vec2 inside = step(vec2(0.0), uv) * step(uv, vec2(1.0));
	return texture(zone_mask, uv) * inside.x * inside.y;
}

vec4 details(vec2 xz) {
	vec2 uv = (xz - mask_rect.xy) / mask_rect.zw;
	vec2 inside = step(vec2(0.0), uv) * step(uv, vec2(1.0));
	return texture(detail_mask, uv) * inside.x * inside.y;
}

void fragment() {
	vec2 xz = wpos.xz;
	vec2 warp = vec2(env_noise(xz * 1.1), env_noise(xz * 1.1 + 19.3)) - 0.5;
	vec4 z = zones(xz + warp * 0.55);
	float n_edge = env_fbm(xz * 1.6 + 3.0) - 0.5;
	float n_fine = env_noise(xz * 6.0) - 0.5;
	float grain = env_noise(xz * 23.0) - 0.5;

	// Lawn: patches and clumps (same function the grass tufts use).
	vec3 lawn = env_lawn(xz, grass_dark.rgb, grass_mid.rgb, grass_light.rgb);
	lawn = mix(lawn, grass_dark.rgb, 0.12);
	lawn *= 1.0 + grain * 0.16 + n_fine * 0.12;
	float lawn_h = env_noise(xz * 9.0) * 0.6 + grain * 0.4;

	// Dirt: dry and damp patches, pebbles.
	float dry = env_fbm(xz * 0.6 + 7.0);
	vec3 dirt = mix(dirt_mid.rgb, dirt_light.rgb, smoothstep(0.42, 0.72, dry));
	dirt = mix(dirt, dirt_dark.rgb, smoothstep(0.56, 0.8, env_fbm(xz * 0.35 + 23.0)) * 0.55);
	dirt *= 1.0 + grain * 0.2 + n_fine * 0.1;
	float d = smoothstep(0.38, 0.62, z.r + n_edge * 0.55 + n_fine * 0.15);
	float g = smoothstep(0.4, 0.6, z.g + n_edge * 0.35 + n_fine * 0.1);
	vec4 dm = details(xz + warp * 0.4);
	float trod = smoothstep(0.2, 0.75, dm.r + n_edge * 0.45 + n_fine * 0.2);
	float damp = smoothstep(0.1, 0.8, dm.g + n_edge * 0.4);
	float puddle = smoothstep(0.42, 0.55, dm.b + n_edge * 0.25 + n_fine * 0.08);
	// Pebbles and clods only where there is dirt, gravel only in the strip:
	// the Voronoi lookups are the expensive part of this shader.
	float dirt_h = n_fine * 0.25;
	if (d > 0.01) {
		// Packed walkways: darker, smoother, a faint sheen.
		float loose = 1.0 - trod;
		dirt = mix(dirt, trodden_color.rgb * (1.0 + n_fine * 0.12 + grain * 0.1), trod * 0.75);
		// One Voronoi lookup gives round pebbles (20 % of the cells) and dark
		// soil crumbs (35 %, loose dirt only). Thresholded value noise would
		// give square blobs that read as pixels.
		vec3 pv = env_voronoi(xz * 8.0);
		float pebble = (1.0 - smoothstep(0.1, 0.2, pv.x)) * step(0.8 + trod * 0.14, pv.y);
		float crumb = (1.0 - smoothstep(0.05, 0.12, pv.x)) * step(0.45, pv.y) * (1.0 - step(0.8, pv.y)) * loose;
		dirt *= 1.0 - crumb * 0.22;
		vec3 pebble_col = mix(dirt_light.rgb * 1.12, gravel_dark.rgb, fract(pv.y * 7.3));
		dirt = mix(dirt, pebble_col, pebble * 0.6);
		dirt_h += pebble * (0.2 - pv.x) * 3.0 + crumb * 0.12;
		dirt_h *= 1.0 - trod * 0.55;
	}

	// Gravel: packed stones with dark gaps.
	vec3 gravel = gravel_dark.rgb;
	float gravel_h = 0.0;
	if (g > 0.01) {
		vec3 gv = env_voronoi(xz * 11.0 + 7.0);
		float stone = smoothstep(0.02, 0.1, gv.z - gv.x);
		gravel = mix(gravel_dark.rgb, gravel_light.rgb, gv.y) * mix(0.4, 1.0, stone);
		gravel *= 1.0 + grain * 0.15;
		gravel_h = stone * (0.45 - gv.x * 0.6);
	}

	// Moulding sand: loose and rammed.
	vec3 sand = mix(sand_rammed.rgb, sand_loose.rgb, smoothstep(0.3, 0.7, env_fbm(xz * 2.0 + 9.0)));
	sand *= 1.0 + grain * 0.12;

	// Spilled-sand edge broken up by fbm: thresholding the 4 cm value-noise
	// grain here gave square blobs that read as pixels at the mold.
	float s = smoothstep(0.35, 0.75, z.a + n_edge * 0.6 + (env_fbm(xz * 7.0 + 3.0) - 0.5) * 0.45);
	float soot = smoothstep(0.15, 0.85, z.b + n_edge * 0.5 + n_fine * 0.2);

	vec3 col = mix(lawn, dirt, d);
	// Damp, trodden seam where turf meets dirt.
	col *= 1.0 - d * (1.0 - d) * 4.0 * 0.2;
	col = mix(col, gravel, g);
	col = mix(col, sand, s * 0.85);
	col = mix(col, soot_color.rgb * (0.85 + grain * 0.6), soot * 0.82);
	// Damp ground darkens; puddles are dark water with a sky reflection.
	col *= 1.0 - damp * 0.38;
	col = mix(col, puddle_color.rgb, puddle);
	// The neighbours' lawns sink into the dusk.
	float far = smoothstep(far_fade_start, far_fade_start + 16.0, length(xz - vec2(0.0, -1.0)));
	col *= 1.0 - far * 0.35;

	float h = mix(lawn_h * 0.3, dirt_h, d);
	h = mix(h, gravel_h, g);
	h = mix(h, grain * 0.2, s * 0.7);
	h *= 1.0 - puddle;

	ALBEDO = col;
	float rough = clamp(mix(mix(0.95, 0.9, d), 0.82, g) + grain * 0.06 - trod * d * 0.14, 0.0, 1.0);
	rough = mix(rough, 0.6, damp * 0.7);
	ROUGHNESS = mix(rough, 0.05, puddle);
	SPECULAR = mix(0.25, 0.5, puddle);
	NORMAL = env_bump(VERTEX, NORMAL, h * 0.012, bump_strength);
}
