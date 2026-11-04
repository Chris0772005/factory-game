// Dollhouse cutaway: a set piece between the camera and the local worker
// dissolves in a soft dithered circle around the line of sight, so interiors
// (the garage) stay readable from the orbit camera. CameraRig feeds the target
// (xyz = worker chest, w = radius in metres; w <= 0 disables it).
global uniform vec4 cutaway_target;

// Per-pixel dither threshold 0..1 (interleaved gradient noise, no arrays).
float env_dither(vec2 frag) {
	return fract(52.9829189 * fract(dot(frag, vec2(0.06711056, 0.00583715))));
}

// Call from fragment() with the fragment's world position.
void env_cutaway(vec3 world, vec3 cam, vec2 frag) {
	float r = cutaway_target.w;
	if (r <= 0.0) {
		return;
	}
	vec3 to_t = cutaway_target.xyz - cam;
	float len = length(to_t);
	vec3 d = to_t / max(len, 0.001);
	vec3 rel = world - cam;
	float t = dot(rel, d);
	float perp = length(rel - d * t);
	float fade = (1.0 - smoothstep(r * 0.8, r, perp)) * (1.0 - smoothstep(len - 1.4, len - 0.5, t));
	if (fade > env_dither(frag)) {
		discard;
	}
}
