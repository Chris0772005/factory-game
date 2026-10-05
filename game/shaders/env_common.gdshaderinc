// Shared helpers for the environment shaders (ground, grass, foliage, wood,
// plaster, sky): cheap 2D value noise, fbm, Voronoi, a bump helper and the
// lawn colour, so grass blades and the ground under them agree.

float env_hash12(vec2 p) {
	vec3 p3 = fract(vec3(p.xyx) * 0.1031);
	p3 += dot(p3, p3.yzx + 33.33);
	return fract((p3.x + p3.y) * p3.z);
}

vec2 env_hash22(vec2 p) {
	vec3 p3 = fract(vec3(p.xyx) * vec3(0.1031, 0.1030, 0.0973));
	p3 += dot(p3, p3.yzx + 33.33);
	return fract((p3.xx + p3.yz) * p3.zy);
}

float env_hash13(vec3 p) {
	p = fract(p * 0.1031);
	p += dot(p, p.zyx + 31.32);
	return fract((p.x + p.y) * p.z);
}

// Smooth value noise in [0, 1].
float env_noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	vec2 u = f * f * (3.0 - 2.0 * f);
	float a = env_hash12(i);
	float b = env_hash12(i + vec2(1.0, 0.0));
	float c = env_hash12(i + vec2(0.0, 1.0));
	float d = env_hash12(i + vec2(1.0, 1.0));
	return mix(mix(a, b, u.x), mix(c, d, u.x), u.y);
}

// Three octaves, roughly in [0, 1].
float env_fbm(vec2 p) {
	return env_noise(p) * 0.5 + env_noise(p * 2.03 + 17.1) * 0.3 + env_noise(p * 4.07 + 41.7) * 0.2;
}

// Voronoi: x = distance to the nearest feature point, y = random id of its cell,
// z = distance to the second nearest (z - x is small on cell borders).
vec3 env_voronoi(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	float d1 = 8.0;
	float d2 = 8.0;
	float id = 0.0;
	for (int y = -1; y <= 1; y++) {
		for (int x = -1; x <= 1; x++) {
			vec2 g = vec2(float(x), float(y));
			vec2 o = env_hash22(i + g);
			vec2 r = g + o - f;
			float d = dot(r, r);
			if (d < d1) {
				d2 = d1;
				d1 = d;
				id = env_hash12(i + g + 13.7);
			} else if (d < d2) {
				d2 = d;
			}
		}
	}
	return vec3(sqrt(d1), id, sqrt(d2));
}

// Bump mapping without tangents (Mikkelsen, "Bump Mapping Unparametrized
// Surfaces on the GPU"): tilts the view-space normal by the screen-space
// slope of the height `h`.
vec3 env_bump(vec3 view_pos, vec3 n, float h, float strength) {
	vec3 dpdx = dFdx(view_pos);
	vec3 dpdy = dFdy(view_pos);
	vec3 r1 = cross(dpdy, n);
	vec3 r2 = cross(n, dpdx);
	float det = dot(dpdx, r1);
	vec3 grad = sign(det) * (dFdx(h) * r1 + dFdy(h) * r2) * strength;
	vec3 r = normalize(abs(det) * n - grad);
	// Limit the tilt (~20 deg): across geometric edges the screen-space slope
	// explodes, and wild normals there would make the ink outline pass draw
	// dotted lines along every edge.
	vec3 t = r - n * dot(r, n);
	float len = length(t);
	if (len > 0.34) {
		t *= 0.34 / len;
		len = 0.34;
	}
	if (dot(r, n) < 0.0 || !(len == len)) {
		return n;
	}
	return normalize(n * sqrt(1.0 - len * len) + t);
}

// Lawn colour at a world position: large light/dark patches plus darker clumps.
// The ground and the grass tufts both call it, so blades melt into the turf.
vec3 env_lawn(vec2 xz, vec3 dark, vec3 mid, vec3 light) {
	float big = env_fbm(xz * 0.21);
	float clump = env_fbm(xz * 1.15 + 5.0);
	vec3 c = mix(mid, light, smoothstep(0.36, 0.7, big));
	c = mix(c, dark, smoothstep(0.5, 0.78, clump) * 0.45);
	// Faint sun-dried streaks.
	float dry = smoothstep(0.62, 0.8, env_fbm(xz * 0.5 + 31.0));
	return mix(c, c * vec3(1.12, 1.06, 0.82), dry * 0.5);
}

// String-light sway (0.4 Hz): world offset of a point at fraction `t` along a
// span; the ends stay put, the middle swings along `perp` (horizontal unit
// vector across the span) and lifts a little at both extremes.
vec3 env_string_sway(float time, float t, float phase, vec2 perp, float amp) {
	float s = sin(time * 2.513 + phase) * amp * sin(3.14159 * clamp(t, 0.0, 1.0));
	return vec3(perp.x * s, -abs(s) * 0.25, perp.y * s);
}
