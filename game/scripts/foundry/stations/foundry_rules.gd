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
	&"scrap_kettle": {metal = &"copper", amount = 1.2, name = "Kupferkessel", color = Color("#b8652f"), size = Vector3(0.3, 0.26, 0.3)},
	&"scrap_tooth": {metal = &"gold", amount = 0.05, name = "Goldzahn", color = Color("#ffd75e"), size = Vector3(0.06, 0.07, 0.06)},
	&"scrap_ring": {metal = &"gold", amount = 0.1, name = "Omas Ring", color = Color("#ffcf3f"), size = Vector3(0.09, 0.03, 0.09)},
	&"scrap_trophy": {metal = &"zinc_brass", amount = 0.8, name = "Alter Pokal", color = Color("#e2bd4f"), size = Vector3(0.16, 0.26, 0.16)},
	&"scrap_candle": {metal = &"zinc_brass", amount = 0.6, name = "Kerzenständer", color = Color("#d4ae48"), size = Vector3(0.13, 0.24, 0.13)},
	&"scrap_coin": {metal = &"gold", amount = 0.04, name = "Goldmünze", color = Color("#ffd24a"), size = Vector3(0.07, 0.02, 0.07)},
	&"scrap_bikebell": {metal = &"zinc_brass", amount = 0.3, name = "Fahrradklingel", color = Color("#dfe3e8"), size = Vector3(0.1, 0.07, 0.1)},
}

## Worthless-looking junk from the big scrap heap: no metal for the furnace,
## but the scrap dealer pays a little for it by the bucket.
const JUNK := {
	&"junk_sheet": {name = "Altblech", color = Color("#8a6f5c"), size = Vector3(0.3, 0.05, 0.22), price = 2},
	&"junk_gear": {name = "Zahnrad", color = Color("#6d6660"), size = Vector3(0.18, 0.06, 0.18), price = 3},
	&"junk_bolt": {name = "Schrauben", color = Color("#7c7772"), size = Vector3(0.12, 0.08, 0.12), price = 1},
	&"junk_spring": {name = "Sprungfeder", color = Color("#75604f"), size = Vector3(0.12, 0.2, 0.12), price = 2},
}
## What the scrap dealer pays for raw finds (casting them first pays far more).
const RAW_PRICES := {&"scrap_can": 2, &"scrap_key": 3, &"scrap_pipe": 5, &"scrap_kettle": 12, &"scrap_tooth": 15, &"scrap_ring": 25,
	&"scrap_trophy": 9, &"scrap_candle": 7, &"scrap_coin": 20, &"scrap_bikebell": 4}


## Hot goods: things somebody hid in the scrap. Kowalski will not touch them.
## The pawnbroker pays `black` under the counter (and the police take notice);
## the police station pays `reward` for handing them in. weight = how often.
const HOT := {
	&"hot_plates": {name = "Geklaute Kennzeichen", color = Color("#d9d4c0"), size = Vector3(0.34, 0.03, 0.12), black = 30, reward = 6, weight = 40},
	&"hot_cashbox": {name = "Aufgebrochene Geldkassette", color = Color("#56664f"), size = Vector3(0.26, 0.1, 0.18), black = 55, reward = 10, weight = 30},
	&"hot_pistol": {name = "Alte Pistole", color = Color("#34373c"), size = Vector3(0.2, 0.13, 0.04), black = 85, reward = 15, weight = 20},
	&"hot_jewels": {name = "Schmuck aus einem Einbruch", color = Color("#e8c66a"), size = Vector3(0.16, 0.08, 0.12), black = 130, reward = 22, weight = 10},
}


## Name, colour and size of a raw find (scrap, junk or hot goods); empty if `kind` is none of them.
static func find_info(kind: StringName) -> Dictionary:
	if SCRAP.has(kind):
		return SCRAP[kind]
	if HOT.has(kind):
		return HOT[kind]
	return JUNK.get(kind, {})


static func is_hot(kind: StringName) -> bool:
	return HOT.has(kind)


## What the pawnbroker pays under the counter for one piece of hot goods.
static func black_price(kind: StringName) -> int:
	return HOT[kind].black if HOT.has(kind) else 0


## What the police pay for handing one piece in.
static func finder_reward(kind: StringName) -> int:
	return HOT[kind].reward if HOT.has(kind) else 0


## Random hot find (weights above).
static func roll_hot() -> StringName:
	var total := 0
	for k in HOT:
		total += int(HOT[k].weight)
	var r := randi() % total
	for k in HOT:
		r -= int(HOT[k].weight)
		if r < 0:
			return k
	return &"hot_plates"


## What the scrap dealer pays for one raw find.
static func raw_price(kind: StringName) -> int:
	if JUNK.has(kind):
		return JUNK[kind].price
	return RAW_PRICES.get(kind, 0)


## Sealed crates (garage): unknown mixes, revealed only by the casting.
## weight = relative chance; mix = metal -> litres.
const CRATES := {
	&"cable": {name = "Kupferkabel", weight = 30, mix = {&"copper": 1.3}},
	&"fittings": {name = "Messingbeschläge", weight = 28, mix = {&"zinc_brass": 0.9, &"copper": 0.4}},
	&"roof": {name = "Kirchendach-Kupfer", weight = 18, mix = {&"patina_copper": 1.2, &"copper": 0.2}},
	&"watchmaker": {name = "Uhrmacher-Nachlass", weight = 14, mix = {&"copper": 0.8, &"zinc_brass": 0.3, &"gold": 0.15}},
	&"jewellery": {name = "Omas Schmuckkästchen", weight = 3, mix = {&"gold": 0.5, &"copper": 0.2}},
	&"hubcaps": {name = "Alte Radkappen", weight = 7, mix = {&"alu": 1.4}},
}
## Price of one sealed crate.
const CRATE_PRICE := 30


## Crate price in `world` (the scrapyard-regular upgrade makes it cheaper).
static func crate_price(world: GameWorld) -> int:
	return 20 if world and world.has_upgrade(&"scrapyard_regular") else CRATE_PRICE


## Random crate contents id (weights above).
static func roll_crate() -> StringName:
	var total := 0
	for k in CRATES:
		total += int(CRATES[k].weight)
	var r := randi() % total
	for k in CRATES:
		r -= int(CRATES[k].weight)
		if r < 0:
			return k
	return &"cable"


## Base price per square metre of relief before alloy and grade multipliers.
const PRICE_PER_M2 := 420.0


## Overall quality 0..1 from the steps the players controlled.
static func score(ram_quality: float, fill_ratio: float, defects: Dictionary) -> float:
	var s := 0.3 * clampf(ram_quality, 0.0, 1.0) + 0.4 * clampf(fill_ratio, 0.0, 1.0) + 0.3
	s -= 0.18 * defects.get("spatter", 0.0)
	s -= 0.25 * defects.get("cold_shut", 0.0)
	s -= 0.2 * defects.get("misrun", 0.0)
	s -= 0.1 * defects.get("flash", 0.0)
	# Quenched while too hot (MoldBox.quench).
	s -= 0.3 * defects.get("crack", 0.0)
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
	var copper: float = share.call(&"copper") + share.call(&"patina_copper")
	var zinc: float = share.call(&"zinc_brass")
	if gold >= 0.3:
		return &"gold"
	if share.call(&"patina_copper") >= 0.4:
		return &"verdigris"
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
