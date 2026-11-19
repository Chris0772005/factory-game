shader_type sky;
// Photographic day sky (Poly Haven "Kloofendal 48d Partly Cloudy (Pure Sky)", CC0, see CREDITS.md).
// What the eye sees is the 8k tone-mapped panorama (its upper part down to a little below the
// horizon); what lights the scene and what paint and glass mirror is the small HDR original, read in
// the radiance pass. Below the horizon the view fades into haze and the light into the ground's bounce.
// The panorama's sun stands 47.9 degrees up: GarageLighting.daylight points the sun light the same way.

uniform sampler2D view_panorama : source_color, filter_linear, repeat_enable;
uniform sampler2D light_panorama : filter_linear, repeat_enable;
// Share of the full panorama's height that view_panorama holds, from the zenith down.
uniform float view_rows = 0.5625;
uniform float view_energy = 1.0;
uniform float light_energy = 1.0;
// The sun's disc is cut down to this in the radiance pass: the sun light itself is a DirectionalLight3D.
uniform float light_clamp = 8.0;
uniform vec3 horizon_haze : source_color = vec3(0.62, 0.68, 0.75);
// What the ground sends back up (lit asphalt and concrete), seen by undersides and in low reflections.
uniform vec3 ground_bounce : source_color = vec3(0.3, 0.28, 0.26);

void sky() {
	vec2 uv = SKY_COORDS;
	float below = smoothstep(0.5, 0.535, uv.y);
	if (AT_CUBEMAP_PASS) {
		vec3 lit = min(textureLod(light_panorama, vec2(uv.x, clamp(uv.y, 0.001, 0.999)), 0.0).rgb, vec3(light_clamp));
		COLOR = mix(lit, ground_bounce, below) * light_energy;
	} else {
		vec3 seen = textureLod(view_panorama, vec2(uv.x, clamp(uv.y / view_rows, 0.001, 0.999)), 0.0).rgb;
		COLOR = mix(seen, horizon_haze, below) * view_energy;
	}
}
