class_name StorageAuction
extends Node3D
## The auctioneer of the storage auctions under the viaduct. He stands at his desk on the pavement
## in front of the lock-ups (StorageLockup) and calls their bidding out: a line over his head on
## every screen, an arm in the air, the hammer when a lot is knocked down. The host's lock-ups tell
## him what to say; he says it to everybody. Stands with his back to the viaduct and looks at the
## bidders (-z).

const GROUP := &"storage_auctions"
## A call stays up this long (s).
const SAY_TIME := 4.6
## Where his chalkboard stands (from the desk).
const BOARD := Vector3(0.5, 0, -1.55)

var _bubble: Label3D
var _bubble_left := 0.0
var _man: TownNpc


static func of(tree: SceneTree) -> StorageAuction:
	return tree.get_first_node_in_group(GROUP) as StorageAuction if tree else null


func _init() -> void:
	name = "StorageAuction"


func _ready() -> void:
	add_to_group(GROUP)
	# The desk stops people (the auctioneer behind it is only to look at).
	WorldBuilder.add_collider(self, Vector3(0.74, 1.15, 0.5), Transform3D(Basis(), Vector3(0, 0.575, 0)))
	# (The board stands by the kerb, clear of the lock-ups' doors.)
	PhotoProp.place(self, "standing_chalkboard_01", BOARD, 188.0)
	if StationKit.visual():
		_build()


## Host: he calls `text` out; with `hammer` the lot is knocked down, with `won` to the crew.
func call_out(text: String, hammer := false, won := false) -> void:
	if not Network.is_sim_authority():
		return
	if Network.is_online():
		_said.rpc(text, hammer, won)
	else:
		_said(text, hammer, won)


@rpc("authority", "call_local", "reliable")
func _said(text: String, hammer: bool, won: bool) -> void:
	if hammer:
		Sfx.play(&"hammer_clank", global_position + Vector3(0, 1.2, 0), -2.0, 0.05)
	if won:
		Sfx.play(&"reveal_fanfare", global_position + Vector3(0, 1.6, 0), -6.0, 0.0)
	if _man:
		_man.wave()
	if _bubble == null:
		return
	_bubble.text = text
	_bubble.visible = true
	_bubble_left = SAY_TIME


func _process(delta: float) -> void:
	if _bubble_left > 0.0:
		_bubble_left -= delta
		if _bubble_left <= 0.0 and _bubble:
			_bubble.visible = false


func _build() -> void:
	# The desk: a sloping top on a boarded front, dark stained, with the house's name on it.
	var wood := EnvMesh.wood("auction_desk", {base_color = Color("#4a3423"), grain_color = Color("#2a1c12"), weathering = 0.35, roughness_base = 0.6})
	var parts := []
	parts.append(EnvMesh.piece(EnvMesh.box(Vector3(0.7, 1.05, 0.06)), Transform3D(Basis(), Vector3(0, 0.525, -0.2))))
	for s: float in [-1.0, 1.0]:
		parts.append(EnvMesh.piece(EnvMesh.box(Vector3(0.06, 1.05, 0.46)), Transform3D(Basis(), Vector3(s * 0.32, 0.525, 0.0))))
	parts.append(EnvMesh.piece(EnvMesh.box(Vector3(0.8, 0.05, 0.56)), Transform3D(Basis(Vector3.RIGHT, -0.22), Vector3(0, 1.1, 0.0))))
	parts.append(EnvMesh.piece(EnvMesh.box(Vector3(0.7, 0.05, 0.4)), Transform3D(Basis(), Vector3(0, 0.3, 0.02))))
	EnvMesh.add(self, EnvMesh.merge(parts), wood)
	StationKit.label(self, "U-STORE-IT", Transform3D(Basis(Vector3.UP, PI), Vector3(0, 0.78, -0.235)), 56, Color("#e6cf8a"), 800, 0.003)
	StationKit.label(self, "AUCTIONS", Transform3D(Basis(Vector3.UP, PI), Vector3(0, 0.56, -0.235)), 46, Color("#e6cf8a"), 700, 0.003)
	# The hammer and its block on the desk.
	var iron := StationKit.metal("auction_hammer", {steel_color = Color("#3a332c"), rust = 0.1, metallic_steel = 0.2, roughness_steel = 0.6})
	EnvMesh.add(self, EnvMesh.cylinder(0.07, 0.07, 0.03, 12), wood, Transform3D(Basis(), Vector3(0.18, 1.11, -0.05)))
	EnvMesh.add(self, EnvMesh.cylinder(0.035, 0.035, 0.12, 10), iron, Transform3D(Basis(Vector3.FORWARD, PI * 0.5), Vector3(-0.12, 1.16, -0.03)))
	EnvMesh.add(self, EnvMesh.cylinder(0.012, 0.012, 0.24, 8), wood, Transform3D(Basis(Vector3.RIGHT, PI * 0.5), Vector3(-0.12, 1.15, 0.1)))
	# The board beside him: what this is.
	var face := Transform3D(Basis(Vector3.UP, deg_to_rad(188.0)), BOARD) * Transform3D(Basis(Vector3.RIGHT, -0.21), Vector3(0.0, 0.88, 0.188))
	var chalk := Color(0.93, 0.92, 0.87, 0.92)
	StationKit.label(self, "AUCTION", face * Transform3D(Basis(), Vector3(0, 0.36, 0)), 96, Color(0.95, 0.82, 0.4, 0.92), 700, 0.0022, StationKit.chalk_font())
	StationKit.label(self, "TODAY", face * Transform3D(Basis(), Vector3(0, 0.15, 0)), 96, Color(0.95, 0.82, 0.4, 0.92), 700, 0.0022, StationKit.chalk_font())
	StationKit.label(self, "lots sold unseen", face * Transform3D(Basis(), Vector3(0, -0.08, 0)), 50, chalk, 500, 0.0022, StationKit.hand_font())
	StationKit.label(self, "cash only", face * Transform3D(Basis(), Vector3(0, -0.28, 0)), 58, chalk, 500, 0.0022, StationKit.hand_font())
	# Under the viaduct it is always shade: a lamp on the pier behind him, lit all day.
	PhotoProp.mount(self, "industrial_wall_lamp", Vector3(0, 3.05, 1.09), Vector3.FORWARD)
	var lamp := OmniLight3D.new()
	lamp.light_color = Color("#ffdcae")
	lamp.light_energy = 1.5
	lamp.omni_range = 6.5
	lamp.omni_attenuation = 1.2
	lamp.shadow_enabled = false
	lamp.position = Vector3(0, 2.75, 0.55)
	add_child(lamp)
	_man = TownNpc.make("Auctioneer")
	_man.position = Vector3(0, 0, 0.62)
	_man.rotation.y = PI
	add_child(_man)
	_bubble = StationKit.label(self, "", Transform3D(), 52, Color("#fff8e6"), 600, 0.0017)
	_bubble.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_bubble.outline_size = 14
	_bubble.outline_modulate = Color(0.08, 0.07, 0.05, 0.92)
	_bubble.position = Vector3(0, 2.3, 0.5)
	_bubble.no_depth_test = true
	_bubble.visible = false
