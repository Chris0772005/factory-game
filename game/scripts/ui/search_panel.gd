class_name SearchPanel
extends PanelContainer
## HUD pill under the money counter for the Suchaufträge (SearchHunt): what
## is lost, the seconds left, how warm the local worker is, and the tally of
## finds per worker. Hidden until the first hunt.

const WARM_COLORS := {"glühend heiß!": Color("#ff5a2e"), "heiß": Color("#ff8a3a"), "warm": Color("#ffb347"),
	"lauwarm": Color("#f0e2c4"), "kalt": Color("#9fc4e8"), "eiskalt": Color("#6fa8e6")}

var world: GameWorld
var _hunt: SearchHunt
var _title: Label
var _item: Label
var _warm: Label
var _scores: HBoxContainer
var _score_labels: Array[Label] = []


func _ready() -> void:
	theme_type_variation = &"HudPill"
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_preset(Control.PRESET_TOP_LEFT)
	offset_left = 100
	offset_top = 150
	custom_minimum_size = Vector2(330, 0)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 0)
	add_child(col)
	_title = Label.new()
	_title.add_theme_font_size_override("font_size", 16)
	_title.add_theme_color_override("font_color", UITheme.ACCENT)
	col.add_child(_title)
	_item = Label.new()
	_item.add_theme_font_size_override("font_size", 21)
	col.add_child(_item)
	_warm = Label.new()
	_warm.add_theme_font_size_override("font_size", 24)
	col.add_child(_warm)
	_scores = HBoxContainer.new()
	_scores.add_theme_constant_override("separation", 14)
	col.add_child(_scores)
	for i in GameWorld.PLAYER_COLORS.size():
		var l := Label.new()
		l.add_theme_font_size_override("font_size", 19)
		l.add_theme_color_override("font_color", (GameWorld.PLAYER_COLORS[i] as Color).lightened(0.35))
		_scores.add_child(l)
		_score_labels.append(l)
	visible = false


func _process(_delta: float) -> void:
	if _hunt == null or not is_instance_valid(_hunt):
		_hunt = get_tree().get_first_node_in_group(&"search_hunts") as SearchHunt
	if _hunt == null:
		visible = false
		return
	var total := 0
	for i in _score_labels.size():
		var n: int = _hunt.scores[i]
		total += n
		_score_labels[i].text = "● %d" % n
		_score_labels[i].visible = n > 0
	visible = _hunt.active or total > 0
	if not visible:
		return
	_scores.visible = total > 0
	if _hunt.active:
		_title.text = "SUCHAUFTRAG · %d s · %d $" % [ceili(_hunt.time_left), _hunt.reward()]
		_item.text = _hunt.item().name
		var me := world.local_player() if world else null
		var w := _hunt.warmth(me.global_position) if me else ""
		_warm.text = w.to_upper()
		_warm.add_theme_color_override("font_color", WARM_COLORS.get(w, Color.WHITE))
		_item.visible = true
		_warm.visible = true
	else:
		_title.text = "SPÜRNASEN"
		_item.visible = false
		_warm.visible = false
