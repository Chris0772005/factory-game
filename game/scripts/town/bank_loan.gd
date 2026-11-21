class_name BankLoan
extends Node
## The crew's loan at the bank on the corner. The bank pays a sum out at once; afterwards a quarter of
## everything the crew earns goes back to it until the sum and its interest are paid (or the rest is
## paid off in one go at the counter, BankCounter). A loan paid back raises what the bank lends next,
## if the crew earned at least the owed sum while it ran (so nobody climbs the ladder by handing
## borrowed money straight back). One loan at a time. The host keeps the books and the others mirror
## them for the HUD. Saved with the game; the debt follows the crew into every hall.

const GROUP := &"bank_loans"
## What the bank lends, loan after loan (the last sum again and again), and its interest.
const SUMS: Array[int] = [200, 500, 1200, 3000, 7000]
const INTEREST := 0.15
## The share of every income that goes to the bank while there is a debt.
const SHARE := 0.25

signal changed

var world: GameWorld
## What is still owed ($), what was owed when the loan was taken, how many loans are paid back.
var debt := 0
var owed := 0
var repaid := 0
## What the crew has earned since the loan was taken ($).
var earned := 0
## What the last income paid off (for the HUD).
var last_rate := 0
var _paying_out := false


static func of(tree: SceneTree) -> BankLoan:
	return tree.get_first_node_in_group(GROUP) as BankLoan if tree else null


func _init() -> void:
	name = "BankLoan"


func _ready() -> void:
	add_to_group(GROUP)
	Network.peer_ready.connect(_on_peer_ready)
	# No pill behind the main menu, where the level only stands as a backdrop.
	if DisplayServer.get_name() != "headless" and not (world and world.attract_mode):
		add_child(BankHud.new())


## The sum the bank would lend now.
func next_sum() -> int:
	return SUMS[mini(repaid, SUMS.size() - 1)]


## What has to be paid back for a loan of `sum`.
static func back_for(sum: int) -> int:
	return sum + roundi(sum * INTEREST)


## Host: the crew takes the next loan. Says whether it did (not while one is running).
func take() -> bool:
	if not Network.is_sim_authority() or world == null or debt > 0:
		return false
	var sum := next_sum()
	owed = back_for(sum)
	debt = owed
	earned = 0
	last_rate = 0
	# Borrowed money is not earned: no share of it goes back at once, and no mission counts it.
	_paying_out = true
	var missions := Missions.of(get_tree())
	if missions:
		missions.unearned(world.add_money.bind(sum))
	else:
		world.add_money(sum)
	_paying_out = false
	_publish()
	return true


## Host: the rest is paid off in one go, if the crew has the money. Says whether it was.
func settle() -> bool:
	if not Network.is_sim_authority() or world == null or debt <= 0 or world.money < debt:
		return false
	var rest := debt
	world.add_money(-rest)
	_pay_down(rest)
	return true


## Host (GameWorld.add_money): the crew earns `gain`. Returns what of it goes to the bank.
func take_share(gain: int) -> int:
	if debt <= 0 or gain <= 0 or _paying_out:
		return 0
	earned += gain
	var rate := mini(debt, ceili(gain * SHARE))
	_pay_down(rate)
	return rate


func _pay_down(amount: int) -> void:
	debt = maxi(0, debt - amount)
	last_rate = amount
	if debt == 0:
		var trusted := trusts()
		if trusted:
			repaid += 1
		owed = 0
		earned = 0
		if world:
			# The next loan is only named where there is a counter to take it at.
			var note := "Alle Einnahmen gehören wieder euch"
			if get_tree().get_first_node_in_group(BankCounter.GROUP) != null:
				note = ("Die Bank leiht euch jetzt bis zu %s $" if trusted else "Zu früh zurückgezahlt: Die Bank leiht euch weiter %s $") % HUD._format(next_sum())
			world.banner_all("KREDIT ABBEZAHLT!", UITheme.GOOD, note)
	_publish()


## Whether paying the running loan off now raises what the bank lends next: the crew has earned at
## least what it owed.
func trusts() -> bool:
	return earned >= owed


func _publish() -> void:
	changed.emit()
	if Network.is_online() and multiplayer.is_server():
		_sync.rpc(debt, owed, repaid, last_rate, earned)


func _on_peer_ready(id: int, _level: String) -> void:
	if is_inside_tree() and Network.is_online() and multiplayer.is_server():
		_sync.rpc_id(id, debt, owed, repaid, last_rate, earned)


@rpc("authority", "call_remote", "reliable")
func _sync(now: int, at_first: int, loans: int, rate: int, income: int) -> void:
	debt = now
	owed = at_first
	repaid = loans
	last_rate = rate
	earned = income
	changed.emit()


func to_save() -> Dictionary:
	return {debt = debt, owed = owed, repaid = repaid, earned = earned}


func load_save(v: Variant) -> void:
	if typeof(v) != TYPE_DICTIONARY:
		return
	debt = maxi(0, int(v.get("debt", 0)))
	owed = maxi(debt, int(v.get("owed", 0)))
	repaid = maxi(0, int(v.get("repaid", 0)))
	earned = maxi(0, int(v.get("earned", 0)))
	last_rate = 0
	changed.emit()
