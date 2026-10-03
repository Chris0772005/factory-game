class_name FoundryRules
## Grading, alloy mixing and prices. Pure functions, shared by all stations.

const GRADES := [
	{min = 0.0, name = "Schrott", mult = 0.3, color = Color("#9a8f86")},
	{min = 0.35, name = "Gut", mult = 1.0, color = Color("#e8e0d0")},
	{min = 0.6, name = "Fein", mult = 1.5, color = Color("#7fd3a8")},
	{min = 0.8, name = "Makellos", mult = 2.2, color = Color("#6fb8ff")},
	{min = 0.95, name = "Spiegelguss", mult = 4.0, color = Color("#ffd75e")},
]

## Scrap kinds: metal they add and how much (litres of melt).
const SCRAP := {
	&"scrap_can": {metal = &"alu", amount = 0.35, name = "Dose", color = Color("#c9d3dc"), size = Vector3(0.14, 0.24, 0.14)},
	&"scrap_key": {metal = &"zinc_brass", amount = 0.25, name = "Schlüssel", color = Color("#d9b44a"), size = Vector3(0.2, 0.05, 0.1)},
	&"scrap_pipe": {metal = &"copper", amount = 0.5, name = "Kupferrohr", color = Color("#c8763f"), size = Vector3(0.5, 0.09, 0.09)},
	&"scrap_ring": {metal = &"gold", amount = 0.1, name = "Omas Ring", color = Color("#ffcf3f"), size = Vector3(0.09, 0.03, 0.09)},
}

## Base price per square metre of relief before alloy and grade multipliers.
const PRICE_PER_M2 := 420.0


## Overall quality 0..1 from the steps the players controlled.
static func score(ram_quality: float, fill_ratio: float, defects: Dictionary) -> float:
	var s := 0.3 * clampf(ram_quality, 0.0, 1.0) + 0.4 * clampf(fill_ratio, 0.0, 1.0) + 0.3
	s -= 0.18 * defects.get("spatter", 0.0)
	s -= 0.25 * defects.get("cold_shut", 0.0)
	s -= 0.2 * defects.get("misrun", 0.0)
	s -= 0.1 * defects.get("flash", 0.0)
	if fill_ratio < 0.9:
		s -= (0.9 - fill_ratio) * 0.8
	return clampf(s, 0.0, 1.0)


static func grade(s: float) -> Dictionary:
	var g: Dictionary = GRADES[0]
	for candidate in GRADES:
		if s >= candidate.min:
			g = candidate
	return g


## Total defect strength 0..1 for the metal shader.
static func defect_amount(defects: Dictionary) -> float:
	var total := 0.0
	for k in defects:
		total += defects[k]
	return clampf(total * 0.6, 0.0, 1.0)


## Which alloy a melt of the given composition (metal -> litres) makes.
static func alloy_for(mix: Dictionary) -> StringName:
	var total := 0.0
	for k in mix:
		total += mix[k]
	if total <= 0.0:
		return &"alu"
	var share := func(k): return mix.get(k, 0.0) / total
	var gold: float = share.call(&"gold")
	var copper: float = share.call(&"copper")
	var zinc: float = share.call(&"zinc_brass")
	if gold >= 0.3:
		return &"gold"
	if gold >= 0.06 and copper + zinc >= 0.3:
		return &"rotgold"
	if copper + zinc >= 0.5:
		return &"brass" if zinc > copper else &"bronze"
	if share.call(&"iron") >= 0.5:
		return &"iron"
	return &"alu"


static func price(area_m2: float, alloy: StringName, s: float) -> int:
	var alloy_mult: float = Alloys.TABLE.get(alloy, {}).get("value_mult", 1.0)
	return maxi(1, roundi(area_m2 * PRICE_PER_M2 * alloy_mult * grade(s).mult))
