class_name UITheme
## Builds the game's UI theme in code: rounded, chunky, high-contrast.

const INK := Color("#1f1b2d")
const PAPER := Color("#fff8ec")
const ACCENT := Color("#f2b134")
const ACCENT_DARK := Color("#c98a12")
const PANEL := Color(0.12, 0.10, 0.18, 0.78)

static var _theme: Theme


static func font(weight := 600) -> FontVariation:
	var fv := FontVariation.new()
	fv.base_font = load("res://assets/fonts/Fredoka.ttf")
	fv.variation_opentype = {TextServerManager.get_primary_interface().name_to_tag("wght"): weight}
	return fv


static func get_theme() -> Theme:
	if _theme:
		return _theme
	var t := Theme.new()
	t.default_font = font(600)
	t.default_font_size = 28
	t.set_color("font_color", "Label", PAPER)
	t.set_color("font_outline_color", "Label", INK)
	t.set_constant("outline_size", "Label", 8)

	var normal := _box(ACCENT, ACCENT_DARK)
	var hover := _box(ACCENT.lightened(0.15), ACCENT_DARK)
	var pressed := _box(ACCENT_DARK, ACCENT_DARK.darkened(0.2))
	pressed.content_margin_top += 4
	for state in [["normal", normal], ["hover", hover], ["pressed", pressed], ["focus", hover]]:
		t.set_stylebox(state[0], "Button", state[1])
	t.set_color("font_color", "Button", INK)
	t.set_color("font_hover_color", "Button", INK)
	t.set_color("font_pressed_color", "Button", INK)
	t.set_color("font_focus_color", "Button", INK)
	t.set_font_size("font_size", "Button", 32)

	var panel := StyleBoxFlat.new()
	panel.bg_color = PANEL
	panel.set_corner_radius_all(22)
	panel.set_content_margin_all(18)
	t.set_stylebox("panel", "PanelContainer", panel)

	var field := StyleBoxFlat.new()
	field.bg_color = PAPER
	field.set_corner_radius_all(14)
	field.set_content_margin_all(12)
	field.border_color = INK
	field.set_border_width_all(3)
	t.set_stylebox("normal", "LineEdit", field)
	t.set_stylebox("focus", "LineEdit", field)
	t.set_color("font_color", "LineEdit", INK)
	_theme = t
	return t


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
	return sb
