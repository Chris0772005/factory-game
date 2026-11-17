class_name MissionsPanel
extends CanvasLayer
## The three running missions on the left edge of the screen: track colour,
## what to do, how far, what it pays.

var _root: Control
var _box: VBoxContainer
var _title: Label
var _rows: Array[Label] = []
var _bars: Array[ColorRect] = []
var _tracks: Array[ColorRect] = []


func _ready() -> void:
	layer = 2
	_root = Control.new()
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.theme = UITheme.get_theme()
	add_child(_root)
	var pill := PanelContainer.new()
	pill.theme_type_variation = &"HudPill"
	pill.position = HUD.SAFE + Vector2(0, 150)
	pill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(pill)
	_box = VBoxContainer.new()
	_box.add_theme_constant_override(&"separation", 6)
	pill.add_child(_box)
	_title = Label.new()
	_title.add_theme_font_override(&"font", UITheme.font(700))
	_title.add_theme_font_size_override(&"font_size", 22)
	_title.add_theme_color_override(&"font_color", UITheme.ACCENT)
	_box.add_child(_title)
	for t in Missions.TRACKS.size():
		var row := Label.new()
		row.add_theme_font_override(&"font", UITheme.font(600))
		row.add_theme_font_size_override(&"font_size", 22)
		row.add_theme_color_override(&"font_color", UITheme.PAPER)
		row.custom_minimum_size = Vector2(400, 0)
		_box.add_child(row)
		_rows.append(row)
		var track := ColorRect.new()
		track.color = Color(1, 1, 1, 0.14)
		track.custom_minimum_size = Vector2(400, 5)
		_box.add_child(track)
		_tracks.append(track)
		var bar := ColorRect.new()
		bar.color = Missions.TRACKS[t].color
		bar.size = Vector2(0, 5)
		track.add_child(bar)
		_bars.append(bar)
	var m := get_parent() as Missions
	if m:
		m.changed.connect(_refresh)
	_refresh()


func _refresh() -> void:
	var m := get_parent() as Missions
	if m == null:
		return
	_title.text = "MISSIONEN · %d geschafft" % m.total if m.total > 0 else "MISSIONEN"
	for t in _rows.size():
		var cur := m.current(t)
		if cur.is_empty():
			_rows[t].text = "Neue Mission kommt …"
			_bars[t].size.x = 0.0
			continue
		_rows[t].text = "%s   %d/%d · +%d $" % [cur.text, cur.progress, cur.goal, cur.reward]
		_bars[t].size = Vector2(_tracks[t].custom_minimum_size.x * clampf(float(cur.progress) / float(cur.goal), 0.0, 1.0), 5)


func _process(_delta: float) -> void:
	# The wanted pill sits between the money and the missions; make room for it.
	var law := TownLaw.of(get_tree())
	var pill := _box.get_parent() as Control
	pill.position.y = HUD.SAFE.y + (150.0 if law and law.stars() > 0 else 92.0)
