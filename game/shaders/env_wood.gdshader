shader_type spatial;
// Wood of boards, posts and planks from a photo scan (Poly Haven, CC0, see CREDITS.md; the project's
// graphics standard, TECH_SPEC Modul Y). The scan is laid on every face of a piece with its grain
// along the piece's grain axis, in the piece's own space, so carried things keep their grain; every
// piece reads another part of the scan. The scan gives the grain, knots, cracks, relief and sheen;
// its light and dark are brought to the material's own colour, so the hand-picked tones stay.
// On top, as before: per-board tint, silver-grey weathering, a darker damp foot near the ground and
// optional flaking paint.
// Per-piece data comes from vertex COLOR (written by EnvMesh.merge):
// r = random seed, gba = grain axis in mesh space (* 0.5 + 0.5). A mesh that is one piece and has
// no colours takes the axis from its instance (`grain_axis`, set by EnvMesh.add to its longest side).
// MultiMesh boards add their instance position to the seed.
render_mode diffuse_burley, specular_schlick_ggx;

#include "res://shaders/env_common.gdshaderinc"

// The scan (EnvMesh.wood picks it), metres per repeat, its mean colour and mean roughness.
uniform sampler2D albedo_map : source_color, repeat_enable, filter_linear_mipmap_anisotropic;
uniform sampler2D normal_map : repeat_enable, filter_linear_mipmap_anisotropic;
uniform sampler2D arm_map : repeat_enable, filter_linear_mipmap_anisotropic;
uniform float tile = 1.5;
uniform vec3 scan_mean = vec3(0.191, 0.099, 0.041);
uniform float rough_mean = 0.86;
// True for a scan whose grain runs up the image (false: along it).
uniform bool grain_up = false;

uniform vec4 base_color : source_color = vec4(0.549, 0.416, 0.306, 1.0);
uniform vec4 grain_color : source_color = vec4(0.36, 0.25, 0.18, 1.0);
uniform vec4 weather_color : source_color = vec4(0.56, 0.53, 0.50, 1.0);
uniform float weathering : hint_range(0.0, 1.0) = 0.35;
uniform float variation : hint_range(0.0, 0.5) = 0.12;
uniform float grain_strength : hint_range(0.0, 1.0) = 0.55;
uniform vec4 paint_color : source_color = vec4(0.247, 0.498, 0.525, 1.0);
// 0 = bare wood, 1 = fully painted; in between paint flakes off at random.
uniform float paint : hint_range(0.0, 1.0) = 0.0;
uniform float roughness_base : hint_range(0.0, 1.0) = 0.82;
instance uniform vec3 grain_axis = vec3(0.0, 1.0, 0.0);

varying vec3 v_local;
varying vec3 v_nlocal;
varying vec3 v_world;
varying float v_seed;
varying vec3 v_axis;

void vertex() {
	v_local = VERTEX;
	v_nlocal = NORMAL;
	v_world = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	v_seed = fract(COLOR.r * 7.31 + env_hash13(floor(MODEL_MATRIX[3].xyz * 13.7) + 0.5));
	// (No colours on the mesh reads as white: the axis (1, 1, 1), which no piece has.)
	vec3 raw = COLOR.gba * 2.0 - 1.0;
	v_axis = normalize((dot(raw, raw) > 2.5 ? grain_axis : raw) + vec3(0.0, 1e-4, 0.0));
}

void fragment() {
	vec3 n = normalize(v_nlocal);
	// The piece's own frame: `a` along the grain and two directions across it. The scan is laid on from
	// those three sides and blended by where the face looks, so a round handle is covered like a board.
	vec3 a = normalize(v_axis);
	vec3 e2 = normalize(cross(a, abs(a.y) < 0.9 ? vec3(0.0, 1.0, 0.0) : vec3(1.0, 0.0, 0.0)));
	vec3 e3 = cross(a, e2);
	vec3 nf = vec3(dot(n, a), dot(n, e2), dot(n, e3));
	vec3 w = pow(abs(nf), vec3(8.0));
	w /= w.x + w.y + w.z;
	vec3 q = v_local / tile;
	float along = dot(q, a) + v_seed * 7.3;
	float side2 = dot(q, e2) + v_seed * 3.1;
	float side3 = dot(q, e3) + v_seed * 5.7;
	// Image coordinates of the three sides (grain along the image, or up it; V runs down the image).
	vec2 u2 = grain_up ? vec2(side2, -along) : vec2(along, -side2);
	vec2 u3 = grain_up ? vec2(side3, -along) : vec2(along, -side3);
	vec2 ue = vec2(side2, -side3);
	vec2 g2a = dFdx(u2);
	vec2 g2b = dFdy(u2);
	vec2 g3a = dFdx(u3);
	vec2 g3b = dFdy(u3);
	vec2 gea = dFdx(ue);
	vec2 geb = dFdy(ue);
	vec3 col = vec3(0.0);
	vec3 arm = vec3(0.0);
	vec3 bumped = vec3(0.0);
	// A face that looks along e3 shows `along` and e2; its relief is tilted in those two directions.
	if (w.z > 0.004) {
		col += textureGrad(albedo_map, u2, g2a, g2b).rgb * w.z;
		arm += textureGrad(arm_map, u2, g2a, g2b).rgb * w.z;
		vec3 t = textureGrad(normal_map, u2, g2a, g2b).xyz * 2.0 - 1.0;
		vec3 right = grain_up ? e2 : a;
		vec3 up = grain_up ? a : e2;
		bumped += normalize(right * t.x + up * t.y + n * abs(t.z)) * w.z;
	}
	if (w.y > 0.004) {
		col += textureGrad(albedo_map, u3, g3a, g3b).rgb * w.y;
		arm += textureGrad(arm_map, u3, g3a, g3b).rgb * w.y;
		vec3 t = textureGrad(normal_map, u3, g3a, g3b).xyz * 2.0 - 1.0;
		vec3 right = grain_up ? e3 : a;
		vec3 up = grain_up ? a : e3;
		bumped += normalize(right * t.x + up * t.y + n * abs(t.z)) * w.y;
	}
	// End grain: the face looks along the grain; darker further down.
	if (w.x > 0.004) {
		col += textureGrad(albedo_map, ue, gea, geb).rgb * w.x;
		arm += textureGrad(arm_map, ue, gea, geb).rgb * w.x;
		bumped += n * w.x;
	}
	bumped = normalize(bumped);
	float end_grain = w.x;

	const vec3 LUM = vec3(0.2126, 0.7152, 0.0722);
	// The scan around its own average: mostly its light and dark, a little of its own play of colour.
	float shade = clamp(dot(col, LUM) / max(dot(scan_mean, LUM), 0.01), 0.3, 2.0);
	vec3 rel = clamp(col / max(scan_mean, vec3(0.01)), 0.25, 2.2);
	vec3 c = base_color.rgb * mix(vec3(shade), rel, 0.3);
	c *= 1.0 + (v_seed - 0.5) * variation * 2.0;
	c *= mix(vec3(1.0), vec3(1.04, 0.99, 0.94), fract(v_seed * 5.3));
	// The darkest of the grain (cracks, seams, knots) goes toward the material's grain colour.
	float dark = 1.0 - smoothstep(0.45, 0.85, shade);
	c = mix(c, grain_color.rgb * 0.8, dark * grain_strength * 0.6);
	c *= mix(1.0, 0.72, end_grain);
	// Weathering: silver-grey where the wood has stood in the open, following the grain.
	float wn = env_fbm(v_world.xz * 0.9 + v_world.y * 1.3 + v_seed * 5.0) + (shade - 1.0) * 0.25;
	float weathered = smoothstep(0.35, 0.75, wn) * weathering;
	c = mix(c, weather_color.rgb * mix(1.0, shade, 0.8) * 0.95, weathered);
	// Paint that flakes off along the grain, first where the wood is cracked.
	float keep = 0.0;
	if (paint > 0.0) {
		float flake = env_fbm(vec2((side2 + side3) * tile * 9.0, along * tile * 2.5) + v_seed * 13.0);
		keep = smoothstep(1.0 - paint - 0.08, 1.0 - paint + 0.08, flake + 0.2 + (shade - 1.0) * 0.3);
		c = mix(c, paint_color.rgb * mix(1.0, shade, 0.5), keep);
	}
	// Damp, dirty foot.
	c *= mix(0.7, 1.0, smoothstep(0.0, 0.3, v_world.y));
	ALBEDO = c;
	ROUGHNESS = clamp(roughness_base + (arm.g - rough_mean) * 0.6 - keep * 0.15, 0.05, 1.0);
	SPECULAR = 0.3;
	AO = mix(1.0, arm.r, 0.8);
	AO_LIGHT_AFFECT = 0.3;
	// The scan's relief, turned from the piece into view space.
	NORMAL = normalize((VIEW_MATRIX * vec4(normalize(mat3(MODEL_MATRIX) * bumped), 0.0)).xyz);
}
