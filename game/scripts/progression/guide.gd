class_name Guide
extends Node
## The thread through the game: letters from Onkel Heinz, who left you the
## backyard foundry. Each letter sets one clear goal, from the first dig by
## hand to the fully automatic hall and the Kaiserglocke, and pays a small
## bonus when it is reached. The HUD shows the letter when it arrives and
## keeps its goal on screen (MailPanel). Host tracks progress; peers mirror
## the index. Saved with the game.

signal changed(new_letter: bool)

## goal: what to do. text: the letter. done: checked against the world.
const LETTERS := [
	{goal = "Wühl 3 Teile aus dem Schrottberg (F halten)", reward = 10,
		text = "Mein Junge, die Gießerei gehört jetzt dir. Fang klein an: Im Schrottberg steckt mehr, als man denkt. Hände rein!"},
	{goal = "Wirf Schrott in den Ofen und tritt den Blasebalg, bis 1 Liter geschmolzen ist", reward = 15,
		text = "Schrott allein macht nicht satt. Ab in den Ofen damit und ordentlich Luft geben – heiß muss es sein."},
	{goal = "Zeichne ein Modell, gieß es und verkauf deinen ersten Guss", reward = 25,
		text = "Jetzt wird's ernst: zeichnen, Sand stampfen, gießen, Form zerschlagen. Was rauskommt, wandert in die Verkaufskiste."},
	{goal = "Kauf dir Lederhandschuhe an der Werkstatt-Tafel", reward = 20,
		text = "Du wühlst mit bloßen Händen? Sei nicht geizig. Handschuhe zuerst – dann geht's schneller und tut weniger weh."},
	{goal = "Kauf die Schaufel", reward = 30,
		text = "Hände sind gut, eine Schaufel ist besser. Damit bist du doppelt so schnell durch den Berg."},
	{goal = "Kauf den Magnet am Seil und den Metalldetektor", reward = 60,
		text = "Die guten Stücke liegen tief. Mit Magnet holst du zwei auf einmal, und der Detektor riecht Gold. Hab ich früher alles gehabt."},
	{goal = "Bau das Förderband zum Ofen", reward = 100,
		text = "Schleppen ist was für Anfänger. Ein Band vom Schrottberg zum Ofen – drauflegen, fertig."},
	{goal = "Stell den Greifarm an den Schrottberg", reward = 200,
		text = "Und jetzt das Beste: ein Greifarm, der für dich wühlt. Dann läuft der Schrott von allein in den Ofen und du kümmerst dich ums Gießen."},
	{goal = "Schalte die Garage frei", reward = 150,
		text = "Der Hof wird zu klein für dich. In der Garage ist Platz für mehr Formen – und Aufträge gibt es dort auch."},
	{goal = "Pachte die Glockengießerei", reward = 400,
		text = "Glocken! Das war immer mein Traum. Die alte Glockengießerei steht leer. Spar drauf."},
	{goal = "Kauf die Eisenhalle", reward = 800,
		text = "Du hast es weit gebracht. Jetzt die große Halle: Kupolofen, Kran, Formband. Dort wartet der Auftrag deines Lebens."},
	{goal = "Gieß die Kaiserglocke und liefere sie an den Dom", reward = 0,
		text = "Die Kaiserglocke für den Dom. Hundert Liter Bronze, zwei Pfannen, eine Mannschaft. Mach mich stolz."},
	{goal = "Alles geschafft – die Hallen gehören dir", reward = 0,
		text = "Ich hab's gehört bis hierher: Sie läutet. Besser hätt ich's nicht gekonnt. Dein Onkel Heinz."},
]

var world: GameWorld
var index := 0
var stats := {digs = 0, sold = 0, great_bell = 0}
var _check := 0.0


func _ready() -> void:
	add_to_group(&"guides")
	Network.peer_ready.connect(_on_peer_ready)


func letter() -> Dictionary:
	return LETTERS[clampi(index, 0, LETTERS.size() - 1)]


## Host: stations report what happened (&"dig", &"sold", &"great_bell").
func note(what: StringName) -> void:
	if Network.is_sim_authority():
		var key := "digs" if what == &"dig" else String(what)
		stats[key] = int(stats.get(key, 0)) + 1


func _reached(i: int) -> bool:
	match i:
		0:
			return stats.digs >= 3
		1:
			return get_tree().get_nodes_in_group(&"crucibles").any(func(c: Crucible) -> bool: return c.amount >= 1.0) or stats.sold > 0
		2:
			return stats.sold >= 1
		3:
			return world.has_upgrade(&"gloves")
		4:
			return world.has_upgrade(&"shovel")
		5:
			return world.has_upgrade(&"magnet") and world.has_upgrade(&"detector")
		6:
			return world.has_upgrade(&"conveyor")
		7:
			return world.has_upgrade(&"robot_arm")
		8:
			return world.upgrade_tier() >= 1
		9:
			return world.upgrade_tier() >= 2
		10:
			return world.upgrade_tier() >= 3
		11:
			return stats.great_bell >= 1
	return false


func _physics_process(delta: float) -> void:
	if not Network.is_sim_authority() or world == null or world.attract_mode:
		return
	_check += delta
	if _check < 0.5:
		return
	_check = 0.0
	if index < LETTERS.size() - 1 and _reached(index):
		var pay: int = letter().reward
		index += 1
		if pay > 0:
			world.add_money(pay)
		_announce(pay)


func _announce(pay: int) -> void:
	changed.emit(true)
	if Network.is_online() and multiplayer.is_server():
		_sync.rpc(index, true)
	if pay > 0:
		world.banner_all("ZIEL ERREICHT!", Color("#7fd3a8"), "+%d $ von Onkel Heinz · neue Post" % pay)


func load_index(i: int) -> void:
	index = clampi(i, 0, LETTERS.size() - 1)
	changed.emit(false)


func _on_peer_ready(id: int, level: String) -> void:
	if is_inside_tree() and multiplayer.is_server() and world and level == world.level_path():
		_sync.rpc_id(id, index, false)


@rpc("authority", "call_remote", "reliable")
func _sync(i: int, new_letter: bool) -> void:
	index = i
	changed.emit(new_letter)
