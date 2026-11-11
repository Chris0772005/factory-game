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
	{id = &"dig", goal = "Wühl 3 Teile aus dem Schrottberg (F halten)", reward = 10,
		text = "Mein Junge, die Gießerei gehört jetzt dir. Fang klein an: Im Schrottberg steckt mehr, als man denkt. Hände rein!"},
	{id = &"melt", goal = "Wirf Schrott in den Ofen und tritt den Blasebalg, bis 1 Liter geschmolzen ist", reward = 15,
		text = "Schrott allein macht nicht satt. Ab in den Ofen damit und ordentlich Luft geben – heiß muss es sein."},
	{id = &"sold", goal = "Zeichne ein Modell, gieß es und verkauf deinen ersten Guss", reward = 25,
		text = "Jetzt wird's ernst: zeichnen, Sand stampfen, gießen, Form zerschlagen. Was rauskommt, wandert in die Verkaufskiste."},
	{id = &"gloves", goal = "Kauf dir Lederhandschuhe an der Werkstatt-Tafel", reward = 20,
		text = "Du wühlst mit bloßen Händen? Sei nicht geizig. Handschuhe zuerst – dann geht's schneller und tut weniger weh."},
	{id = &"shovel", goal = "Kauf die Schaufel", reward = 30,
		text = "Hände sind gut, eine Schaufel ist besser. Damit bist du doppelt so schnell durch den Berg."},
	{id = &"tools", goal = "Kauf den Magnet am Seil und den Metalldetektor", reward = 60,
		text = "Die guten Stücke liegen tief. Mit Magnet holst du zwei auf einmal, und der Detektor riecht Gold. Hab ich früher alles gehabt."},
	{id = &"conveyor", goal = "Bau das Förderband zum Ofen", reward = 100,
		text = "Schleppen ist was für Anfänger. Ein Band vom Schrottberg zum Ofen – drauflegen, fertig."},
	{id = &"robot_arm", goal = "Stell den Greifarm an den Schrottberg", reward = 200,
		text = "Und jetzt das Beste: ein Greifarm, der für dich wühlt. Dann läuft der Schrott von allein in den Ofen und du kümmerst dich ums Gießen."},
	{id = &"auto_bellows", goal = "Kauf den Gebläseautomat", reward = 120,
		text = "Du trittst immer noch den Blasebalg? Ein Elektrogebläse hält den Ofen heiß, solange was drin ist. Dann hast du die Hände frei."},
	{id = &"garage", goal = "Schalte die Garage frei", reward = 150,
		text = "Der Hof wird zu klein für dich. In der Garage ist Platz für mehr Formen – und Aufträge gibt es dort auch."},
	{id = &"auto_molds", goal = "Kauf Stampfautomat und Rüttelrost", reward = 250,
		text = "In der Garage wird nicht mehr von Hand gestampft. Der Stampfautomat formt dein letztes Modell immer wieder neu, der Rüttelrost schlägt die Form auf."},
	{id = &"auto_pour", goal = "Bau die Gieß-Hängebahn", reward = 350,
		text = "Lass den Tiegel im Ofen stehen. Die Pfanne an der Schiene holt sich die Schmelze selbst und gießt jede Form."},
	{id = &"auto_ship", goal = "Kauf den Schleuderversand – dann läuft die Garage allein", reward = 500,
		text = "Fehlt nur noch der Versand. Dann wühlt, schmilzt, gießt und verkauft die Garage von ganz allein – und du zeichnest neue Modelle."},
	{id = &"bells", goal = "Pachte die Glockengießerei", reward = 400,
		text = "Glocken! Das war immer mein Traum. Die alte Glockengießerei steht leer. Spar drauf."},
	{id = &"iron", goal = "Kauf die Eisenhalle", reward = 800,
		text = "Du hast es weit gebracht. Jetzt die große Halle: Kupolofen, Kran, Formband. Dort wartet der Auftrag deines Lebens."},
	{id = &"great_bell", goal = "Gieß die Kaiserglocke und liefere sie an den Dom", reward = 0,
		text = "Die Kaiserglocke für den Dom. Hundert Liter Bronze, zwei Pfannen, eine Mannschaft. Mach mich stolz."},
	{id = &"end", goal = "Alles geschafft – die Hallen gehören dir", reward = 0,
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
	match LETTERS[i].id:
		&"dig":
			return stats.digs >= 3
		&"melt":
			return get_tree().get_nodes_in_group(&"crucibles").any(func(c: Crucible) -> bool: return c.amount >= 1.0) or stats.sold > 0
		&"sold":
			return stats.sold >= 1
		&"tools":
			return world.has_upgrade(&"magnet") and world.has_upgrade(&"detector")
		&"auto_molds":
			return world.has_upgrade(&"auto_rammer") and world.has_upgrade(&"auto_breaker")
		&"garage":
			return world.upgrade_tier() >= 1
		&"bells":
			return world.upgrade_tier() >= 2
		&"iron":
			return world.upgrade_tier() >= 3
		&"great_bell":
			return stats.great_bell >= 1
		&"end":
			return false
	# Everything else is "own this upgrade".
	return world.has_upgrade(LETTERS[i].id)


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
