shader_type spatial;
// Clay roof tiles in rows: staggered vertical joints, a dark overlap shadow
// at the bottom of every row, per-tile tone, the odd replaced tile and moss
// creeping up from the eaves. Rows follow the mesh's local height (rows are
// placed every `row_rise` above `eave_y`), joints follow local x.
render_mode diffuse_burley, specular_schlick_ggx;

#include "res://shaders/env_common.gdshaderinc"

uniform vec4 tile_color : source_color = vec4(0.42, 0.29, 0.31, 1.0);
uniform vec4 tile_light : source_color = vec4(0.58, 0.40, 0.38, 1.0);
uniform vec4 moss_color : source_color = vec4(0.30, 0.40, 0.25, 1.0);
uniform float eave_y = 5.4;
uniform float row_rise = 0.22;
uniform float tile_width = 0.32;
uniform float moss : hint_range(0.0, 1.0) = 0.4;

varying vec3 v_local;
varying vec3 v_world;

void vertex() {
	v_local = VERTEX;
	v_world = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	float rows = (v_local.y - eave_y) / row_rise;
	float row = floor(rows);
	float fy = fract(rows);
	float tx = v_local.x / tile_width + env_hash12(vec2(row, 3.1)) * 0.5 + mod(row, 2.0) * 0.5;
	float col = floor(tx);
	float fx = fract(tx);
	float id = env_hash12(vec2(col, row));
	vec3 c = mix(tile_color.rgb, tile_light.rgb, id * 0.6 + env_fbm(v_world.xz * 0.4) * 0.4);
	c *= step(0.04, id) * 0.25 + 0.75 + step(id, 0.04) * 0.1;
	// Rounded tile: lighter crown, darker joints, overlap shadow at the bottom edge.
	float crown = sin(fx * 3.14159);
	c *= 0.82 + crown * 0.22;
	c *= mix(0.55, 1.0, smoothstep(0.0, 0.22, fy));
	float joint = 1.0 - smoothstep(0.0, 0.06, min(fx, 1.0 - fx));
	c *= 1.0 - joint * 0.35;
	// Moss from the eaves and in damp patches.
	float m = smoothstep(0.55, 0.8, env_fbm(v_world.xz * 0.8 + v_world.y) + (1.0 - smoothstep(0.0, 1.5, v_local.y - eave_y)) * 0.25) * moss;
	m *= 0.6 + env_noise(v_world.xz * 12.0) * 0.4;
	c = mix(c, moss_color.rgb, m);
	c *= 0.94 + env_noise(v_world.xz * 18.0) * 0.12;
	ALBEDO = c;
	ROUGHNESS = 0.78 + m * 0.15;
	SPECULAR = 0.35;
	NORMAL = env_bump(VERTEX, NORMAL, (crown * 0.6 + smoothstep(0.0, 0.22, fy) * 0.4) * 0.012, 1.0);
}
