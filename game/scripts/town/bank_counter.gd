class_name BankCounter
extends Node3D
## The place at the bank's counter where the crew takes a loan (BankLoan) and pays it off. Both take
## two presses: [F] asks, a second [F] within a few seconds does it, so nobody runs into debt or
## pays a fresh loan straight back with its interest by a slip of the finger. Paying off needs the
## whole rest in hand. Stands on the counter's customer side.

const GROUP := &"bank_counters"
## As far as a player is offered the counter (Player.nearest_interactable), so [F] never falls flat.
const USE_RANGE := 3.5
## Seconds the question "sure?" stays open.
const CONFIRM_TIME := 6.0

## Host: who was asked "sure?": peer id -> [seconds left, whether it was about paying off].
var _asked := {}
## This peer: seconds the question is still open for the local player, and what it was about.
var _confirm_left := 0.0
var _confirm_settle := false


func _init() -> void:
	name = "BankCounter"


func _ready() -> void:
	add_to_group(GROUP)
	add_to_group(&"interactable")


func interact_point() -> Vector3:
	return global_position + Vector3(0, TownCounter.TOP, 0)


func in_reach(player: Node3D) -> bool:
	return interact_point().distance_to(player.global_position + Vector3(0, 0.9, 0)) < USE_RANGE


## A Suchauftrag hides its find only on the customers' side of the counter.
func hunt_spot_ok(at: Vector3) -> bool:
	return to_local(at).z < 0.0


func hint(_player: Node) -> String:
	var bank := BankLoan.of(get_tree())
	var world := get_tree().get_first_node_in_group(&"world") as GameWorld
	if bank == null or world == null:
		return ""
	# A question about the other business (the loan was taken or paid off meanwhile) is no longer open.
	var sure := _confirm_left > 0.0 and _confirm_settle == (bank.debt > 0)
	if bank.debt > 0:
		if world.money < bank.debt:
			return "Kredit: noch %s $ offen · ein Viertel jeder Einnahme geht von selbst an die Bank" % HUD._format(bank.debt)
		if sure and not bank.trusts():
			return "[F] Sicher? %s $ zahlen – für einen größeren Kredit vorher noch %s $ verdienen" % [HUD._format(bank.debt), HUD._format(bank.owed - bank.earned)]
		if sure:
			return "[F] Sicher? %s $ zahlen – dann ist der Kredit abbezahlt" % HUD._format(bank.debt)
		return "[F] Kredit ablösen · %s $" % HUD._format(bank.debt)
	var sum := bank.next_sum()
	if sure:
		return "[F] Sicher? %s $ jetzt, %s $ zurück" % [HUD._format(sum), HUD._format(BankLoan.back_for(sum))]
	return "[F] Kredit aufnehmen · %s $ sofort, %s $ zurück – ein Viertel jeder Einnahme" % [HUD._format(sum), HUD._format(BankLoan.back_for(sum))]


## Host: the player at the counter presses [F].
func interact(player: Node) -> void:
	var who := player as Player
	if not Network.is_sim_authority() or who == null or not in_reach(who):
		return
	var bank := BankLoan.of(get_tree())
	var world := get_tree().get_first_node_in_group(&"world") as GameWorld
	if bank == null or world == null:
		return
	var at := interact_point() + Vector3(0, 0.5, 0)
	var settling := bank.debt > 0
	if settling and world.money < bank.debt:
		world.popup_all(at, "Noch %s $ offen" % HUD._format(bank.debt), UITheme.BAD)
		return
	var open: Array = _asked.get(who.peer_id, [0.0, false])
	if float(open[0]) <= 0.0 or bool(open[1]) != settling:
		_ask(who.peer_id, CONFIRM_TIME, settling)
		return
	_ask(who.peer_id, 0.0, settling)
	if settling:
		var rest := bank.debt
		if bank.settle():
			world.popup_all(at, "Kredit abgelöst · -%s $" % HUD._format(rest), UITheme.GOOD)
			_fx_all()
		return
	var sum := bank.next_sum()
	if bank.take():
		world.popup_all(at, "+%s $ Kredit" % HUD._format(sum), UITheme.ACCENT)
		_fx_all()


func _physics_process(delta: float) -> void:
	_confirm_left = maxf(0.0, _confirm_left - delta)
	for id: int in _asked.keys():
		var open: Array = _asked[id]
		open[0] = float(open[0]) - delta
		if float(open[0]) <= 0.0:
			_asked.erase(id)


## Host: opens (or closes, with 0 seconds) the question for player `id`, here and on that player's screen.
func _ask(id: int, seconds: float, settling: bool) -> void:
	if seconds > 0.0:
		_asked[id] = [seconds, settling]
	else:
		_asked.erase(id)
	if not Network.is_online() or id == multiplayer.get_unique_id():
		_asked_remote(seconds, settling)
	else:
		_asked_remote.rpc_id(id, seconds, settling)


@rpc("authority", "call_remote", "reliable")
func _asked_remote(seconds: float, settling: bool) -> void:
	_confirm_left = seconds
	_confirm_settle = settling


func _fx_all() -> void:
	if Network.is_online():
		_fx.rpc()
	else:
		_fx()


@rpc("authority", "call_local", "reliable")
func _fx() -> void:
	Sfx.play(&"coin", interact_point(), 0.0, 0.03)
