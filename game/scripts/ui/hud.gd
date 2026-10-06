class_name HUD
extends CanvasLayer
## In-game overlay (Art Bible 12): the money counter (coin icon, rolling number, coins
## that fly in from the sale and pop the counter, a +/− chip), contextual key-glyph
## prompts – anchored above the station you face, or bottom centre for what you carry –
## big grade/reveal banners (`HUD.banner`), the pause menu (Esc / Start) and floating
## world popups (`HUD.popup`). At most three elements at once; safe area 5 %.
## Debug for screenshots: `-- --ui=pause` opens the pause menu, `--ui=banner` shows a banner.

const SAFE := Vector2(96.0, 54.0)
## Station prompts float this far above the station's interact point (m).
const PROMPT_LIFT := 0.55

## The HUD of the running level (for the static `banner`).
static var _current: HUD
## Where the last "+N $" world popup appeared, so coins can fly from the sale.
static var _last_money_pos := Vector3.ZERO
static var _last_money_msec := -100000

var world: GameWorld
var pause_menu: PauseMenu

var _root: Control
var _money_pill: PanelContainer
var _coin: CoinIcon
var _label: Label
var _delta: Label
var _delta_sum := 0
var _delta_tween: Tween
var _shown := 0.0
var _target := 0.0
var _last_money := 0
var _held_bubble: PromptBubble
var _station_bubble: PromptBubble
var _fly_layer: Control
var _banner_layer: Control
var _banner: GradeBanner
var _banner_queue: Array[Array] = []


func _ready() -> void:
	_current = self
	_root = Control.new()
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.theme = UITheme.get_theme()
	add_child(_root)
	_build_money()
	_station_bubble = PromptBubble.new()
	_station_bubble.anchor = PromptBubble.Anchor.WORLD
	_station_bubble.key_size = 38.0
	_station_bubble.font_size = UITheme.SIZE_HINT - 2
	_root.add_child(_station_bubble)
	_held_bubble = PromptBubble.new()
	_root.add_child(_held_bubble)
	var card := NextStepCard.new()
	card.world = world
	_root.add_child(card)
	_banner_layer = _layer_control()
	_fly_layer = _layer_control()
	var pause_layer := CanvasLayer.new()
	pause_layer.layer = 40
	add_child(pause_layer)
	pause_menu = PauseMenu.new()
	pause_menu.world = world
	pause_menu.theme = UITheme.get_theme()
	pause_layer.add_child(pause_menu)
	if world:
		_last_money = world.money
		_shown = world.money
		_target = world.money
		world.money_changed.connect(_on_money)
	_label.text = _format(int(_shown))
	_debug_ui.call_deferred()


func _exit_tree() -> void:
	if _current == self:
		_current = null


func _process(delta: float) -> void:
	if not world:
		return
	# Rolling number: eases onto the target, which the arriving coins raise.
	_shown = lerpf(_shown, _target, 1.0 - exp(-9.0 * delta))
	if absf(_shown - _target) < 0.5:
		_shown = _target
	_label.text = _format(int(round(_shown)))
	_update_prompts()


func _update_prompts() -> void:
	var me := world.local_player()
	if me == null or me.ui_locked or (pause_menu and pause_menu.is_open):
		_held_bubble.set_hint("")
		_station_bubble.set_hint("")
		return
	var hint := me.current_hint()
	if me.holding:
		_station_bubble.set_hint("")
		_held_bubble.set_hint(hint, "held:" + me.held_name)
		return
	_held_bubble.set_hint("")
	var station := me.nearest_interactable() if not hint.is_empty() else null
	if station == null:
		_station_bubble.set_hint("")
		return
	var point: Vector3 = station.interact_point() if station.has_method("interact_point") else station.global_position
	_station_bubble.world_point = point + Vector3.UP * PROMPT_LIFT
	_station_bubble.set_hint(hint, str(station.get_instance_id()))


# --- Money --------------------------------------------------------------------

func _build_money() -> void:
	_money_pill = PanelContainer.new()
	_money_pill.theme_type_variation = &"HudPill"
	_money_pill.position = SAFE
	_money_pill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(_money_pill)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	_money_pill.add_child(row)
	_coin = CoinIcon.new()
	_coin.radius = 23.0
	_coin.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(_coin)
	_label = Label.new()
	_label.add_theme_font_override("font", UITheme.display_font())
	_label.add_theme_font_size_override("font_size", 50)
	_label.add_theme_constant_override("outline_size", 12)
	_label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.35))
	_label.add_theme_constant_override("shadow_offset_y", 4)
	_label.add_theme_constant_override("shadow_offset_x", 0)
	_label.custom_minimum_size.x = 0
	_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	row.add_child(_label)
	_delta = Label.new()
	_delta.add_theme_font_override("font", UITheme.display_font())
	_delta.add_theme_font_size_override("font_size", 38)
	_delta.add_theme_constant_override("outline_size", 12)
	_delta.modulate.a = 0.0
	_root.add_child(_delta)
	UITheme.pop_in(_money_pill, 0.15, Vector2(-30, 0))


func _on_money(amount: int) -> void:
	var change := amount - _last_money
	_last_money = amount
	if change == 0:
		return
	_show_delta(change)
	if change > 0:
		# Deferred: the sale's "+N $" popup (which tells us where it happened) follows the signal.
		_fly_coins.call_deferred(change)
	else:
		_target = amount
		var tw := _money_pill.create_tween()
		for i in 4:
			tw.tween_property(_money_pill, "position:x", SAFE.x + (8.0 if i % 2 == 0 else -6.0) * (1.0 - i * 0.22), 0.04)
		tw.tween_property(_money_pill, "position:x", SAFE.x, 0.06)


func _show_delta(change: int) -> void:
	if _delta_tween and _delta_tween.is_running() and signi(_delta_sum) == signi(change):
		_delta_sum += change
	else:
		_delta_sum = change
	_delta.text = ("+%s" if _delta_sum > 0 else "−%s") % _format(absi(_delta_sum))
	_delta.add_theme_color_override("font_color", UITheme.COIN if _delta_sum > 0 else UITheme.BAD)
	_delta.reset_size()
	var base := Vector2(_money_pill.position.x + _money_pill.size.x + 16.0, _money_pill.position.y + (_money_pill.size.y - _delta.size.y) * 0.5)
	if _delta_tween:
		_delta_tween.kill()
	_delta.position = base + Vector2(-18, 0)
	_delta_tween = _delta.create_tween()
	_delta_tween.set_parallel()
	_delta_tween.tween_property(_delta, "position", base, 0.22).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_delta_tween.tween_property(_delta, "modulate:a", 1.0, 0.12)
	_delta_tween.chain().tween_interval(1.1)
	_delta_tween.chain().tween_property(_delta, "position:y", base.y - 22.0, 0.3).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	_delta_tween.parallel().tween_property(_delta, "modulate:a", 0.0, 0.3)
	Juice.punch(_delta, 0.12)


func _fly_coins(amount: int) -> void:
	var to := _coin.get_global_rect().get_center()
	var from := to + Vector2(140.0, 300.0)
	var cam := get_viewport().get_camera_3d()
	if Time.get_ticks_msec() - _last_money_msec < 800 and cam and not cam.is_position_behind(_last_money_pos):
		from = cam.unproject_position(_last_money_pos)
	var n := clampi(3 + amount / 40, 3, 9)
	var share := float(amount) / n
	var rng := RandomNumberGenerator.new()
	rng.seed = amount * 31 + _last_money
	for i in n:
		var coin := CoinIcon.new()
		coin.radius = 13.0
		_fly_layer.add_child(coin)
		var start := from + Vector2(rng.randf_range(-36, 36), rng.randf_range(-24, 24))
		var bend := (start + to) * 0.5 + Vector2(rng.randf_range(-220.0, 60.0), rng.randf_range(-260.0, -120.0))
		var half := coin.custom_minimum_size * 0.5
		coin.position = start - half
		coin.pivot_offset = half
		coin.scale = Vector2.ONE * 0.4
		coin.modulate.a = 0.0
		var time := rng.randf_range(0.48, 0.66)
		var delay := 0.12 + i * 0.055
		var last := i == n - 1
		var tw := coin.create_tween()
		tw.tween_interval(delay)
		tw.tween_callback(coin.spin.bind(time))
		tw.set_parallel()
		tw.tween_property(coin, "modulate:a", 1.0, 0.08)
		tw.tween_property(coin, "scale", Vector2.ONE * 1.15, time * 0.45).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		tw.tween_method(func(t: float) -> void:
			var a := start.lerp(bend, t)
			var b := bend.lerp(to, t)
			coin.position = a.lerp(b, t) - half
		, 0.0, 1.0, time).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
		tw.chain().tween_callback(func() -> void:
			_target = float(world.money) if last else minf(float(world.money), _target + share)
			Juice.punch(_label, 0.16, 0.3)
			Juice.punch(_coin, 0.22, 0.3)
			_coin.spin(0.35)
			Sfx.play_ui(&"pop", -18.0 if not last else -12.0)
			coin.queue_free()
		)


# --- Banner -------------------------------------------------------------------

## Big juicy ribbon in the upper third, e.g. HUD.banner("MAKELLOS!", Color("#6fb8ff"), "Katze · 240 $").
## Banners queue; a waiting one hurries the current one along. No-op without a HUD.
static func banner(text: String, color := UITheme.ACCENT, subtitle := "") -> void:
	if _current == null or not is_instance_valid(_current):
		return
	_current._enqueue_banner(text, color, subtitle)


func _enqueue_banner(text: String, color: Color, subtitle: String) -> void:
	_banner_queue.append([text, color, subtitle])
	if _banner and is_instance_valid(_banner):
		_banner.hurry()
	else:
		_next_banner()


func _next_banner() -> void:
	_banner = null
	if _banner_queue.is_empty():
		return
	var entry: Array = _banner_queue.pop_front()
	var b := GradeBanner.new()
	b.text = entry[0]
	b.color = entry[1]
	b.subtitle = entry[2]
	_banner_layer.add_child(b)
	var vp := _root.get_viewport_rect().size
	b.position = Vector2(vp.x * 0.5, vp.y * 0.3) - b.size * 0.5
	b.finished.connect(_next_banner)
	_banner = b
	if not _banner_queue.is_empty():
		b.hurry()


# --- World popups -------------------------------------------------------------

static func _format(n: int) -> String:
	var s := str(absi(n))
	var out := ""
	while s.length() > 3:
		out = "." + s.substr(s.length() - 3) + out
		s = s.substr(0, s.length() - 3)
	return ("-" if n < 0 else "") + s + out


## Floating world-space popup, e.g. "+5" above a seller: pops in with a bounce,
## drifts up and fades. "+N $" popups also tell the HUD where coins fly from.
static func popup(parent: Node3D, pos: Vector3, text: String, color := UITheme.ACCENT) -> void:
	if text.begins_with("+") and text.ends_with("$"):
		_last_money_pos = pos
		_last_money_msec = Time.get_ticks_msec()
	var l := Label3D.new()
	l.text = text
	l.font = UITheme.display_font()
	# Small enough to sit at the casting (cap height ≈ 4 % of the screen at play distance).
	l.font_size = 64
	l.outline_size = 18
	l.modulate = color
	l.outline_modulate = UITheme.INK
	l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	l.no_depth_test = true
	l.pixel_size = 0.0022
	l.render_priority = 10
	l.outline_render_priority = 9
	# Animated in _process by the tween: render where we put it.
	l.physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
	parent.add_child(l)
	l.global_position = pos
	l.scale = Vector3.ONE * 0.35
	var drift := Vector3(randf_range(-0.15, 0.15), 0.8, 0.0)
	var tw := l.create_tween().set_parallel()
	tw.tween_property(l, "scale", Vector3.ONE, 0.32).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(l, "global_position", pos + drift, 1.2).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	tw.tween_property(l, "modulate:a", 0.0, 0.4).set_delay(0.8)
	tw.tween_property(l, "outline_modulate:a", 0.0, 0.4).set_delay(0.8)
	tw.chain().tween_callback(l.queue_free)


# --- Helpers ------------------------------------------------------------------

func _layer_control() -> Control:
	var c := Control.new()
	c.set_anchors_preset(Control.PRESET_FULL_RECT)
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(c)
	return c


func _debug_ui() -> void:
	var args := OS.get_cmdline_user_args()
	if "--ui=pause" in args:
		await get_tree().create_timer(1.0).timeout
		pause_menu.open()
	if "--ui=banner" in args:
		await get_tree().create_timer(1.3).timeout
		HUD.banner("MAKELLOS!", Color("#5bb8e8"), "Katze · Bronze · 240 $")
