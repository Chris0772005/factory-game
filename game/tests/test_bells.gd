extends Node
## Bells, headless: profiles from drawings, the shell mesh and its metal, the
## pitch rule (size, alloy), note names, crooked profiles and the rendered tone.

var _failures := 0


func _ready() -> void:
	_run.call_deferred()


func _run() -> void:
	var bell := BellProfile.from_drawing(DrawingSamples.bell())
	_check(bell != null, "bell outline becomes a profile")
	var flat := Drawing.new()
	flat.add_stroke(PackedVector2Array([Vector2(0.2, 0.5), Vector2(0.8, 0.52)]))
	_check(BellProfile.from_drawing(flat) == null, "a flat line is not a bell")
	if bell == null:
		_finish()
		return
	_check(bell.radius[BellProfile.SAMPLES - 1] >= 0.99 and bell.radius[0] < 0.6, "crown narrow, mouth widest (%.2f / %.2f)" % [bell.radius[0], bell.radius[BellProfile.SAMPLES - 1]])
	var mesh := bell.mesh(0.35)
	_check(mesh != null and mesh.get_surface_count() > 0, "lathe shell mesh built")
	var litres := bell.litres(0.35)
	_check(litres > 3.0 and litres < 14.0, "a 70 cm bell needs a few crucibles (%.1f l)" % litres)
	_check(bell.litres(0.5) > litres * 2.0, "metal grows with the cube of the size (%.1f l at 1 m)" % bell.litres(0.5))
	var f := BellTone.prime(bell, 0.35, &"bronze")
	var f_big := BellTone.prime(bell, 0.7, &"bronze")
	_check(f > 250.0 and f < 1200.0, "a 70 cm bronze bell sings at %.0f Hz (%s)" % [f, BellTone.note_name(f)])
	_check(absf(f_big - f * 0.5) < 1.0, "twice as wide = one octave lower (%.0f Hz)" % f_big)
	_check(BellTone.prime(bell, 0.35, &"alu") > f, "aluminium rings higher than bronze")
	_check(BellTone.note_name(440.0) == "A4" and BellTone.note_name(523.25) == "C5" and BellTone.note_name(493.88) == "H4", "German note names (A4, C5, H4)")
	var crooked := BellProfile.from_drawing(DrawingSamples.crooked_bell())
	_check(crooked != null and crooked.irregularity > bell.irregularity + 0.3, "shaky outline is irregular (%.2f vs %.2f)" % [crooked.irregularity if crooked else -1.0, bell.irregularity])
	_check(BellTone.verdict(bell) == "rein", "clean bell sounds pure (%.2f)" % BellTone.purity(bell))
	_check(crooked != null and BellTone.verdict(crooked) != "rein", "shaky bell sounds crooked (%s)" % (BellTone.verdict(crooked) if crooked else "?"))
	var t0 := Time.get_ticks_msec()
	var wav := BellTone.stream(bell, 0.35, &"bronze")
	var ms := Time.get_ticks_msec() - t0
	_check(wav != null and wav.data.size() > BellTone.RATE * 2 * 2, "tone rendered (%.1f s, %d ms)" % [wav.data.size() / 2.0 / BellTone.RATE, ms])
	_check(BellTone.stream(bell, 0.35, &"bronze") == wav, "tone is cached")
	_finish()


func _finish() -> void:
	print("BELL TESTS %s (%d failures)" % ["PASSED" if _failures == 0 else "FAILED", _failures])
	get_tree().quit(1 if _failures else 0)


func _check(ok: bool, what: String) -> void:
	print("%s %s" % ["ok  " if ok else "FAIL", what])
	if not ok:
		_failures += 1
