extends Node3D
## Close-up of the four player colours for judging the character dressing
## (hard hat, apron) without staging a whole level. `-- --cam=front|high`.

func _ready() -> void:
	YardLighting.build(self)
	var floor_mesh := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(12, 12)
	floor_mesh.mesh = plane
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color("#5a4636")
	mat.roughness = 0.9
	floor_mesh.material_override = mat
	add_child(floor_mesh)
	for i in GameWorld.PLAYER_COLORS.size():
		var worker := PlayerModel.new()
		worker.suit_color = GameWorld.PLAYER_COLORS[i]
		add_child(worker)
		worker.position = Vector3(-1.5 + i * 1.0, 0, 0)
		worker.rotation.y = [0.5, 0.15, -0.15, PI * 0.9][i]
	var cam := Camera3D.new()
	cam.fov = 40
	add_child(cam)
	cam.add_child(OutlinePass.create())
	var high := "--cam=high" in OS.get_cmdline_user_args()
	if high:
		cam.look_at_from_position(Vector3(0, 6.5, 6.0), Vector3(0, 0.9, 0))
	else:
		cam.look_at_from_position(Vector3(0, 1.6, 4.2), Vector3(0, 1.0, 0))
	cam.make_current()
	set_physics_process(true)


func _physics_process(delta: float) -> void:
	for c in get_children():
		if c is PlayerModel:
			c.animate(delta, Vector3.ZERO, true, false, Vector3.ZERO)
