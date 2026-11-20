// A photo scan (Poly Haven, CC0, see CREDITS.md) laid over a designed surface in object space, from
// three sides, so it travels with the part: for clay and sand, whose colours and marks (glaze, soot,
// furrows, stamps) the shader draws because they change with the work, while the grain is real.
// `p`: object-space position divided by the size the scan is laid on at; `n`: unit object-space
// normal; `mean`: the scan's mean colour. Returns how bright the scan is there against its own
// average (1 = average) and, in `bumped`, the normal with the scan's relief (object space).
float station_scan(sampler2D d, sampler2D nm, vec3 p, vec3 n, vec3 mean, out vec3 bumped) {
	vec3 w = pow(abs(n), vec3(8.0));
	w /= w.x + w.y + w.z;
	// V runs down the image: turned over, the scan stands upright.
	vec2 ux = vec2(p.z, -p.y);
	vec2 uy = vec2(p.x, -p.z);
	vec2 uz = vec2(p.x, -p.y);
	vec3 col = texture(d, ux).rgb * w.x + texture(d, uy).rgb * w.y + texture(d, uz).rgb * w.z;
	vec3 tx = texture(nm, ux).xyz * 2.0 - 1.0;
	vec3 ty = texture(nm, uy).xyz * 2.0 - 1.0;
	vec3 tz = texture(nm, uz).xyz * 2.0 - 1.0;
	bumped = normalize(vec3(tx.xy + n.zy, abs(tx.z) * n.x).zyx * w.x
		+ vec3(ty.xy + n.xz, abs(ty.z) * n.y).xzy * w.y
		+ vec3(tz.xy + n.xy, abs(tz.z) * n.z) * w.z);
	return clamp(dot(col, vec3(0.2126, 0.7152, 0.0722)) / max(dot(mean, vec3(0.2126, 0.7152, 0.0722)), 0.01), 0.45, 1.7);
}
