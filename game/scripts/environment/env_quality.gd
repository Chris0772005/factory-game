class_name EnvQuality
## Graphics level for the environment builders (grass density, shadows,
## screen-space effects, practical lights). Chosen once per run:
## `-- --quality=low|medium|high` on the command line, otherwise LOW when Steam
## sets `SteamDeck=1`, otherwise HIGH. See docs/ENVIRONMENT.md for the table.

enum Level { LOW, MEDIUM, HIGH }

static var _level := -1
static var _off: PackedStringArray = []
static var _off_read := false


static func level() -> Level:
	if _level < 0:
		_level = _detect()
	return _level as Level


## Overrides the detected level (call before the level is built).
static func set_level(value: Level) -> void:
	_level = value


static func is_low() -> bool:
	return level() == Level.LOW


## Fraction of the full grass tuft count.
static func grass_density() -> float:
	return [0.4, 0.7, 1.0][level()]


## Distance (m) at which grass chunks stop drawing.
static func grass_distance() -> float:
	return [24.0, 34.0, 48.0][level()]


## Profiling switch: `-- --env-off=vol,ssil,ssao,grass,shadows,lights`
## turns single environment features off to measure what they cost.
static func disabled(feature: String) -> bool:
	if not _off_read:
		_off_read = true
		for arg in OS.get_cmdline_user_args():
			if arg.begins_with("--env-off="):
				_off = arg.trim_prefix("--env-off=").split(",")
	return feature in _off


static func _detect() -> int:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--quality="):
			match arg.trim_prefix("--quality="):
				"low":
					return Level.LOW
				"medium":
					return Level.MEDIUM
				"high":
					return Level.HIGH
	if OS.get_environment("SteamDeck") == "1":
		return Level.LOW
	return Level.HIGH
