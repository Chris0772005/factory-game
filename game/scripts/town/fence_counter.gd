class_name FenceCounter
extends TownCounter
## The pawnbroker's counter. Officially he lends money on watches; under the
## counter he buys whatever turned up in the scrap and asks no questions.

func _init() -> void:
	name = "FenceCounter"


func price(kind: StringName) -> int:
	return FoundryRules.black_price(kind)


func heat_per_piece() -> float:
	return TownLaw.SALE_HEAT


func pay_text(pay: int, pieces: int) -> String:
	return "+%d $ · %d Teil%s unter der Theke" % [pay, pieces, "" if pieces == 1 else "e"]


func bucket_hint(pay: int) -> String:
	return "[F] Heiße Ware unter der Theke verkaufen · %d $" % pay


func _verb() -> String:
	return "Unter der Theke verkaufen"


# --- Cast weapons (the dark orders on his board) -----------------------------------

func toss_accepts(body: Node3D) -> bool:
	return TownLaw.weapon_of(body) != &"" or super(body)


func toss_hint(body: Node3D) -> String:
	if TownLaw.weapon_of(body) != &"":
		return "Waffe unter der Theke verkaufen · %d $" % TownLaw.weapon_price(body)
	return super(body)


func toss_place(body: Node3D) -> bool:
	if TownLaw.weapon_of(body) == &"":
		return super(body)
	if not Network.is_sim_authority():
		return false
	var world := get_tree().get_first_node_in_group(&"world") as GameWorld
	if world == null:
		return false
	var pay := TownLaw.weapon_price(body) + OrderBoard.fulfil(world, body, true)
	_pay_out(world, pay, 1, TownLaw.WEAPON_HEAT)
	body.queue_free()
	return true


func hint(_player: Node) -> String:
	return "Pfandhaus · kauft heiße Ware, keine Fragen"
