class_name FxBurst
extends Node3D
## Container for a one-shot effect: starts its particle emitters when it enters
## the tree, fades an optional flash light and frees itself once the last
## particle has died (or after `lifetime`, whichever is later).

var lifetime := 0.0
var light: OmniLight3D
var light_time := 0.25

var _light_energy := 0.0
var _age := 0.0


func _ready() -> void:
	for child in get_children():
		if child is GPUParticles3D:
			var p: GPUParticles3D = child
			p.restart()
			# One-shot emission is spread over (1 - explosiveness) of a lifetime.
			lifetime = maxf(lifetime, p.lifetime * (2.0 - p.explosiveness) / maxf(p.speed_scale, 0.1) + 0.1)
	if light:
		_light_energy = light.light_energy


func _process(delta: float) -> void:
	_age += delta
	if light:
		var k := clampf(1.0 - _age / light_time, 0.0, 1.0)
		light.light_energy = _light_energy * k * k
		light.visible = k > 0.0
	if _age >= lifetime:
		queue_free()
