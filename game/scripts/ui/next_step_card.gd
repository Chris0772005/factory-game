class_name NextStepCard
extends PanelContainer
## "Was jetzt?" card in the top-right corner. Reads the world state and names
## the next step of the casting loop. Shown during the first minutes of a
## session, and later again when the local player has been idle for a while.

const ALWAYS_FOR := 600.0
const IDLE_AFTER := 8.0

var world: GameWorld
var _title: Label
var _text: Label
var _age := 0.0
var _idle := 0.0
var _last_pos := Vector3.ZERO
var _shown := ""


func _ready() -> void:
	theme_type_variation = &"HudPill"
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_preset(Control.PRESET_TOP_RIGHT)
	position = Vector2(-460, 36)
	custom_minimum_size = Vector2(420, 0)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 2)
	add_child(col)
	_title = Label.new()
	_title.text = "NÄCHSTER SCHRITT"
	_title.add_theme_font_size_override("font_size", 18)
	_title.add_theme_color_override("font_color", UITheme.ACCENT)
	col.add_child(_title)
	_text = Label.new()
	_text.add_theme_font_size_override("font_size", 26)
	_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	col.add_child(_text)
	modulate.a = 0.0


func _process(delta: float) -> void:
	if world == null:
		return
	_age += delta
	var me := world.local_player()
	if me:
		_idle = 0.0 if me.global_position.distance_to(_last_pos) > 0.05 else _idle + delta
		_last_pos = me.global_position
	var step := next_step(world)
	var visible_now := not step.is_empty() and (_age < ALWAYS_FOR or _idle > IDLE_AFTER)
	if step != _shown and not step.is_empty():
		_shown = step
		_text.text = step
	modulate.a = move_toward(modulate.a, 1.0 if visible_now else 0.0, delta * 3.0)


## The next thing to do, derived from what the stations are doing right now.
static func next_step(w: GameWorld) -> String:
	var tree := w.get_tree()
	for node in w.entities.get_children():
		if node is CastPiece or node is BronzeStatue:
			return "Wirf die Gussteile in die Verkaufskiste."
	var molds := tree.get_nodes_in_group(&"molds")
	for m: MoldBox in molds:
		if m.state == MoldBox.State.READY:
			return "Zerschlag die Form – mit dem Hammer geht's schneller."
	for m: MoldBox in molds:
		if m.state == MoldBox.State.COOLING:
			return "Kurz warten: Der Guss kühlt ab."
	for m: MoldBox in molds:
		if m.state == MoldBox.State.PATTERNED:
			return "Stampf den Sand im Formkasten fest (F)."
	var rammed := molds.any(func(m: MoldBox) -> bool: return m.state in [MoldBox.State.RAMMED, MoldBox.State.FILLING])
	if rammed:
		var crucible := tree.get_first_node_in_group(&"crucibles") as Crucible
		if crucible and crucible.amount >= 1.0:
			return "Trag den glühenden Tiegel zur Form und gieß (F halten)."
		return "Wirf Schrott in den Ofen und tritt den Blasebalg."
	return "Zeichne an der Werkbank ein Modell."
