shader_type canvas_item;
// Frosted backdrop for menus over the live game: mip-blurred screen, darkened and
// tinted towards ink, with a soft vignette.

uniform sampler2D screen_tex : hint_screen_texture, filter_linear_mipmap;
uniform float amount : hint_range(0.0, 1.0) = 1.0;
uniform float blur_lod = 3.2;
uniform vec4 tint : source_color = vec4(0.122, 0.106, 0.176, 1.0);
uniform float darken = 0.5;

void fragment() {
	vec2 uv = SCREEN_UV;
	vec3 c = textureLod(screen_tex, uv, blur_lod * amount).rgb;
	c = mix(c, c * 0.35 + tint.rgb * 0.5, darken * amount);
	float v = smoothstep(0.95, 0.25, length(uv - 0.5));
	c *= mix(1.0, 0.6 + 0.4 * v, amount);
	COLOR = vec4(c, 1.0);
}
