class_name OfflineIncome
extends Node
## Idle earnings: once the hall runs by itself (all automation owned), the
## income of the last minutes is remembered in the savegame, and on the next
## start the machines have "worked on" at half speed for up to two hours.

const WINDOW := 180.0            ## seconds of income the rate is measured over
const MAX_MINUTES := 120.0
const MIN_MINUTES := 2.0
const SHARE := 0.5
const AUTO := [&"conveyor", &"robot_arm", &"auto_bellows", &"auto_rammer", &"auto_pour", &"auto_breaker", &"auto_ship"]

var world: GameWorld
var _gains: Array = []           ## [seconds, amount]
var _clock := 0.0
var _last := -1


static func full_auto(w: GameWorld) -> bool:
	return w != null and AUTO.all(func(id: StringName) -> bool: return w.has_upgrade(id))


## Money for `seconds` away at `rate` $/min (0 when too short or no rate).
static func payout(rate: float, seconds: float) -> int:
	var minutes := seconds / 60.0
	if rate <= 0.0 or minutes < MIN_MINUTES:
		return 0
	return int(rate * minf(minutes, MAX_MINUTES) * SHARE)


func _ready() -> void:
	_last = world.money
	world.money_changed.connect(_on_money)


func _process(delta: float) -> void:
	_clock += delta
	while not _gains.is_empty() and _clock - float(_gains[0][0]) > WINDOW:
		_gains.pop_front()


func _on_money(amount: int) -> void:
	# One-off bonuses (letters, the find book) are capped so they do not inflate the rate.
	if amount > _last:
		_gains.append([_clock, mini(amount - _last, 400)])
	_last = amount


## $ per minute right now; only counts while the hall is fully automatic.
func rate() -> float:
	if not full_auto(world) or _gains.is_empty():
		return 0.0
	var sum := 0
	for g: Array in _gains:
		sum += int(g[1])
	return sum / (maxf(minf(_clock, WINDOW), 30.0) / 60.0)


## After loading: pays for the time away and tells the crew. `away` is the
## saved {time, rate}.
func welcome_back(away: Dictionary) -> void:
	var seconds := Time.get_unix_time_from_system() - float(away.get("time", 0.0))
	var amount := payout(float(away.get("rate", 0.0)), seconds) if full_auto(world) else 0
	if amount <= 0:
		return
	_last = world.money + amount
	world.add_money(amount)
	await get_tree().create_timer(2.5).timeout
	if not is_inside_tree():
		return
	var me := world.local_player()
	var at := me.global_position if me else Vector3.ZERO
	world.banner_near(at, "WILLKOMMEN ZURÜCK!", Color("#ffcf3f"), "Deine Maschinen haben %d $ verdient (%d min)" % [amount, int(minf(seconds / 60.0, MAX_MINUTES))], true)
