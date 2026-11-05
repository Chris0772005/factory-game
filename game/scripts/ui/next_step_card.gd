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
	# Offsets from the top-right corner (setting `position` would be relative to
	# the HUD's size at creation and can land off-screen).
	set_anchors_preset(Control.PRESET_TOP_RIGHT)
	offset_left = -460
	offset_right = -40
	offset_top = 36
	grow_horizontal = Control.GROW_DIRECTION_BEGIN
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
	var bell_step := _bell_step(tree)
	if not bell_step.is_empty():
		return bell_step
	var molds := tree.get_nodes_in_group(&"molds")
	for m: MoldBox in molds:
		if m.state == MoldBox.State.READY:
			return "Zerschlag die Form – mit dem Hammer geht's schneller."
	for m: MoldBox in molds:
		if m.state == MoldBox.State.COOLING:
			if tree.get_first_node_in_group(&"buckets"):
				return "Warten – oder mit dem Wassereimer abschrecken (Rissgefahr!)."
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


## Bell halls: the next step at the busiest casting pit ("" when no pit is in use).
static func _bell_step(tree: SceneTree) -> String:
	var pits := tree.get_nodes_in_group(&"bell_pits")
	if pits.is_empty():
		return ""
	for p: BellPit in pits:
		if p.state == BellPit.State.READY:
			return "Schlag den Lehmmantel auf – die Glocke wartet!"
	for p: BellPit in pits:
		if p.state == BellPit.State.FILLING:
			return "Weitergießen! Eine Pause macht einen Kaltlauf."
		if p.state == BellPit.State.COOLING:
			return "Die Glocke kühlt ab – kein Wasser, sonst springt sie!"
	for p: BellPit in pits:
		if p.state == BellPit.State.TURNED:
			return "Beide Tiegel füllen und in einem Zug in die Grube gießen."
		if p.state == BellPit.State.PROFILED:
			return "Dreh die Schablone an der Gießgrube (F, im Takt)."
	if tree.get_nodes_in_group(&"molds").any(func(m: MoldBox) -> bool: return m.state != MoldBox.State.EMPTY):
		return ""
	return "Zeichne an der Profilbank eine Glocken-Silhouette."
