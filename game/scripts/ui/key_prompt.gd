class_name KeyPrompt
extends Control
## Input glyph drawn in code (Art Bible 12): a rounded paper key cap ("F", "SHIFT"),
## a mouse with the left/right button lit ("LMB"/"RMB"), or – after gamepad input –
## the bound pad button (coloured A/B/X/Y discs, LB/RB/LT/RT pills).
## Hold actions get a ring that fills while the button is held. The cap sinks while
## its action is pressed. Switches device live via Juice.device_changed.

## Hint tokens ("[F]", "[LMB]") → input actions.
const TOKEN_ACTIONS := {
	"F": &"interact", "LMB": &"grab", "RMB": &"throw", "E": &"grab", "Q": &"throw",
	"SPACE": &"jump", "LEERTASTE": &"jump", "SHIFT": &"sprint",
}
const PAD_COLORS := {
	JOY_BUTTON_A: Color("#6ccb5f"), JOY_BUTTON_B: Color("#e5533d"),
	JOY_BUTTON_X: Color("#5bb8e8"), JOY_BUTTON_Y: Color("#f2b134"),
}
const PAD_NAMES := {
	JOY_BUTTON_A: "A", JOY_BUTTON_B: "B", JOY_BUTTON_X: "X", JOY_BUTTON_Y: "Y",
	JOY_BUTTON_LEFT_SHOULDER: "LB", JOY_BUTTON_RIGHT_SHOULDER: "RB",
	JOY_BUTTON_LEFT_STICK: "L3", JOY_BUTTON_RIGHT_STICK: "R3",
	JOY_BUTTON_START: "START", JOY_BUTTON_BACK: "BACK",
}
const HOLD_FILL := 0.4

## Cap height in pixels (44 at 1080p).
@export var cap := 44.0
var key_text := "F"
var action: StringName = &""
var hold := false

var _pad_text := ""
var _pad_button := -1
var _force_pad := false
var _pressed := false
var _hold_t := 0.0
var _font: Font


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_font = UITheme.font(700)


## Glyph for an input action: its first keyboard/mouse binding, or its pad button.
static func for_action(input_action: StringName, cap_px := 44.0) -> KeyPrompt:
	var k := KeyPrompt.new()
	k.cap = cap_px
	k.key_text = "?"
	if InputMap.has_action(input_action):
		for ev in InputMap.action_get_events(input_action):
			if ev is InputEventKey:
				k.key_text = OS.get_keycode_string((ev as InputEventKey).physical_keycode).to_upper()
				break
			if ev is InputEventMouseButton:
				k.key_text = {MOUSE_BUTTON_LEFT: "LMB", MOUSE_BUTTON_RIGHT: "RMB"}.get((ev as InputEventMouseButton).button_index, "MMB")
				break
	k.action = input_action
	k._refresh_pad()
	k._update_size()
	return k


## A fixed gamepad glyph ("LS", "A"), shown whatever device was used last.
static func pad_glyph(text: String, cap_px := 44.0) -> KeyPrompt:
	var k := KeyPrompt.new()
	k.cap = cap_px
	k._force_pad = true
	k._pad_text = text
	k._pad_button = PAD_NAMES.find_key(text) if PAD_NAMES.values().has(text) else -1
	k._update_size()
	return k


## `token` is the text inside the hint brackets ("F", "LMB", "F halten").
func setup(token: String, is_hold := false) -> KeyPrompt:
	var parts := token.strip_edges().split(" ", false)
	key_text = parts[0].to_upper() if parts.size() > 0 else "?"
	hold = is_hold or token.contains("halten")
	action = TOKEN_ACTIONS.get(key_text, &"")
	_refresh_pad()
	_update_size()
	return self


func _ready() -> void:
	Juice.device_changed.connect(_on_device_changed)


func _on_device_changed(_pad: bool) -> void:
	_update_size()


func _process(delta: float) -> void:
	if action == &"" or not InputMap.has_action(action):
		return
	var down := Input.is_action_pressed(action)
	_hold_t = clampf(_hold_t + (delta if down else -delta * 3.0) / HOLD_FILL, 0.0, 1.0) if hold else 0.0
	if down != _pressed or (hold and _hold_t > 0.0 and _hold_t < 1.0):
		_pressed = down
		queue_redraw()


func _pad_mode() -> bool:
	return _force_pad or (Juice.using_gamepad and _pad_text != "")


func _refresh_pad() -> void:
	_pad_text = ""
	_pad_button = -1
	if action == &"" or not InputMap.has_action(action):
		return
	for ev in InputMap.action_get_events(action):
		if ev is InputEventJoypadButton:
			_pad_button = (ev as InputEventJoypadButton).button_index
			_pad_text = PAD_NAMES.get(_pad_button, "?")
			return
	for ev in InputMap.action_get_events(action):
		if ev is InputEventJoypadMotion:
			var axis := (ev as InputEventJoypadMotion).axis
			if axis == JOY_AXIS_TRIGGER_RIGHT:
				_pad_text = "RT"
			elif axis == JOY_AXIS_TRIGGER_LEFT:
				_pad_text = "LT"
			return


func _update_size() -> void:
	var w := cap
	if _pad_mode():
		w = cap if _pad_button in PAD_COLORS else maxf(cap * 1.35, _text_width(_pad_text, cap * 0.42) + 22.0)
	elif _is_mouse():
		w = cap * 0.78
	else:
		w = maxf(cap, _text_width(key_text, _key_font_size()) + 24.0)
	var ring := 10.0 if hold else 0.0
	custom_minimum_size = Vector2(w + ring, cap + ring)
	update_minimum_size()
	queue_redraw()


func _is_mouse() -> bool:
	return key_text == "LMB" or key_text == "RMB" or key_text == "MMB"


func _key_font_size() -> int:
	return int(cap * (0.5 if key_text.length() <= 2 else 0.36))


func _text_width(text: String, font_size: float) -> float:
	return _font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, int(font_size)).x


func _draw() -> void:
	var ring := 5.0 if hold else 0.0
	var box := Rect2(Vector2(ring, ring), size - Vector2(ring, ring) * 2.0)
	if _pad_mode():
		_draw_pad(box)
	elif _is_mouse():
		_draw_mouse(box)
	else:
		_draw_key(box)
	if hold:
		var c := size * 0.5
		var r := minf(size.x, size.y) * 0.5 - 2.0
		draw_arc(c, r, 0.0, TAU, 48, Color(UITheme.PAPER, 0.4), 4.5, true)
		if _hold_t > 0.0:
			draw_arc(c, r, -PI * 0.5, -PI * 0.5 + TAU * _hold_t, 48, UITheme.ACCENT, 4.5, true)


func _draw_key(box: Rect2) -> void:
	var sink := 3.0 if _pressed else 0.0
	_round_rect(box, 10.0, UITheme.INK)
	var lip := Rect2(box.position + Vector2(3, 3 + sink), box.size - Vector2(6, 6 + sink))
	_round_rect(lip, 8.0, UITheme.PAPER.darkened(0.32))
	var face := Rect2(lip.position, lip.size - Vector2(0, 4.0 - sink * 0.75))
	_round_rect(face, 8.0, UITheme.PAPER if not _pressed else UITheme.ACCENT.lightened(0.35))
	var fs := _key_font_size()
	var tw := _text_width(key_text, fs)
	var base := face.position.y + face.size.y * 0.5 + fs * 0.36
	draw_string(_font, Vector2(face.get_center().x - tw * 0.5, base), key_text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, UITheme.INK)


func _draw_mouse(box: Rect2) -> void:
	var body := Rect2(box.position + Vector2(1, 0), box.size - Vector2(2, 0))
	var r := body.size.x * 0.5
	_round_rect(body, r, UITheme.INK)
	var inner := body.grow(-3.0)
	_round_rect(inner, r - 3.0, UITheme.PAPER)
	var split_y := inner.position.y + inner.size.y * 0.46
	var left := key_text == "LMB"
	var half := inner.size.x * 0.5
	var lit := Rect2(Vector2(inner.position.x if left else inner.position.x + half, inner.position.y), Vector2(half, split_y - inner.position.y))
	var sb := StyleBoxFlat.new()
	sb.bg_color = UITheme.ACCENT if not _pressed else UITheme.ACCENT_DARK
	sb.anti_aliasing_size = 1.0
	if left:
		sb.corner_radius_top_left = int(half)
	else:
		sb.corner_radius_top_right = int(half)
	draw_style_box(sb, lit)
	draw_line(Vector2(inner.get_center().x, inner.position.y), Vector2(inner.get_center().x, split_y), UITheme.INK, 2.5, true)
	draw_line(Vector2(inner.position.x, split_y), Vector2(inner.end.x, split_y), UITheme.INK, 2.5, true)


func _draw_pad(box: Rect2) -> void:
	var sink := 2.0 if _pressed else 0.0
	if _pad_button in PAD_COLORS:
		var c := box.get_center()
		var r := minf(box.size.x, box.size.y) * 0.5
		var col: Color = PAD_COLORS[_pad_button]
		draw_circle(c + Vector2(0, 2), r, UITheme.INK, true, -1.0, true)
		draw_circle(c, r, UITheme.INK, true, -1.0, true)
		draw_circle(c + Vector2(0, sink), r - 3.0, col.darkened(0.25), true, -1.0, true)
		draw_circle(c + Vector2(0, sink - 1.5), r - 4.5, col, true, -1.0, true)
		draw_arc(c + Vector2(0, sink - 1.5), r - 8.0, PI * 1.1, PI * 1.6, 12, Color(1, 1, 1, 0.45), 2.5, true)
		var fs := int(cap * 0.5)
		var tw := _text_width(_pad_text, fs)
		var base := c.y + sink + fs * 0.34
		draw_string_outline(_font, Vector2(c.x - tw * 0.5, base), _pad_text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, 6, UITheme.INK)
		draw_string(_font, Vector2(c.x - tw * 0.5, base), _pad_text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, UITheme.PAPER)
	else:
		_round_rect(box, box.size.y * 0.45, UITheme.INK)
		var face := Rect2(box.position + Vector2(3, 3 + sink), box.size - Vector2(6, 8))
		_round_rect(face, face.size.y * 0.45, Color("#4a4460") if not _pressed else UITheme.ACCENT_DARK)
		var fs := int(cap * 0.42)
		var tw := _text_width(_pad_text, fs)
		draw_string(_font, Vector2(face.get_center().x - tw * 0.5, face.get_center().y + fs * 0.36), _pad_text,
			HORIZONTAL_ALIGNMENT_LEFT, -1, fs, UITheme.PAPER)


func _round_rect(r: Rect2, radius: float, color: Color) -> void:
	var sb := StyleBoxFlat.new()
	sb.bg_color = color
	sb.set_corner_radius_all(int(radius))
	sb.anti_aliasing_size = 1.0
	draw_style_box(sb, r)
