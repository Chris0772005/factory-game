// Shared helpers for the foundry shaders: cheap 3D value noise and the
// blackbody ramp used for glowing metal, streams, flames and sparks.

float fx_hash(vec3 p) {
	p = fract(p * 0.1031);
	p += dot(p, p.zyx + 31.32);
	return fract((p.x + p.y) * p.z);
}

// Smooth value noise in [0, 1].
float fx_noise(vec3 p) {
	vec3 i = floor(p);
	vec3 f = fract(p);
	vec3 u = f * f * (3.0 - 2.0 * f);
	float a = mix(fx_hash(i), fx_hash(i + vec3(1.0, 0.0, 0.0)), u.x);
	float b = mix(fx_hash(i + vec3(0.0, 1.0, 0.0)), fx_hash(i + vec3(1.0, 1.0, 0.0)), u.x);
	float c = mix(fx_hash(i + vec3(0.0, 0.0, 1.0)), fx_hash(i + vec3(1.0, 0.0, 1.0)), u.x);
	float d = mix(fx_hash(i + vec3(0.0, 1.0, 1.0)), fx_hash(i + vec3(1.0, 1.0, 1.0)), u.x);
	return mix(mix(a, b, u.y), mix(c, d, u.y), u.z);
}

// Three octaves, roughly in [0, 1].
float fx_fbm(vec3 p) {
	return fx_noise(p) * 0.57 + fx_noise(p * 2.03 + 17.1) * 0.29 + fx_noise(p * 4.11 + 41.7) * 0.14;
}

vec3 fx_hash3(vec3 p) {
	return vec3(fx_hash(p), fx_hash(p + 19.19), fx_hash(p + 47.47));
}

// Approximate distance to the nearest Voronoi cell border (0 on the border):
// crust plates separated by cracks.
float fx_cell_border(vec3 p) {
	vec3 i = floor(p);
	vec3 f = fract(p);
	float d1 = 8.0;
	float d2 = 8.0;
	for (int z = -1; z <= 1; z++) {
		for (int y = -1; y <= 1; y++) {
			for (int x = -1; x <= 1; x++) {
				vec3 g = vec3(float(x), float(y), float(z));
				vec3 r = g + fx_hash3(i + g) - f;
				float d = dot(r, r);
				if (d < d1) {
					d2 = d1;
					d1 = d;
				} else if (d < d2) {
					d2 = d;
				}
			}
		}
	}
	return sqrt(d2) - sqrt(d1);
}

// Thin bright lines that drift with `offset`, like light on wavelets.
float fx_glint_lines(vec3 p) {
	return smoothstep(0.82, 0.97, 1.0 - abs(fx_noise(p) * 2.0 - 1.0));
}

// Blackbody-like colour for t in [0, 1]: dull red, red, orange, gold, pale yellow.
// Deliberately redder than physical: AgX desaturates and shifts bright oranges
// towards yellow-white, so these inputs land on the intended on-screen hues
// (calibrated against the AgX + glow environment: saturated orange around 0.7,
// gold around 0.9 instead of washed-out peach and cream).
vec3 fx_heat_color(float t) {
	t = clamp(t, 0.0, 1.0);
	vec3 c = mix(vec3(0.5, 0.01, 0.0), vec3(1.0, 0.04, 0.0), smoothstep(0.0, 0.35, t));
	c = mix(c, vec3(1.0, 0.12, 0.0), smoothstep(0.3, 0.6, t));
	c = mix(c, vec3(1.0, 0.3, 0.0), smoothstep(0.55, 0.85, t));
	return mix(c, vec3(1.0, 0.62, 0.08), smoothstep(0.82, 1.0, t));
}

// HDR energy that goes with fx_heat_color: invisible when cold, blooming when hot.
// Kept moderate because AgX bleaches bright colours towards white.
float fx_heat_energy(float t) {
	t = clamp(t, 0.0, 1.0);
	return smoothstep(0.04, 0.22, t) * (0.3 + 0.8 * t + 0.4 * t * t * t);
}
