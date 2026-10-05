shader_type spatial;
// Window pane (QuadMesh UVs). Lit windows glow warm from inside: a lamp-lit
// gradient, a darker room depth towards the frame, curtain silhouettes and a
// shadowy plant or lamp on the sill. Unlit windows show dark glass with a
// sky reflection streak. Per window: instance uniforms `lit` and `seed`.
render_mode diffuse_burley, specular_schlick_ggx;

#include "res://shaders/env_common.gdshaderinc"

uniform vec4 glow : source_color = vec4(1.0, 0.761, 0.478, 1.0);
uniform vec4 room : source_color = vec4(0.55, 0.30, 0.18, 1.0);
uniform vec4 curtain : source_color = vec4(0.72, 0.42, 0.40, 1.0);
uniform vec4 glass_dark : source_color = vec4(0.12, 0.13, 0.20, 1.0);
uniform vec4 glass_sky : source_color = vec4(0.45, 0.42, 0.62, 1.0);
uniform float energy = 2.0;
instance uniform float lit = 1.0;
instance uniform float seed = 0.0;

void fragment() {
	vec2 uv = UV;
	float s = fract(seed * 7.13);
	if (lit > 0.0) {
		// Warm light from a lamp near the top, darker room depth at the edges.
		float lamp = 1.0 - smoothstep(0.0, 0.9, length((uv - vec2(0.35 + s * 0.3, 0.15)) * vec2(1.0, 1.3)));
		float edge = smoothstep(0.0, 0.18, min(min(uv.x, 1.0 - uv.x), min(uv.y, 1.0 - uv.y)));
		vec3 c = mix(room.rgb, glow.rgb, 0.45 + lamp * 0.55) * mix(0.55, 1.0, edge);
		// Curtains: soft folds at both sides, gathered towards the bottom.
		float width = mix(0.16, 0.26, s);
		float gather = width * (0.75 + 0.35 * uv.y);
		float folds = 0.75 + 0.25 * sin(uv.x * 60.0 + s * 10.0);
		float cl = 1.0 - smoothstep(gather - 0.02, gather + 0.02, uv.x);
		float cr = smoothstep(1.0 - gather - 0.02, 1.0 - gather + 0.02, uv.x);
		c = mix(c, curtain.rgb * folds * (0.55 + lamp * 0.3), max(cl, cr));
		// Silhouette on the sill: a pot plant or a lamp.
		vec2 q = uv - vec2(0.62 - s * 0.25, 0.9);
		float pot = step(abs(q.x), 0.05) * step(0.0, q.y) * step(q.y, 0.08);
		float leaves = 1.0 - smoothstep(0.07, 0.09, length((q + vec2(0.0, 0.1)) * vec2(1.0, 1.4)) - env_noise(uv * 30.0) * 0.03);
		c = mix(c, room.rgb * 0.25, max(pot, leaves) * step(0.35, s));
		ALBEDO = vec3(0.0);
		EMISSION = c * energy * lit;
		ROUGHNESS = 0.3;
	} else {
		float streak = smoothstep(0.1, 0.0, abs(uv.x + uv.y * 0.6 - 0.55 - s * 0.3));
		vec3 c = mix(glass_dark.rgb, glass_sky.rgb, (1.0 - uv.y) * 0.5 + streak * 0.4);
		ALBEDO = c;
		ROUGHNESS = 0.15;
		METALLIC = 0.2;
	}
	SPECULAR = 0.5;
}
