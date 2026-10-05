shader_type sky;
// Stylized dusk sky: three-stop gradient, warm afterglow around the setting
// sun, the pink "belt of Venus" above the cool earth shadow on the opposite
// side, a soft moon with halo, twinkling stars towards the zenith and drifting
// flat-bottomed clouds lit from the sunset side. Only light 0 (the sun) is
// passed in: the fill light uses sky_mode LIGHT_ONLY.

#include "res://shaders/env_common.gdshaderinc"

uniform vec4 zenith : source_color = vec4(0.204, 0.251, 0.498, 1.0);
uniform vec4 upper : source_color = vec4(0.36, 0.36, 0.62, 1.0);
uniform vec4 horizon : source_color = vec4(0.941, 0.627, 0.494, 1.0);
uniform vec4 afterglow : source_color = vec4(1.0, 0.70, 0.45, 1.0);
uniform vec4 venus_belt : source_color = vec4(0.86, 0.58, 0.66, 1.0);
uniform vec4 earth_shadow : source_color = vec4(0.36, 0.38, 0.58, 1.0);
uniform vec4 below : source_color = vec4(0.17, 0.16, 0.24, 1.0);
uniform float energy = 1.0;
uniform vec3 moon_dir = vec3(-0.549, 0.263, -0.794);
uniform vec4 moon_color : source_color = vec4(1.0, 0.96, 0.88, 1.0);
uniform float moon_size = 0.027;
uniform float star_amount = 1.0;
uniform vec4 cloud_lit : source_color = vec4(1.0, 0.824, 0.659, 1.0);
uniform vec4 cloud_shade : source_color = vec4(0.42, 0.38, 0.58, 1.0);
uniform float cloud_cover = 0.55;
uniform float cloud_speed = 0.004;

float cloud_density(vec2 uv) {
	float n = env_fbm(uv * vec2(0.55, 1.1)) * 0.75 + env_noise(uv * 3.1 + 7.0) * 0.25;
	return smoothstep(cloud_cover, cloud_cover + 0.12, n);
}

void sky() {
	vec3 d = EYEDIR;
	float h = d.y;
	float t = clamp(h, 0.0, 1.0);
	vec3 sun = LIGHT0_ENABLED ? LIGHT0_DIRECTION : normalize(vec3(-0.68, 0.28, 0.68));
	float sun_dot = dot(d, sun);
	vec2 flat_d = normalize(d.xz + vec2(1e-5));
	float az = dot(flat_d, normalize(sun.xz + vec2(1e-5)));   // 1 = towards the sun

	// Base gradient.
	vec3 col = mix(horizon.rgb, upper.rgb, smoothstep(0.0, 0.3, t));
	col = mix(col, zenith.rgb, smoothstep(0.22, 0.85, t));
	// Opposite side: cool earth shadow at the horizon, pink belt above it.
	float anti = smoothstep(0.1, -0.8, az);
	col = mix(col, earth_shadow.rgb, anti * (1.0 - smoothstep(0.0, 0.08, t)) * 0.75);
	col = mix(col, venus_belt.rgb, anti * smoothstep(0.03, 0.09, t) * (1.0 - smoothstep(0.1, 0.3, t)) * 0.55);
	// Warm afterglow hugging the horizon on the sun side, tight halo around the sun.
	float glow_side = pow(max(az * 0.5 + 0.5, 0.0), 3.0);
	col = mix(col, afterglow.rgb, glow_side * (1.0 - smoothstep(0.0, 0.35, t)) * 0.8);
	col += afterglow.rgb * pow(max(sun_dot, 0.0), 48.0) * 1.2;

	// Clouds on a curved layer, thicker towards the horizon band.
	if (h > 0.0) {
		vec2 uv = d.xz / (h + 0.12) * 1.6 + vec2(TIME * cloud_speed, TIME * cloud_speed * 0.4) * 10.0;
		float dens = cloud_density(uv);
		float dens2 = cloud_density(uv + sun.xz * 0.18);
		float lit = clamp((dens - dens2) * 2.5 + 0.45, 0.0, 1.0);
		float band = smoothstep(0.02, 0.1, h) * (1.0 - smoothstep(0.35, 0.65, h));
		vec3 cloud = mix(cloud_shade.rgb, cloud_lit.rgb, lit * (0.35 + 0.65 * glow_side));
		cloud = mix(cloud, col, 0.25);
		float c = dens * band * 0.9;
		col = mix(col, cloud, c);
		// Stars only in the visible sky, hidden by clouds and the afterglow.
		if (!AT_CUBEMAP_PASS) {
			vec3 sp = d * 170.0;
			vec3 cell = floor(sp);
			float r = env_hash13(cell);
			if (r > 0.991) {
				vec3 jitter = vec3(env_hash13(cell + 1.3), env_hash13(cell + 2.7), env_hash13(cell + 5.1)) - 0.5;
				float s = 1.0 - smoothstep(0.06, 0.2, length(fract(sp) - 0.5 - jitter * 0.55));
				float twinkle = 0.65 + 0.35 * sin(TIME * (1.5 + r * 3.0) + r * 400.0);
				float fade = smoothstep(0.12, 0.55, h) * (1.0 - glow_side * 0.8) * (1.0 - c);
				col += vec3(1.0, 0.95, 0.86) * s * twinkle * fade * star_amount * (0.6 + (r - 0.991) * 120.0);
			}
		}
	}

	// Moon: soft disc with a little mottling and a wide halo.
	vec3 md = normalize(moon_dir);
	float m = dot(d, md);
	float ang = acos(clamp(m, -1.0, 1.0));
	float disc = 1.0 - smoothstep(moon_size * 0.92, moon_size, ang);
	float mottle = env_fbm((d - md).xy * 90.0 + 3.0);
	col = mix(col, moon_color.rgb * (1.5 - mottle * 0.35), disc);
	col += moon_color.rgb * (exp(-ang * 30.0) * 0.12 + exp(-ang * 7.0) * 0.05) * (1.0 - disc);

	// Below the horizon: the darkening ground.
	if (h < 0.0) {
		col = mix(col, below.rgb, smoothstep(0.0, -0.1, h));
	}
	COLOR = col * energy;
}
