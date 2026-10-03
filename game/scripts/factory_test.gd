extends GameWorld
## Factory loop test level: ore source -> belts -> smelter -> belts -> seller,
## plus a side belt that ends in the open so items spill onto the floor.


func build_level() -> void:
	ItemType.define(&"ore", Vector3(0.32, 0.26, 0.32), Color("#8a6d5a"), 0.8, 1)
	ItemType.define(&"ingot", Vector3(0.42, 0.18, 0.24), Color("#f2b134"), 1.0, 5)
	WorldBuilder.add_environment(self)
	WorldBuilder.add_floor(self)
	var f := create_factory()
	var source := SourceMachine.new()
	source.output_type = &"ore"
	source.process_time = 0.5
	add_child(source)
	source.setup(f, Vector2i(-6, 0), Vector2i(1, 1), Vector2i(-5, 0))
	for x in range(-5, -1):
		f.add_belt(Vector2i(x, 0), 0)
	var smelter := Machine.new()
	smelter.input_types = [&"ore"]
	smelter.output_type = &"ingot"
	smelter.inputs_needed = 2
	smelter.process_time = 0.8
	add_child(smelter)
	smelter.setup(f, Vector2i(-1, 0), Vector2i(1, 1), Vector2i(0, 0))
	for x in range(0, 5):
		f.add_belt(Vector2i(x, 0), 0)
	var seller := SellerMachine.new()
	add_child(seller)
	seller.setup(f, Vector2i(5, 0), Vector2i(1, 1))
	seller.sold.connect(func(_t, v):
		add_money(v)
		HUD.popup(self, seller.global_position + Vector3(0, 1.8, 0), "+%d" % v))
	# Overflow line: a second source feeding a belt that ends in the open.
	var spiller := SourceMachine.new()
	spiller.output_type = &"ore"
	spiller.process_time = 1.0
	add_child(spiller)
	spiller.setup(f, Vector2i(-6, 4), Vector2i(1, 1), Vector2i(-5, 4))
	for x in range(-5, 0):
		f.add_belt(Vector2i(x, 4), 0)
