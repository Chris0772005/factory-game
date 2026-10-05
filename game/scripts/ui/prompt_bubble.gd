class_name PromptBubble
extends PanelContainer
## Contextual hint chip: key glyphs plus action words, parsed from the stations'
## hint strings ("[F] Blasebalg treten  · Hitze 37 %", "[LMB] Ablegen   [RMB] Werfen").
## Text before a "·" is the action, text after it is muted info. Pops in (scale 0.85 → 1,
## back ease, slide up), pops out (fade, slide down), and only re-animates when the
## prompt itself changes – live numbers just update. Pinned bottom centre, or
## anchored above a world point with a small pointer (Art Bible 12, rule 14).

enum Anchor { BOTTOM, WORLD }

const SAFE := Vector2(96.0, 54.0)
const POINTER := 12.0

var anchor := Anchor.BOTTOM
## WORLD anchor: where the bubble's pointer sits (projected through the current camera).
var world_point := Vector3.ZERO
## Distance from the screen bottom for the BOTTOM anchor.
var bottom_margin := 70.0
var key_size := 40.0
var font_size := UITheme.SIZE_HINT

var _row: HBoxContainer
var _labels: Array[Label] = []
var _shape := ""
var _text := ""
var _shown := false
var _vis := 0.0
var _tween: Tween
var _screen := Vector2.ZERO
var _has_screen := false
var _occluded := false


func _ready() -> void:
	theme_type_variation = &"HudPill"
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_row = HBoxContainer.new()
	_row.add_theme_constant_override("separation", 10)
	_row.alignment = BoxContainer.ALIGNMENT_CENTER
	_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_row)
	modulate.a = 0.0
	visible = false


## Shows `hint` (empty hides). `key` identifies what the hint belongs to (e.g. the
## station); a new key re-pops the bubble even when the text shape matches.
func set_hint(hint: String, key := "") -> void:
	if hint.is_empty():
		_hide()
		return
	var parts := parse(hint)
	var shape := key + "|" + _shape_of(parts)
	if not _shown or shape != _shape:
		var was_shown := _shown
		_rebuild(parts)
		_shape = shape
		if was_shown:
			_repop()
		else:
			_show()
	elif hint != _text:
		var i := 0
		for p in parts:
			if p.kind == "text" and i < _labels.size():
				_labels[i].text = p.text
				i += 1
		reset_size()
	_text = hint


func _show() -> void:
	_shown = true
	visible = true
	_has_screen = false
	if _tween:
		_tween.kill()
	_tween = create_tween()
	_tween.tween_property(self, "_vis", 1.0, 0.24).from(0.0).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


## A new prompt while visible: a quick dip and bounce instead of a full re-entry.
func _repop() -> void:
	if _tween:
		_tween.kill()
	_tween = create_tween()
	_tween.tween_property(self, "_vis", 1.0, 0.2).from(0.8).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func _hide() -> void:
	if not _shown:
		return
	_shown = false
	_text = ""
	_shape = ""
	if _tween:
		_tween.kill()
	_tween = create_tween()
	_tween.tween_property(self, "_vis", 0.0, 0.14).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	_tween.tween_callback(func() -> void: visible = false)


func _process(delta: float) -> void:
	if not visible:
		return
	var vp := get_viewport_rect().size
	var goal := Vector2(vp.x * 0.5, vp.y - bottom_margin)
	_occluded = false
	if anchor == Anchor.WORLD:
		var cam := get_viewport().get_camera_3d()
		if cam == null or cam.is_position_behind(world_point):
			_occluded = true
		else:
			goal = cam.unproject_position(world_point)
	var half := size.x * 0.5
	goal.x = clampf(goal.x, SAFE.x + half, vp.x - SAFE.x - half)
	goal.y = clampf(goal.y, SAFE.y + size.y + POINTER, vp.y - SAFE.y)
	if not _has_screen:
		_screen = goal
		_has_screen = true
	else:
		_screen = _screen.lerp(goal, 1.0 - exp(-24.0 * delta))
	var v := clampf(_vis, 0.0, 1.2)
	modulate.a = clampf(_vis, 0.0, 1.0) * (0.0 if _occluded else 1.0)
	pivot_offset = Vector2(half, size.y + (POINTER if anchor == Anchor.WORLD else 0.0))
	scale = Vector2.ONE * (0.85 + 0.15 * v)
	var lift := POINTER + 4.0 if anchor == Anchor.WORLD else 0.0
	position = (_screen - Vector2(half, size.y + lift) + Vector2(0, (1.0 - clampf(_vis, 0.0, 1.0)) * 18.0)).round()


func _draw() -> void:
	if anchor != Anchor.WORLD:
		return
	var c := Vector2(size.x * 0.5, size.y - 2.0)
	var tri := PackedVector2Array([c + Vector2(-POINTER, 0), c + Vector2(POINTER, 0), c + Vector2(0, POINTER + 2.0)])
	draw_colored_polygon(tri, UITheme.PANEL)


## Splits a hint into [{kind = "key", token, hold}, {kind = "text", text, muted}, {kind = "dot"}].
static func parse(hint: String) -> Array:
	var parts := []
	var re := RegEx.create_from_string("\\[([^\\]]+)\\]")
	var pos := 0
	var muted := false
	for m in re.search_all(hint):
		muted = _add_text(parts, hint.substr(pos, m.get_start() - pos), muted)
		var token := m.get_string(1)
		parts.append({kind = "key", token = token, hold = token.contains("halten")})
		muted = false
		pos = m.get_end()
	_add_text(parts, hint.substr(pos), muted)
	return parts


static func _add_text(parts: Array, s: String, muted: bool) -> bool:
	var segs := s.split("·")
	for i in segs.size():
		var seg := segs[i].strip_edges()
		if i > 0:
			muted = true
		if seg.is_empty():
			continue
		if i > 0 and not parts.is_empty():
			parts.append({kind = "dot"})
		parts.append({kind = "text", text = seg, muted = muted})
	return muted


static func _shape_of(parts: Array) -> String:
	var out := ""
	for p in parts:
		match p.kind:
			"key":
				out += "[%s]" % p.token
			"text":
				out += "t" if not p.muted else "m"
			"dot":
				out += "."
	return out


func _rebuild(parts: Array) -> void:
	for c in _row.get_children():
		_row.remove_child(c)
		c.queue_free()
	_labels.clear()
	var prev := ""
	for p in parts:
		match p.kind:
			"key":
				if prev == "text":
					_row.add_child(_spacer(14.0))
				var key := KeyPrompt.new()
				key.cap = key_size
				_row.add_child(key.setup(p.token, p.hold))
				key.size_flags_vertical = Control.SIZE_SHRINK_CENTER
			"text":
				var l := Label.new()
				l.text = p.text
				l.theme_type_variation = &"Muted" if p.muted else &""
				l.add_theme_font_size_override("font_size", font_size - (2 if p.muted else 0))
				l.add_theme_font_override("font", UITheme.font(600 if p.muted else 700))
				if not p.muted:
					l.add_theme_constant_override("outline_size", 0)
				l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
				_row.add_child(l)
				_labels.append(l)
			"dot":
				var d := Label.new()
				d.text = "•"
				d.add_theme_color_override("font_color", Color(UITheme.PAPER, 0.35))
				d.add_theme_constant_override("outline_size", 0)
				d.add_theme_font_size_override("font_size", font_size - 6)
				_row.add_child(d)
		prev = p.kind
	reset_size()
	queue_redraw()


static func _spacer(w: float) -> Control:
	var c := Control.new()
	c.custom_minimum_size.x = w
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return c
