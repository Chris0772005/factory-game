shader_type spatial;
// Cast metal uber shader: PBR alloy, blackbody glow with a cooling crust,
// liquid surface when hot, fill cut with glowing meniscus and casting defects.
// Everything is driven by object-space position (procedural meshes have no UVs).
render_mode cull_disabled;

#include "res://shaders/fx_common.gdshaderinc"

uniform vec4 base_color : source_color = vec4(0.8, 0.81, 0.84, 1.0);
uniform float roughness : hint_range(0.0, 1.0) = 0.3;
uniform float metallic : hint_range(0.0, 1.0) = 1.0;
/// 0 cold, 0.3 dark red, 0.6 orange, 1 white-hot liquid.
uniform float temperature : hint_range(0.0, 1.0) = 0.0;
uniform float glow_scale = 1.0;
/// Brightness of the stylised studio reflection that replaces the sky reflection,
/// so alloys keep their hue under a blue sky and still shine in dark rooms.
uniform float env_brightness = 1.0;
/// Fragments above this object-space Y are cut away when use_fill is on.
uniform float fill_level = 0.0;
uniform bool use_fill = false;
uniform float meniscus_width = 0.03;
uniform float defect_amount : hint_range(0.0, 1.0) = 0.0;
uniform vec4 patina_color : source_color = vec4(0.33, 0.62, 0.5, 1.0);
uniform float patina_amount : hint_range(0.0, 1.0) = 0.0;
/// Per-piece offset so pieces of the same alloy do not share their noise.
uniform vec3 noise_seed = vec3(0.0);

varying vec3 obj_pos;
varying vec3 cam_pos;

void vertex() {
	// While filling, shrink a hair so the interior (drawn as the liquid top)
	// never z-fights with a mold floor or table the piece rests on.
	if (use_fill) {
		VERTEX -= NORMAL * 0.003;
	}
	obj_pos = VERTEX;
	cam_pos = (inverse(MODEL_MATRIX) * vec4(CAMERA_POSITION_WORLD, 1.0)).xyz;
}

// Object-space gradient of animated noise, used to ripple the liquid surface.
vec3 ripple(vec3 q) {
	float e = 0.05;
	float n0 = fx_noise(q);
	return vec3(fx_noise(q + vec3(e, 0.0, 0.0)) - n0, fx_noise(q + vec3(0.0, e, 0.0)) - n0, fx_noise(q + vec3(0.0, 0.0, e)) - n0) / e;
}

// Neutral softbox environment: dark floor, light grey ceiling and a bright
// warm band at the horizon that draws highlights along edges and bevels.
vec3 studio_env(vec3 r, float rough) {
	float soft = mix(0.06, 0.6, rough);
	vec3 c = mix(vec3(0.14, 0.12, 0.1), vec3(0.6, 0.6, 0.62), smoothstep(-soft, soft, r.y - 0.05));
	float band = exp(-pow((r.y - 0.15) / (0.07 + 0.5 * rough), 2.0));
	return c + vec3(1.0, 0.93, 0.82) * band * (1.1 - 0.7 * rough);
}

void fragment() {
	vec3 p = obj_pos + noise_seed;
	float t = temperature;
	bool cap = false;
	float rim = 0.0;
	if (use_fill) {
		float cut = fill_level + (fx_noise(vec3(p.xz * 14.0, TIME * 1.3)) - 0.5) * 0.008;
		if (obj_pos.y > cut) {
			discard;
		}
		rim = 1.0 - smoothstep(0.0, meniscus_width, cut - obj_pos.y);
		t = max(t, 0.72);
		// Back faces seen through the cut stand in for the liquid surface. Their
		// patterns are sampled where the view ray crosses the fill plane so the
		// hollow interior reads as a flat top (depth stays raw: writing DEPTH
		// would drop the material from the normal prepass the outlines need).
		cap = !FRONT_FACING;
		if (cap) {
			vec3 dir = obj_pos - cam_pos;
			float k = (dir.y < -1e-4 && cam_pos.y > fill_level) ? (fill_level - cam_pos.y) / dir.y : 1.0;
			p = cam_pos + dir * clamp(k, 0.0, 1.0) + noise_seed;
		}
	} else if (!FRONT_FACING) {
		discard;
	}
	float hot = smoothstep(0.04, 0.2, t);
	float liquid = cap ? 1.0 : smoothstep(0.5, 0.88, t);

	// Cast surface: broad tone variation plus fine sand grain in the roughness.
	float broad = fx_fbm(p * 4.0);
	float grain = fx_noise(p * 150.0);
	vec3 albedo = base_color.rgb * (0.94 + 0.12 * broad);
	float rough = clamp(roughness + (grain - 0.5) * 0.06 + (broad - 0.5) * 0.08, 0.04, 1.0);
	float metal = metallic;

	float patina = patina_amount * (1.0 - hot);
	if (patina > 0.0) {
		float pn = fx_fbm(p * 10.0 + 11.0);
		float m = min(patina * 2.0, 1.0) * smoothstep(0.62 - 0.25 * patina, 0.7 - 0.25 * patina, pn + (grain - 0.5) * 0.2);
		albedo = mix(albedo, patina_color.rgb * (0.8 + 0.4 * grain), m);
		metal = mix(metal, 0.1, m);
		rough = mix(rough, 0.75, m);
	}

	if (defect_amount > 0.0) {
		float d = defect_amount;
		float blotch = smoothstep(0.66 - 0.28 * d, 0.72 - 0.28 * d, fx_fbm(p * 3.5 + 37.0)) * min(d * 3.0, 1.0);
		float pits = smoothstep(0.84 - 0.2 * d, 0.89 - 0.2 * d, fx_noise(p * 48.0 + 71.0)) * min(d * 4.0, 1.0);
		albedo *= (1.0 - 0.5 * blotch) * (1.0 - 0.85 * pits);
		rough = mix(rough, 0.8, blotch);
		rough = mix(rough, 1.0, pits);
		metal = mix(metal, 0.4, pits);
	}

	vec3 emit = vec3(0.0);
	if (hot > 0.0 && !cap) {
		float drift = TIME * (0.04 + 0.3 * liquid);
		float cracks = 0.0;
		if (liquid < 1.0) {
			// Cooling: dark crust plates separated by glowing cracks.
			vec3 warp = vec3(fx_noise(p * 6.0), fx_noise(p * 6.0 + 7.0), fx_noise(p * 6.0 + 13.0)) - 0.5;
			float border = fx_cell_border(p * 8.0 + warp * 1.2 + vec3(0.0, drift, 0.0));
			cracks = 1.0 - smoothstep(0.02, 0.1 + 0.08 * t, border);
		}
		// Liquid: slow convection blotches and bright glints drifting over them.
		float flow = fx_fbm(p * 9.0 + vec3(drift, drift * 0.7, -drift * 0.4));
		// Melt: saturated orange body, drifting dark-red dross and pale glints.
		float skin = smoothstep(0.55, 0.65, flow);
		float glint = 0.0;
		if (liquid > 0.0) {
			glint = fx_glint_lines(p * vec3(7.0, 16.0, 7.0) + vec3(drift * 2.0, -drift, drift));
			glint *= smoothstep(0.38, 0.62, fx_noise(p * 3.0 + drift)) * (1.0 - skin);
		}
		float body = mix(0.15, 0.72, smoothstep(0.3, 0.75, t)) * (0.85 + 0.3 * broad);
		float mask = mix(body + (1.0 - body) * cracks, 1.0 - 0.45 * skin + 0.9 * glint, liquid);
		float heat = mix(0.85 + 0.25 * cracks, 0.82 - 0.3 * skin, liquid);
		float lt = clamp(t * heat + 0.35 * glint * liquid, 0.0, 1.0);
		emit = fx_heat_color(lt) * fx_heat_energy(lt) * mask;
		// Dark oxide scale while glowing; it burns off again once liquid.
		float scale = hot * (1.0 - liquid);
		albedo = mix(albedo, vec3(0.07, 0.055, 0.05), 0.8 * scale);
		metal = mix(metal, 0.3, scale);
		rough = mix(rough, 0.7, scale);
		rough = mix(rough, 0.08, liquid);
		albedo *= 1.0 - 0.5 * liquid;
	}

	if (cap) {
		// Liquid pool: bright melt with slowly drifting darker oxide skin.
		NORMAL = normalize((VIEW_MATRIX * vec4(MODEL_MATRIX[1].xyz, 0.0)).xyz);
		float drift = TIME * 0.12;
		float skin = smoothstep(0.55, 0.65, fx_fbm(vec3(p.xz * 8.0 + vec2(drift, -drift * 0.6), drift)));
		float glint = fx_glint_lines(vec3(p.x * 6.0 + drift * 3.0, p.z * 16.0, TIME * 0.3));
		glint *= smoothstep(0.38, 0.62, fx_noise(vec3(p.xz * 3.0, drift))) * (1.0 - skin);
		float lt = clamp(t * (0.82 - 0.3 * skin) + 0.35 * glint, 0.0, 1.0);
		emit = fx_heat_color(lt) * fx_heat_energy(lt) * (1.0 - 0.45 * skin + 0.9 * glint);
		rough = 0.06;
		// The cap is lit (and shadowed) at the hidden interior, so keep direct
		// lighting faint and let the emission carry the surface.
		albedo *= 0.12;
	}
	if (rim > 0.0) {
		float rt = min(t + 0.12, 1.0);
		emit += fx_heat_color(rt) * fx_heat_energy(rt) * rim * 0.9;
	}

	if (liquid > 0.0) {
		vec3 g = ripple(p * 10.0 + vec3(TIME * 0.5, TIME * 0.8, -TIME * 0.6));
		vec3 gv = (VIEW_MATRIX * (MODEL_MATRIX * vec4(g, 0.0))).xyz;
		NORMAL = normalize(NORMAL - gv * 0.05 * liquid);
	}

	vec3 r = (INV_VIEW_MATRIX * vec4(reflect(-VIEW, NORMAL), 0.0)).xyz;
	RADIANCE = vec4(studio_env(r, rough) * env_brightness, 1.0);

	ALBEDO = albedo;
	METALLIC = metal;
	ROUGHNESS = rough;
	EMISSION = emit * glow_scale;
}
