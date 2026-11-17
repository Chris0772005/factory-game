class_name PoliceDesk
extends TownCounter
## The front desk of the police station: the honest way to get rid of hot
## goods. Pays a small finder's reward and cools the heat.

func _init() -> void:
	name = "PoliceDesk"


func price(kind: StringName) -> int:
	return FoundryRules.finder_reward(kind)


func heat_per_piece() -> float:
	return TownLaw.HAND_IN_HEAT


func pay_text(pay: int, _pieces: int) -> String:
	return "+%d $ Finderlohn" % pay


func bucket_hint(pay: int) -> String:
	return "[F] Heiße Ware abgeben · %d $ Finderlohn" % pay


func _verb() -> String:
	return "Bei der Polizei abgeben · Finderlohn"


func hint(_player: Node) -> String:
	return "Polizeiwache · Fundsachen abgeben, es gibt Finderlohn"
