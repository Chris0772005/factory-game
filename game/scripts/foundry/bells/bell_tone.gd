class_name BellTone
extends RefCounted
## The voice of a cast bell. Pitch follows the founders' rule of thumb
## f ~ wall / diameter^2 (a bell twice as wide sounds about two octaves lower
## at the same wall), scaled by the alloy and the shape (slender bells hum
## lower). The sound is modal synthesis of the classic minor-third bell
## partials; a lumpy profile detunes them (a crooked bell). Rendered once per
## bell into an AudioStreamWAV and cached.

const RATE := 22050
## Prime frequency of the reference bell: mouth 0.35 m, standard wall, bronze.
const REF_PRIME := 523.25
const REF_RADIUS := 0.35
## Partials relative to the prime: hum, prime, tierce, quint, nominal,
## superquint, octave nominal; relative loudness; relative decay.
const PARTIALS := [
	[0.5, 0.55, 1.6], [1.0, 0.7, 1.0], [1.2, 0.5, 0.8], [1.5, 0.22, 0.6],
	[2.0, 1.0, 0.55], [3.0, 0.32, 0.35], [4.0, 0.15, 0.25],
]
const ALLOY_PITCH := {&"bronze": 1.0, &"brass": 0.94, &"alu": 1.18, &"iron": 1.05, &"gold": 0.78,
	&"rotgold": 0.82, &"verdigris": 0.98}
const NOTE_NAMES := ["C", "Cis", "D", "Dis", "E", "F", "Fis", "G", "Gis", "A", "B", "H"]

static var _cache := {}


## Prime (strike note) frequency in Hz.
static func prime(profile: BellProfile, mouth_radius: float, alloy: StringName) -> float:
	var f := REF_PRIME * pow(REF_RADIUS / mouth_radius, 1.0)
	# Same relative wall at every size, so f ~ t / D^2 ~ 1 / D.
	f *= ALLOY_PITCH.get(alloy, 1.0)
	f *= pow(1.0 / clampf(profile.aspect, 0.4, 2.5), 0.3)
	return f


## 0..1, how clean the bell sounds.
static func purity(profile: BellProfile) -> float:
	return 1.0 - profile.irregularity


static func verdict(profile: BellProfile) -> String:
	var p := purity(profile)
	if p >= 0.85:
		return "rein"
	if p >= 0.6:
		return "leicht schief"
	return "schief"


## German note name with octave, e.g. "C5", "Fis4" (H = B natural).
static func note_name(freq: float) -> String:
	var midi := roundi(69.0 + 12.0 * log(freq / 440.0) / log(2.0))
	return "%s%d" % [NOTE_NAMES[posmod(midi, 12)], midi / 12 - 1]


## The struck bell as a mono 16-bit stream (cached per profile, size and alloy).
static func stream(profile: BellProfile, mouth_radius: float, alloy: StringName) -> AudioStreamWAV:
	var key := "%d_%.3f_%s" % [profile.seed, mouth_radius, alloy]
	if _cache.has(key):
		return _cache[key]
	var f0 := prime(profile, mouth_radius, alloy)
	var decay := 1.4 + mouth_radius * 6.0
	var length := minf(decay * 2.2, 7.0)
	var n := int(length * RATE)
	var buf := PackedFloat32Array()
	buf.resize(n)
	var rng := RandomNumberGenerator.new()
	rng.seed = profile.seed
	var crooked := profile.irregularity
	for p in PARTIALS:
		var ratio: float = p[0]
		# A crooked bell: every partial slips off its ideal ratio.
		var f := f0 * ratio * (1.0 + rng.randf_range(-1.0, 1.0) * crooked * 0.07)
		if f > RATE * 0.45:
			continue
		var amp: float = p[1]
		var tau: float = decay * float(p[2])
		# Oscillator by rotation (cheaper than sin per sample) with a tiny beat.
		var w := TAU * f / RATE
		var c := cos(w)
		var s := sin(w)
		var x := 0.0
		var y := 1.0
		var k := exp(-1.0 / (tau * RATE))
		var e := amp
		for i in n:
			var nx := x * c - y * s
			y = x * s + y * c
			x = nx
			buf[i] += x * e
			e *= k
	# Strike transient: a short clank of noise.
	for i in mini(n, int(0.02 * RATE)):
		buf[i] += rng.randf_range(-1.0, 1.0) * 0.6 * (1.0 - float(i) / (0.02 * RATE))
	var peak := 0.001
	for v in buf:
		peak = maxf(peak, absf(v))
	var bytes := PackedByteArray()
	bytes.resize(n * 2)
	var attack := int(0.003 * RATE)
	for i in n:
		var g := minf(1.0, float(i) / attack) * 0.85 / peak
		bytes.encode_s16(i * 2, clampi(int(buf[i] * g * 32767.0), -32768, 32767))
	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = RATE
	wav.stereo = false
	wav.data = bytes
	_cache[key] = wav
	return wav
