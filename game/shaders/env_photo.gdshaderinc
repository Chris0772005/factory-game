// Photo detail for the procedural surfaces: CC0 scans from Poly Haven
// (assets/textures/pbr, see CREDITS.md) laid over the designed colours.
// The scan is projected from three sides in world (or object) space, so no
// UVs are needed. Its colour only modulates the surface around the scan's
// own average, which keeps every hand-picked tint; its normal map and
// roughness add the real grain, pores and scratches.
global uniform sampler2D ph_concrete_d : source_color, repeat_enable, filter_linear_mipmap_anisotropic;
global uniform sampler2D ph_concrete_n : repeat_enable, filter_linear_mipmap_anisotropic;
global uniform sampler2D ph_concrete_arm : repeat_enable, filter_linear_mipmap_anisotropic;
global uniform sampler2D ph_plaster_d : source_color, repeat_enable, filter_linear_mipmap_anisotropic;
global uniform sampler2D ph_plaster_n : repeat_enable, filter_linear_mipmap_anisotropic;
global uniform sampler2D ph_plaster_arm : repeat_enable, filter_linear_mipmap_anisotropic;
global uniform sampler2D ph_wood_d : source_color, repeat_enable, filter_linear_mipmap_anisotropic;
global uniform sampler2D ph_wood_n : repeat_enable, filter_linear_mipmap_anisotropic;
global uniform sampler2D ph_wood_arm : repeat_enable, filter_linear_mipmap_anisotropic;
global uniform sampler2D ph_metal_d : source_color, repeat_enable, filter_linear_mipmap_anisotropic;
global uniform sampler2D ph_metal_n : repeat_enable, filter_linear_mipmap_anisotropic;
global uniform sampler2D ph_metal_arm : repeat_enable, filter_linear_mipmap_anisotropic;
global uniform sampler2D ph_dirt_d : source_color, repeat_enable, filter_linear_mipmap_anisotropic;
global uniform sampler2D ph_dirt_n : repeat_enable, filter_linear_mipmap_anisotropic;
global uniform sampler2D ph_dirt_arm : repeat_enable, filter_linear_mipmap_anisotropic;
// 0 switches the photo detail off (low quality), 1 is full strength.
global uniform float photo_detail;

// `p`: position the scan is anchored to (world for sets, object for things
// that move). `n`: unit normal in the same space. `tiles`: repeats per metre.
// Updates albedo and roughness in place and returns the detailed normal
// (same space as `n`).
vec3 env_photo(sampler2D d, sampler2D nm, sampler2D arm, vec3 p, vec3 n, float tiles, float strength, inout vec3 albedo, inout float rough) {
	float k = strength * photo_detail;
	if (k <= 0.001) {
		return n;
	}
	vec3 w = pow(abs(n), vec3(6.0));
	w /= w.x + w.y + w.z;
	vec2 ux = p.zy * tiles;
	vec2 uy = p.xz * tiles;
	vec2 uz = p.xy * tiles;
	vec3 col = texture(d, ux).rgb * w.x + texture(d, uy).rgb * w.y + texture(d, uz).rgb * w.z;
	vec3 mean = textureLod(d, vec2(0.5), 10.0).rgb + 0.02;
	vec3 orm = texture(arm, ux).rgb * w.x + texture(arm, uy).rgb * w.y + texture(arm, uz).rgb * w.z;
	albedo *= mix(vec3(1.0), clamp(col / mean, 0.35, 1.9), k);
	albedo *= mix(1.0, orm.r, 0.7 * k);
	float mean_r = textureLod(arm, vec2(0.5), 10.0).g;
	rough = clamp(rough + (orm.g - mean_r) * 0.9 * k, 0.04, 1.0);
	vec3 tx = texture(nm, ux).xyz * 2.0 - 1.0;
	vec3 ty = texture(nm, uy).xyz * 2.0 - 1.0;
	vec3 tz = texture(nm, uz).xyz * 2.0 - 1.0;
	tx = vec3(tx.xy * k + n.zy, abs(tx.z) * n.x);
	ty = vec3(ty.xy * k + n.xz, abs(ty.z) * n.y);
	tz = vec3(tz.xy * k + n.xy, abs(tz.z) * n.z);
	return normalize(tx.zyx * w.x + ty.xzy * w.y + tz.xyz * w.z);
}

// The same for surfaces shaded in view space: `view_n` is NORMAL (after any
// bump), `wpos` the world position. Returns the new view-space normal.
vec3 env_photo_world(sampler2D d, sampler2D nm, sampler2D arm, vec3 wpos, vec3 view_n, mat4 inv_view, mat4 view, float tiles, float strength, inout vec3 albedo, inout float rough) {
	vec3 wn = normalize((inv_view * vec4(view_n, 0.0)).xyz);
	vec3 res = env_photo(d, nm, arm, wpos, wn, tiles, strength, albedo, rough);
	return normalize((view * vec4(res, 0.0)).xyz);
}

// For things that move (tools, crates, machines): anchored to the object,
// so the grain travels with it. `opos` is the object-space position.
vec3 env_photo_object(sampler2D d, sampler2D nm, sampler2D arm, vec3 opos, vec3 view_n, mat4 inv_view, mat4 view, mat4 model, float tiles, float strength, inout vec3 albedo, inout float rough) {
	vec3 wn = normalize((inv_view * vec4(view_n, 0.0)).xyz);
	mat3 m = mat3(model);
	vec3 on = normalize(transpose(m) * wn);
	vec3 res = env_photo(d, nm, arm, opos, on, tiles, strength, albedo, rough);
	return normalize((view * vec4(normalize(m * res), 0.0)).xyz);
}
