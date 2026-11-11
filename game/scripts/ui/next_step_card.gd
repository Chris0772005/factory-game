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
var _marker: Label3D
var _bob := 0.0


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
	_title.text = "JETZT"
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
	_update_marker(delta, visible_now, me)


## A yellow arrow bobs over the station the tip is about, so nobody has to
## search the yard for it. Hidden when standing right in front.
func _update_marker(delta: float, on: bool, me: Player) -> void:
	if _marker == null:
		_marker = Label3D.new()
		_marker.text = "▼"
		_marker.font = UITheme.font(700)
		_marker.font_size = 96
		_marker.pixel_size = 0.0011
		_marker.fixed_size = true
		_marker.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		_marker.no_depth_test = true
		_marker.render_priority = 10
		_marker.outline_size = 22
		_marker.outline_modulate = Color(0.12, 0.09, 0.05, 0.85)
		_marker.modulate = UITheme.ACCENT
		_marker.top_level = true
		world.add_child(_marker)
	var t := target
	var show := on and t != null and is_instance_valid(t) and t.is_inside_tree() and me != null
	var alpha := 0.0
	if show:
		var at: Vector3 = t.interact_point() if t.has_method("interact_point") else t.global_position
		_bob += delta * 3.0
		_marker.global_position = at + Vector3(0, 0.75 + sin(_bob) * 0.08, 0)
		alpha = clampf((me.global_position.distance_to(at) - 1.6) / 1.2, 0.0, 1.0)
	_marker.modulate.a = move_toward(_marker.modulate.a, alpha, delta * 4.0)
	_marker.outline_modulate.a = _marker.modulate.a * 0.85
	_marker.visible = _marker.modulate.a > 0.01


## Where the step returned last by `next_step` happens (null: nowhere special).
static var target: Node3D


## The next thing to do, derived from what the stations are doing right now.
## Also sets `target` to the station it happens at, for the yellow marker.
static func next_step(w: GameWorld) -> String:
	target = null
	var tree := w.get_tree()
	for node in w.entities.get_children():
		if (node is CastPiece and not (node as CastPiece).series) or node is BronzeStatue:
			target = _of_class(tree, "SellCrate")
			return "Trag den Guss in die Verkaufskiste – das bringt Geld."
	var iron_step := _iron_step(tree)
	if not iron_step.is_empty():
		return iron_step
	var bell_step := _bell_step(tree)
	if not bell_step.is_empty():
		return bell_step
	var guide := tree.get_first_node_in_group(&"guides") as Guide
	var goal: StringName = guide.letter().id if guide else &""
	var furnace := tree.get_first_node_in_group(&"furnaces") as Furnace
	var pile := tree.get_first_node_in_group(&"scrap_piles") as ScrapPile
	var crucible := tree.get_first_node_in_group(&"crucibles") as Crucible
	var loose := 0
	for node in w.entities.get_children():
		if node is Item and FoundryRules.SCRAP.has((node as Item).kind):
			loose += 1
	var charged := furnace != null and not furnace.charge.is_empty()
	# The first two letters walk through digging and melting, one move at a time.
	if goal == &"dig":
		target = pile
		return "Geh zum Schrottberg und halte F. Schrott ist dein Rohstoff."
	if goal == &"melt":
		if charged:
			target = furnace
			return "Halte F am Blasebalg, bis der Schrott geschmolzen ist."
		if loose > 0:
			target = furnace
			return "Heb den Schrott auf (Linksklick) und wirf ihn oben in den Ofen."
		target = pile
		return "Hol Schrott aus dem Schrottberg (F halten)."
	var molds := tree.get_nodes_in_group(&"molds")
	for m: MoldBox in molds:
		if m.state == MoldBox.State.READY:
			target = m
			return "Zerschlag die Form (F halten) – mit dem Hammer geht's schneller."
	for m: MoldBox in molds:
		if m.state == MoldBox.State.COOLING:
			target = m
			if tree.get_first_node_in_group(&"buckets"):
				return "Warten – oder mit dem Wassereimer abschrecken (Rissgefahr!)."
			return "Kurz warten: Der Guss kühlt ab."
	for m: MoldBox in molds:
		if m.state == MoldBox.State.PATTERNED:
			target = m
			return "Stampf den Sand im Formkasten fest (F halten)."
	for m: MoldBox in molds:
		if m.state in [MoldBox.State.RAMMED, MoldBox.State.FILLING]:
			if crucible and crucible.amount >= 1.0:
				target = m if crucible.is_held() else crucible
				return "Gieß in die Form (F halten)." if crucible.is_held() else "Nimm den glühenden Tiegel aus dem Ofen (Linksklick)."
			if charged:
				target = furnace
				return "Halte F am Blasebalg, bis genug geschmolzen ist."
			target = furnace if loose > 0 else pile
			return "Wirf Schrott in den Ofen." if loose > 0 else "Hol Schrott aus dem Schrottberg (F halten)."
	target = _of_class(tree, "ModelBench")
	return "Zeichne an der Werkbank ein Modell – daraus wird die Gussform."


static func _of_class(tree: SceneTree, name: String) -> Node3D:
	for n in tree.get_nodes_in_group(&"interactable"):
		var script := n.get_script() as Script
		if script and script.get_global_name() == name:
			return n as Node3D
	return null


## Eisenhalle: Kaiserglocke first, then the iron flow cupola -> ladle -> line
## ("" when there is no cupola).
static func _iron_step(tree: SceneTree) -> String:
	var cupola := tree.get_first_node_in_group(&"cupolas") as CupolaFurnace
	if cupola == null:
		return ""
	for b: Bell in tree.get_nodes_in_group(&"bells"):
		if b.is_great() and not b.freeze:
			return "Liefert die Glocke an den Dom aus (F an der Glocke)." if b.temperature <= 0.15 else "Die Riesenglocke kühlt ab …"
	for p: BellPit in tree.get_nodes_in_group(&"bell_pits"):
		match p.state:
			BellPit.State.READY:
				return "Schlag den Lehmmantel auf – die Kaiserglocke wartet!"
			BellPit.State.FILLING:
				return "Weitergießen! Pfanne leer? Zum Kupolofen, nachfüllen – ihr habt %d s." % roundi(p.pour_gap)
			BellPit.State.COOLING:
				return "Die Kaiserglocke kühlt ab – kein Wasser!"
			BellPit.State.PROFILED:
				return "Dreh die Schablone in der Kaisergrube (F, im Takt)."
	var ladle := tree.get_first_node_in_group(&"ladles") as Ladle
	var line := tree.get_first_node_in_group(&"mold_lines") as MoldLine
	if ladle and ladle.amount >= 1.0:
		if cupola.tap_open:
			return "Stopfen! Abstich schließen, bevor die Pfanne überläuft (F am Abstich)."
		for p: BellPit in tree.get_nodes_in_group(&"bell_pits"):
			if p.state == BellPit.State.TURNED and ladle.alloy() == &"bronze":
				return "Bronze in der Pfanne: über die Kaisergrube fahren und kurbeln (F halten, zu zweit schneller)."
		if line and line.has_tundish() and line.tundish < MoldLine.TUNDISH_CAPACITY * 0.5:
			return "Pfanne über den Gießautomaten fahren und kurbeln – dann gießt das Band allein."
		if line and line.pattern == "":
			return "Zeichnet an der Musterbank ein Serienmuster fürs Formband."
		return "Pfanne übers Formband fahren, absenken (F) und am Handrad kurbeln (F halten)."
	if cupola.bath >= 5.0:
		return "Pfanne unter den Abstich fahren (Steuerbirne tragen), absenken, Abstich öffnen."
	if not cupola.charge.is_empty() or cupola._remote_charges > 0:
		return "Gebläse kurbeln (F halten) – mehr Hände, mehr Wind!"
	for p: BellPit in tree.get_nodes_in_group(&"bell_pits"):
		if p.state == BellPit.State.TURNED:
			return "Kaisergrube bereit: Glockenbronze kaufen und in den Gichtkübel werfen (100 l!)."
	return "Eisenkörbe am Gussbruch füllen und in den Gichtkübel am Kupolofen werfen."


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
