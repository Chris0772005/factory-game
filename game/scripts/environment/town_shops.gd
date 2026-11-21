class_name TownShops
## The two shops at the ends of the street across from the hall (ScrapHallSet): the hardware store in
## the west, where the crew buys its hand tools from the bench (ToolOffer), and the bank in the east,
## where it borrows at the counter (BankCounter). Houses, furniture and people are built here; the
## level adds what can be used. Everything that stands about is a photo scan (Poly Haven, CC0, see
## CREDITS.md) or made of scanned surfaces (graphics standard, TECH_SPEC Modul Y).

## Top of a shop counter (TownBlock.counter).
const TOP := 1.03

# --- Hardware store: places along the room, from the middle of the front (m) --------------------
## The bench with the tools on show stands against the back wall: its middle and its width.
const BENCH_X := -2.9
const BENCH_W := 4.5
## The clerk's counter: its middle, width and depth in the room; the clerk behind it.
const HW_COUNTER_X := 2.0
const HW_COUNTER_W := 6.2
const HW_COUNTER_Z := 4.2
const CLERK := Vector3(2.4, 0, 5.25)
## The tools on the bench: upgrade and place along it (ToolOffer).
const OFFERS := [[&"detector", -4.7], [&"shovel", -3.9], [&"magnet", -3.1], [&"bucket_big", -2.3], [&"gloves", -1.55]]
## Where a customer stands at the clerk's counter.
const HW_CUSTOMER := Vector3(2.4, 0, 3.3)
## What fills the shelves behind the clerk (TownBlock.shelves).
const HARDWARE_GOODS := ["spray_paint_bottles", "lubricant_spray", "metal_toolbox", "oil_tin", "measuring_tape_01@90", "propane_torch",
	"hand_plane_no4", "small_oil_can_01", "Drill_01", "trowel_01@90", "watering_can_metal_01@90", "screwdrivers_02@90", "metal_jerrycan_green",
	"combination_wrench@90", "cardboard_box_01@90"]

# --- Bank ----------------------------------------------------------------------------------------
## The two places at the counter (ScrapHallSet.COUNTER_Z deep in the room): where loans are given, and
## where the townspeople queue. The clerk stands behind the first.
const LOANS_X := -1.95
const QUEUE_X := 1.95
## Height of the glass over the counter, and of the slot under it at the two places.
const SCREEN_TOP := 2.25
const SLOT_TOP := 1.45
## The vault door in the back wall: its middle along the wall, its height, its radius.
const VAULT_X := 2.6
const VAULT_Y := 1.3
const VAULT_R := 1.0


# --- Post office (in its own frame, see post_lot) ----------------------------------------------------
## Along the front, from its middle (+x is the end towards the main street): the door. Along the
## counter (ScrapHallSet.COUNTER_Z deep in the room): where things are handed over, and behind it
## the postmistress.
const POST_DOOR_X := 3.1
const POST_HAND_X := 1.7
const POSTMISTRESS := Vector3(0.1, 0, 4.7)
## Parcels on the shelves behind the counter (TownBlock.shelves).
const POST_GOODS := ["cardboard_box_01", "cardboard_box_01@90", "book_encyclopedia_set_01", "cardboard_box_01@90", "cardboard_box_01",
	"metal_toolbox", "cardboard_box_01@90"]


## The post office's own frame: the middle of its front at the origin, +z into the house, +x along
## the front towards the main street. It stands beyond the eastern side street and looks west
## across it; everything of the post office is built and placed in this frame.
static func post_lot() -> Transform3D:
	return Transform3D(Basis(Vector3.UP, PI * 0.5), Vector3(TownStreets.FAR_X, 0, (TownStreets.POST_FROM + TownStreets.POST_TO) * 0.5))


## Where mail orders are handed over (the level puts the PostOffice there, in the house's frame).
static func post_spot() -> Transform3D:
	return post_lot() * Transform3D(Basis(), Vector3(POST_HAND_X, 0, ScrapHallSet.COUNTER_Z - 0.3))


## Where on the bench tool `index` of OFFERS lies (the level puts a ToolOffer there, turned to the room).
static func offer_spot(index: int) -> Vector3:
	return ScrapHallSet.HARDWARE + Vector3(float(OFFERS[index][1]), TOP, ScrapHallSet.HOUSE_D - TownBlock.WALL - 0.37)


## Where the loan is asked for (the level puts a BankCounter there).
static func loan_spot() -> Vector3:
	return ScrapHallSet.BANK + Vector3(LOANS_X, 0, ScrapHallSet.COUNTER_Z - 0.3)


# =====================================================================================================
# Hardware store
# =====================================================================================================

static func hardware(set: Node3D) -> void:
	var at := ScrapHallSet.HARDWARE
	var w := ScrapHallSet.SHOP_W
	var d := ScrapHallSet.HOUSE_D
	var back := d - TownBlock.WALL
	var side := w * 0.5 - TownBlock.WALL
	TownBlock.house(set, at, w, d, {key = "hardware", scan = "painted_worn_brick", door_x = 0.0, windows = [[-4.7, -1.5], [1.5, 4.7]],
		sign = "HARDWARE", sign_back = Color("#1f4a3a"), sign_color = Color("#f2c84b"), floor_scan = "wood_floor_worn",
		lining = Color("#e4dccb"), trim = Color("#1f4a3a"), lamp = Color("#ffe9c4"), storeys = 1})
	# What is solid first (colliders are wanted on a headless host too): the bench against the back wall
	# with the tools on show, the clerk's counter with its return to the bench, the shelves behind him.
	var bench_z := back - 0.37
	var wood := Color("#5a4630")
	TownBlock.counter(set, at + Vector3(BENCH_X, 0, bench_z), BENCH_W, "hardware_bench", Color("#6b5234"))
	TownBlock.counter(set, at + Vector3(HW_COUNTER_X, 0, HW_COUNTER_Z), HW_COUNTER_W, "hardware_counter", wood)
	var left := HW_COUNTER_X - HW_COUNTER_W * 0.5
	var bench_end := BENCH_X + BENCH_W * 0.5
	var from_z := HW_COUNTER_Z + 0.31
	var to_z := bench_z - 0.31
	var turn := Vector3((left + bench_end) * 0.5, 0, (from_z + to_z) * 0.5)
	var turn_size := Vector3(bench_end - left, 0.96, to_z - from_z)
	WorldBuilder.add_collider(set, turn_size + Vector3(0, 0.04, 0), Transform3D(Basis(), at + turn + Vector3(0, 0.5, 0)))
	TownBlock.shelves(set, at + Vector3(2.65, 0, back - 0.24), 4.8, "hardware_shelf", 21, HARDWARE_GOODS)
	# Along the left wall: a steel rack and shelves with stock, the ladder; by the windows what is too
	# big for a shelf.
	PhotoProp.place(set, "worn_metal_rack", at + Vector3(-side + 0.34, 0, 3.55), 90.0, true)
	PhotoProp.place(set, "steel_frame_shelves_02", at + Vector3(-side + 0.29, 0, 2.45), 90.0, true)
	PhotoProp.place(set, "ladder_sectioned_01", at + Vector3(-side + 0.16, 0, 1.55), 90.0)
	PhotoProp.place(set, "compost_bags", at + Vector3(-3.2, 0, 0.92), 180.0)
	PhotoProp.place(set, "portable_generator", at + Vector3(2.35, 0, 0.75), 200.0)
	PhotoProp.place(set, "tool_cart", at + Vector3(4.15, 0, 0.82), 180.0)
	PhotoProp.place(set, "wooden_ladder", at + Vector3(side - 0.45, 0, 1.85), -90.0)
	PhotoProp.place(set, "wooden_display_shelves_01", at + Vector3(side - 0.2, 0, 3.28), 180.0)
	PhotoProp.place(set, "wooden_bucket_02", at + Vector3(-1.9, 0, 0.8), 30.0)
	PhotoProp.place(set, "cement_bag", at + Vector3(3.2, 0, 2.2), 80.0)
	if not EnvMesh.visual():
		return
	var counter_wood := EnvMesh.wood("town_hardware_counter", {base_color = wood, grain_color = wood.darkened(0.45), weathering = 0.3, roughness_base = 0.6})
	var counter_top := EnvMesh.wood("town_hardware_counter_top", {base_color = wood.lightened(0.18), grain_color = wood.darkened(0.3), weathering = 0.5, roughness_base = 0.45})
	EnvMesh.add(set, EnvMesh.box(turn_size), counter_wood, Transform3D(Basis(), at + turn + Vector3(0, 0.48, 0)))
	EnvMesh.add(set, EnvMesh.box(Vector3(turn_size.x + 0.06, 0.06, turn_size.z + 0.04), 0.01), counter_top, Transform3D(Basis(), at + turn + Vector3(0, 1.0, 0)))
	# A shop is bright: the strips under the ceiling give light of their own.
	for x: float in [-side * 0.56, 0.0, side * 0.56]:
		var tube := OmniLight3D.new()
		tube.light_color = Color("#fff1d6")
		tube.light_energy = 0.8
		tube.omni_range = 6.5
		tube.omni_attenuation = 1.1
		tube.shadow_enabled = false
		tube.position = at + Vector3(x, TownBlock.ROOM_H - 0.5, d * 0.5 + 0.4)
		set.add_child(tube)
	# The board of perforated hardboard over the bench, and the hand tools that hang on it.
	var wall := back - 0.02
	var board := EnvMesh.wood("hardware_pegboard", {base_color = Color("#a98d63"), grain_color = Color("#8a7150"), weathering = 0.1, roughness_base = 0.8})
	EnvMesh.add(set, EnvMesh.box(Vector3(BENCH_W - 0.2, 1.3, 0.02)), board, Transform3D(Basis(), at + Vector3(BENCH_X, 1.98, wall)), false)
	var rail := EnvMesh.wood("town_trim_hardware", {})
	var rails := []
	for y: float in [1.31, 2.65]:
		rails.append(EnvMesh.piece(EnvMesh.box(Vector3(BENCH_W - 0.1, 0.05, 0.035)), Transform3D(Basis(), at + Vector3(BENCH_X, y, wall - 0.005))))
	EnvMesh.add(set, EnvMesh.merge(rails), rail, Transform3D(), false)
	var peg := wall - 0.012
	_hung(set, "handsaw_wood", at + Vector3(-2.95, 2.18, peg), 90.0)
	_hung(set, "adjustable_wrench", at + Vector3(-2.5, 2.2, peg), 0.0)
	_hung(set, "pipe_wrench", at + Vector3(-2.28, 2.1, peg), 0.0)
	_hung(set, "cross_pein_hammer", at + Vector3(-2.05, 2.2, peg), 0.0)
	_hung(set, "pliers", at + Vector3(-1.84, 2.28, peg), 0.0)
	_hung(set, "hatchet", at + Vector3(-1.62, 2.18, peg), 90.0)
	_hung(set, "crowbar_01", at + Vector3(-1.4, 1.95, peg), 90.0)
	_hung(set, "bolt_cutters_01", at + Vector3(-1.12, 1.72, peg), 0.0)
	# The long tools stand against the wall left of the bench, the hose hangs over them.
	_hung(set, "picke_dirty_01", at + Vector3(-side + 0.04, 0.0, 4.75), 0.0, 90.0, 7.0)
	_hung(set, "sledgehammer_01", at + Vector3(-side + 0.05, 0.0, 5.25), 0.0, 90.0, 6.0)
	PhotoProp.mount(set, "garden_hose_wall_mounted_01", at + Vector3(-side + 0.02, 1.75, 4.3), Vector3.RIGHT)
	# On the racks (the green one has boards at 0.42, 0.92, 1.40 and 1.89 m, the black one at 0.11,
	# 0.62, 1.13, 1.63 and 2.11 m): crates, boots, buckets and cans.
	var rack := at + Vector3(-side + 0.34, 0, 3.55)
	PhotoProp.stand(set, "plastic_crate_02", rack + Vector3(0, 0.425, 0.0), 92.0)
	PhotoProp.stand(set, "rubber_boots", rack + Vector3(0.02, 0.925, 0.0), 95.0, 0.9)
	PhotoProp.stand(set, "wooden_bucket_01", rack + Vector3(0, 1.405, -0.22), 20.0, 0.75)
	PhotoProp.stand(set, "watering_can_metal_01", rack + Vector3(0.02, 1.405, 0.2), 60.0)
	PhotoProp.stand(set, "cardboard_box_01", rack + Vector3(0, 1.895, 0.1), 5.0)
	var shelf := at + Vector3(-side + 0.29, 0, 2.45)
	PhotoProp.stand(set, "oil_tin", shelf + Vector3(0.02, 0.115, -0.14), 80.0)
	PhotoProp.stand(set, "small_oil_can_01", shelf + Vector3(0.0, 0.115, 0.12), 110.0)
	PhotoProp.stand(set, "metal_toolbox", shelf + Vector3(0, 0.625, 0.0), 88.0)
	PhotoProp.stand(set, "hand_plane_no4", shelf + Vector3(0.02, 1.135, -0.1), 60.0)
	PhotoProp.stand(set, "Drill_01", shelf + Vector3(0.0, 1.135, 0.17), 100.0)
	PhotoProp.stand(set, "spray_paint_bottles", shelf + Vector3(0.02, 1.635, 0.0), 90.0)
	PhotoProp.stand(set, "propane_tank", at + Vector3(-side + 0.3, 0, 1.95), 0.0)
	PhotoProp.stand(set, "tire_pump", at + Vector3(-side + 0.22, 0, 4.25), 90.0)
	# In the pine shelf by the right wall (boards at 0.41, 0.79 and 1.17 m, its top at 1.54 m).
	var cubes := at + Vector3(side - 0.2, 0, 3.28)
	PhotoProp.stand(set, "lubricant_spray", cubes + Vector3(-0.02, 0.795, -0.36), 250.0)
	PhotoProp.stand(set, "spray_paint_bottles", cubes + Vector3(-0.02, 0.795, 0.0), 270.0)
	PhotoProp.stand(set, "measuring_tape_01", cubes + Vector3(-0.04, 1.175, 0.36), 200.0)
	PhotoProp.stand(set, "propane_torch", cubes + Vector3(-0.02, 1.175, -0.36), 0.0)
	PhotoProp.stand(set, "oil_tin", cubes + Vector3(-0.02, 1.175, 0.0), 280.0)
	PhotoProp.stand(set, "potted_plant_04", cubes + Vector3(0, 1.545, 0.3), 30.0)
	# By the windows and on the floor.
	PhotoProp.stand(set, "wooden_broom", at + Vector3(-1.9, 0.02, 0.8), 15.0)
	PhotoProp.stand(set, "cement_bag", at + Vector3(3.22, 0.18, 2.24), 96.0)
	PhotoProp.stand(set, "cement_bag", at + Vector3(3.18, 0.36, 2.18), 74.0)
	PhotoProp.stand(set, "metal_toolbox", at + Vector3(4.15, 0.905, 0.82), 170.0)
	# On the counter: the till, a vice, a box of small things.
	PhotoProp.stand(set, "CashRegister_01", at + Vector3(4.2, TOP, HW_COUNTER_Z + 0.05), 0.0)
	PhotoProp.stand(set, "bench_vice_01", at + Vector3(0.1, TOP + 0.09, HW_COUNTER_Z + 0.02), 90.0)
	PhotoProp.stand(set, "measuring_tape_01", at + Vector3(1.2, TOP, HW_COUNTER_Z - 0.1), 40.0)
	PhotoProp.mount(set, "wall_clock", at + Vector3(-0.2, 2.25, back - 0.03), Vector3.FORWARD)
	# What the signs under the ceiling say.
	_ceiling_sign(set, at + Vector3(BENCH_X, 2.72, bench_z - 0.75), "HAND TOOLS", Color("#1f4a3a"))
	_ceiling_sign(set, at + Vector3(HW_COUNTER_X + 0.4, 2.72, HW_COUNTER_Z - 0.3), "PAY HERE", Color("#7a2a1c"))
	StationKit.label(set, "TOOLS · PAINT · GARDEN · SINCE 1921", Transform3D(Basis(Vector3.UP, PI),
		at + Vector3(2.65, 2.72, back - 0.04)), 76, Color("#1f4a3a"), 700, 0.0032)
	var clerk := TownNpc.make("Clerk")
	clerk.position = at + CLERK
	clerk.rotation.y = PI
	set.add_child(clerk)
	# Outside: a lamp over the door, a few goods by the wall.
	PhotoProp.mount(set, "industrial_wall_lamp", at + Vector3(0, TownBlock.DOOR_H + 0.1, 0), Vector3.FORWARD)
	PhotoProp.mount(set, "exterior_aircon_unit:0", at + Vector3(4.2, 2.75, 0), Vector3.FORWARD)


# =====================================================================================================
# Post office
# =====================================================================================================

## The post office, built into `lot` (a node at post_lot()): red brick under two more storeys, a
## counter across the room with the scales and the till, parcels on the shelves and a sorting frame
## behind it, a bench and a writing table for the customers, the postmistress, and outside a
## mail box on the pavement. The board with the mail orders is PostOffice's own.
static func post_office(lot: Node3D) -> void:
	var w := TownStreets.POST_TO - TownStreets.POST_FROM
	var d := ScrapHallSet.HOUSE_D
	var back := d - TownBlock.WALL
	var side := w * 0.5 - TownBlock.WALL
	var counter_z := ScrapHallSet.COUNTER_Z
	TownBlock.house(lot, Vector3.ZERO, w, d, {key = "post", scan = "red_brick", door_x = POST_DOOR_X, windows = [[-4.6, -1.7], [-0.9, 1.6]],
		sign = "POST OFFICE", sign_back = Color("#1d2f4f"), sign_color = Color("#f0e2b8"), floor_scan = "wood_floor_worn",
		lining = Color("#dfd8c6"), trim = Color("#1d2f4f"), lamp = Color("#ffe6c0"), storeys = 2})
	# What is solid first (colliders are wanted on a headless host too).
	TownBlock.counter(lot, Vector3(0, 0, counter_z), w - 0.6, "post_counter", Color("#4d3a2a"))
	TownBlock.shelves(lot, Vector3(-3.1, 0, back - 0.24), 4.0, "post_shelf", 31, POST_GOODS)
	# (The cabinet of drawers is 1.9 m high; the sorting frame hangs on the wall beside it.)
	PhotoProp.place(lot, "drawer_cabinet", Vector3(4.55, 0, back - 0.27), 180.0)
	PhotoProp.place(lot, "painted_wooden_bench", Vector3(-side + 0.3, 0, 2.45), 90.0)
	PhotoProp.place(lot, "round_wooden_table_01", Vector3(-3.6, 0, 1.0), 0.0)
	PhotoProp.place(lot, "painted_wooden_chair_01", Vector3(-2.55, 0, 1.15), 265.0)
	PhotoProp.place(lot, "hand_truck", Vector3(side - 0.45, 0, 2.5), 268.0)
	PhotoProp.place(lot, "vintage_suitcase", Vector3(side - 0.2, 0, 1.15), 90.0)
	# The mail box on the pavement beside the door.
	var box_at := Vector3(POST_DOOR_X - 1.75, 0, -0.62)
	WorldBuilder.add_collider(lot, Vector3(0.6, 1.25, 0.5), Transform3D(Basis(), box_at + Vector3(0, 0.625, 0)))
	if not EnvMesh.visual():
		return
	for x: float in [-side * 0.56, 0.0, side * 0.56]:
		var tube := OmniLight3D.new()
		tube.light_color = Color("#fff1d6")
		tube.light_energy = 0.75
		tube.omni_range = 6.5
		tube.omni_attenuation = 1.1
		tube.shadow_enabled = false
		tube.position = Vector3(x, TownBlock.ROOM_H - 0.5, d * 0.5 + 0.4)
		lot.add_child(tube)
	# The sorting frame on the wall between the board and the drawers: pigeon-holes with letters in
	# some, a clock on top, parcels under it.
	_pigeon_holes(lot, Vector3(3.38, 1.05, back - 0.16))
	PhotoProp.stand(lot, "mantel_clock_01", Vector3(3.38, 1.98, back - 0.14), 180.0)
	PhotoProp.stand(lot, "cardboard_box_01", Vector3(3.2, 0, back - 0.32), 95.0)
	PhotoProp.stand(lot, "cardboard_box_01", Vector3(3.62, 0, back - 0.3), 70.0, 0.8)
	# On the counter: the scales where things are handed over, the till, a lamp, cards and forms.
	_scales(lot, Vector3(POST_HAND_X - 0.75, TOP, counter_z - 0.02))
	PhotoProp.stand(lot, "CashRegister_01", Vector3(-1.4, TOP, counter_z + 0.05), 0.0)
	PhotoProp.stand(lot, "desk_lamp_arm_01", Vector3(-3.6, TOP, counter_z + 0.08), 150.0)
	PhotoProp.stand(lot, "binder_notebook", Vector3(-2.5, TOP, counter_z - 0.05), 190.0)
	PhotoProp.stand(lot, "clipboard", Vector3(4.2, TOP, counter_z - 0.05), 170.0)
	# For the customers: picture postcards on the wall over the bench, forms on the writing table,
	# a parcel on the hand truck, a fan under the ceiling.
	PhotoProp.mount(lot, "postcard_set_01", Vector3(-side + 0.02, 1.45, 2.45), Vector3.RIGHT)
	PhotoProp.stand(lot, "clipboard", Vector3(-3.5, 1.015, 0.9), 40.0)
	PhotoProp.stand(lot, "binder_notebook", Vector3(-3.75, 1.015, 1.25), 200.0)
	PhotoProp.stand(lot, "cardboard_box_01", Vector3(side - 0.47, 0.16, 2.52), 85.0, 0.8)
	PhotoProp.hang(lot, "ceiling_fan", Vector3(0.6, TownBlock.ROOM_H, 1.9), 30.0)
	PhotoProp.mount(lot, "hanging_picture_frame_02", Vector3(side - 0.02, 1.75, 1.2), Vector3.LEFT)
	_ceiling_sign(lot, Vector3(POST_HAND_X, 2.72, counter_z - 0.3), "PARCELS & MAIL ORDERS", Color("#1d2f4f"))
	StationKit.label(lot, "STAMPS · PARCELS · TELEGRAMS", Transform3D(Basis(Vector3.UP, PI), Vector3(-3.1, 2.72, back - 0.04)), 76, Color("#1d2f4f"), 700, 0.0032)
	var clerk := TownNpc.make("Postmistress")
	clerk.position = POSTMISTRESS
	clerk.rotation.y = PI
	lot.add_child(clerk)
	# Outside: a lamp over the door and the mail box.
	PhotoProp.mount(lot, "industrial_wall_lamp", Vector3(POST_DOOR_X, TownBlock.DOOR_H + 0.1, 0), Vector3.FORWARD)
	_mail_box(lot, box_at)


## The post office's scales: an enamelled foot, a steel pan on a short stem, a dial behind it.
static func _scales(set: Node3D, at: Vector3) -> void:
	var enamel := StationKit.metal("post_scales", {steel_color = Color("#6f7a70"), rust = 0.08, metallic_steel = 0.2, roughness_steel = 0.45})
	var steel := StationKit.metal("post_scales_pan", {steel_color = Color("#b9bcbd"), rust = 0.03, metallic_steel = 0.85, roughness_steel = 0.3})
	EnvMesh.add(set, EnvMesh.box(Vector3(0.36, 0.07, 0.3), 0.015), enamel, Transform3D(Basis(), at + Vector3(0, 0.035, 0)))
	EnvMesh.add(set, EnvMesh.cylinder(0.025, 0.03, 0.07, 10), steel, Transform3D(Basis(), at + Vector3(0, 0.105, -0.02)))
	EnvMesh.add(set, EnvMesh.box(Vector3(0.32, 0.012, 0.26), 0.004), steel, Transform3D(Basis(), at + Vector3(0, 0.146, -0.02)))
	EnvMesh.add(set, EnvMesh.cylinder(0.1, 0.1, 0.05, 20), enamel, Transform3D(Basis(Vector3.RIGHT, PI * 0.5), at + Vector3(0, 0.26, 0.15)))
	var face := StandardMaterial3D.new()
	face.albedo_color = Color("#ece6d4")
	face.roughness = 0.5
	EnvMesh.add(set, EnvMesh.cylinder(0.085, 0.085, 0.004, 20), face, Transform3D(Basis(Vector3.RIGHT, PI * 0.5), at + Vector3(0, 0.26, 0.123)), false)
	var hand := StandardMaterial3D.new()
	hand.albedo_color = Color("#8a1f1a")
	EnvMesh.add(set, EnvMesh.box(Vector3(0.006, 0.07, 0.003)), hand, Transform3D(Basis(Vector3.BACK, -0.7), at + Vector3(0.02, 0.28, 0.12)), false)
	EnvMesh.add(set, EnvMesh.box(Vector3(0.05, 0.14, 0.04)), enamel, Transform3D(Basis(), at + Vector3(0, 0.13, 0.15)))


## The sorting frame: a wooden case of pigeon-holes, `at` the middle of its foot on the wall.
static func _pigeon_holes(set: Node3D, at: Vector3) -> void:
	var wood := EnvMesh.wood("post_holes", {base_color = Color("#6b5234"), grain_color = Color("#3e2c1c"), weathering = 0.3, roughness_base = 0.6})
	var cols := 4
	var rows := 4
	var w := 1.0
	var h := 0.92
	var deep := 0.26
	var parts := [EnvMesh.piece(EnvMesh.box(Vector3(w, h, 0.02)), Transform3D(Basis(), at + Vector3(0, h * 0.5, 0.12)))]
	for c in cols + 1:
		parts.append(EnvMesh.piece(EnvMesh.box(Vector3(0.02, h, deep)), Transform3D(Basis(), at + Vector3(-w * 0.5 + c * w / cols, h * 0.5, 0))))
	for r in rows + 1:
		parts.append(EnvMesh.piece(EnvMesh.box(Vector3(w, 0.02, deep)), Transform3D(Basis(), at + Vector3(0, r * h / rows, 0))))
	EnvMesh.add(set, EnvMesh.merge(parts), wood)
	# Letters in some of the holes.
	var paper := StandardMaterial3D.new()
	paper.albedo_color = Color("#e9e2cf")
	paper.roughness = 0.9
	var letters := []
	var pick := 7
	for c in cols:
		for r in rows:
			pick = (pick * 1103515245 + 12345) & 0x7fffffff
			if pick % 5 < 2:
				continue
			var n := 1 + pick % 3
			letters.append(EnvMesh.piece(EnvMesh.box(Vector3(w / cols - 0.07, 0.012 * n, 0.2)), Transform3D(Basis(Vector3.UP, (pick % 7 - 3) * 0.03),
				at + Vector3(-w * 0.5 + (c + 0.5) * w / cols, r * h / rows + 0.012 + 0.006 * n, -0.02))))
	EnvMesh.add(set, EnvMesh.merge(letters), paper, Transform3D(), false)


## A street mail box: a blue steel box with a rounded top on four legs, a flap and a white board.
static func _mail_box(set: Node3D, at: Vector3) -> void:
	var blue := StationKit.metal("post_mailbox", {steel_color = Color("#1f3f7a"), rust = 0.12, metallic_steel = 0.3, roughness_steel = 0.5})
	var dark := StationKit.metal("post_mailbox_legs", {steel_color = Color("#22262b"), rust = 0.2, metallic_steel = 0.5, roughness_steel = 0.55})
	var bw := 0.56
	var bd := 0.46
	# The body is the outline of its side (a box with a rounded top), drawn out to its width.
	var outline := PackedVector2Array([Vector2(-bd * 0.5, 0), Vector2(bd * 0.5, 0)])
	for k in 9:
		var a := PI * k / 8.0
		outline.append(Vector2(bd * 0.5 * cos(a), 0.62 + bd * 0.5 * sin(a)))
	var body := ChurchKit.prism(outline, bw, true)
	EnvMesh.add(set, body, blue, Transform3D(Basis(Vector3.UP, PI * 0.5), at + Vector3(-bw * 0.5, 0.32, 0)))
	var legs := []
	for sx: float in [-1.0, 1.0]:
		for sz: float in [-1.0, 1.0]:
			legs.append(EnvMesh.piece(EnvMesh.box(Vector3(0.05, 0.34, 0.05)), Transform3D(Basis(), at + Vector3(sx * (bw * 0.5 - 0.05), 0.17, sz * (bd * 0.5 - 0.05)))))
	EnvMesh.add(set, EnvMesh.merge(legs), dark)
	# The flap with its handle, and the board that says what this is (towards the street).
	EnvMesh.add(set, EnvMesh.box(Vector3(bw - 0.1, 0.16, 0.02), 0.005), dark, Transform3D(Basis(Vector3.RIGHT, 0.5), at + Vector3(0, 0.98, -bd * 0.5 + 0.04)))
	var plate := StandardMaterial3D.new()
	plate.albedo_color = Color("#ece6d4")
	plate.roughness = 0.5
	EnvMesh.add(set, EnvMesh.box(Vector3(bw - 0.14, 0.2, 0.008)), plate, Transform3D(Basis(), at + Vector3(0, 0.6, -bd * 0.5 - 0.005)), false)
	StationKit.label(set, "MAIL", Transform3D(Basis(Vector3.UP, PI), at + Vector3(0, 0.6, -bd * 0.5 - 0.012)), 72, Color("#1f3f7a"), 800, 0.0026)


# =====================================================================================================
# Bank
# =====================================================================================================

static func bank(set: Node3D) -> void:
	var at := ScrapHallSet.BANK
	var w := ScrapHallSet.SHOP_W
	var d := ScrapHallSet.HOUSE_D
	var back := d - TownBlock.WALL
	var side := w * 0.5 - TownBlock.WALL
	var counter_z := ScrapHallSet.COUNTER_Z
	TownBlock.house(set, at, w, d, {key = "bank", scan = "large_sandstone_blocks", tone = Color("#c9bda4"), door_x = 0.0,
		windows = [[-4.6, -2.3], [2.3, 4.6]], sign = "BANK", sign_back = Color("#23282e"), sign_color = Color("#e8c66a"),
		floor_scan = "marble_01", floor_tile = 1.5, lining = Color("#e6dcc6"), trim = Color("#3a2a20"), lamp = Color("#ffe2b4"),
		strips = false, storeys = 2})
	# What is solid first: the counter across the room, the glass over it, the furniture.
	TownBlock.counter(set, at + Vector3(0, 0, counter_z), side * 2.0 - 0.1, "bank_counter", Color("#3a2416"))
	var screen_z := counter_z - 0.18
	# (Glass over the whole counter; at the two places a slot stays open under it.)
	WorldBuilder.add_collider(set, Vector3(side * 2.0, SCREEN_TOP - SLOT_TOP, 0.05), Transform3D(Basis(), at + Vector3(0, (SCREEN_TOP + SLOT_TOP) * 0.5, screen_z)))
	PhotoProp.place(set, "metal_office_desk", at + Vector3(-3.3, 0, back - 0.52), 180.0)
	PhotoProp.place(set, "GothicCabinet_01", at + Vector3(-0.45, 0, back - 0.6), 180.0)
	PhotoProp.place(set, "sofa_02", at + Vector3(-side + 0.45, 0, 1.75), 90.0, true)
	PhotoProp.place(set, "ArmChair_01", at + Vector3(-2.75, 0, 0.95), 300.0)
	PhotoProp.place(set, "ClassicConsole_01", at + Vector3(side - 0.32, 0, 1.45), -90.0, true)
	PhotoProp.place(set, "vintage_grandfather_clock_01", at + Vector3(side - 0.24, 0, 2.75), -90.0, true)
	PhotoProp.place(set, "potted_plant_02", at + Vector3(-side + 0.5, 0, 0.6), 30.0)
	PhotoProp.place(set, "potted_plant_02", at + Vector3(1.25, 0, 0.6), 200.0)
	if not EnvMesh.visual():
		return
	var top := TOP
	# Dark panelling to the height of the counter on the three walls.
	var panel := EnvMesh.scan("bank_panel", "dark_paneled_wood", {tint = EnvMesh.toward("dark_paneled_wood", Color("#3f2618"), 0.9)})
	var cap := EnvMesh.wood("bank_cap", {base_color = Color("#3a2416"), grain_color = Color("#1f130c"), weathering = 0.1, roughness_base = 0.45})
	var up := 1.2
	var panels := []
	var caps := []
	panels.append(EnvMesh.piece(EnvMesh.box(Vector3(side * 2.0, up, 0.02)), Transform3D(Basis(), at + Vector3(0, up * 0.5, back - 0.04))))
	caps.append(EnvMesh.piece(EnvMesh.box(Vector3(side * 2.0, 0.07, 0.05)), Transform3D(Basis(), at + Vector3(0, up + 0.035, back - 0.055))))
	for s: float in [-1.0, 1.0]:
		panels.append(EnvMesh.piece(EnvMesh.box(Vector3(0.02, up, back - TownBlock.WALL)), Transform3D(Basis(), at + Vector3(s * (side - 0.04), up * 0.5, (back + TownBlock.WALL) * 0.5))))
		caps.append(EnvMesh.piece(EnvMesh.box(Vector3(0.05, 0.07, back - TownBlock.WALL)), Transform3D(Basis(), at + Vector3(s * (side - 0.055), up + 0.035, (back + TownBlock.WALL) * 0.5))))
	EnvMesh.add(set, EnvMesh.merge(panels), panel)
	EnvMesh.add(set, EnvMesh.merge(caps), cap)
	# A red runner from the door to the counter.
	var runner := EnvMesh.scan("bank_runner", "quatrefoil_jacquard_fabric", {tint = Vector3(0.55, 0.55, 0.55)})
	EnvMesh.add(set, EnvMesh.box(Vector3(2.4, 0.012, counter_z - 0.75), 0.0), runner, Transform3D(Basis(), at + Vector3(0, 0.036, (counter_z - 0.35 + TownBlock.WALL + 0.1) * 0.5)), false)
	_screen(set, at, side, screen_z)
	_vault(set, at + Vector3(VAULT_X, VAULT_Y, back - 0.03))
	# Behind the counter: the desk with the day's ledgers, a strip of light over the clerks.
	var desk := at + Vector3(-3.3, 0.79, back - 0.52)
	PhotoProp.stand(set, "binder_notebook", desk + Vector3(0.35, 0, -0.05), 170.0)
	PhotoProp.stand(set, "stationery_supplies", desk + Vector3(-0.55, 0.07, 0.12), 200.0)
	PhotoProp.stand(set, "mantel_clock_01", desk + Vector3(-0.2, 0, 0.25), 180.0)
	PhotoProp.stand(set, "book_encyclopedia_set_01", desk + Vector3(0.6, 0, 0.25), 180.0)
	TownBlock.strip_light(set, at + Vector3(-1.6, TownBlock.ROOM_H - 0.02, counter_z + 1.3), Color("#fff1d6"))
	for x: float in [-2.4, 2.4]:
		var tube := OmniLight3D.new()
		tube.light_color = Color("#ffe6c0")
		tube.light_energy = 1.3
		tube.omni_range = 5.5
		tube.omni_attenuation = 1.1
		tube.shadow_enabled = false
		tube.position = at + Vector3(x, TownBlock.ROOM_H - 0.55, counter_z + 1.4)
		set.add_child(tube)
	PhotoProp.mount(set, "security_camera_01", at + Vector3(side - 0.5, 2.6, back - 0.03), Vector3.FORWARD)
	# On the counter, on the clerks' side of the glass.
	PhotoProp.stand(set, "CashRegister_01", at + Vector3(QUEUE_X + 0.95, top, counter_z + 0.2), 0.0)
	PhotoProp.stand(set, "vintage_oil_lamp", at + Vector3(-4.4, top, counter_z + 0.1), 25.0, 0.6)
	PhotoProp.stand(set, "clipboard", at + Vector3(LOANS_X + 0.55, top, counter_z + 0.1), 190.0)
	# The customers' side: the console with slips and pens, pictures, two chandeliers.
	var console := at + Vector3(side - 0.32, 0.95, 1.45)
	PhotoProp.stand(set, "office_notepads", console + Vector3(0.02, 0, 0.1), -90.0, 0.42)
	PhotoProp.stand(set, "stationery_supplies", console + Vector3(0.05, 0.07, -0.5), -70.0)
	PhotoProp.mount(set, "hanging_picture_frame_03", at + Vector3(side - 0.03, 1.72, 1.45), Vector3.LEFT)
	PhotoProp.mount(set, "fancy_picture_frame_02", at + Vector3(-side + 0.03, 1.5, 1.75), Vector3.RIGHT)
	for x: float in [-2.6, 2.6]:
		PhotoProp.hang(set, "Chandelier_02", at + Vector3(x, TownBlock.ROOM_H, 1.75), x * 20.0)
		var glow := OmniLight3D.new()
		glow.light_color = Color("#ffd9a0")
		glow.light_energy = 1.5
		glow.omni_range = 5.5
		glow.omni_attenuation = 1.2
		glow.shadow_enabled = false
		glow.position = at + Vector3(x, 2.15, 1.75)
		set.add_child(glow)
	StationKit.label(set, "LOANS · SAVINGS · SAFE DEPOSIT", Transform3D(Basis(Vector3.UP, PI), at + Vector3(-2.2, 2.72, back - 0.04)), 76,
		Color("#3a2416"), 700, 0.0032)
	var teller := TownNpc.make("Teller")
	teller.position = at + Vector3(LOANS_X, 0, counter_z + 1.05)
	teller.rotation.y = PI
	set.add_child(teller)
	_front(set, at, w)


## The glass over the bank's counter: brass posts and rails, panes between them, a slot at the two
## places where customers stand, and a brass board over each that says what is done there.
static func _screen(set: Node3D, at: Vector3, side: float, z: float) -> void:
	var brass := MachineDetail.brass_mat()
	var glass := StandardMaterial3D.new()
	glass.albedo_color = Color(0.8, 0.9, 0.94, 0.07)
	glass.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	glass.roughness = 0.06
	glass.metallic_specular = 0.9
	var bars := []
	var panes := []
	var pitch := 1.3
	var count := int(floor(side * 2.0 / pitch))
	var start := -count * pitch * 0.5
	for i in count + 1:
		bars.append(EnvMesh.piece(EnvMesh.cylinder(0.018, 0.018, SCREEN_TOP - TOP, 10), Transform3D(Basis(), at + Vector3(start + i * pitch, (SCREEN_TOP + TOP) * 0.5, z))))
		bars.append(EnvMesh.piece(EnvMesh.sphere(0.032, 10, 6), Transform3D(Basis(), at + Vector3(start + i * pitch, SCREEN_TOP + 0.02, z))))
	bars.append(EnvMesh.piece(EnvMesh.box(Vector3(count * pitch, 0.03, 0.03)), Transform3D(Basis(), at + Vector3(0, SCREEN_TOP - 0.015, z))))
	for i in count:
		var mid := start + (i + 0.5) * pitch
		var open := absf(mid - LOANS_X) < 0.1 or absf(mid - QUEUE_X) < 0.1
		var low := SLOT_TOP if open else TOP + 0.03
		panes.append(EnvMesh.piece(EnvMesh.box(Vector3(pitch - 0.04, SCREEN_TOP - 0.03 - low, 0.012)), Transform3D(Basis(), at + Vector3(mid, (SCREEN_TOP - 0.03 + low) * 0.5, z))))
		if open:
			bars.append(EnvMesh.piece(EnvMesh.box(Vector3(pitch - 0.04, 0.025, 0.025)), Transform3D(Basis(), at + Vector3(mid, SLOT_TOP, z))))
	EnvMesh.add(set, EnvMesh.merge(bars), brass, Transform3D(), false)
	EnvMesh.add(set, EnvMesh.merge(panes), glass, Transform3D(), false)
	var dark := StandardMaterial3D.new()
	dark.albedo_color = Color("#23282e")
	dark.roughness = 0.6
	for entry: Array in [[LOANS_X, "LOANS"], [QUEUE_X, "DEPOSITS"]]:
		var x: float = entry[0]
		EnvMesh.add(set, EnvMesh.box(Vector3(0.9, 0.2, 0.03), 0.01), dark, Transform3D(Basis(), at + Vector3(x, SCREEN_TOP + 0.17, z)), false)
		StationKit.label(set, entry[1], Transform3D(Basis(Vector3.UP, PI), at + Vector3(x, SCREEN_TOP + 0.17, z - 0.018)), 64, Color("#e8c66a"), 700, 0.0022)


## The vault door in the bank's back wall: a round steel door in its frame, bolts round the rim, the
## hand wheel, two hinges and the maker's plate. `at` is its middle on the wall; it looks -Z.
static func _vault(set: Node3D, at: Vector3) -> void:
	var holder := Node3D.new()
	holder.name = "VaultDoor"
	holder.position = at
	set.add_child(holder)
	var steel := StationKit.metal("vault_door", {steel_color = Color("#8d9296"), rust = 0.03, dents = 0.02, metallic_steel = 0.9, roughness_steel = 0.32})
	var frame := StationKit.metal("vault_frame", {steel_color = Color("#5d6166"), rust = 0.08, dents = 0.03, metallic_steel = 0.85, roughness_steel = 0.45})
	var r := VAULT_R
	# Revolved round the axis that comes out of the wall (the lathe turns round Y: laid over to -Z).
	var lay := Basis(Vector3.RIGHT, -PI * 0.5)
	# (StationKit.lathe: the outside lies to the right of the way the profile runs, so from the rim inwards.)
	var door := PackedVector2Array([Vector2(r * 0.98, 0.05), Vector2(r * 0.98, 0.13), Vector2(r * 0.96, 0.15), Vector2(r * 0.84, 0.15),
		Vector2(r * 0.8, 0.13), Vector2(0.15, 0.145), Vector2(0.15, 0.17), Vector2(0.13, 0.2), Vector2(0.0, 0.2)])
	StationKit.add(holder, StationKit.lathe(door, 48, 40.0), steel, Transform3D(lay, Vector3.ZERO))
	var rim := PackedVector2Array([Vector2(r * 1.19, 0.0), Vector2(r * 1.19, 0.06), Vector2(r * 1.17, 0.085), Vector2(r * 1.03, 0.085), Vector2(r * 1.03, 0.05), Vector2(r * 0.985, 0.05)])
	StationKit.add(holder, StationKit.lathe(rim, 48, 40.0), frame, Transform3D(lay, Vector3.ZERO))
	var out := Vector3.FORWARD
	var parts := MachineDetail.Parts.new()
	MachineDetail.bolt_circle(parts, out * 0.15, out, r * 0.9, 16, 0.03)
	MachineDetail.bolt_circle(parts, out * 0.085, out, r * 1.11, 12, 0.022, true)
	MachineDetail.handwheel(parts, out * 0.3, out, 0.27)
	# The spindle of the wheel and the two hinges on the right.
	parts.steel.append(EnvMesh.piece(EnvMesh.cylinder(0.035, 0.035, 0.12, 12), Transform3D(lay, out * 0.24)))
	for y: float in [-0.5, 0.5]:
		MachineDetail.hinge(parts, Vector3(-r * 1.06, y * r, -0.13), Vector3.UP, out, 0.3, 0.04)
		parts.steel.append(EnvMesh.piece(EnvMesh.box(Vector3(r * 0.34, 0.11, 0.03)), Transform3D(Basis(), Vector3(-r * 0.9, y * r, -0.165))))
	MachineDetail.commit(holder, parts, true)
	MachineDetail.type_plate(holder, Transform3D(Basis(Vector3.UP, PI), Vector3(0.0, -r * 0.42, -0.142)), "MM SAFE WORKS", ["VAULT DOOR", "No. 7 · 1907"], Vector2(0.3, 0.17))


## Cast stone on the bank's front: pilasters beside the door and at the corners, a cornice over the
## ground floor, a brass plate by the door and two lamps.
static func _front(set: Node3D, at: Vector3, w: float) -> void:
	var stone := TownBlock.stone()
	var pieces := []
	var rise := TownBlock.HEIGHT - 0.5
	for x: float in [-w * 0.5 + 0.3, -1.25, 1.25, w * 0.5 - 0.3]:
		pieces.append(EnvMesh.piece(EnvMesh.box(Vector3(0.46, rise, 0.14)), Transform3D(Basis(), at + Vector3(x, rise * 0.5, -0.07))))
		pieces.append(EnvMesh.piece(EnvMesh.box(Vector3(0.62, 0.3, 0.22)), Transform3D(Basis(), at + Vector3(x, 0.15, -0.11))))
		pieces.append(EnvMesh.piece(EnvMesh.box(Vector3(0.6, 0.16, 0.2)), Transform3D(Basis(), at + Vector3(x, rise - 0.08, -0.1))))
	pieces.append(EnvMesh.piece(EnvMesh.box(Vector3(w + 0.3, 0.26, 0.34)), Transform3D(Basis(), at + Vector3(0, TownBlock.HEIGHT - 0.2, -0.17))))
	pieces.append(EnvMesh.piece(EnvMesh.box(Vector3(w + 0.16, 0.12, 0.24)), Transform3D(Basis(), at + Vector3(0, TownBlock.HEIGHT - 0.39, -0.12))))
	EnvMesh.add(set, EnvMesh.merge(pieces), stone)
	MachineDetail.type_plate(set, Transform3D(Basis(Vector3.UP, PI), at + Vector3(1.78, 1.45, -0.012)), "TOWN BANK", ["LOANS · SAVINGS", "EST. 1907"], Vector2(0.44, 0.3))
	for x: float in [-1.25, 1.25]:
		PhotoProp.mount(set, "industrial_wall_lamp", at + Vector3(x, 2.5, -0.14), Vector3.FORWARD)


# =====================================================================================================
# Shared helpers
# =====================================================================================================

## Scan `pick` hung or leant on a wall: its foot at `at`, turned by `turn` degrees about the vertical
## (so that its flat side lies on the wall), the whole swung to a wall that looks `wall` degrees away
## from -Z (90: a wall that looks +X) and leant back by `lean` degrees. Looks only.
static func _hung(set: Node3D, pick: String, at: Vector3, turn := 0.0, wall := 0.0, lean := 0.0) -> void:
	if not EnvMesh.visual():
		return
	var box := PhotoProp.box(pick)
	var thick := box.size.x if absf(fmod(turn, 180.0)) > 45.0 else box.size.z
	var holder := Node3D.new()
	# The wall looks along the holder's -Z; the piece stands off it by half its thickness, and a leaning
	# one by what its top comes back.
	var off := thick * 0.5 + 0.004 + box.size.y * sin(deg_to_rad(lean))
	holder.transform = Transform3D(Basis(Vector3.UP, deg_to_rad(-wall)), at) * Transform3D(Basis(Vector3.RIGHT, deg_to_rad(lean)), Vector3(0, 0, -off))
	set.add_child(holder)
	PhotoProp.stand(holder, pick, Vector3.ZERO, turn)


## A board that hangs from the ceiling on two rods, written on both sides.
static func _ceiling_sign(set: Node3D, at: Vector3, text: String, colour: Color) -> void:
	var board := StandardMaterial3D.new()
	board.albedo_color = colour
	board.roughness = 0.65
	var wide := 0.5 + text.length() * 0.115
	EnvMesh.add(set, EnvMesh.box(Vector3(wide, 0.3, 0.03), 0.01), board, Transform3D(Basis(), at), false)
	var iron := StandardMaterial3D.new()
	iron.albedo_color = Color("#2a2a2c")
	iron.roughness = 0.6
	iron.metallic = 0.6
	var drop := TownBlock.ROOM_H - at.y - 0.15
	for s: float in [-1.0, 1.0]:
		EnvMesh.add(set, EnvMesh.cylinder(0.006, 0.006, drop, 6), iron, Transform3D(Basis(), at + Vector3(s * (wide * 0.5 - 0.1), 0.15 + drop * 0.5, 0)), false)
	for face: float in [0.0, PI]:
		StationKit.label(set, text, Transform3D(Basis(Vector3.UP, face), at + Vector3(0, 0, 0.018 if face == 0.0 else -0.018)), 84, Color("#f2e6c8"), 800, 0.0022)
