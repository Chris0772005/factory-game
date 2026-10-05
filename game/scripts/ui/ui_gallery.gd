extends Control
## Quick 2D preview of the UI kit for screenshots without the 3D yard:
## `godot-render --path game res://scripts/ui/ui_gallery.tscn -- --show=hud|pause|settings --shot=… --frames=60`

var _show := "hud"


func _ready() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--show="):
			_show = arg.trim_prefix("--show=")
	theme = UITheme.get_theme()
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var bg := TextureRect.new()
	var grad := Gradient.new()
	grad.offsets = PackedFloat32Array([0.0, 0.55, 1.0])
	grad.colors = PackedColorArray([Color("#3a3355"), Color("#7a5a6a"), Color("#4a3a2e")])
	var tex := GradientTexture2D.new()
	tex.gradient = grad
	tex.fill_from = Vector2(0.5, 0.0)
	tex.fill_to = Vector2(0.5, 1.0)
	bg.texture = tex
	bg.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)
	match _show:
		"pause", "settings":
			var pm := PauseMenu.new()
			pm.pause_tree = false
			add_child(pm)
			await get_tree().process_frame
			pm.open()
			if _show == "settings":
				await get_tree().create_timer(0.3).timeout
				pm._show_settings()
		_:
			_hud_kit()


func _hud_kit() -> void:
	var pill := PanelContainer.new()
	pill.theme_type_variation = &"HudPill"
	pill.position = Vector2(96, 54)
	add_child(pill)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	pill.add_child(row)
	var coin := CoinIcon.new()
	coin.radius = 23.0
	coin.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(coin)
	var money := Label.new()
	money.text = "2.173"
	money.add_theme_font_override("font", UITheme.display_font())
	money.add_theme_font_size_override("font_size", 50)
	money.add_theme_constant_override("outline_size", 12)
	row.add_child(money)
	var delta := Label.new()
	delta.text = "+120"
	delta.add_theme_font_override("font", UITheme.display_font())
	delta.add_theme_font_size_override("font_size", 38)
	delta.add_theme_constant_override("outline_size", 12)
	delta.add_theme_color_override("font_color", UITheme.COIN)
	delta.position = Vector2(330, 64)
	add_child(delta)

	var keys := HBoxContainer.new()
	keys.position = Vector2(96, 220)
	keys.add_theme_constant_override("separation", 14)
	add_child(keys)
	for t in ["F", "LMB", "RMB", "SHIFT", "SPACE", "E"]:
		keys.add_child(KeyPrompt.new().setup(t))
	var hold := KeyPrompt.new().setup("F halten")
	hold._hold_t = 0.65
	keys.add_child(hold)
	var pads := HBoxContainer.new()
	pads.position = Vector2(96, 300)
	pads.add_theme_constant_override("separation", 14)
	add_child(pads)
	for t in ["A", "B", "X", "Y", "LB", "RT", "LS", "START"]:
		pads.add_child(KeyPrompt.pad_glyph(t))

	var world_bubble := PromptBubble.new()
	add_child(world_bubble)
	world_bubble.bottom_margin = 640
	world_bubble.anchor = PromptBubble.Anchor.BOTTOM
	world_bubble.set_hint("[F] Blasebalg treten  · Hitze 37 %")
	var held := PromptBubble.new()
	add_child(held)
	held.set_hint("[F halten] Gießen  · 1.4 l · 1150 °C")
	var carry := PromptBubble.new()
	add_child(carry)
	carry.bottom_margin = 170
	carry.set_hint("[LMB] Ablegen   [RMB] Werfen")
	var plain := PromptBubble.new()
	add_child(plain)
	plain.bottom_margin = 270
	plain.set_hint("Gold · Gut · 120 $   [RMB] Werfen")
	await get_tree().create_timer(0.35).timeout
	var b := GradeBanner.new()
	b.text = "MAKELLOS!"
	b.color = Color("#5bb8e8")
	b.subtitle = "Katze · Bronze · 240 $"
	add_child(b)
	b.position = Vector2(1200, 330) - b.size * 0.5
