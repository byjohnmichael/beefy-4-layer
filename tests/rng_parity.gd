extends SceneTree
## Prints mulberry32 output (as exact 32-bit integer numerators) for a few
## seeds, to diff against the JS implementation.


func _init() -> void:
	for seed_value: int in [0, 1, 42, 123456789, 4294967295]:
		var rng := Mulberry32.new(seed_value)
		var parts: PackedStringArray = []
		for i in 60:
			parts.append(str(int(floor(rng.next() * 4294967296.0))))
		print("%d:%s" % [seed_value, ",".join(parts)])
	quit(0)
