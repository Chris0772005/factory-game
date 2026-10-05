class_name UITheme
## Builds the game's UI theme in code: rounded, chunky, high-contrast
## (Art Bible 4.4 / 12). Also holds the shared UI motion helpers
## (`juice_button`, `pop_in`) so every screen animates the same way.
##
## Theme type variations:
##   Button:  "SecondaryButton" (dark glass, paper text), "SegmentButton" (toggle chips),
##            "ToggleButton" (AN/AUS pill), "BigButton" (primary, larger text)
##   Panel:   "CardPanel" (pause/settings card), "HudPill" (money counter, prompts)
##   Label:   "H1", "H2", "Muted", "Small"

const INK := Color("#1f1b2d")
const PAPER := Color("#fff8ec")
const ACCENT := Color("#f2b134")
const ACCENT_DARK := Color("#c98a12")
const PANEL := Color(0.122, 0.106, 0.176, 0.82)
const GOOD := Color("#6ccb5f")
const BAD := Color("#e5533d")
const INFO := Color("#5bb8e8")
const COIN := Color("#f7c948")
## Molten-metal gradient (logo, highlights): hot top → deep orange bottom.
const MOLTEN_HOT := Color("#ffd27a")
const MOLTEN := Color("#ff7a1a")
const MOLTEN_DEEP := Color("#ff6a1a")
const MUTED := Color("#cfc4b4")

## Type scale at 1080p (Art Bible 12).
const SIZE_TITLE := 72
const SIZE_H2 := 48
const SIZE_TEXT := 30
const SIZE_HINT := 26
const SIZE_SMALL := 22

const DISPLAY_FONT := "res://assets/ui/fonts/LilitaOne-Regular.ttf"

static var _theme: Theme
static var _fonts := {}


## Fredoka at the given weight (variable font); cached per weight.
static func font(weight := 600) -> FontVariation:
	if _fonts.has(weight):
		return _fonts[weight]
	var fv := FontVariation.new()
	fv.base_font = load("res://assets/fonts/Fredoka.ttf")
	fv.variation_opentype = {TextServerManager.get_primary_interface().name_to_tag("wght"): weight}
	_fonts[weight] = fv
	return fv


## Chunky display face for the logo, banners and big numbers (Lilita One, OFL).
static func display_font() -> Font:
	if not _fonts.has(&"display"):
		_fonts[&"display"] = load(DISPLAY_FONT)
	return _fonts[&"display"]


static func get_theme() -> Theme:
	if _theme:
		return _theme
	var t := Theme.new()
	t.default_font = font(600)
	t.default_font_size = 28
	t.set_color("font_color", "Label", PAPER)
	t.set_color("font_outline_color", "Label", INK)
	t.set_constant("outline_size", "Label", 8)

	_label_variation(t, &"H1", SIZE_TITLE, font(700), PAPER, 16)
	_label_variation(t, &"H2", SIZE_H2, font(700), PAPER, 12)
	_label_variation(t, &"Muted", SIZE_HINT, font(500), MUTED, 0)
	_label_variation(t, &"Small", SIZE_SMALL, font(500), MUTED, 0)

	# Primary button: gold slab with a darker lip (radius 18, 6 px bottom edge).
	var normal := _box(ACCENT, ACCENT_DARK)
	var hover := _box(ACCENT.lightened(0.18), ACCENT_DARK)
	var pressed := _box(ACCENT_DARK, ACCENT_DARK.darkened(0.2))
	pressed.border_width_bottom = 2
	pressed.content_margin_top += 4
	var disabled := _box(ACCENT.darkened(0.45), ACCENT_DARK.darkened(0.5))
	for state in [["normal", normal], ["hover", hover], ["pressed", pressed], ["disabled", disabled],
			["hover_pressed", pressed]]:
		t.set_stylebox(state[0], "Button", state[1])
	t.set_stylebox("focus", "Button", _focus_ring())
	for c in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color", "font_hover_pressed_color"]:
		t.set_color(c, "Button", INK)
	t.set_color("font_disabled_color", "Button", INK.lightened(0.25))
	t.set_font_size("font_size", "Button", 32)
	t.set_font("font", "Button", font(700))

	t.set_type_variation(&"BigButton", &"Button")
	t.set_font_size("font_size", "BigButton", 40)
	var big := _box(ACCENT, ACCENT_DARK)
	big.content_margin_top = 16
	big.content_margin_bottom = 20
	t.set_stylebox("normal", "BigButton", big)
	var big_hover := big.duplicate() as StyleBoxFlat
	big_hover.bg_color = ACCENT.lightened(0.18)
	t.set_stylebox("hover", "BigButton", big_hover)
	var big_pressed := big.duplicate() as StyleBoxFlat
	big_pressed.bg_color = ACCENT_DARK
	big_pressed.border_width_bottom = 2
	big_pressed.content_margin_top += 4
	t.set_stylebox("pressed", "BigButton", big_pressed)
	t.set_stylebox("hover_pressed", "BigButton", big_pressed)

	# Secondary: dark glass with paper text, turns gold on hover.
	t.set_type_variation(&"SecondaryButton", &"Button")
	var sec := _box(Color(INK, 0.72), Color(0.0, 0.0, 0.0, 0.35))
	sec.border_width_left = 2
	sec.border_width_right = 2
	sec.border_width_top = 2
	sec.border_color = Color(PAPER, 0.14)
	sec.border_width_bottom = 6
	t.set_stylebox("normal", "SecondaryButton", sec)
	t.set_stylebox("hover", "SecondaryButton", hover)
	t.set_stylebox("pressed", "SecondaryButton", pressed)
	t.set_stylebox("hover_pressed", "SecondaryButton", pressed)
	t.set_stylebox("disabled", "SecondaryButton", _box(Color(INK, 0.4), Color(0, 0, 0, 0.2)))
	t.set_color("font_color", "SecondaryButton", PAPER)
	t.set_color("font_focus_color", "SecondaryButton", PAPER)
	t.set_color("font_disabled_color", "SecondaryButton", Color(PAPER, 0.35))

	# Segment chips (Low / Medium / High) and the AN/AUS toggle.
	for variation in [&"SegmentButton", &"ToggleButton"]:
		t.set_type_variation(variation, &"Button")
		var off := _box(Color(PAPER, 0.08), Color(0, 0, 0, 0.3))
		off.set_corner_radius_all(14)
		off.border_width_bottom = 4
		off.content_margin_left = 22
		off.content_margin_right = 22
		off.content_margin_top = 6
		off.content_margin_bottom = 8
		off.shadow_size = 0
		var off_hover := off.duplicate() as StyleBoxFlat
		off_hover.bg_color = Color(PAPER, 0.18)
		var on := off.duplicate() as StyleBoxFlat
		on.bg_color = ACCENT
		on.border_color = ACCENT_DARK
		var on_hover := on.duplicate() as StyleBoxFlat
		on_hover.bg_color = ACCENT.lightened(0.15)
		t.set_stylebox("normal", variation, off)
		t.set_stylebox("hover", variation, off_hover)
		t.set_stylebox("pressed", variation, on)
		t.set_stylebox("hover_pressed", variation, on_hover)
		t.set_font_size("font_size", variation, 24)
		t.set_color("font_color", variation, PAPER)
		t.set_color("font_hover_color", variation, PAPER)
		t.set_color("font_focus_color", variation, PAPER)
		t.set_color("font_pressed_color", variation, INK)
		t.set_color("font_hover_pressed_color", variation, INK)

	# Panels: INK @ 82 %, 3 px paper rim @ 10 %, soft drop shadow (0/4/12 @ 25 %).
	t.set_stylebox("panel", "PanelContainer", panel_box(22, 18))
	t.set_type_variation(&"CardPanel", &"PanelContainer")
	var card := panel_box(28, 40)
	card.content_margin_top = 34
	card.content_margin_bottom = 34
	card.shadow_size = 24
	card.shadow_offset = Vector2(0, 10)
	card.shadow_color = Color(0, 0, 0, 0.35)
	t.set_stylebox("panel", "CardPanel", card)
	t.set_type_variation(&"HudPill", &"PanelContainer")
	var pill := panel_box(40, 14)
	pill.content_margin_left = 16
	pill.content_margin_right = 26
	pill.content_margin_top = 8
	pill.content_margin_bottom = 8
	t.set_stylebox("panel", "HudPill", pill)

	# Text fields: dark glass like the secondary buttons, gold rim when focused.
	var field := StyleBoxFlat.new()
	field.bg_color = Color(INK, 0.78)
	field.set_corner_radius_all(18)
	field.set_content_margin_all(12)
	field.content_margin_left = 20
	field.content_margin_right = 20
	field.border_color = Color(PAPER, 0.16)
	field.set_border_width_all(2)
	field.border_width_bottom = 6
	field.anti_aliasing_size = 1.2
	t.set_stylebox("normal", "LineEdit", field)
	var field_focus := field.duplicate() as StyleBoxFlat
	field_focus.border_color = ACCENT
	field_focus.set_border_width_all(3)
	field_focus.border_width_bottom = 6
	t.set_stylebox("focus", "LineEdit", field_focus)
	t.set_color("font_color", "LineEdit", PAPER)
	t.set_color("caret_color", "LineEdit", ACCENT)
	t.set_color("font_placeholder_color", "LineEdit", Color(MUTED, 0.55))
	t.set_color("selection_color", "LineEdit", Color(ACCENT, 0.45))
	t.set_font("font", "LineEdit", font(600))

	# Sliders: rounded track, gold fill, paper knob with an ink rim.
	var track := StyleBoxFlat.new()
	track.bg_color = Color(PAPER, 0.12)
	track.set_corner_radius_all(8)
	track.content_margin_top = 6
	track.content_margin_bottom = 6
	var fill := track.duplicate() as StyleBoxFlat
	fill.bg_color = ACCENT
	var fill_hi := track.duplicate() as StyleBoxFlat
	fill_hi.bg_color = ACCENT.lightened(0.2)
	t.set_stylebox("slider", "HSlider", track)
	t.set_stylebox("grabber_area", "HSlider", fill)
	t.set_stylebox("grabber_area_highlight", "HSlider", fill_hi)
	t.set_icon("grabber", "HSlider", knob_texture(30, PAPER))
	t.set_icon("grabber_highlight", "HSlider", knob_texture(34, Color.WHITE))
	t.set_icon("grabber_disabled", "HSlider", knob_texture(30, MUTED))
	t.set_stylebox("focus", "HSlider", _focus_ring())
	_theme = t
	return t


## The game's standard panel box: INK glass with a faint paper rim and drop shadow.
static func panel_box(radius := 22, margin := 18) -> StyleBoxFlat:
	var panel := StyleBoxFlat.new()
	panel.bg_color = PANEL
	panel.set_corner_radius_all(radius)
	panel.set_content_margin_all(margin)
	panel.border_color = Color(PAPER, 0.1)
	panel.set_border_width_all(3)
	panel.shadow_color = Color(0, 0, 0, 0.25)
	panel.shadow_size = 12
	panel.shadow_offset = Vector2(0, 4)
	panel.anti_aliasing_size = 1.2
	return panel


## Round slider knob: paper disc with an ink rim (anti-aliased, generated once).
static func knob_texture(px: int, color: Color) -> ImageTexture:
	var img := Image.create(px, px, false, Image.FORMAT_RGBA8)
	var c := (px - 1) * 0.5
	for y in px:
		for x in px:
			var d := Vector2(x - c, y - c).length()
			var outer := clampf(c - d + 0.5, 0.0, 1.0)
			var inner := clampf(c - 4.0 - d + 0.5, 0.0, 1.0)
			var col := INK.lerp(color, inner)
			col.a = outer
			img.set_pixel(x, y, col)
	return ImageTexture.create_from_image(img)


## Hover/press motion and sound for any button: hover/focus scale 1.04 in 0.08 s,
## press 0.96, release springs back; soft pop on hover, louder pop on press.
static func juice_button(b: BaseButton, sounds := true) -> void:
	var center := func() -> void: b.pivot_offset = b.size * 0.5
	b.resized.connect(center)
	center.call()
	var to := func(s: float, time: float) -> void:
		var tw: Tween = b.get_meta(&"juice_tween") if b.has_meta(&"juice_tween") else null
		if tw:
			tw.kill()
		tw = b.create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		tw.tween_property(b, "scale", Vector2.ONE * s, time)
		b.set_meta(&"juice_tween", tw)
	var hover := func() -> void:
		if b.disabled:
			return
		to.call(1.04, 0.08)
		if sounds and b.is_visible_in_tree():
			Sfx.play_ui(&"pop", -20.0)
	b.mouse_entered.connect(hover)
	b.focus_entered.connect(hover)
	b.mouse_exited.connect(func() -> void:
		if not b.has_focus():
			to.call(1.0, 0.12)
	)
	b.focus_exited.connect(func() -> void: to.call(1.0, 0.12))
	b.button_down.connect(func() -> void: to.call(0.96, 0.05))
	b.button_up.connect(func() -> void: to.call(1.04 if b.is_hovered() or b.has_focus() else 1.0, 0.18))
	if sounds:
		b.pressed.connect(func() -> void: Sfx.play_ui(&"pop", -6.0))


## Animates a control in (scale 0.9 → 1 with back ease 0.25 s, fade 0.15 s), optionally
## delayed and sliding in from `from_offset`. Inside containers the slide starts after
## the next layout pass, so it ends exactly where the container puts the control.
static func pop_in(c: CanvasItem, delay := 0.0, from_offset := Vector2.ZERO) -> void:
	c.modulate.a = 0.0
	c.scale = Vector2.ONE * 0.9
	var ctrl := c as Control
	if ctrl and ctrl.get_parent() is Container and c.is_inside_tree():
		await c.get_tree().process_frame
		if not is_instance_valid(c):
			return
	if ctrl:
		ctrl.pivot_offset = ctrl.size * 0.5
	var tw := c.create_tween().set_parallel()
	if from_offset != Vector2.ZERO and ctrl:
		var target := ctrl.position
		ctrl.position = target + from_offset
		tw.tween_property(ctrl, "position", target, 0.32).set_delay(delay) \
			.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tw.tween_property(c, "scale", Vector2.ONE, 0.25).set_delay(delay).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(c, "modulate:a", 1.0, 0.15).set_delay(delay)


static func _label_variation(t: Theme, name: StringName, size: int, f: Font, color: Color, outline: int) -> void:
	t.set_type_variation(name, &"Label")
	t.set_font_size("font_size", name, size)
	t.set_font("font", name, f)
	t.set_color("font_color", name, color)
	t.set_constant("outline_size", name, outline)


static func _focus_ring() -> StyleBoxFlat:
	var ring := StyleBoxFlat.new()
	ring.draw_center = false
	ring.set_corner_radius_all(24)
	ring.border_color = PAPER
	ring.set_border_width_all(4)
	ring.set_expand_margin_all(6)
	ring.anti_aliasing_size = 1.2
	return ring


static func _box(bg: Color, border: Color) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	sb.set_corner_radius_all(18)
	sb.border_color = border
	sb.border_width_bottom = 6
	sb.content_margin_left = 34
	sb.content_margin_right = 34
	sb.content_margin_top = 12
	sb.content_margin_bottom = 14
	sb.shadow_color = Color(0, 0, 0, 0.25)
	sb.shadow_size = 6
	sb.shadow_offset = Vector2(0, 4)
	sb.anti_aliasing_size = 1.2
	return sb
