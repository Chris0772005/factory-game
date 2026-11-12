class_name AutoIron
extends Node3D
## The Eisenhalle's last hand work, automated (tier 3):
##   auto_charger  a feeder belt throws iron scrap into the cupola's skip
##   auto_blast    the blower runs by itself while there is work
##   auto_tap      a floor channel pumps iron from the hearth straight into
##                 the mold line's pouring box (needs the Gießautomat)
## One cabinet by the blower switches all three off and on (bronze for a
## bell needs the hearth to itself). Host simulates.

const CHARGE_EVERY := 5.0
const CHARGE := 6.0               ## litres of iron per charge
const PUMP_RATE := 1.6            ## litres per second through the channel
const PUMP_TEMP := 0.5

var cupola: CupolaFurnace
var line: MoldLine
var enabled := true
var flowing := false

var _charge_timer := 0.0
var _sync_accum := 0.0
var _belt: Node3D
var _belt_mat: ShaderMaterial
var _belt_offset := 0.0
var _channel: Node3D
var _glow: StandardMaterial3D
var _cabinet: Node3D
var _lamps: Array = []
var _stream: PourStream
var _spout := Vector3.ZERO


static func build_for(world: Node3D) -> AutoIron:
	var c := world.get_tree().get_first_node_in_group(&"cupolas") as CupolaFurnace
	var l := world.get_tree().get_first_node_in_group(&"mold_lines") as MoldLine
	if c == null or l == null or not world.is_ancestor_of(c) or not world.is_ancestor_of(l):
		return null
	var auto := AutoIron.new()
	auto.name = "AutoIron"
	auto.cupola = c
	auto.line = l
	world.add_child(auto)
	return auto


func _ready() -> void:
	physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
	add_to_group(&"auto_irons")
	add_to_group(&"interactable")
	Network.peer_ready.connect(func(id: int) -> void:
		if Network.is_sim_authority():
			_sync.rpc_id(id, enabled, flowing))
	_build()


func has(id: StringName) -> bool:
	var world := get_tree().get_first_node_in_group(&"world") as GameWorld
	return world != null and world.has_upgrade(id)


func any() -> bool:
	return has(&"auto_charger") or has(&"auto_blast") or has(&"auto_tap")


# --- The switch (interactable) ---------------------------------------------------

func cabinet_position() -> Vector3:
	return cupola.to_global(CupolaFurnace.BLOWER_POS + Vector3(-0.75, 0, 0.75))


func interact_point() -> Vector3:
	return cabinet_position() + Vector3(0, 1.0 if any() else -50.0, 0)


func hint(_player: Node) -> String:
	return "[F] Eisen-Automatik AUS (Ofen frei für Glockenbronze)" if enabled else "[F] Eisen-Automatik wieder AN"


func interact(_player: Node) -> void:
	enabled = not enabled
	Sfx.play(&"pop", interact_point(), -2.0)
	if Network.is_online():
		_sync.rpc(enabled, flowing)


@rpc("authority", "call_remote", "unreliable_ordered")
func _sync(on: bool, flow: bool) -> void:
	enabled = on
	flowing = flow


# --- Simulation (host) -----------------------------------------------------------

func _physics_process(delta: float) -> void:
	if Network.is_sim_authority():
		_simulate(delta)
		if Network.is_online():
			_sync_accum += delta
			if _sync_accum > 0.25:
				_sync_accum = 0.0
				_sync.rpc(enabled, flowing)
	_animate(delta)


## True while the hearth holds (almost) only iron: bronze is never pumped away.
func _iron_bath() -> bool:
	var iron: float = cupola.mix.get(&"iron", 0.0)
	return cupola.bath <= 0.01 or iron / maxf(cupola.bath, 0.0001) > 0.9


func _wanted() -> bool:
	return line.pattern != "" and line.has_tundish() and line.tundish < MoldLine.TUNDISH_CAPACITY - 0.5


func _simulate(delta: float) -> void:
	flowing = false
	if not enabled:
		return
	var iron := _iron_bath()
	if has(&"auto_charger") and iron and _wanted() and cupola.charge.size() < 2 and cupola.bath < 40.0:
		_charge_timer += delta
		if _charge_timer >= CHARGE_EVERY:
			_charge_timer = 0.0
			cupola.charge.append({&"iron": CHARGE})
			cupola._skip_anim = 1.0
			cupola._skip_fx_all()
			Sfx.play(&"scrap_clatter", cupola.to_global(CupolaFurnace.SKIP_POS + Vector3(0, 0.5, 0)), -4.0)
	if has(&"auto_blast") and (not cupola.charge.is_empty() or cupola.bath > 0.5):
		cupola.heat = maxf(cupola.heat, move_toward(cupola.heat, 0.94, delta * 0.3))
	if has(&"auto_tap") and iron and _wanted() and cupola.bath > 0.05 and cupola.temperature >= PUMP_TEMP and not cupola.tap_open:
		var litres := minf(minf(cupola.bath, PUMP_RATE * delta), MoldLine.TUNDISH_CAPACITY - line.tundish)
		var share := {}
		for k in cupola.mix:
			share[k] = cupola.mix[k] / maxf(cupola.bath, 0.0001) * litres
			cupola.mix[k] -= share[k]
		cupola.bath -= litres
		if cupola.bath <= 0.001:
			cupola.bath = 0.0
			cupola.mix.clear()
		line.receive_at(line.to_global(MoldLine.TUNDISH_POS + Vector3(0, MoldLine.TUNDISH_TOP + 0.2, 0)), litres, cupola.temperature, share, PUMP_RATE, delta)
		flowing = true


# --- Presentation -------------------------------------------------------------------

func _animate(delta: float) -> void:
	if _belt:
		_belt.visible = has(&"auto_charger")
		if _belt.visible and enabled and _belt_mat:
			_belt_offset += delta * 0.6
			_belt_mat.set_shader_parameter(&"offset", _belt_offset)
	if _channel:
		_channel.visible = has(&"auto_tap")
		_glow.emission_energy_multiplier = move_toward(_glow.emission_energy_multiplier, 3.2 if flowing else 0.0, delta * 4.0)
		_glow.albedo_color = Color("#2a1c16").lerp(Color("#ff9a3a"), clampf(_glow.emission_energy_multiplier / 3.2, 0.0, 1.0))
	if _cabinet:
		_cabinet.visible = any()
		(_lamps[0] as StandardMaterial3D).emission_energy_multiplier = 2.4 if enabled else 0.05
		(_lamps[1] as StandardMaterial3D).emission_energy_multiplier = 2.6 if flowing else 0.1
	if _stream:
		_stream.flow = 0.45 if flowing and _channel.visible else 0.0
		_stream.temperature = maxf(0.6, cupola.temperature)


func _build() -> void:
	if not StationKit.visual():
		return
	var res := AutoArt.mold_unit(self, cabinet_position(), cupola.global_position)
	_cabinet = res[0]
	_lamps = [res[1], res[2]]
	# Feeder belt from the iron heap up to the skip.
	var heap: Node3D = null
	for s in get_parent().get_children():
		if s is ChargeSupply and (s as ChargeSupply).look == &"iron":
			heap = s
	var skip := cupola.to_global(CupolaFurnace.SKIP_POS + Vector3(0, CupolaFurnace.SKIP_SIZE.y + 0.25, 0))
	if heap:
		var from := heap.global_position + (skip - heap.global_position).normalized() * 0.7
		from.y = 0.5
		var to := skip - Vector3(skip.x - from.x, 0, skip.z - from.z).normalized() * 0.3
		var x := (to - from).normalized()
		var z := x.cross(Vector3.UP).normalized()
		_belt = Node3D.new()
		_belt.transform = Transform3D(Basis(x, z.cross(x), z), from)
		add_child(_belt)
		var length := from.distance_to(to)
		_belt_mat = MachineArt.conveyor(_belt, length, 0.42)
		var legs := []
		for u: float in [0.15, 0.85]:
			var top := from + x * length * u + Vector3(0, -0.12, 0)
			for s: float in [-1.0, 1.0]:
				var p := top + z * s * 0.24
				legs.append(EnvMesh.piece(EnvMesh.box(Vector3(0.05, p.y, 0.05), 0.012, 2), Transform3D(Basis(), Vector3(p.x, p.y * 0.5, p.z))))
		# Legs are in world space: parent them to a node that undoes the belt frame.
		var world_space := Node3D.new()
		_belt.add_child(world_space)
		world_space.global_transform = Transform3D()
		StationKit.add_merged(world_space, legs, MachineArt.galv_mat())
	# Floor channel: down pipe at the tap, grated channel, riser and spout at the box.
	_channel = Node3D.new()
	add_child(_channel)
	var tap := cupola.to_global(Vector3(0.55, 0, 1.25))
	var box := line.to_global(MoldLine.TUNDISH_POS + Vector3(0, 0, 0.55))
	_spout = line.to_global(MoldLine.TUNDISH_POS + Vector3(0, MoldLine.TUNDISH_TOP + 0.3, 0.12))
	_glow = StandardMaterial3D.new()
	_glow.albedo_color = Color("#2a1c16")
	_glow.emission_enabled = true
	_glow.emission = Color("#ff8a2e")
	_glow.emission_energy_multiplier = 0.0
	var run := Vector3(box.x - tap.x, 0, box.z - tap.z)
	var len := run.length()
	var xf := Transform3D(Basis.looking_at(run, Vector3.UP), Vector3((tap.x + box.x) * 0.5, 0, (tap.z + box.z) * 0.5))
	StationKit.add(_channel, EnvMesh.box(Vector3(0.2, 0.012, len), 0.002), _glow, xf * Transform3D(Basis(), Vector3(0, 0.012, 0)), false)
	var frame := []
	for s: float in [-1.0, 1.0]:
		frame.append(EnvMesh.piece(EnvMesh.box(Vector3(0.05, 0.035, len + 0.1), 0.006), xf * Transform3D(Basis(), Vector3(s * 0.125, 0.018, 0))))
	for k in int(len / 0.11):
		frame.append(EnvMesh.piece(EnvMesh.box(Vector3(0.22, 0.014, 0.035), 0.004), xf * Transform3D(Basis(), Vector3(0, 0.032, -len * 0.5 + 0.06 + k * 0.11))))
	StationKit.add_merged(_channel, frame, MachineArt.graphite_mat())
	# Pump housing at the furnace foot and the riser at the pouring box.
	var steel := MachineArt.steel_mat()
	var pipes := [MachineArt.turned(MachineArt.drum(0.085, 0.5, 0.01), Vector3.UP, Vector3(tap.x, 0.02, tap.z), 20)]
	pipes.append_array(MachineArt.bolt_circle(Vector3.UP, Vector3(tap.x, 0.52, tap.z), 0.065, 6, 0.01))
	StationKit.add_merged(_channel, pipes, steel)
	StationKit.add(_channel, MachineArt.turned(MachineArt.motor(0.075, 0.24), Vector3.UP, Vector3.ZERO, 24)[0], MachineArt.black_mat(), Transform3D(Basis(), Vector3(tap.x + 0.2, 0.02, tap.z)))
	var riser := MachineArt.pipe(PackedVector3Array([Vector3(box.x, 0.03, box.z), Vector3(box.x, 0.5, box.z), Vector3(box.x, _spout.y - 0.05, box.z), Vector3(box.x, _spout.y + 0.08, box.z - 0.08),
		Vector3(_spout.x, _spout.y + 0.1, _spout.z + 0.12), Vector3(_spout.x, _spout.y, _spout.z)]), 0.06, 14)
	StationKit.add(_channel, riser, MachineArt.graphite_mat())
	_stream = PourStream.new()
	_stream.top_level = true
	_stream.max_radius = 0.035
	add_child(_stream)
	_stream.set_endpoints(_spout, line.to_global(MoldLine.TUNDISH_POS + Vector3(0, MoldLine.TUNDISH_TOP - 0.1, 0)))
