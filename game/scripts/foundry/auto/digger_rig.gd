class_name DiggerRig
extends Node3D
## The 20 t excavator model (zx200_hd.glb, Apache 2.0, see assets/models/machinery/NOTICE.txt) made
## movable: the upper carriage swings, boom, stick and bucket turn in their pins, and the loose parts
## of the file are put where they belong for every pose. The file keeps each loose part in its own
## frame, pin at the origin, pointing at its other pin: the three hydraulic cylinders (barrel and rod)
## are stretched between their two pins, and the bucket linkage (guide link, side link and the rod eye
## that share one pin) is solved as the four-bar it is.
## Faces +Z (the file faces +X). `set_pose` takes the swing in radians and the three joint angles in
## degrees as the file's joints define them: boom < 0 is up, stick and bucket > 0 fold in.

const MODEL := "res://assets/models/machinery/zx200_hd.glb"
## The links turn about their local Y (the file keeps the Z-up frames of its source), the swing about Z.
const PIN := Vector3(0, 1, 0)
const UP := Vector3(0, 0, 1)
## Far pins of the two link plates in their own frames (their near pin, shared with the rod eye, is the origin).
const GUIDE_END := Vector3(-0.34, 0, -0.45)
const SIDE_END := Vector3(-0.33, 0, 0.48)
## Pins on the links, by the name of the pin's mesh in the file.
const PINS: Array[String] = ["boom_head_pins", "boom_rod_pin", "arm_head_pin", "arm_rod_pin", "bucket_head_pin", "guide_pin", "bucket_link_pin"]

var _body: Node3D
var _boom: Node3D
var _arm: Node3D
var _bucket: Node3D
var _rest := {}
var _pins := {}
var _parts := {}
var _eyes := {}


func _ready() -> void:
	var packed := load(MODEL) as PackedScene
	if packed == null:
		return
	var scene := packed.instantiate() as Node3D
	scene.rotation.y = -PI * 0.5
	add_child(scene)
	_body = scene.find_child("body_link", true, false) as Node3D
	_boom = scene.find_child("boom_link", true, false) as Node3D
	_arm = scene.find_child("arm_link", true, false) as Node3D
	_bucket = scene.find_child("bucket_link", true, false) as Node3D
	if _body == null or _boom == null or _arm == null or _bucket == null:
		return
	for link: Node3D in [_body, _boom, _arm, _bucket]:
		_rest[link] = link.transform.basis
	for pin_name in PINS:
		var mesh := scene.find_child(pin_name, true, false) as MeshInstance3D
		if mesh == null:
			continue
		var link := mesh.get_parent() as Node3D
		while link and not String(link.name).ends_with("_link"):
			link = link.get_parent() as Node3D
		if link:
			_pins[pin_name] = [link, link.global_transform.affine_inverse() * (mesh.global_transform * mesh.get_aabb().get_center())]
	for part_name: String in ["boom_barrel", "boom_rod", "arm_barrel", "arm_rod", "bucket_barrel", "bucket_rod", "guide_link", "side_link"]:
		_parts[part_name] = scene.find_child(part_name, true, false) as Node3D
	for cyl: String in ["boom", "arm", "bucket"]:
		var eye := scene.find_child(cyl + "_rod_eye", true, false) as MeshInstance3D
		var rod := _parts[cyl + "_rod"] as Node3D
		if eye and rod:
			_eyes[cyl] = rod.global_transform.affine_inverse() * (eye.global_transform * eye.get_aabb().get_center())
	set_pose(0.0, -20.0, 95.0, 70.0)


## Swing in radians, joint angles in degrees.
func set_pose(swing: float, boom: float, arm: float, bucket: float) -> void:
	if _rest.is_empty() or _pins.size() < PINS.size() or _eyes.size() < 3:
		return
	_body.transform.basis = (_rest[_body] as Basis) * Basis(UP, swing)
	_boom.transform.basis = (_rest[_boom] as Basis) * Basis(PIN, deg_to_rad(boom))
	_arm.transform.basis = (_rest[_arm] as Basis) * Basis(PIN, deg_to_rad(arm))
	_bucket.transform.basis = (_rest[_bucket] as Basis) * Basis(PIN, deg_to_rad(bucket))
	var side := (_arm.global_basis.orthonormalized() * PIN).normalized()
	var size := global_basis.get_scale().x
	_stretch("boom", _pin("boom_head_pins"), _pin("boom_rod_pin"), side, size)
	_stretch("arm", _pin("arm_head_pin"), _pin("arm_rod_pin"), side, size)
	# Bucket linkage: the shared pin lies where the two link plates meet, on the cylinder's side.
	var a := _pin("guide_pin")
	var b := _pin("bucket_link_pin")
	var foot := _pin("bucket_head_pin")
	var la := GUIDE_END.length() * size
	var lb := SIDE_END.length() * size
	var d := b - a
	d -= side * d.dot(side)
	var dist := maxf(d.length(), 0.001)
	var x := clampf((la * la - lb * lb + dist * dist) / (2.0 * dist), -la, la)
	var h := sqrt(maxf(la * la - x * x, 0.0))
	var e := d / dist
	var out := side.cross(e)
	if (foot - a).dot(out) < 0.0:
		out = -out
	var shared := a + e * x + out * h
	_place(_parts.guide_link, GUIDE_END, shared, a - shared, side, size)
	_place(_parts.side_link, SIDE_END, shared, b - shared, side, size)
	_stretch("bucket", foot, shared, side, size)


func _pin(pin_name: String) -> Vector3:
	var entry: Array = _pins[pin_name]
	return (entry[0] as Node3D).global_transform * (entry[1] as Vector3)


## A cylinder between its foot pin and the pin its rod eye sits on.
func _stretch(cyl: String, foot: Vector3, eye_pin: Vector3, side: Vector3, size: float) -> void:
	var eye: Vector3 = _eyes[cyl]
	_place(_parts[cyl + "_barrel"], eye, foot, eye_pin - foot, side, size)
	_place(_parts[cyl + "_rod"], eye, eye_pin, eye_pin - foot, side, size, eye)


## Puts `part` so that the point `anchor` of its own frame lies at `at` and its own direction
## `along` points along `toward`; its Y axis stays across the machine (`side`).
func _place(part: Node3D, along: Vector3, at: Vector3, toward: Vector3, side: Vector3, size: float, anchor := Vector3.ZERO) -> void:
	if part == null:
		return
	var dir := toward - side * toward.dot(side)
	if dir.length() < 0.0001:
		return
	dir = dir.normalized()
	var own := along.normalized()
	var basis := Basis(dir, side, dir.cross(side)) * Basis(own, PIN, own.cross(PIN)).inverse()
	basis = basis * Basis.from_scale(Vector3.ONE * size)
	part.global_transform = Transform3D(basis, at - basis * anchor)
