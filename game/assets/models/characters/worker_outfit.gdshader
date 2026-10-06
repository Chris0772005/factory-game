// Worker outfit: the KayKit character atlas with the shirt cells recoloured to the
// player colour, the barbarian's fur trim turned into dark leather, the hands into
// leather gloves and the fur boots into work boots (Art Bible 4.2), plus per-player
// skin/beard tints. Keeps the atlas' painted top-to-bottom gradients (new colours
// follow the original luminance) and adds soft wrap lighting and a gentle rim so
// the chunky shapes read against the dusk yard.
shader_type spatial;
render_mode diffuse_lambert_wrap, specular_schlick_ggx;

// KayKit atlas: 8 columns x 4 rows of vertical gradient cells.
uniform sampler2D atlas : source_color, filter_linear_mipmap_anisotropic, repeat_disable;
// Player colour for the shirt and sleeves.
uniform vec3 suit_color : source_color = vec3(0.24, 0.49, 0.85);
// Multipliers for the skin, hair/beard and fur-trim cells (white = atlas colour).
uniform vec3 skin_tint : source_color = vec3(1.0);
uniform vec3 hair_tint : source_color = vec3(1.0);
uniform vec3 trim_tint : source_color = vec3(1.0);
// Atlas rectangles (min u, min v, max u, max v).
uniform vec4 suit_rect_a = vec4(0.0, 0.25, 0.125, 0.5);
uniform vec4 suit_rect_b = vec4(0.125, 0.25, 0.25, 0.5);
uniform vec4 skin_rect = vec4(0.0, 0.0, 0.125, 0.25);
uniform vec4 hair_rect = vec4(0.125, 0.0, 0.25, 0.25);
uniform vec4 trim_rect = vec4(0.25, 0.25, 0.375, 0.5);
// Hands (cell 7/2) and boots (cell 3/2) of the Barbarian atlas, recoloured to
// glove and boot leather.
uniform vec4 glove_rect = vec4(0.875, 0.5, 1.0, 0.75);
uniform vec4 boot_rect = vec4(0.375, 0.5, 0.5, 0.75);
uniform vec3 glove_color : source_color = vec3(0.353, 0.275, 0.212);
uniform vec3 boot_color : source_color = vec3(0.227, 0.184, 0.169);
// Linear luminance of the original hand and boot cells at mid height.
uniform float glove_ref_luma = 0.24;
uniform float boot_ref_luma = 0.11;
// Linear luminance of the original shirt at mid height; maps onto suit_color.
uniform float suit_ref_luma = 0.14;
uniform float roughness_value : hint_range(0.0, 1.0) = 0.78;
uniform float rim_amount : hint_range(0.0, 1.0) = 0.22;

float in_rect(vec2 uv, vec4 r) {
	vec2 inside = step(r.xy, uv) * step(uv, r.zw);
	return inside.x * inside.y;
}

void fragment() {
	vec3 base = texture(atlas, UV).rgb;
	float luma = dot(base, vec3(0.2126, 0.7152, 0.0722));
	float suit = max(in_rect(UV, suit_rect_a), in_rect(UV, suit_rect_b));
	// Slightly desaturated so the cloth sits with the painted atlas instead of looking like plastic.
	vec3 cloth_tone = mix(suit_color, vec3(dot(suit_color, vec3(0.2126, 0.7152, 0.0722))), 0.12);
	vec3 cloth = min(cloth_tone * clamp(luma / suit_ref_luma, 0.5, 1.45), vec3(1.0));
	base = mix(base, cloth, suit);
	base *= mix(vec3(1.0), skin_tint, in_rect(UV, skin_rect));
	base *= mix(vec3(1.0), hair_tint, in_rect(UV, hair_rect));
	base *= mix(vec3(1.0), trim_tint, in_rect(UV, trim_rect));
	base = mix(base, glove_color * clamp(luma / glove_ref_luma, 0.6, 1.4), in_rect(UV, glove_rect));
	base = mix(base, boot_color * clamp(luma / boot_ref_luma, 0.6, 1.5), in_rect(UV, boot_rect));
	ALBEDO = base;
	ROUGHNESS = roughness_value;
	SPECULAR = 0.35;
	RIM = rim_amount;
	RIM_TINT = 0.6;
}
