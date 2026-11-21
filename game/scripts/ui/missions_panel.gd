class_name MissionsPanel
extends CanvasLayer
## The three running missions on the left edge of the screen, one line each:
## a bar in the track's colour, what to do, the count, the pay. Short labels
## and numbers, no sentences (HUDs of Supermarket Simulator and Find the
## Needle were the model).

const WIDTH := 392.0

var _pill: PanelContainer
var _title: Label
var _names: Array[Label] = []
var _counts: Array[Label] = []
var _pays: Array[Label] = []
var _bars: Array[ColorRect] = []
var _tracks: Array[ColorRect] = []


func _ready() -> void:
	layer = 2
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.theme = UITheme.get_theme()
	add_child(root)
	_pill = PanelContainer.new()
	_pill.theme_type_variation = &"HudPill"
	_pill.position = HUD.SAFE + Vector2(0, 92)
	_pill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(_pill)
	var box := VBoxContainer.new()
	box.add_theme_constant_override(&"separation", 5)
	_pill.add_child(box)
	_title = _label(17, UITheme.ACCENT, 700)
	box.add_child(_title)
	for t in Missions.TRACKS.size():
		var row := HBoxContainer.new()
		row.add_theme_constant_override(&"separation", 12)
		row.custom_minimum_size = Vector2(WIDTH, 0)
		box.add_child(row)
		var name_l := _label(21, UITheme.PAPER, 600)
		name_l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		name_l.clip_text = true
		row.add_child(name_l)
		_names.append(name_l)
		var count := _label(21, UITheme.MUTED, 600)
		row.add_child(count)
		_counts.append(count)
		var pay := _label(21, UITheme.ACCENT, 700)
		pay.custom_minimum_size = Vector2(70, 0)
		pay.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		row.add_child(pay)
		_pays.append(pay)
		var track := ColorRect.new()
		track.color = Color(1, 1, 1, 0.1)
		track.custom_minimum_size = Vector2(WIDTH, 3)
		box.add_child(track)
		_tracks.append(track)
		var bar := ColorRect.new()
		bar.color = Missions.TRACKS[t].color
		bar.size = Vector2(0, 3)
		track.add_child(bar)
		_bars.append(bar)
	var m := get_parent() as Missions
	if m:
		m.changed.connect(_refresh)
	_refresh()


func _label(size: int, color: Color, weight: int) -> Label:
	var l := Label.new()
	l.add_theme_font_override(&"font", UITheme.font(weight))
	l.add_theme_font_size_override(&"font_size", size)
	l.add_theme_color_override(&"font_color", color)
	l.add_theme_constant_override(&"outline_size", 0)
	return l


func _refresh() -> void:
	var m := get_parent() as Missions
	if m == null:
		return
	_title.text = "MISSIONEN  %d" % m.total if m.total > 0 else "MISSIONEN"
	for t in _names.size():
		var cur := m.current(t)
		if cur.is_empty():
			_names[t].text = "…"
			_counts[t].text = ""
			_pays[t].text = ""
			_bars[t].size.x = 0.0
			continue
		_names[t].text = cur.text
		_counts[t].text = "%d/%d" % [cur.progress, cur.goal]
		_pays[t].text = "+%d $" % cur.reward
		_bars[t].size = Vector2(WIDTH * clampf(float(cur.progress) / float(cur.goal), 0.0, 1.0), 3)


func _process(_delta: float) -> void:
	# The wanted box and the debt at the bank sit between the money and the missions; make room for them.
	var law := TownLaw.of(get_tree())
	_pill.position.y = HUD.SAFE.y + (146.0 if law and law.stars() > 0 else 92.0) + BankHud.room(get_tree())
