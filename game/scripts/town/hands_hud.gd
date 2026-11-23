class_name HandsHud
extends CanvasLayer
## The hands the crew employs (HiredHand): a pill under the money with how many there are and what
## they cost per minute, so nobody wonders where the money goes. It turns red while one of them
## waits for the wage. Nothing shows while nobody is hired.

## Height the pill takes in the column under the money (the missions move down by it).
const ROW := 46.0

var _pill: PanelContainer
var _text: Label
var _shown := ""


## How far the things under the money move down for the pill (0 while nobody is hired).
static func room(tree: SceneTree) -> float:
	return ROW if tree and HiredHand.count(tree) > 0 else 0.0


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
	_pill.visible = false
	root.add_child(_pill)
	var row := HBoxContainer.new()
	row.add_theme_constant_override(&"separation", 10)
	_pill.add_child(row)
	var title := Label.new()
	title.text = "HELFER"
	title.add_theme_font_override(&"font", UITheme.font(700))
	title.add_theme_font_size_override(&"font_size", 24)
	title.add_theme_color_override(&"font_color", UITheme.PAPER)
	row.add_child(title)
	_text = Label.new()
	_text.add_theme_font_override(&"font", UITheme.font(700))
	_text.add_theme_font_size_override(&"font_size", 24)
	row.add_child(_text)


func _process(_delta: float) -> void:
	var hands := 0
	var cost := 0
	var unpaid := 0
	for node in get_tree().get_nodes_in_group(HiredHand.GROUP):
		var hand := node as HiredHand
		if not hand.hired():
			continue
		hands += 1
		cost += int(hand.info().wage)
		if hand.state == HiredHand.State.UNPAID:
			unpaid += 1
	_pill.visible = hands > 0
	if hands == 0:
		_shown = ""
		return
	# The wanted box (TownLaw) and the debt at the bank come first in the column under the money.
	var law := TownLaw.of(get_tree())
	_pill.position.y = HUD.SAFE.y + (146.0 if law and law.stars() > 0 else 92.0) + BankHud.room(get_tree())
	var text := "%d · %d $ pro Minute" % [hands, cost]
	if unpaid > 0:
		text = "%d · %s auf Lohn" % [hands, "einer wartet" if unpaid == 1 else "%d warten" % unpaid]
	if text != _shown:
		_shown = text
		_text.text = text
		_text.add_theme_color_override(&"font_color", UITheme.BAD if unpaid > 0 else UITheme.ACCENT)
