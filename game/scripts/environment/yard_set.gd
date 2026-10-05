class_name YardSet
extends Node3D
## Everything in the backyard that is not gameplay: ground and grass, fences,
## house, shed, string lights, props, trees and the neighbourhood behind the
## fence. Built once per peer from fixed seeds, so every player sees (and
## collides with) the same yard. Solid props are StaticBody3D on layer 1.
## Headless runs (tests, servers) build only the colliders.

## String-light anchors: pole tops and hooks on the house wall (world).
const LIGHT_ANCHORS := {
	"p_left": Vector3(-7.6, 3.7, 4.4),
	"p_right": Vector3(7.4, 3.7, 5.2),
	"p_back": Vector3(7.9, 3.7, -6.6),
	"w_left": Vector3(-8.6, 3.85, -9.0),
	"w_mid": Vector3(1.8, 3.85, -9.0),
}
const LIGHT_SPANS := [
	["w_left", "p_left"], ["p_right", "p_back"], ["p_back", "w_mid"], ["w_mid", "p_left"], ["w_left", "p_back"],
]
## Group of the set's solid pieces that game cameras ignore (Art Bible 8.2):
## poles, posts, tree trunks, fences and every dressing prop. Only the house,
## the shed and the ground stay camera blockers, so the view never pops in
## when a thin piece passes between camera and worker. CameraRig skips hits
## on this group; YardSet also hands the bodies to every SpringArm3D in the
## scene (SpringArm3D.add_excluded_object). Workers still collide with them.
const CAMERA_PASSTHROUGH := &"camera_passthrough"

var layout: YardLayout
var grass: GrassField
var house: Node3D
var shed: Node3D
var _passthrough: Array[RID] = []
var _build_ms := 0.0


## Builds the set under `world`. `stations` are the gameplay station nodes;
## their positions decide where the ground is worn and where props may stand.
static func build(world: Node3D, stations: Array) -> YardSet:
	var yard := YardSet.new()
	yard.name = "YardSet"
	world.add_child(yard)
	yard.layout = YardLayout.new(stations)
	yard._build()
	return yard


func _build() -> void:
	var t0 := Time.get_ticks_usec()
	YardGround.build(self, layout)
	PlankFence.build_yard(self)
	var hx := (YardLayout.HOUSE_X.x + YardLayout.HOUSE_X.y) * 0.5
	house = YardHouse.build(self, Transform3D(Basis(), Vector3(hx, 0, YardLayout.HOUSE_FRONT_Z)), {
		width = YardLayout.HOUSE_X.y - YardLayout.HOUSE_X.x,
		solid = true,
		door = YardLayout.DOOR_X - hx,
		chimney_x = -4.6,
		windows = [
			[-5.2, 1.6, 1.1, 1.3, 1.0, true, false],
			[1.2, 1.6, 1.1, 1.3, 1.0, false, false],
			[4.6, 1.6, 1.1, 1.3, 0.0, true, false],
			[-5.2, 4.15, 0.95, 1.1, 0.0, false, true],
			[-2.0, 4.15, 0.95, 1.1, 0.75, false, false],
			[1.6, 4.15, 0.95, 1.1, 0.0, true, false],
			[4.8, 4.15, 0.95, 1.1, 1.0, false, true],
		],
	})
	shed = GardenShed.build(self, YardLayout.SHED_CENTER, YardLayout.SHED_SIZE)
	StringLights.build(self, LIGHT_ANCHORS, ["p_left", "p_right", "p_back"], LIGHT_SPANS)
	_wall_hooks()
	for k: String in ["p_left", "p_right", "p_back"]:
		var a: Vector3 = LIGHT_ANCHORS[k]
		layout.cover(Vector2(a.x, a.z), 0.2)
	YardDressing.build(self, layout)
	GroundScatter.build(self, layout)
	var ridge := 5.4 + 4.0 * tan(deg_to_rad(40.0))
	YardAmbience.build(self, Vector3(hx - 4.6, ridge + 1.5, YardLayout.HOUSE_FRONT_Z - 3.3))
	_collect_passthrough()
	_reflection_probe()
	# Grass last: it skips everything the builders above marked as covered.
	if EnvMesh.visual() and not EnvQuality.disabled("grass"):
		grass = GrassField.create(layout)
		add_child(grass)
	_build_ms = (Time.get_ticks_usec() - t0) / 1000.0
	print_verbose("YardSet built in %.0f ms (grass tufts %d)" % [_build_ms, grass.tuft_count if grass else 0])
	if "--env-stats" in OS.get_cmdline_user_args():
		_report_stats.call_deferred()


## Profiling aid (`-- --env-stats`): after the scene settles, prints what the
## current view costs (docs/ENVIRONMENT.md, section 4).
func _report_stats() -> void:
	var vp := get_viewport()
	var rid := vp.get_viewport_rid()
	RenderingServer.viewport_set_measure_render_time(rid, true)
	for i in 60:
		await get_tree().process_frame
	var cpu := 0.0
	var gpu := 0.0
	var t0 := Time.get_ticks_usec()
	var frames := 20
	for i in frames:
		await get_tree().process_frame
		cpu += RenderingServer.viewport_get_measured_render_time_cpu(rid)
		gpu += RenderingServer.viewport_get_measured_render_time_gpu(rid)
	var wall := (Time.get_ticks_usec() - t0) / 1000.0 / frames
	var lights := 0
	var shadowed := 0
	for l: Light3D in get_tree().root.find_children("*", "Light3D", true, false):
		if l.is_visible_in_tree():
			lights += 1
			shadowed += 1 if l.shadow_enabled else 0
	var info := func(type: Viewport.RenderInfoType, what: Viewport.RenderInfo) -> int:
		return vp.get_render_info(type, what)
	print("[env-stats] quality=%s build=%.0f ms grass_tufts=%d" % [EnvQuality.Level.keys()[EnvQuality.level()], _build_ms,
		grass.tuft_count if grass else 0])
	print("[env-stats] visible: objects=%d draws=%d primitives=%d | shadow: objects=%d draws=%d primitives=%d" % [
		info.call(Viewport.RENDER_INFO_TYPE_VISIBLE, Viewport.RENDER_INFO_OBJECTS_IN_FRAME),
		info.call(Viewport.RENDER_INFO_TYPE_VISIBLE, Viewport.RENDER_INFO_DRAW_CALLS_IN_FRAME),
		info.call(Viewport.RENDER_INFO_TYPE_VISIBLE, Viewport.RENDER_INFO_PRIMITIVES_IN_FRAME),
		info.call(Viewport.RENDER_INFO_TYPE_SHADOW, Viewport.RENDER_INFO_OBJECTS_IN_FRAME),
		info.call(Viewport.RENDER_INFO_TYPE_SHADOW, Viewport.RENDER_INFO_DRAW_CALLS_IN_FRAME),
		info.call(Viewport.RENDER_INFO_TYPE_SHADOW, Viewport.RENDER_INFO_PRIMITIVES_IN_FRAME)])
	print("[env-stats] lights in scene=%d (shadowed %d) frame: wall %.1f ms, render cpu %.2f ms, gpu %.2f ms, video mem %.0f MB" % [
		lights, shadowed, wall, cpu / frames, gpu / frames, RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_VIDEO_MEM_USED) / 1048576.0])


## Tags every set collider except the camera blockers (house, shed, ground)
## and hands them to all present and future spring arms in the scene.
func _collect_passthrough() -> void:
	for body: StaticBody3D in find_children("*", "StaticBody3D", true, false):
		if body.name == &"GroundCollision" or house.is_ancestor_of(body) or shed.is_ancestor_of(body):
			continue
		body.add_to_group(CAMERA_PASSTHROUGH)
		_passthrough.append(body.get_rid())
	if not is_inside_tree():
		return
	get_tree().node_added.connect(_on_node_added)
	for arm: SpringArm3D in get_tree().root.find_children("*", "SpringArm3D", true, false):
		_exclude_from(arm)


func _on_node_added(node: Node) -> void:
	if node is SpringArm3D:
		_exclude_from(node as SpringArm3D)


func _exclude_from(arm: SpringArm3D) -> void:
	for rid in _passthrough:
		arm.add_excluded_object(rid)


## One box probe over the yard, captured once (Art Bible 6.5): cold metal
## (anvil, tools, drips) mirrors the yard and its lights instead of the sky.
func _reflection_probe() -> void:
	if not EnvMesh.visual():
		return
	var probe := ReflectionProbe.new()
	probe.name = "YardReflections"
	probe.update_mode = ReflectionProbe.UPDATE_ONCE
	probe.size = Vector3(26.0, 9.0, 19.0)
	probe.position = Vector3(-0.5, 4.5, -0.3)
	# Captured from 2 m above the ground, roughly where the metal is seen from.
	probe.origin_offset = Vector3(0, -2.5, 0)
	probe.box_projection = true
	probe.max_distance = 60.0
	probe.intensity = 0.85
	probe.ambient_mode = ReflectionProbe.AMBIENT_DISABLED
	add_child(probe)


func _wall_hooks() -> void:
	if not EnvMesh.visual():
		return
	var iron := EnvMesh.surface("dark_iron", {base_color = Color("#2e2b2c"), metallic_base = 0.5, roughness_base = 0.5})
	for k: String in ["w_left", "w_mid"]:
		var a: Vector3 = LIGHT_ANCHORS[k]
		EnvMesh.add(self, EnvMesh.box(Vector3(0.05, 0.05, 0.16), 0.01, 1), iron, Transform3D(Basis(), a + Vector3(0, 0, -0.05)))
