shader_type spatial;
// Dust and mud over a vehicle or machine, drawn as an overlay on all its surfaces
// (GeometryInstance3D.material_overlay, see VehicleFinish). Mud is caked on low down, breaks up
// towards the top of its zone and is thrown higher in splashes; a thin film of dust lies on what
// faces up. Between them the paint stays clean and keeps its gloss. The pattern lives in each
// part's own frame, so it stays put when the part moves.
// Reference: the working machines in Construction Simulator (TECH_SPEC Modul Y).
render_mode blend_mix, depth_draw_never, cull_back, diffuse_burley, specular_schlick_ggx;

uniform vec3 mud_color : source_color = vec3(0.40, 0.29, 0.20);
uniform vec3 mud_dry_color : source_color = vec3(0.60, 0.49, 0.37);
uniform vec3 dust_color : source_color = vec3(0.68, 0.60, 0.49);
// World height of the ground under the machine and the height of the caked zone (m).
uniform float ground = 0.0;
uniform float mud_height = 1.25;
uniform float amount : hint_range(0.0, 1.0) = 0.75;
uniform float dust : hint_range(0.0, 1.0) = 0.35;
uniform float scale = 1.0;

varying vec3 part_pos;
varying vec3 world_pos;
varying vec3 world_normal;

float hash(vec3 p) {
	p = fract(p * vec3(0.1031, 0.1030, 0.0973));
	p += dot(p, p.yxz + 33.33);
	return fract((p.x + p.y) * p.z);
}

float noise(vec3 p) {
	vec3 i = floor(p);
	vec3 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(mix(hash(i), hash(i + vec3(1, 0, 0)), f.x), mix(hash(i + vec3(0, 1, 0)), hash(i + vec3(1, 1, 0)), f.x), f.y),
		mix(mix(hash(i + vec3(0, 0, 1)), hash(i + vec3(1, 0, 1)), f.x), mix(hash(i + vec3(0, 1, 1)), hash(i + vec3(1, 1, 1)), f.x), f.y), f.z);
}

float fbm(vec3 p, int octaves) {
	float v = 0.0;
	float a = 0.5;
	float total = 0.0;
	for (int i = 0; i < octaves; i++) {
		v += a * noise(p);
		total += a;
		p = p * 2.03 + vec3(11.7, 3.1, 7.3);
		a *= 0.5;
	}
	return v / total;
}

void vertex() {
	part_pos = VERTEX;
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	world_normal = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
}

void fragment() {
	// The parts differ in size and scale: measure the pattern in metres.
	float metres = length(MODEL_MATRIX[0].xyz);
	vec3 p = part_pos * metres * scale;
	// Bend the lattice of the noise away, so the patches have no straight edges.
	vec3 q = p + 0.22 * (vec3(noise(p * 2.3 + 17.0), noise(p * 2.3 + 41.0), noise(p * 2.3 + 73.0)) - 0.5);
	float broad = fbm(q * 1.4, 3);
	float mid = fbm(q * 4.5 + 3.7, 3);
	float fine = fbm(q * 19.0 + 9.1, 3);
	// Thrown-up mud runs down: the splashes are drawn out along the vertical.
	float streak = fbm(vec3(world_pos.x - ground, world_pos.y * 0.22, world_pos.z) * 9.0 + q * 3.0, 3);
	// 0 at the ground, 1 at the top of the caked zone.
	float h = (world_pos.y - ground) / max(mud_height, 0.01);
	float caked = 1.0 - smoothstep(0.25, 1.0, h + (broad - 0.5) * 1.0 + (mid - 0.5) * 0.5 + (fine - 0.5) * 0.3);
	float reach = 1.0 - smoothstep(0.6, 2.4, h + (broad - 0.5) * 0.9);
	float splash = smoothstep(0.56, 0.7, streak * 0.55 + fine * 0.45) * reach;
	float mud = clamp(max(caked, splash * 0.9), 0.0, 1.0) * smoothstep(0.0, 0.5, amount) * mix(0.55, 1.0, amount);
	// Thin dust in soft patches, mostly on what faces up.
	float up = smoothstep(-0.2, 0.9, world_normal.y);
	float film = dust * (0.06 + 0.5 * up) * smoothstep(0.25, 0.75, broad * 0.6 + mid * 0.4);
	vec3 mud_tone = mix(mud_color, mud_dry_color, smoothstep(0.38, 0.68, mid)) * (0.8 + 0.4 * fine);
	float cover = max(mud, film);
	ALBEDO = mix(dust_color, mud_tone, mud / max(mud + film, 0.001));
	ALPHA = clamp(cover, 0.0, 0.97);
	ROUGHNESS = 0.95;
	SPECULAR = 0.12;
	METALLIC = 0.0;
	// Caked mud is lumpy: bump the surface by the pattern (Mikkelsen, unparametrised surfaces).
	float height = (mid * 0.5 + fine * 0.5) * mud;
	vec3 dpdx = dFdx(VERTEX);
	vec3 dpdy = dFdy(VERTEX);
	vec3 r1 = cross(dpdy, NORMAL);
	vec3 r2 = cross(NORMAL, dpdx);
	float det = dot(dpdx, r1);
	vec3 grad = sign(det) * (dFdx(height) * r1 + dFdy(height) * r2);
	NORMAL = normalize(abs(det) * NORMAL - 0.03 * grad);
}
