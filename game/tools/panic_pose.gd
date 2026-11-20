extends Node3D
## Makes the pose of a worker caught by the metal (PlayerModel.PANIC_POSE): arms flung up and out
## in a Y, the right knee kicked up, the body leaning back. Aims a worker's rig that way and
## prints the snapshot, to paste into player_model.gd.
##   godot --headless --path . res://tools/panic_pose.tscn

func _ready() -> void:
	var model := PlayerModel.new()
	add_child(model)
	await get_tree().physics_frame
	var rig := model.find_child("WorkerRig", true, false) as WorkerRig
	var skeleton := rig.get_skeleton()
	# The pose is taken from the figure as it stands at rest, not from a moment of a clip.
	var tree := model.find_child("AnimationTree", true, false) as AnimationTree
	tree.active = false
	skeleton.reset_bone_poses()
	var to_skel := skeleton.global_transform.affine_inverse() * model.global_transform
	rig.left_target = to_skel * Vector3(0.5, 2.02, 0.0)
	rig.right_target = to_skel * Vector3(-0.5, 2.02, 0.0)
	rig.reach_left = 1.0
	rig.reach_right = 1.0
	rig.hinge = -0.1
	rig.bend = Vector3(-0.16, 0.0, 0.0)
	rig.look = Vector2(-0.3, 0.0)
	rig.right_foot_offset = to_skel.basis * Vector3(0.0, 0.4, 0.22)
	var out := func() -> void:
		var pose := model.pose_data()
		var lines := PackedStringArray()
		lines.append("\t%.1f, %.5f, %.5f, %.5f," % [pose[0], pose[1], pose[2], pose[3]])
		for i in PlayerModel.POSE_BONES.size():
			lines.append("\t%.5f, %.5f, %.5f," % [pose[4 + i * 3], pose[5 + i * 3], pose[6 + i * 3]])
		print("const PANIC_POSE: Array[float] = [\n" + "\n".join(lines) + "\n]")
	rig.modification_processed.connect(out, CONNECT_ONE_SHOT)
	# A touched bone makes the skeleton run its modifiers.
	skeleton.set_bone_pose_position(0, skeleton.get_bone_pose_position(0))
	await get_tree().process_frame
	await get_tree().process_frame
	get_tree().quit()
