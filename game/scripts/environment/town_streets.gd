class_name TownStreets
extends RefCounted
## The streets round the block (stage U14). The main street in front of the hall met a bare side
## street at each end; now both lead north between houses to a back street that runs behind the row,
## so that one can walk round the whole block, and two passages cut through the row. A railway
## viaduct closes the quarter to the north: sixteen brick arches along the back street (lock-ups,
## workshops, bricked up) and a wide arch over each side street, through which the town's cars come
## and go. Beyond the viaduct a cross road leads them away out of sight.
## Everything is laid out from ScrapHallSet's street (FRONT_Z, ROAD, SIDE_X); z grows to the north.
## Comparison pictures: Police Simulator: Patrol Officers (pavements, kerbs, crossings), Schedule I
## (back streets), Storage Hunter Simulator (lock-ups with roller shutters).

## The back street: the far face of the yard wall behind the row, its two kerbs, its middle.
const BACK_NEAR := 29.02
const BACK_KERB_S := 31.4
const BACK_Z := 34.2
const BACK_KERB_N := 37.0
## The viaduct: its face on the back street, how deep it is, the height of the band under the
## parapet and of the parapet's top.
const VIADUCT_Z := 40.4
const VIADUCT_D := 8.0
const DECK_H := 5.5
const VIADUCT_H := 6.6
## The cross road beyond the viaduct (its middle), and how far along it the cars run until nobody
## can see them any more.
const NORTH_Z := 52.2
const NORTH_RUN := 17.5
## The arches along the back street: so many between the two street arches, each opening this wide,
## its round head springing this high.
const BAYS := 16
const ARCH_W := 3.8
const SPRING := 1.75
## The street arches: their middle (east: +, west: -), width, springing and rise of the flat arch;
## the width of the abutment on either side of one, and how far the viaduct runs on beyond.
const GATE_X := 44.85
const GATE_W := 9.0
const GATE_SPRING := 3.3
const GATE_RISE := 1.5
const ABUT := 1.4
const END_RUN := 14.0
## Half the length of the arcade between the two inner abutments.
const ARCADE := GATE_X - GATE_W * 0.5 - ABUT
## Where the houses beyond the side streets stand (their fronts on the side street), and the
## stretch of the eastern row that is the post office (z from, to).
const FAR_X := 49.7
## Where the boom and the barriers of a street arch stand: just in front of the viaduct's face, so
## the boom lifts in the open and not into the vault.
const BAR_Z := VIADUCT_Z - 0.7
const POST_FROM := 19.52
const POST_TO := 30.5
## What is in the arches, from the west: "" bricked up, "lockup" a lock-up of the storage auctions
## (StorageLockup), "office", "garage" and "store" shut fronts.
const USES := ["", "store", "", "", "", "store", "", "office", "lockup", "lockup", "lockup", "lockup", "", "garage", "garage", ""]
## The passages through the row from the main street to the back street: [x from, x to].
const PASSAGE := Vector2(-7.0, -1.5)
const ALLEY_EAST := Vector2(26.6, 29.0)
## Whether the lock-ups are run by StorageLockup nodes (which bring their own shutters). False: their
## doorways are shut for good by the viaduct itself.
const LOCKUPS_LIVE := true
## Depth of a lock-up behind its front (m), and how far the front stands back in its arch.
const LOCKUP_D := 5.6
const INFILL := 0.45
## The shutter of a lock-up: width and height of the doorway.
const DOOR := Vector2(2.7, 2.35)


## The width of one bay (pier and arch).
static func pitch() -> float:
	return ARCADE * 2.0 / BAYS


## The middle of bay `index` (0 in the west) along the viaduct.
static func bay_x(index: int) -> float:
	return -ARCADE + pitch() * (index + 0.5)


## The bays that are lock-ups, from the west.
static func lockups() -> Array[int]:
	var out: Array[int] = []
	for i in USES.size():
		if USES[i] == "lockup":
			out.append(i)
	return out


## The middle of the doorway of bay `index` at ground level (on the infill wall).
static func door_spot(index: int) -> Vector3:
	return Vector3(bay_x(index), 0, VIADUCT_Z + INFILL)


# --- Roads, kerbs, paint -------------------------------------------------------------------------

## Asphalt, kerbs and paint of the side streets, the back street and the cross road, and the paint
## of the main street (visual only). `road_z`: the middle of the main street.
static func surfaces(set: ScrapHallSet, road_z: float) -> void:
	if not EnvMesh.visual():
		return
	var road := ScrapHallSet.ROAD
	var side := ScrapHallSet.SIDE_X
	var main_n := road_z + road * 0.5
	var north_far := NORTH_Z + road * 0.5
	var asphalt := EnvMesh.scan("street_asphalt", "asphalt_02", {drift = 0.22, tint = Vector3(0.7, 0.7, 0.72)})
	var roads := [EnvMesh.piece(EnvMesh.box(Vector3(side * 2.0 + road, 0.04, road), 0.0), Transform3D(Basis(), Vector3(0, 0.0, road_z)))]
	for s: float in [-1.0, 1.0]:
		roads.append(EnvMesh.piece(EnvMesh.box(Vector3(road, 0.04, north_far - main_n), 0.0), Transform3D(Basis(), Vector3(s * side, 0.0, (main_n + north_far) * 0.5))))
		var out_from := side + road * 0.5
		roads.append(EnvMesh.piece(EnvMesh.box(Vector3(22.0, 0.04, road), 0.0), Transform3D(Basis(), Vector3(s * (out_from + 11.0), 0.0, NORTH_Z))))
	roads.append(EnvMesh.piece(EnvMesh.box(Vector3(side * 2.0 - road, 0.04, road), 0.0), Transform3D(Basis(), Vector3(0, 0.0, BACK_Z))))
	EnvMesh.add(set, EnvMesh.merge(roads), asphalt, Transform3D(), false)
	# Paint: the middle line of the main street and of the side streets, the crossings, a stop line
	# where the western side street meets the main street.
	var paint := EnvMesh.surface("street_paint", {base_color = Color("#d9d4c4"), roughness_base = 0.8})
	var marks := []
	for i in 20:
		marks.append(EnvMesh.piece(EnvMesh.box(Vector3(1.6, 0.012, 0.14)), Transform3D(Basis(), Vector3(-38.0 + i * 4.0, 0.025, road_z))))
	for s: float in [-1.0, 1.0]:
		for i in 2:
			marks.append(EnvMesh.piece(EnvMesh.box(Vector3(0.14, 0.012, 1.6)), Transform3D(Basis(), Vector3(s * side, 0.025, 25.6 + i * 3.6))))
		crossing(marks, Vector3(s * side, 0, main_n + 2.6), false, road, 3.0)
	marks.append(EnvMesh.piece(EnvMesh.box(Vector3(road - 0.5, 0.012, 0.32)), Transform3D(Basis(), Vector3(-side, 0.025, main_n + 4.75))))
	# The crossing from the hall's door to the dealer, and the two where the passages meet the back street.
	crossing(marks, Vector3(3.1, 0, road_z), true, road, 5.0)
	crossing(marks, Vector3((PASSAGE.x + PASSAGE.y) * 0.5, 0, BACK_Z), true, road, 3.0)
	crossing(marks, Vector3((ALLEY_EAST.x + ALLEY_EAST.y) * 0.5, 0, BACK_Z), true, road, 2.6)
	EnvMesh.add(set, EnvMesh.merge(marks), paint, Transform3D(), false)
	# Kerbs: both sides of every street, broken where another street runs out of it.
	var kerb := EnvMesh.scan("street_kerb", "dirty_concrete", {tile = 1.6, tint = Vector3(0.85, 0.85, 0.85)})
	var kerbs := []
	var in_x := side - road * 0.5 - 0.1
	var out_x := side + road * 0.5 + 0.1
	var main_s := road_z - road * 0.5 - 0.1
	_kerb(kerbs, Vector3(-out_x, 0, main_s), Vector3(out_x, 0, main_s))
	_kerb(kerbs, Vector3(-in_x, 0, main_n + 0.1), Vector3(in_x, 0, main_n + 0.1))
	_kerb(kerbs, Vector3(-in_x, 0, BACK_KERB_S - 0.1), Vector3(in_x, 0, BACK_KERB_S - 0.1))
	_kerb(kerbs, Vector3(-in_x, 0, BACK_KERB_N + 0.1), Vector3(in_x, 0, BACK_KERB_N + 0.1))
	for s: float in [-1.0, 1.0]:
		_kerb(kerbs, Vector3(s * in_x, 0, main_n + 0.1), Vector3(s * in_x, 0, BACK_KERB_S - 0.1))
		_kerb(kerbs, Vector3(s * in_x, 0, BACK_KERB_N + 0.1), Vector3(s * in_x, 0, north_far + 0.1))
		_kerb(kerbs, Vector3(s * out_x, 0, main_s), Vector3(s * out_x, 0, NORTH_Z - road * 0.5 - 0.1))
		_kerb(kerbs, Vector3(s * out_x, 0, NORTH_Z - road * 0.5 - 0.1), Vector3(s * (out_x + 21.0), 0, NORTH_Z - road * 0.5 - 0.1))
		_kerb(kerbs, Vector3(s * in_x, 0, north_far + 0.1), Vector3(s * (out_x + 21.0), 0, north_far + 0.1))
	EnvMesh.add(set, EnvMesh.merge(kerbs), kerb)


## A kerb stone from `a` to `b` (along x or along z).
static func _kerb(kerbs: Array, a: Vector3, b: Vector3) -> void:
	var size := Vector3(absf(b.x - a.x) + 0.2, 0.12, absf(b.z - a.z) + 0.2)
	kerbs.append(EnvMesh.piece(EnvMesh.box(size), Transform3D(Basis(), (a + b) * 0.5 + Vector3(0, 0.06, 0))))


## A pedestrian crossing: bars that lie the way the traffic runs, side by side across the road.
## `at` is its middle; `along_x`: the road runs along x; `width` of the road; `length` of the bars.
static func crossing(marks: Array, at: Vector3, along_x: bool, width: float, length: float) -> void:
	var n := int((width - 0.3) / 1.05)
	for i in n:
		var off := (i - (n - 1) * 0.5) * 1.05
		if along_x:
			marks.append(EnvMesh.piece(EnvMesh.box(Vector3(length, 0.012, 0.5)), Transform3D(Basis(), Vector3(at.x, 0.026, at.z + off))))
		else:
			marks.append(EnvMesh.piece(EnvMesh.box(Vector3(0.5, 0.012, length)), Transform3D(Basis(), Vector3(at.x + off, 0.026, at.z))))


# --- The viaduct ---------------------------------------------------------------------------------

## The outline of a wall `w` wide and `h` high with an arched opening in its middle: `open` wide,
## upright to `spring`, then a round head (`rise` 0) or a flat arch that rises by `rise`.
## Anticlockwise from the lower left, x from the middle.
static func arch_wall(w: float, h: float, open: float, spring: float, rise := 0.0, steps := 14) -> PackedVector2Array:
	var out := PackedVector2Array([Vector2(-w * 0.5, 0), Vector2(-open * 0.5, 0)])
	out.append_array(arch_line(open, spring, rise, steps))
	out.append_array(PackedVector2Array([Vector2(open * 0.5, 0), Vector2(w * 0.5, 0), Vector2(w * 0.5, h), Vector2(-w * 0.5, h)]))
	return out


## The line of an arch from its left springing over the crown to the right one: `open` wide,
## springing at `spring`; a half circle, or with `rise` a flatter arc that rises by that much.
static func arch_line(open: float, spring: float, rise := 0.0, steps := 14) -> PackedVector2Array:
	var out := PackedVector2Array()
	var half := open * 0.5
	if rise <= 0.0 or rise >= half:
		for k in steps + 1:
			var a := PI - PI * k / steps
			out.append(Vector2(half * cos(a), spring + half * sin(a)))
		return out
	# A circle through both springing points and the crown: its middle lies below the springing line.
	var r := (half * half + rise * rise) / (2.0 * rise)
	var reach := asin(half / r)
	for k in steps + 1:
		var a := -reach + 2.0 * reach * k / steps
		out.append(Vector2(r * sin(a), spring + rise - r + r * cos(a)))
	return out


## The viaduct: brick piers and arches, a stone band and a parapet, the two street arches with their
## barriers, what closes each arch, and the cross road's backdrop behind. Colliders also headless.
static func viaduct(set: ScrapHallSet) -> void:
	var p := pitch()
	var gate_in := GATE_X - GATE_W * 0.5
	var gate_out := GATE_X + GATE_W * 0.5
	var end_from := gate_out + ABUT
	var mid_z := VIADUCT_Z + VIADUCT_D * 0.5
	var pier := p - ARCH_W
	# What stops people (and the things they throw): the piers between the arches, what closes every
	# arch, the abutments and the solid ends, and the barriers under the street arches. The lock-ups
	# keep their rooms free; their shutters are StorageLockup's.
	for i in range(1, BAYS):
		WorldBuilder.add_collider(set, Vector3(pier, VIADUCT_H, VIADUCT_D), Transform3D(Basis(), Vector3(-ARCADE + p * i, VIADUCT_H * 0.5, mid_z)))
	for i in BAYS:
		var x := bay_x(i)
		if USES[i] == "lockup":
			var behind := VIADUCT_D - LOCKUP_D - INFILL
			WorldBuilder.add_collider(set, Vector3(ARCH_W, VIADUCT_H, behind), Transform3D(Basis(), Vector3(x, VIADUCT_H * 0.5, VIADUCT_Z + VIADUCT_D - behind * 0.5)))
			WorldBuilder.add_collider(set, Vector3(ARCH_W, VIADUCT_H - DOOR.y, 0.2), Transform3D(Basis(), Vector3(x, DOOR.y + (VIADUCT_H - DOOR.y) * 0.5, VIADUCT_Z + INFILL + 0.1)))
			var jamb := (ARCH_W - DOOR.x) * 0.5
			for s: float in [-1.0, 1.0]:
				WorldBuilder.add_collider(set, Vector3(jamb, DOOR.y, 0.2), Transform3D(Basis(), Vector3(x + s * (DOOR.x + jamb) * 0.5, DOOR.y * 0.5, VIADUCT_Z + INFILL + 0.1)))
			if not LOCKUPS_LIVE:
				WorldBuilder.add_collider(set, Vector3(DOOR.x, DOOR.y, 0.2), Transform3D(Basis(), Vector3(x, DOOR.y * 0.5, VIADUCT_Z + INFILL + 0.1)))
		else:
			WorldBuilder.add_collider(set, Vector3(ARCH_W, VIADUCT_H, VIADUCT_D - INFILL), Transform3D(Basis(), Vector3(x, VIADUCT_H * 0.5, mid_z + INFILL * 0.5)))
	for s: float in [-1.0, 1.0]:
		# The abutment between the arcade and the street arch (with the arcade's last half pier), and
		# the solid end beyond the arch.
		var ab_w := ABUT + pier * 0.5
		WorldBuilder.add_collider(set, Vector3(ab_w, VIADUCT_H, VIADUCT_D), Transform3D(Basis(), Vector3(s * (gate_in - ab_w * 0.5), VIADUCT_H * 0.5, mid_z)))
		WorldBuilder.add_collider(set, Vector3(END_RUN + ABUT, VIADUCT_H, VIADUCT_D), Transform3D(Basis(), Vector3(s * (gate_out + (END_RUN + ABUT) * 0.5), VIADUCT_H * 0.5, mid_z)))
		# People stay in the quarter: a barrier across the street arch, a boom over the road that lifts
		# for the cars and the truck.
		# What stops them is as deep as the viaduct and as high as the arch: a worker a lorry pushes
		# against it is never squeezed out on the far side, and nothing is thrown over it for good.
		var bar_z := BAR_Z
		var stop_h := GATE_SPRING + GATE_RISE + 0.2
		var stop_d := VIADUCT_Z + VIADUCT_D - (bar_z - 0.2)
		WorldBuilder.add_collider(set, Vector3(GATE_W, stop_h, stop_d), Transform3D(Basis(), Vector3(s * GATE_X, stop_h * 0.5, bar_z - 0.2 + stop_d * 0.5)))
		var gate := BoomGate.new()
		gate.length = ScrapHallSet.ROAD
		gate.position = Vector3(s * ScrapHallSet.SIDE_X, 0, bar_z)
		gate.rotation.y = PI * 0.5
		set.add_child(gate)
	if not EnvMesh.visual():
		return
	# (The face on the back street never sees the sun: the brick is taken lighter than it is, so that
	# it does not sink into black beside the lit yard wall across the street.)
	var brick := EnvMesh.scan("viaduct_brick", "red_brick_03", {foot = 0.7, drift = 0.3, tint = Vector3(1.34, 1.26, 1.2)})
	var dark := EnvMesh.scan("viaduct_inside", "red_brick_03", {drift = 0.2, tint = Vector3(0.7, 0.66, 0.64)})
	var frame := ChurchKit.wall_frame(Vector3.FORWARD)
	var walls := []
	var insides := []
	var stones := []
	var back := VIADUCT_Z + VIADUCT_D
	for i in BAYS:
		var x := bay_x(i)
		walls.append(EnvMesh.piece(ChurchKit.prism(arch_wall(p, DECK_H, ARCH_W, SPRING), VIADUCT_D, true), Transform3D(frame, Vector3(x, 0, back))))
		# A ring of stone round each arch.
		stones.append(EnvMesh.piece(_arch_ring(ARCH_W, SPRING, 0.0, 0.3, 0.07), Transform3D(frame, Vector3(x, 0, VIADUCT_Z))))
	for i in BAYS + 1:
		# A pilaster on every pier, on a stone foot, with a stone block where the arches spring.
		var x := -ARCADE + p * i
		walls.append(EnvMesh.piece(EnvMesh.box(Vector3(0.66, DECK_H, 0.16)), Transform3D(Basis(), Vector3(x, DECK_H * 0.5, VIADUCT_Z - 0.08))))
		stones.append(EnvMesh.piece(EnvMesh.box(Vector3(0.84, 0.3, 0.26)), Transform3D(Basis(), Vector3(x, 0.15, VIADUCT_Z - 0.11))))
		stones.append(EnvMesh.piece(EnvMesh.box(Vector3(0.8, 0.16, 0.24)), Transform3D(Basis(), Vector3(x, SPRING + 0.08, VIADUCT_Z - 0.1))))
	for s: float in [-1.0, 1.0]:
		# The street arch between its two abutments, and the solid end beyond it.
		walls.append(EnvMesh.piece(ChurchKit.prism(arch_wall(GATE_W + ABUT * 2.0, DECK_H, GATE_W, GATE_SPRING, GATE_RISE, 18), VIADUCT_D, true),
			Transform3D(frame, Vector3(s * GATE_X, 0, back))))
		stones.append(EnvMesh.piece(_arch_ring(GATE_W, GATE_SPRING, GATE_RISE, 0.42, 0.09, 18), Transform3D(frame, Vector3(s * GATE_X, 0, VIADUCT_Z))))
		walls.append(EnvMesh.piece(EnvMesh.box(Vector3(END_RUN, DECK_H, VIADUCT_D)), Transform3D(Basis(), Vector3(s * (end_from + END_RUN * 0.5), DECK_H * 0.5, mid_z))))
		for x: float in [gate_in - ABUT * 0.5, gate_out + ABUT * 0.5]:
			stones.append(EnvMesh.piece(EnvMesh.box(Vector3(ABUT + 0.12, 0.34, 0.26)), Transform3D(Basis(), Vector3(s * x, 0.17, VIADUCT_Z - 0.11))))
			stones.append(EnvMesh.piece(EnvMesh.box(Vector3(ABUT + 0.1, 0.2, 0.26)), Transform3D(Basis(), Vector3(s * x, GATE_SPRING + 0.1, VIADUCT_Z - 0.11))))
		# The barriers on the two pavements under the arch.
		for part: Array in [[gate_in, ScrapHallSet.SIDE_X - ScrapHallSet.ROAD * 0.5], [ScrapHallSet.SIDE_X + ScrapHallSet.ROAD * 0.5, gate_out]]:
			var from: float = part[0]
			var to: float = part[1]
			_cross_barrier(set, Vector3(s * (from + to) * 0.5, 0, BAR_Z), to - from - 0.15)
	# The band under the parapet, the parapet and its coping, and the deck behind, along the whole length.
	var length := (end_from + END_RUN) * 2.0
	stones.append(EnvMesh.piece(EnvMesh.box(Vector3(length, 0.22, 0.34)), Transform3D(Basis(), Vector3(0, DECK_H + 0.11, VIADUCT_Z - 0.09))))
	walls.append(EnvMesh.piece(EnvMesh.box(Vector3(length, VIADUCT_H - DECK_H - 0.22, 0.4)), Transform3D(Basis(), Vector3(0, (DECK_H + 0.22 + VIADUCT_H) * 0.5, VIADUCT_Z + 0.2))))
	stones.append(EnvMesh.piece(EnvMesh.box(Vector3(length, 0.12, 0.52)), Transform3D(Basis(), Vector3(0, VIADUCT_H + 0.06, VIADUCT_Z + 0.2))))
	walls.append(EnvMesh.piece(EnvMesh.box(Vector3(length, 0.3, VIADUCT_D)), Transform3D(Basis(), Vector3(0, DECK_H + 0.15, mid_z))))
	EnvMesh.add(set, EnvMesh.merge(walls), brick)
	EnvMesh.add(set, EnvMesh.merge(stones), TownBlock.stone())
	# What closes the arches.
	for i in BAYS:
		_close_arch(set, i, insides)
	if not insides.is_empty():
		EnvMesh.add(set, EnvMesh.merge(insides), dark)
	_viaduct_dressing(set)


## A raised ring of stone round an arch (see arch_line), `band` wide and `proud` of the wall.
static func _arch_ring(open: float, spring: float, rise: float, band: float, proud: float, steps := 14) -> ArrayMesh:
	var inner := arch_line(open, spring, rise, steps)
	var outer := PackedVector2Array()
	# The outer line: every point pushed out from the arch's own middle.
	var half := open * 0.5
	var centre := Vector2(0, spring)
	if rise > 0.0 and rise < half:
		var r := (half * half + rise * rise) / (2.0 * rise)
		centre = Vector2(0, spring + rise - r)
	for point in inner:
		outer.append(point + (point - centre).normalized() * band)
	# (An open band: closed, it would run back along the springing line right across the arch.)
	return ChurchKit.ring(inner, outer, proud, true)


## A red-and-white barrier across a pavement under a street arch: `at` its middle on the ground,
## `length` along x. Looks only (the collider across the whole arch is the viaduct's).
static func _cross_barrier(set: Node3D, at: Vector3, length: float) -> void:
	var red := StandardMaterial3D.new()
	red.albedo_color = Color("#b8362c")
	red.roughness = 0.6
	var white := StandardMaterial3D.new()
	white.albedo_color = Color("#e6e1d4")
	white.roughness = 0.6
	var reds := []
	var whites := []
	var n := maxi(int(length / 0.5), 1)
	for y: float in [0.55, 1.05]:
		for i in n:
			var piece := EnvMesh.piece(EnvMesh.box(Vector3(length / n, 0.2, 0.05)), Transform3D(Basis(), at + Vector3(-length * 0.5 + (i + 0.5) * length / n, y, 0)))
			if i % 2 == 0:
				reds.append(piece)
			else:
				whites.append(piece)
	for end: float in [-0.5, 0.5]:
		whites.append(EnvMesh.piece(EnvMesh.box(Vector3(0.09, 1.25, 0.09)), Transform3D(Basis(), at + Vector3(end * length, 0.625, 0))))
	EnvMesh.add(set, EnvMesh.merge(reds), red)
	EnvMesh.add(set, EnvMesh.merge(whites), white)


## What closes arch `index`: a bricked-up panel, a shut front with a roller shutter, or the front
## of a lock-up with its doorway (the shutter and what is inside are StorageLockup's).
static func _close_arch(set: ScrapHallSet, index: int, insides: Array) -> void:
	var use: String = USES[index]
	var x := bay_x(index)
	var frame := ChurchKit.wall_frame(Vector3.FORWARD)
	var head := SPRING + ARCH_W * 0.5
	var panel_z := VIADUCT_Z + INFILL
	if use == "":
		# Bricked up long ago: darker brick set back in the arch, a blind window in some.
		insides.append(EnvMesh.piece(EnvMesh.box(Vector3(ARCH_W, head, 0.3)), Transform3D(Basis(), Vector3(x, head * 0.5, panel_z + 0.15))))
		return
	var sheet := EnvMesh.repainted("viaduct_front", "box_profile_metal_sheet", Color("#4c5a52"), {drift = 0.12})
	if use == "lockup":
		# The front: profiled sheet in the arch with the doorway cut out.
		var outline := PackedVector2Array([Vector2(-ARCH_W * 0.5, 0), Vector2(-DOOR.x * 0.5, 0), Vector2(-DOOR.x * 0.5, DOOR.y), Vector2(DOOR.x * 0.5, DOOR.y),
			Vector2(DOOR.x * 0.5, 0), Vector2(ARCH_W * 0.5, 0)])
		var over := arch_line(ARCH_W, SPRING, 0.0)
		over.reverse()
		outline.append_array(over)
		EnvMesh.add(set, ChurchKit.prism(outline, 0.12, true), sheet, Transform3D(frame, Vector3(x, 0, panel_z + 0.12)))
		# The room behind: brick walls and the back, a concrete floor.
		insides.append(EnvMesh.piece(EnvMesh.box(Vector3(ARCH_W, head, 0.3)), Transform3D(Basis(), Vector3(x, head * 0.5, panel_z + LOCKUP_D + 0.15))))
		if not LOCKUPS_LIVE:
			PhotoProp.mount(set, "rollershutter_door:0", Vector3(x, 0, panel_z + 0.06), Vector3.FORWARD, DOOR)
		return
	# A shut front: sheet in the arch, a roller shutter (the garage's is wide), a board over it.
	var arch := PackedVector2Array([Vector2(-ARCH_W * 0.5, 0), Vector2(ARCH_W * 0.5, 0)])
	var top := arch_line(ARCH_W, SPRING, 0.0)
	top.reverse()
	arch.append_array(top)
	EnvMesh.add(set, ChurchKit.prism(arch, 0.12, true), sheet, Transform3D(frame, Vector3(x, 0, panel_z + 0.12)))
	var wide := 3.1 if use == "garage" else 2.5
	PhotoProp.mount(set, "rollershutter_door:" + ("1" if use == "store" else "0"), Vector3(x, 0, panel_z), Vector3.FORWARD, Vector2(wide, 2.45))


## Signs and lamps on the viaduct, the backdrop beyond the street arches (visual only).
static func _viaduct_dressing(set: ScrapHallSet) -> void:
	var head := SPRING + ARCH_W * 0.5
	# Boards over the shut fronts.
	var boards := {"office": ["U-STORE-IT · OFFICE", Color("#1d3b2c"), Color("#e9dfc4")], "garage": ["AUTO REPAIR", Color("#7a2a22"), Color("#f1e7cf")]}
	var seen := {}
	for i in BAYS:
		var use: String = USES[i]
		if not boards.has(use):
			continue
		var x := bay_x(i)
		# (Two arches side by side share one long board.)
		if seen.has(use):
			continue
		var span := 1
		while i + span < BAYS and USES[i + span] == use:
			span += 1
		seen[use] = true
		var mid := x + pitch() * (span - 1) * 0.5
		var text: String = boards[use][0]
		var width := maxf(2.6, 0.6 + text.length() * 0.21)
		var board := StandardMaterial3D.new()
		board.albedo_color = boards[use][1]
		board.roughness = 0.7
		EnvMesh.add(set, EnvMesh.box(Vector3(width, 0.56, 0.05), 0.02), board, Transform3D(Basis(), Vector3(mid, head + 0.75, VIADUCT_Z - 0.2)))
		StationKit.label(set, text, Transform3D(Basis(Vector3.UP, PI), Vector3(mid, head + 0.75, VIADUCT_Z - 0.235)), 110, boards[use][2], 800, 0.0034)
		if use == "garage":
			StationKit.label(set, "OPENING SOON", Transform3D(Basis(Vector3.UP, PI), Vector3(mid, head + 0.3, VIADUCT_Z - 0.235)), 64, Color("#e8dcc0"), 600, 0.003)
	# A lamp on every other pier along the back street.
	for i in range(1, BAYS, 2):
		PhotoProp.mount(set, "industrial_wall_lamp", Vector3(-ARCADE + pitch() * i, 3.5, VIADUCT_Z - 0.16), Vector3.FORWARD)
	for s: float in [-1.0, 1.0]:
		# Under the street arches it is dusk: two lamps on the walls, and a sign for those on foot.
		for z: float in [VIADUCT_Z + 2.0, VIADUCT_Z + 6.0]:
			var lamp := OmniLight3D.new()
			lamp.light_color = Color("#ffd9a0")
			lamp.light_energy = 1.1
			lamp.omni_range = 7.0
			lamp.shadow_enabled = false
			lamp.position = Vector3(s * GATE_X, 3.6, z)
			set.add_child(lamp)
		# (On the barrier across the outer pavement, between its posts.)
		var sign_at := Vector3(s * (GATE_X + GATE_W * 0.5 - 1.1), 1.02, BAR_Z - 0.06)
		var plate := StandardMaterial3D.new()
		plate.albedo_color = Color("#e9e4d6")
		plate.roughness = 0.6
		EnvMesh.add(set, EnvMesh.box(Vector3(1.5, 0.5, 0.03), 0.01), plate, Transform3D(Basis(), sign_at))
		StationKit.label(set, "NO WAY THROUGH", Transform3D(Basis(Vector3.UP, PI), sign_at + Vector3(0, 0.1, -0.02)), 60, Color("#a3271f"), 800, 0.0032)
		StationKit.label(set, "ON FOOT", Transform3D(Basis(Vector3.UP, PI), sign_at + Vector3(0, -0.12, -0.02)), 60, Color("#a3271f"), 800, 0.0032)
		# Beyond the cross road a row of houses closes the view through the arch.
		TownBlock.block(set, Vector3(s * (GATE_X + 4.0), 0, NORTH_Z + ScrapHallSet.ROAD * 0.5 + 2.4), 34.0, 9.0, {key = "north_" + ("e" if s > 0.0 else "w"),
			scan = "painted_worn_brick" if s > 0.0 else "red_brick", storeys = 3})


# --- What stands in the new streets ---------------------------------------------------------------

## The side streets, the back street and the two passages: lamps, parked cars, containers and bins
## along the yard wall, trees, the pillars and boards of the passages and the names of the streets.
## What is solid comes first: its colliders are wanted on a headless host too.
static func dressing(set: ScrapHallSet, zf: float) -> void:
	var side := ScrapHallSet.SIDE_X
	var road := ScrapHallSet.ROAD
	var front := ScrapHallSet.FRONT_Z
	var out_kerb := side + road * 0.5
	var lamp := {scale = 1.0, solid = PropKit.Solid.CYLINDER}
	for x: float in [-33.0, -13.5, 9.0, 33.5]:
		set.prop("kaykit_city/streetlight.gltf", Vector3(x, 0, BACK_KERB_S - 0.6), 0.0, lamp)
	set.prop("kaykit_city/streetlight.gltf", Vector3(out_kerb + 0.6, 0, 27.0), 270.0, lamp)
	set.prop("kaykit_city/streetlight.gltf", Vector3(-out_kerb - 0.6, 0, 27.0), 90.0, lamp)
	# Parked along the back street: a saloon and a small car at the yard wall's kerb, a van in front
	# of the garage under the arches.
	ParkedVehicle.place(set, ParkedVehicle.CAR_SALOON, Vector3(-23.0, 0, BACK_KERB_S + 0.95), 180.0, Color("#5c5f52"))
	ParkedVehicle.place(set, ParkedVehicle.CAR_SMALL, Vector3(15.0, 0, BACK_KERB_S + 0.92), 0.0, Color("#8a8f96"))
	# (The van stands clear of the crossing at the alley's end.)
	ParkedVehicle.place(set, ParkedVehicle.VAN, Vector3(bay_x(14) + 1.0, 0, BACK_KERB_N - 1.2), 180.0)
	TownBlock.dumpster(set, Vector3(-18.6, 0, BACK_NEAR + 0.6), 0.0)
	TownBlock.dumpster(set, Vector3(20.4, 0, BACK_NEAR + 0.6), 0.0)
	PhotoProp.place(set, "metal_trash_can", Vector3(PASSAGE.y + 0.9, 0, BACK_NEAR + 0.45), 0.0)
	PhotoProp.place(set, "utility_box_01", Vector3(-36.0, 0, BACK_NEAR + 0.35), 0.0)
	# On the pavements of the side streets, against the houses beyond them.
	# (The bin stands clear of the post office's door and windows.)
	PhotoProp.place(set, "metal_trash_can", Vector3(FAR_X - 0.4, 0, POST_TO + 1.2), 270.0)
	PhotoProp.place(set, "utility_box_01", Vector3(-FAR_X + 0.35, 0, 33.4), 90.0)
	PhotoProp.place(set, "painted_wooden_bench", Vector3(-FAR_X + 0.4, 0, 24.4), 90.0)
	for x: float in [-ARCADE + pitch() * 3.0, -ARCADE + pitch() * 5.0, -ARCADE + pitch() * 13.0]:
		TownBlock.street_tree(set, Vector3(x, 0, BACK_KERB_N + 0.95), x * 37.0, 0.95)
	# The passage beside the dealer's and the alley beside the bank: a brick pillar on either side
	# where they come out through the yard wall.
	var wall_z := front + ScrapHallSet.HOUSE_D + 0.15
	var pillars := []
	for x: float in [PASSAGE.x + 0.28, PASSAGE.y - 0.28, ALLEY_EAST.x + 0.2, ALLEY_EAST.y - 0.2]:
		var wide := 0.56 if x < 0.0 else 0.4
		WorldBuilder.add_collider(set, Vector3(wide, 3.3, 0.56), Transform3D(Basis(), Vector3(x, 1.65, wall_z)))
		pillars.append(EnvMesh.piece(EnvMesh.box(Vector3(wide, 3.3, 0.56)), Transform3D(Basis(), Vector3(x, 1.65, wall_z))))
	if not EnvMesh.visual():
		return
	EnvMesh.add(set, EnvMesh.merge(pillars), EnvMesh.scan("town_yardwall", "red_brick_03", {foot = 0.6, drift = 0.22}))
	var caps := []
	for x: float in [PASSAGE.x + 0.28, PASSAGE.y - 0.28, ALLEY_EAST.x + 0.2, ALLEY_EAST.y - 0.2]:
		caps.append(EnvMesh.piece(EnvMesh.box(Vector3(0.7 if x < 0.0 else 0.52, 0.1, 0.7)), Transform3D(Basis(), Vector3(x, 3.35, wall_z))))
	EnvMesh.add(set, EnvMesh.merge(caps), TownBlock.stone())
	# Boards over the two ways through, for those who look from the main street.
	_way_board(set, Vector3((PASSAGE.x + PASSAGE.y) * 0.5, 3.0, front + 0.2), 3.4, "PASSAGE TO VIADUCT LANE", PASSAGE.y - PASSAGE.x)
	_way_board(set, Vector3((ALLEY_EAST.x + ALLEY_EAST.y) * 0.5, 2.85, front + 0.2), 2.2, "VIADUCT LANE")
	# The names of the streets on the corners.
	_name_plate(set, Vector3(-38.2, 2.55, BACK_NEAR + 0.012), 0.0, "VIADUCT LANE")
	_name_plate(set, Vector3(38.2, 2.55, BACK_NEAR + 0.012), 0.0, "VIADUCT LANE")
	_name_plate(set, Vector3(ScrapHallSet.HARDWARE.x - ScrapHallSet.SHOP_W * 0.5 - 0.012, 2.6, front + 1.4), -90.0, "MILL STREET")
	_name_plate(set, Vector3(ScrapHallSet.BANK.x + ScrapHallSet.SHOP_W * 0.5 + 0.012, 2.6, front + 1.4), 90.0, "BANK STREET")
	_name_plate(set, Vector3(-36.5, 1.95, zf + 0.012), 0.0, "FOUNDRY ROW")
	_name_plate(set, Vector3(36.5, 1.95, zf + 0.012), 0.0, "FOUNDRY ROW")
	# Odds and ends: bags by the containers, crates and tyres by the garage, covers in the road.
	PhotoProp.place(set, "trashbag", Vector3(-17.3, 0, BACK_NEAR + 0.45), 30.0, false)
	PhotoProp.place(set, "trashbag", Vector3(21.8, 0, BACK_NEAR + 0.5), 200.0, false)
	PhotoProp.place(set, "trashbag", Vector3(22.3, 0, BACK_NEAR + 0.4), 80.0, false)
	PhotoProp.place(set, "wooden_crate_02", Vector3(bay_x(14) + 1.2, 0, VIADUCT_Z - 0.5), 12.0, false)
	PhotoProp.place(set, "old_tyre", Vector3(bay_x(14) + 2.0, 0, VIADUCT_Z - 0.45), 0.0, false)
	PhotoProp.place(set, "plastic_crate_02", Vector3(bay_x(5) - 1.3, 0, VIADUCT_Z - 0.4), 100.0, false)
	PhotoProp.place(set, "water_manhole_cover", Vector3(-9.0, 0.021, BACK_Z + 0.8), 20.0, false)
	PhotoProp.place(set, "water_manhole_cover", Vector3(24.0, 0.021, BACK_Z - 0.9), 60.0, false)
	PhotoProp.place(set, "water_manhole_cover", Vector3(side - 0.8, 0.021, 24.0), 0.0, false)
	PhotoProp.place(set, "water_manhole_cover", Vector3(-side + 0.9, 0.021, 28.0), 45.0, false)
	PhotoProp.mount(set, "exterior_aircon_unit:0", Vector3(-11.0, 2.3, BACK_NEAR), Vector3.BACK)
	PhotoProp.mount(set, "exterior_aircon_unit:0", Vector3(17.0, 2.3, BACK_NEAR), Vector3.BACK)


## A painted board over a way through the row: `at` its middle, `width` wide; it looks to the main
## street. Where the way is wider than the board (`span`, from wall to wall), it hangs from an iron
## rail across it; else two arms hold it between the houses.
static func _way_board(set: Node3D, at: Vector3, width: float, text: String, span := 0.0) -> void:
	var board := StandardMaterial3D.new()
	board.albedo_color = Color("#22342c")
	board.roughness = 0.7
	EnvMesh.add(set, EnvMesh.box(Vector3(width, 0.46, 0.05), 0.02), board, Transform3D(Basis(), at))
	var iron := StationKit.metal("way_board_iron", {steel_color = Color("#2c2f31"), rust = 0.3, metallic_steel = 0.6})
	if span > width:
		EnvMesh.add(set, EnvMesh.box(Vector3(span, 0.07, 0.07)), iron, Transform3D(Basis(), at + Vector3(0, 0.44, 0)))
		for s: float in [-1.0, 1.0]:
			EnvMesh.add(set, EnvMesh.box(Vector3(0.04, 0.2, 0.04)), iron, Transform3D(Basis(), at + Vector3(s * (width * 0.5 - 0.3), 0.32, 0)))
			EnvMesh.add(set, EnvMesh.box(Vector3(0.12, 0.2, 0.12)), iron, Transform3D(Basis(), at + Vector3(s * (span * 0.5 - 0.06), 0.44, 0)))
	else:
		for s: float in [-1.0, 1.0]:
			EnvMesh.add(set, EnvMesh.box(Vector3(0.05, 0.05, 0.4)), iron, Transform3D(Basis(), at + Vector3(s * (width * 0.5 - 0.15), 0.1, 0.2)))
	StationKit.label(set, text, Transform3D(Basis(Vector3.UP, PI), at + Vector3(0, 0, -0.035)), 84, Color("#e9dfc4"), 800, 0.003)


## A street's name on a wall: a white enamel plate with dark letters. `at` its middle on the wall,
## `yaw` (degrees) the way the wall looks: 0 north (+z), 90 east (+x), -90 west.
static func _name_plate(set: Node3D, at: Vector3, yaw: float, text: String) -> void:
	var turn := Basis(Vector3.UP, deg_to_rad(yaw))
	var plate := StandardMaterial3D.new()
	plate.albedo_color = Color("#e8e6dd")
	plate.roughness = 0.35
	var width := 0.3 + text.length() * 0.105
	EnvMesh.add(set, EnvMesh.box(Vector3(width, 0.24, 0.02), 0.008), plate, Transform3D(turn, at), false)
	StationKit.label(set, text, Transform3D(turn, at + turn * Vector3(0, 0, 0.014)), 56, Color("#1d2a3a"), 800, 0.0026)
