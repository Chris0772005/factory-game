extends SceneTree
## Renders sample bells to WAV files for listening:
##   godot --headless --path game -s res://tools/bell_audition.gd -- --out=/abs/dir
## Writes a clean bell at three sizes (bronze), one in aluminium and a crooked one.

func _init() -> void:
	var out := "user://bells"
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):
			out = arg.trim_prefix("--out=")
	DirAccess.make_dir_recursive_absolute(out)
	var clean := BellProfile.from_drawing(DrawingSamples.bell())
	var crooked := BellProfile.from_drawing(DrawingSamples.crooked_bell())
	var jobs := [[clean, 0.25, &"bronze", "klein"], [clean, 0.35, &"bronze", "mittel"], [clean, 0.6, &"bronze", "gross"],
		[clean, 0.35, &"alu", "alu"], [crooked, 0.35, &"bronze", "schief"]]
	for j in jobs:
		var p: BellProfile = j[0]
		var f := BellTone.prime(p, j[1], j[2])
		var path := "%s/glocke_%s_%s.wav" % [out, j[3], BellTone.note_name(f)]
		BellTone.stream(p, j[1], j[2]).save_to_wav(path)
		print("%s  %.0f Hz  %s" % [path, f, BellTone.verdict(p)])
	quit()
