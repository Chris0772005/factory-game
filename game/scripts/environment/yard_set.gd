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
## Group of thin solid set pieces (poles, posts, tree trunks) that a camera
## spring arm should ignore, so the view does not pop in when one passes
## between camera and worker (SpringArm3D.add_excluded_object).
const CAMERA_PASSTHROUGH := &"camera_passthrough"

var layout: YardLayout
var grass: GrassField
var house: Node3D


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
	GardenShed.build(self, YardLayout.SHED_CENTER, YardLayout.SHED_SIZE)
	StringLights.build(self, LIGHT_ANCHORS, ["p_left", "p_right", "p_back"], LIGHT_SPANS)
	_wall_hooks()
	for k: String in ["p_left", "p_right", "p_back"]:
		var a: Vector3 = LIGHT_ANCHORS[k]
		layout.cover(Vector2(a.x, a.z), 0.2)
	YardDressing.build(self, layout)
	GroundScatter.build(self, layout)
	var ridge := 5.4 + 4.0 * tan(deg_to_rad(40.0))
	YardAmbience.build(self, Vector3(hx - 4.6, ridge + 1.5, YardLayout.HOUSE_FRONT_Z - 3.3))
	# Grass last: it skips everything the builders above marked as covered.
	if EnvMesh.visual() and not EnvQuality.disabled("grass"):
		grass = GrassField.create(layout)
		add_child(grass)
	print_verbose("YardSet built in %.0f ms (grass tufts %d)" % [(Time.get_ticks_usec() - t0) / 1000.0, grass.tuft_count if grass else 0])


func _wall_hooks() -> void:
	if not EnvMesh.visual():
		return
	var iron := EnvMesh.surface("dark_iron", {base_color = Color("#2e2b2c"), metallic_base = 0.5, roughness_base = 0.5})
	for k: String in ["w_left", "w_mid"]:
		var a: Vector3 = LIGHT_ANCHORS[k]
		EnvMesh.add(self, EnvMesh.box(Vector3(0.05, 0.05, 0.16), 0.01, 1), iron, Transform3D(Basis(), a + Vector3(0, 0, -0.05)))
