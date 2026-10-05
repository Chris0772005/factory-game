shader_type canvas_item;
// Logo / title lettering: molten gradient on the glyph fill (vertex colour white),
// ink outline and drop shadow untouched, a shine band that sweeps across every few
// seconds and a slow liquid wobble.

uniform vec4 hot : source_color = vec4(1.0, 0.95, 0.78, 1.0);
uniform vec4 top_color : source_color = vec4(1.0, 0.824, 0.478, 1.0);
uniform vec4 bottom_color : source_color = vec4(1.0, 0.416, 0.102, 1.0);
uniform vec4 deep : source_color = vec4(0.85, 0.22, 0.05, 1.0);
// Label-local y of the cap height top and the baseline (px).
uniform float glyph_top = 0.0;
uniform float glyph_bottom = 100.0;
uniform float shine_period = 4.5;
uniform float wobble = 2.0;
uniform float glow = 0.0;

varying vec2 local_pos;
varying vec4 vcol;
varying vec2 canvas_pos;

void vertex() {
	vcol = COLOR;
	canvas_pos = (MODEL_MATRIX * vec4(VERTEX, 0.0, 1.0)).xy;
	local_pos = VERTEX;
	VERTEX.y += sin(TIME * 1.7 + canvas_pos.x * 0.012) * wobble;
}

void fragment() {
	vec4 tex = texture(TEXTURE, UV);
	float fill = step(0.92, min(vcol.r, min(vcol.g, vcol.b)));
	float t = clamp((local_pos.y - glyph_top) / max(glyph_bottom - glyph_top, 1.0), 0.0, 1.0);
	vec3 g = t < 0.45 ? mix(hot.rgb, top_color.rgb, t / 0.45) : mix(top_color.rgb, bottom_color.rgb, (t - 0.45) / 0.4);
	g = mix(g, deep.rgb, smoothstep(0.85, 1.0, t));
	float phase = fract(TIME / shine_period);
	float band = canvas_pos.x - canvas_pos.y * 0.45 - mix(-400.0, 2400.0, phase);
	float shine = (1.0 - smoothstep(0.0, 70.0, abs(band))) * 0.75;
	vec3 fill_col = g + vec3(shine) + g * glow;
	vec3 col = mix(vcol.rgb * tex.rgb, fill_col, fill);
	COLOR = vec4(col, vcol.a * tex.a);
}
