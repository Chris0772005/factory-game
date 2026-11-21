class_name BankHud
extends CanvasLayer
## The crew's debt at the bank (BankLoan): a pill under the money with what is still owed and a bar
## of how much is paid back. Nothing shows while nothing is owed.

## Height the pill takes in the column under the money (the missions move down by it).
const ROW := 54.0

var _pill: PanelContainer
var _amount: Label
var _bar: ColorRect
var _track: ColorRect
var _flash := 0.0
var _shown := -1


## How far the things under the money move down for the debt pill (0 while nothing is owed).
static func room(tree: SceneTree) -> float:
	var bank := BankLoan.of(tree)
	return ROW if bank and bank.debt > 0 else 0.0


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
	var col := VBoxContainer.new()
	col.add_theme_constant_override(&"separation", 3)
	_pill.add_child(col)
	var row := HBoxContainer.new()
	row.add_theme_constant_override(&"separation", 10)
	col.add_child(row)
	var title := Label.new()
	title.text = "KREDIT"
	title.add_theme_font_override(&"font", UITheme.font(700))
	title.add_theme_font_size_override(&"font_size", 24)
	title.add_theme_color_override(&"font_color", UITheme.PAPER)
	row.add_child(title)
	_amount = Label.new()
	_amount.add_theme_font_override(&"font", UITheme.font(700))
	_amount.add_theme_font_size_override(&"font_size", 24)
	_amount.add_theme_color_override(&"font_color", UITheme.BAD)
	row.add_child(_amount)
	_track = ColorRect.new()
	_track.color = Color(1, 1, 1, 0.16)
	_track.custom_minimum_size = Vector2(200, 3)
	col.add_child(_track)
	_bar = ColorRect.new()
	_bar.color = UITheme.GOOD
	_bar.size = Vector2(0, 3)
	_track.add_child(_bar)


func _process(delta: float) -> void:
	var bank := get_parent() as BankLoan
	if bank == null:
		return
	_pill.visible = bank.debt > 0
	if not _pill.visible:
		_shown = -1
		return
	# The wanted box (TownLaw) sits right under the money; the debt comes after it.
	var law := TownLaw.of(get_tree())
	_pill.position.y = HUD.SAFE.y + (146.0 if law and law.stars() > 0 else 92.0)
	if bank.debt != _shown:
		# A rate has gone to the bank: the sum lights up for a moment.
		if _shown >= 0 and bank.debt < _shown:
			_flash = 1.0
		_shown = bank.debt
		_amount.text = "noch %s $" % HUD._format(bank.debt)
	_flash = maxf(0.0, _flash - delta * 1.6)
	_amount.add_theme_color_override(&"font_color", UITheme.BAD.lerp(UITheme.GOOD, _flash))
	var paid := 1.0 - float(bank.debt) / float(maxi(bank.owed, 1))
	_bar.size = Vector2(_track.size.x * clampf(paid, 0.0, 1.0), 3)
