// Short-cropped hair on the back of the worker's head, under the hard hat.
// The mesh (WorkerGear.hair_mesh) is the KayKit head's back half lifted off the
// skin, in the rig's rest space; the hairline is cut here so it stays smooth on
// the low-poly head: a nape that rises towards the ears, a small tuft zigzag,
// and nothing on the sides around the ears.
shader_type spatial;
render_mode diffuse_lambert_wrap, specular_schlick_ggx;

uniform vec3 hair_color : source_color = vec3(0.36, 0.24, 0.16);
uniform float roughness_value : hint_range(0.0, 1.0) = 0.85;

varying vec3 rest;

void vertex() {
	rest = VERTEX;
}

void fragment() {
	float around = atan(rest.x, -rest.z);
	float back = clamp(-rest.z / 0.45, 0.0, 1.0);
	float nape = mix(1.6, 1.43, back * back) + 0.022 * abs(sin(around * 9.0));
	// Behind the ears only: the sides stay skin from the temple down.
	float ear_side = step(0.4, abs(rest.x)) * step(-0.22, rest.z);
	if (rest.y < nape || rest.z > -0.02 || ear_side > 0.5) {
		discard;
	}
	// Combed strands: fine vertical streaks and a darker underside.
	float strands = 0.5 + 0.5 * sin(around * 70.0 + sin(rest.y * 40.0) * 0.6);
	float shade = mix(0.72, 1.0, smoothstep(nape, nape + 0.12, rest.y));
	ALBEDO = hair_color * shade * (0.9 + 0.14 * strands);
	ROUGHNESS = roughness_value;
	SPECULAR = 0.3;
	RIM = 0.15;
	RIM_TINT = 0.5;
}
