class_name Guide
extends Node
## The thread through the game: letters from Onkel Heinz, who left you the
## backyard foundry. Each letter sets one clear goal, from the first dig by
## hand to the fully automatic hall and the Kaiserglocke, and pays a small
## bonus when it is reached. The HUD shows the letter when it arrives and
## keeps its goal on screen (MailPanel). Host tracks progress; peers mirror
## the index. Saved with the game.

signal changed(new_letter: bool)

## goal: what to do (hall_goal: the same in the scrap hall, where tools are bought at the hardware
## store). text: the letter. done: checked against the world.
const LETTERS := [
	{id = &"dig", goal = "Wühl 3 Teile aus dem Schrottberg (F halten)", reward = 10,
		text = "Mein Junge, die Gießerei gehört jetzt dir. Fang klein an: Im Schrottberg steckt mehr, als man denkt. Hände rein!"},
	{id = &"melt", goal = "Wirf Schrott in den Ofen und tritt den Blasebalg, bis 1 Liter geschmolzen ist", reward = 15,
		text = "Schrott allein macht nicht satt. Ab in den Ofen damit und ordentlich Luft geben – heiß muss es sein."},
	{id = &"sold", goal = "Zeichne ein Modell, gieß es und verkauf deinen ersten Guss", reward = 25,
		text = "Jetzt wird's ernst: zeichnen, Sand stampfen, gießen, Form zerschlagen. Was rauskommt, wandert in die Verkaufskiste."},
	{id = &"gloves", goal = "Kauf dir Lederhandschuhe an der Werkstatt-Tafel", reward = 20,
		hall_goal = "Kauf dir Lederhandschuhe im HARDWARE Store (aus der Halle rechts die Straße hinunter, hinter Molly's Diner)",
		text = "Du wühlst mit bloßen Händen? Sei nicht geizig. Handschuhe zuerst – dann geht's schneller und tut weniger weh."},
	{id = &"shovel", goal = "Kauf die Schaufel", reward = 30, hall_goal = "Kauf die Schaufel im HARDWARE Store",
		text = "Hände sind gut, eine Schaufel ist besser. Damit bist du doppelt so schnell durch den Berg."},
	{id = &"tools", goal = "Kauf den Magnet am Seil und den Metalldetektor", reward = 60,
		hall_goal = "Kauf den Magnet am Seil und den Metalldetektor im HARDWARE Store",
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
	{id = &"auto_iron", goal = "Kauf Beschickungsband, Gebläsesteuerung und Abstichkanal", reward = 1000,
		text = "Mit Formautomat und Gießautomat fehlt der Halle nur noch das Futter. Band, Gebläse, Kanal – dann gießt das Formband Tag und Nacht Serie."},
	{id = &"great_bell", goal = "Gieß die Kaiserglocke und liefere sie an den Dom", reward = 0,
		text = "Die Kaiserglocke für den Dom. Hundert Liter Bronze, zwei Pfannen, eine Mannschaft. Mach mich stolz."},
	{id = &"end", goal = "Alles geschafft – die Hallen gehören dir", reward = 0,
		text = "Ich hab's gehört bis hierher: Sie läutet. Besser hätt ich's nicht gekonnt. Dein Onkel Heinz."},
]
## The scrap hall starts earlier: these come right after the first letter there.
const HALL_LETTERS := [
	{id = &"scrap_sold", goal = "Trag den Eimer über die Straße zum Scrap Dealer und verkauf den Inhalt (F)", reward = 10,
		text = "Siehst du den Laden gegenüber? Der alte Kowalski kauft alles, was rostet. Eimer vollmachen, rübertragen, kassieren."},
	{id = &"foundry_corner", goal = "Spar 150 $ und kauf Schmelzofen & Formkästen an der Werkstatt-Tafel", reward = 20,
		text = "Schrott verkaufen ist Kleingeld. Wer das Metall selber einschmilzt und gießt, verdient das Zehnfache. Spar auf den Ofen!"},
]

var world: GameWorld
var index := 0
var _letters: Array = []
var stats := {digs = 0, sold = 0, great_bell = 0}
var _check := 0.0


func _ready() -> void:
	add_to_group(&"guides")
	Network.peer_ready.connect(_on_peer_ready)


func letter() -> Dictionary:
	var list := letters()
	return list[clampi(index, 0, list.size() - 1)]


## The letters of this level, in order (`index` counts in this list).
func letters() -> Array:
	if _letters.is_empty():
		_letters = LETTERS.duplicate()
		if world and world.is_scrap_hall():
			for i in _letters.size():
				if (_letters[i] as Dictionary).has("hall_goal"):
					var own: Dictionary = (_letters[i] as Dictionary).duplicate()
					own.goal = own.hall_goal
					_letters[i] = own
			for k in HALL_LETTERS.size():
				_letters.insert(1 + k, HALL_LETTERS[k])
	return _letters


## Host: stations report what happened (&"dig", &"sold", &"great_bell").
func note(what: StringName) -> void:
	if Network.is_sim_authority():
		var key := "digs" if what == &"dig" else String(what)
		stats[key] = int(stats.get(key, 0)) + 1


func _reached(i: int) -> bool:
	match letters()[i].id:
		&"dig":
			return stats.digs >= 3
		&"melt":
			return get_tree().get_nodes_in_group(&"crucibles").any(func(c: Crucible) -> bool: return c.amount >= 1.0) or stats.sold > 0
		&"sold":
			return stats.sold >= 1
		&"scrap_sold":
			return int(stats.get("scrap_sold", 0)) >= 1
		&"tools":
			return world.has_upgrade(&"magnet") and world.has_upgrade(&"detector")
		&"auto_iron":
			return world.has_upgrade(&"auto_charger") and world.has_upgrade(&"auto_blast") and world.has_upgrade(&"auto_tap")
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
	return world.has_upgrade(letters()[i].id)


func _physics_process(delta: float) -> void:
	if not Network.is_sim_authority() or world == null or world.attract_mode:
		return
	_check += delta
	if _check < 0.5:
		return
	_check = 0.0
	if index < letters().size() - 1 and _reached(index):
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


## What the save file keeps: the letter's id (the lists differ per level).
func to_save() -> String:
	return String(letter().id)


## `v`: a letter id (or an index from an old save). A hall letter loaded in
## another level continues with the first shared one after it.
func load_save(v: Variant) -> void:
	if typeof(v) == TYPE_STRING:
		var id := StringName(v)
		if not (world and world.is_scrap_hall()) and HALL_LETTERS.any(func(l: Dictionary) -> bool: return l.id == id):
			id = &"melt"
		var list := letters()
		for i in list.size():
			if list[i].id == id:
				load_index(i)
				return
		load_index(0)
	else:
		load_index(int(v))


func load_index(i: int) -> void:
	index = clampi(i, 0, letters().size() - 1)
	changed.emit(false)


func _on_peer_ready(id: int, level: String) -> void:
	if is_inside_tree() and multiplayer.is_server() and world and level == world.level_path():
		_sync.rpc_id(id, index, false)


@rpc("authority", "call_remote", "reliable")
func _sync(i: int, new_letter: bool) -> void:
	index = i
	changed.emit(new_letter)
