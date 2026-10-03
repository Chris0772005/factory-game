class_name Alloys
## Castable alloys: display name, look and sale value multiplier.
## Optional `patina` (0..1) adds green verdigris patches over the base metal.

const TABLE := {
	&"alu": {name = "Aluminium", color = Color("#d3d7dd"), roughness = 0.3, value_mult = 1.0},
	&"brass": {name = "Messing", color = Color("#efc95c"), roughness = 0.22, value_mult = 1.6},
	&"bronze": {name = "Bronze", color = Color("#c98a55"), roughness = 0.3, value_mult = 2.0},
	&"iron": {name = "Eisen", color = Color("#6b6e74"), roughness = 0.48, value_mult = 0.8},
	&"gold": {name = "Gold", color = Color("#ffb52e"), roughness = 0.16, value_mult = 8.0},
	&"rotgold": {name = "Rotgold", color = Color("#f0a98e"), roughness = 0.2, value_mult = 6.0},
	&"verdigris": {name = "Grünspan", color = Color("#c08a58"), roughness = 0.32, value_mult = 2.5, patina = 0.5},
}
const DEFAULT := &"alu"


static func has(alloy_id: StringName) -> bool:
	return TABLE.has(alloy_id)


## Entry for `alloy_id`; falls back to aluminium for unknown ids.
static func get_alloy(alloy_id: StringName) -> Dictionary:
	return TABLE.get(alloy_id, TABLE[DEFAULT])


static func display_name(alloy_id: StringName) -> String:
	return get_alloy(alloy_id).name


static func value_mult(alloy_id: StringName) -> float:
	return get_alloy(alloy_id).value_mult


static func ids() -> Array[StringName]:
	var out: Array[StringName] = []
	for id in TABLE:
		out.append(id)
	return out
