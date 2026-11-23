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
	offset_left = -436
	offset_right = -56
	offset_top = 54
	grow_horizontal = Control.GROW_DIRECTION_BEGIN
	custom_minimum_size = Vector2(380, 0)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 2)
	add_child(col)
	_title = Label.new()
	_title.text = "AUFGABE"
	_title.add_theme_font_override("font", UITheme.font(700))
	_title.add_theme_font_size_override("font_size", 17)
	_title.add_theme_constant_override("outline_size", 0)
	_title.add_theme_color_override("font_color", UITheme.ACCENT)
	col.add_child(_title)
	_text = Label.new()
	_text.add_theme_font_size_override("font_size", 23)
	_text.add_theme_constant_override("outline_size", 0)
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
		_marker.pixel_size = 0.0006
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
## Scrap hall: bucket, dealer across the street, saving up for the furnace, the hardware store for tools.
static func _hall_step(w: GameWorld, goal: StringName, pile: ScrapPile, furnace: Furnace) -> String:
	var tree := w.get_tree()
	var bucket := tree.get_first_node_in_group(&"scrap_buckets") as ScrapBucket
	var shop := tree.get_first_node_in_group(&"scrap_shops") as Node3D
	var count := bucket.count if bucket else 0
	if goal == &"dig":
		target = pile
		return "Am Schrottberg F halten. Der Eimer daneben fängt die Funde."
	# The letters that ask for a hand tool: once the money is there, off to the hardware store.
	var wanted: Array = {&"gloves": [&"gloves"], &"shovel": [&"shovel"], &"tools": [&"magnet", &"detector"]}.get(goal, [])
	for id: StringName in wanted:
		if w.has_upgrade(id):
			continue
		var tool: Dictionary = w.upgrades.info(id)
		if w.money < int(tool.cost):
			break
		for node in tree.get_nodes_in_group(ToolOffer.GROUP):
			if (node as ToolOffer).upgrade == id:
				target = node as Node3D
		return "%d $ sind da: %s im HARDWARE Store kaufen – aus der Halle rechts die Straße hinunter, hinter Molly's Diner." % [tool.cost, tool.name]
	if goal == &"scrap_sold" or goal == &"foundry_corner":
		if goal == &"foundry_corner" and w.money >= 150:
			target = _of_class(tree, "UpgradeBoard")
			return "150 $ sind da: Schmelzofen an der Werkstatt-Tafel kaufen."
		# Something the post office has on order pays most of all (the host knows what is in the bucket).
		var post := tree.get_first_node_in_group(PostOffice.GROUP) as PostOffice
		if goal == &"foundry_corner" and bucket and post and post.wanted_in(bucket) > 0:
			target = post
			return "Im Eimer liegt etwas, das die Post bestellt hat: Das POST OFFICE zahlt am meisten (an der Bank vorbei um die Ecke, Eimer hintragen, F)."
		# Something dear in the bucket (the host knows what is in it): the crew's stall pays more for it.
		var stall := tree.get_first_node_in_group(YardStall.GROUP) as YardStall
		if goal == &"foundry_corner" and bucket and stall and not stall.free_places().is_empty() \
				and bucket.contents.any(func(k: StringName) -> bool: return YardStall.find_price(k) >= 20):
			target = stall
			return "Im Eimer liegt etwas Wertvolles: Am Verkaufstisch vor der Halle zahlen Kunden mehr als der Händler (Eimer hintragen, F)."
		if bucket and (bucket.is_full() or (goal == &"scrap_sold" and count >= 3)):
			target = shop
			return "Eimer über die Straße zum Scrap Dealer tragen, dort F."
		var uncle := tree.get_first_node_in_group(&"guides") as Guide
		# Money for a helper and never hired one: the labour exchange beyond Mill Street has hands for hire.
		var digger := HiredHand.of(tree, &"digger")
		if goal == &"foundry_corner" and Network.is_sim_authority() and uncle and int(uncle.stats.get("hired", 0)) == 0 and digger \
				and digger.state == HiredHand.State.WAITING and w.money >= int(digger.info().fee) and w.money < 150:
			target = digger
			return "Hilfe gefällig? In der LABOUR EXCHANGE wartet Hugo: %d $ Handgeld, dann wühlt er für euch in den Eimer (aus der Halle rechts die Straße hinunter, über die Kreuzung)." % digger.info().fee
		# Money in hand and never bid yet: the storage auctions behind the row are worth a look.
		if goal == &"foundry_corner" and Network.is_sim_authority() and uncle and int(uncle.stats.get("lot_bid", 0)) == 0 and w.money < 150:
			for node in tree.get_nodes_in_group(StorageLockup.GROUP):
				var unit := node as StorageLockup
				if unit.state == StorageLockup.State.SHUT and w.money >= unit.opening + 30:
					target = unit
					return "Lager-Auktion unter dem Viadukt: Los %d ab %d $ – Fundstücke für euren Verkaufstisch (durch den Durchgang neben dem Scrap Dealer)." % [unit.number, unit.opening]
		target = pile
		if goal == &"foundry_corner":
			if w.bank and w.bank.debt == 0:
				return "Für den Schmelzofen sparen: 150 $ – oder bei der Bank leihen (aus der Halle links die Straße hinunter)."
			return "Für den Schmelzofen sparen: 150 $."
		return "Eimer am Schrottberg füllen."
	if goal == &"melt" and furnace and bucket and furnace.charge.is_empty() and bucket._metal_count() > 0:
		target = furnace
		return "Eimer zum Ofen tragen, dort F."
	return ""


static func next_step(w: GameWorld) -> String:
	target = null
	var tree := w.get_tree()
	var me := w.local_player()
	if me and TownLaw.of(tree) and not TownLaw.carried_hot(me).is_empty():
		target = tree.get_first_node_in_group(TownCounter.GROUP) as Node3D
		if TownLaw.weapon_of(me.held) != &"":
			return "Waffe zum Pawn Shop bringen. Streife meiden."
		return "Heiße Ware: Pawn Shop zahlt viel, Police zahlt sicher. Streife meiden."
	# What lies on the crew's stall is where it should be: the customers take it.
	var table := tree.get_first_node_in_group(YardStall.GROUP) as YardStall
	var laid_out: Array = table.goods() if table else []
	for node in w.entities.get_children():
		if ((node is CastPiece and not (node as CastPiece).series) or node is BronzeStatue) and node not in laid_out:
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
		if node is Item and FoundryRules.SCRAP.has((node as Item).kind) and node not in laid_out:
			loose += 1
	var charged := furnace != null and not furnace.charge.is_empty()
	if w.is_scrap_hall():
		var hall_step := _hall_step(w, goal, pile, furnace)
		if not hall_step.is_empty():
			return hall_step
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
