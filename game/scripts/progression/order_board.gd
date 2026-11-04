class_name OrderBoard
extends Node3D
## Cork board with three order cards (garage and later halls). An order asks
## for a casting of an alloy and grade, or for a bronze buddy; selling a
## matching piece in the sell crate pays the order's bonus on top
## (SellCrate -> `fulfil`). The host owns the orders, peers mirror them.
## The first card is always the garage's first Bronzefreund order.

signal changed

const SLOTS := 3
## Seconds until an empty slot gets a new order.
const REFILL_DELAY := 12.0
## Order templates. kind: &"statue" (a BronzeStatue) or &"cast" (a CastPiece of
## `alloy`, &"" = any, with quality >= `min`).
const TEMPLATES := [
	{id = &"bronze_buddy", kind = &"statue", title = "Bronzefreund für den Vorgarten", need = "Eine Bronzestatue in Sturzpose", reward = 350, weight = 2},
	{id = &"knocker", kind = &"cast", alloy = &"brass", min = 0.35, title = "Türklopfer aus Messing", need = "Messing · mind. Gut", reward = 90, weight = 5},
	{id = &"trophy", kind = &"cast", alloy = &"", min = 0.6, title = "Pokal für den Kegelverein", need = "Beliebiges Metall · mind. Fein", reward = 110, weight = 5},
	{id = &"plaque", kind = &"cast", alloy = &"verdigris", min = 0.35, title = "Grünspan-Plakette fürs Rathaus", need = "Grünspan · mind. Gut", reward = 160, weight = 3},
	{id = &"statuette", kind = &"cast", alloy = &"bronze", min = 0.6, title = "Bronze-Statuette", need = "Bronze · mind. Fein", reward = 130, weight = 4},
	{id = &"ring", kind = &"cast", alloy = &"rotgold", min = 0.35, title = "Rotgold-Anhänger für Tante Erna", need = "Rotgold · mind. Gut", reward = 220, weight = 2},
	{id = &"mirror", kind = &"cast", alloy = &"", min = 0.95, title = "Spiegelguss für die Galerie", need = "Beliebig · Spiegelguss", reward = 300, weight = 1},
]

## Active orders: template ids, &"" for an empty slot.
var slots: Array[StringName] = []
var _refill := [0.0, 0.0, 0.0]
var _cards: Array[Label3D] = []


func _ready() -> void:
	physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
	add_to_group(&"interactable")
	add_to_group(&"order_boards")
	slots.resize(SLOTS)
	slots.fill(&"")
	if Network.is_sim_authority():
		slots[0] = &"bronze_buddy"
		for i in range(1, SLOTS):
			slots[i] = _roll()
	Network.peer_ready.connect(_on_peer_ready)
	_build_art()
	_refresh()


static func template(id: StringName) -> Dictionary:
	for t in TEMPLATES:
		if t.id == id:
			return t
	return {}


## Host: pays the bonus of the first order `piece` fulfils (0 if none).
static func fulfil(world: GameWorld, piece: Node) -> int:
	for node in world.get_tree().get_nodes_in_group(&"order_boards"):
		var board := node as OrderBoard
		var bonus := board._take(piece)
		if bonus > 0:
			return bonus
	return 0


static func matches(t: Dictionary, piece: Node) -> bool:
	if t.is_empty():
		return false
	if t.kind == &"statue":
		return piece is BronzeStatue
	if not piece is CastPiece:
		return false
	var cast := piece as CastPiece
	return (t.alloy == &"" or cast.alloy == t.alloy) and cast.quality >= float(t.min)


func _take(piece: Node) -> int:
	for i in slots.size():
		var t := template(slots[i])
		if matches(t, piece):
			slots[i] = &""
			_refill[i] = REFILL_DELAY
			_broadcast()
			var world := get_tree().get_first_node_in_group(&"world") as GameWorld
			if world:
				world.banner_all("AUFTRAG ERLEDIGT!", Color("#7fd3a8"), "%s · +%d $ Bonus" % [t.title, t.reward])
			return int(t.reward)
	return 0


func _roll() -> StringName:
	var pool := TEMPLATES.filter(func(t: Dictionary) -> bool: return not slots.has(t.id))
	var total := 0
	for t in pool:
		total += int(t.weight)
	var r := randi() % maxi(total, 1)
	for t in pool:
		r -= int(t.weight)
		if r < 0:
			return t.id
	return &"trophy"


func _physics_process(delta: float) -> void:
	if not Network.is_sim_authority():
		return
	for i in slots.size():
		if slots[i] == &"" and _refill[i] > 0.0:
			_refill[i] -= delta
			if _refill[i] <= 0.0:
				slots[i] = _roll()
				_broadcast()


func _broadcast() -> void:
	_refresh()
	if Network.is_online() and multiplayer.is_server():
		_sync.rpc(PackedStringArray(slots.map(func(s: StringName) -> String: return String(s))))


func _on_peer_ready(id: int, level: String) -> void:
	var world := get_tree().get_first_node_in_group(&"world") as GameWorld
	if is_inside_tree() and multiplayer.is_server() and world and level == world.level_path():
		_sync.rpc_id(id, PackedStringArray(slots.map(func(s: StringName) -> String: return String(s))))


@rpc("authority", "call_remote", "reliable")
func _sync(ids: PackedStringArray) -> void:
	for i in mini(ids.size(), slots.size()):
		slots[i] = StringName(ids[i])
	_refresh()


func _refresh() -> void:
	for i in _cards.size():
		var t := template(slots[i]) if i < slots.size() else {}
		_cards[i].text = "%s\n%s\n+%d $" % [t.title, t.need, t.reward] if not t.is_empty() else "Neuer Auftrag\nkommt gleich…"
	changed.emit()


func interact_point() -> Vector3:
	return global_position + Vector3(0, 1.1, 0) + global_transform.basis.z * 0.3


func hint(_player: Node) -> String:
	return "Aufträge – passendes Gussteil (oder Bronzefreund) in die Verkaufskiste = Bonus"


func interact(_player: Node) -> void:
	pass


# --- Art -------------------------------------------------------------------------

## Wall-mounted cork board (faces +Z): frame, three pinned paper cards with text.
func _build_art() -> void:
	if not StationKit.visual():
		return
	var frame := StationKit.wood("order_frame", {base_color = Color("#6d4c32"), weathering = 0.2})
	var cork := EnvMesh.surface("order_cork", {base_color = Color("#b98a5a"), stain_color = Color("#8a6040"), stains = 0.4,
		roughness_base = 0.95, macro = 0.15, grain = 0.2, noise_scale = 8.0})
	var size := Vector2(1.5, 0.95)
	var y := 1.55
	StationKit.add(self, EnvMesh.box(Vector3(size.x, size.y, 0.03), 0.004), cork, Transform3D(Basis(), Vector3(0, y, 0.015)))
	var bars := []
	for s: float in [-1.0, 1.0]:
		bars.append(EnvMesh.piece(EnvMesh.box(Vector3(size.x + 0.1, 0.05, 0.05)), Transform3D(Basis(), Vector3(0, y + s * (size.y + 0.05) * 0.5, 0.03))))
		bars.append(EnvMesh.piece(EnvMesh.box(Vector3(0.05, size.y, 0.05)), Transform3D(Basis(), Vector3(s * (size.x + 0.05) * 0.5, y, 0.03))))
	StationKit.add_merged(self, bars, frame)
	StationKit.label(self, "AUFTRÄGE", Transform3D(Basis(), Vector3(0, y + size.y * 0.5 + 0.12, 0.04)), 96, Color("#f0e2c4"), 800, 0.0016)
	var paper := StationKit.paper()
	var pin := StandardMaterial3D.new()
	pin.albedo_color = Color("#c0392b")
	for i in SLOTS:
		var x := -size.x * 0.5 + size.x * (i + 0.5) / SLOTS
		var tilt: float = [-0.05, 0.03, -0.02][i]
		var card := MeshInstance3D.new()
		card.mesh = EnvMesh.box(Vector3(0.42, 0.62, 0.006), 0.002)
		card.material_override = paper
		card.transform = Transform3D(Basis(Vector3.BACK, tilt), Vector3(x, y - 0.03, 0.04))
		add_child(card)
		var p := MeshInstance3D.new()
		p.mesh = EnvMesh.sphere(0.018, 8, 5)
		p.material_override = pin
		p.position = Vector3(x, y + 0.24, 0.05)
		add_child(p)
		var l := StationKit.label(self, "", Transform3D(Basis(Vector3.BACK, tilt), Vector3(x, y - 0.03, 0.046)), 30, Color("#2a2522"), 700, 0.0011)
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		l.width = 340
		_cards.append(l)
