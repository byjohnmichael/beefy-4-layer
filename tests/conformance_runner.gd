extends SceneTree
## Conformance runner: replays every recorded TS transition through the
## GDScript reducer and deep-compares the result.
##
## Run: /Applications/Godot.app/Contents/MacOS/Godot --headless --path godot \
##        --script res://tests/conformance_runner.gd
## Vectors are produced by scripts/generate-vectors.mjs at the repo root.

const VECTORS_DIR := "res://tests/vectors"
const MAX_FAILURES_PRINTED := 5


func _init() -> void:
	var files: Array = []
	var dir := DirAccess.open(VECTORS_DIR)
	if dir == null:
		push_error("No vectors directory at %s - run scripts/generate-vectors.mjs first" % VECTORS_DIR)
		quit(2)
		return
	for f in dir.get_files():
		if f.ends_with(".json.gz") or f.ends_with(".json"):
			files.append(f)
	files.sort()

	var total := 0
	var passed := 0
	var failures := 0
	var start := Time.get_ticks_msec()

	for file_name: String in files:
		var data: Dictionary = _load_vector_file(VECTORS_DIR + "/" + file_name)
		if data.is_empty():
			push_error("Failed to load/parse %s" % file_name)
			failures += 1
			continue
		for i: int in (data["vectors"] as Array).size():
			var vector: Dictionary = data["vectors"][i]
			total += 1
			if _check_vector(vector, file_name, i, failures < MAX_FAILURES_PRINTED):
				passed += 1
			else:
				failures += 1

	var elapsed := (Time.get_ticks_msec() - start) / 1000.0
	print("Conformance: %d/%d passed (%d failed) across %d files in %.1fs" % [
		passed, total, failures, files.size(), elapsed
	])
	quit(0 if failures == 0 and total > 0 else 1)


func _load_vector_file(path: String) -> Dictionary:
	var bytes := FileAccess.get_file_as_bytes(path)
	if bytes.is_empty():
		return {}
	if path.ends_with(".gz"):
		bytes = bytes.decompress_dynamic(-1, FileAccess.COMPRESSION_GZIP)
		if bytes.is_empty():
			return {}
	var parsed: Variant = JSON.parse_string(bytes.get_string_from_utf8())
	if parsed is Dictionary:
		return parsed
	return {}


func _check_vector(vector: Dictionary, file_name: String, index: int, verbose: bool) -> bool:
	var pre := SimState.from_dict(vector["preState"])
	var rng := Mulberry32.new(int(vector["seed"]))
	SimDeck.set_rng(Callable(rng, "next"))
	var post := SimReducer.reduce(pre, vector["action"])
	var post_dict := post.to_dict()
	var expected: Dictionary = vector["postState"]
	var diff_path := _first_diff(post_dict, expected, "state")
	if diff_path == "":
		return true
	if verbose:
		print("FAIL %s #%d action=%s" % [file_name, index, JSON.stringify(vector["action"])])
		print("  first diff at: %s" % diff_path)
	return false


## Returns "" when equal, else a dotted path to the first difference.
## Ints and floats compare by value (JSON parses all numbers as float).
func _first_diff(a: Variant, b: Variant, path: String) -> String:
	if a is Dictionary and b is Dictionary:
		var ad := a as Dictionary
		var bd := b as Dictionary
		for key: Variant in bd:
			if not ad.has(key):
				return "%s.%s (missing)" % [path, key]
		for key: Variant in ad:
			if not bd.has(key):
				return "%s.%s (extra)" % [path, key]
			var sub := _first_diff(ad[key], bd[key], "%s.%s" % [path, key])
			if sub != "":
				return sub
		return ""
	if a is Array and b is Array:
		var aa := a as Array
		var ba := b as Array
		if aa.size() != ba.size():
			return "%s (length %d != %d)" % [path, aa.size(), ba.size()]
		for i: int in aa.size():
			var sub := _first_diff(aa[i], ba[i], "%s[%d]" % [path, i])
			if sub != "":
				return sub
		return ""
	if (a is int or a is float) and (b is int or b is float):
		if float(a) == float(b):
			return ""
		return "%s (%s != %s)" % [path, a, b]
	if typeof(a) != typeof(b):
		return "%s (type %s != %s)" % [path, type_string(typeof(a)), type_string(typeof(b))]
	if a != b:
		return "%s (%s != %s)" % [path, a, b]
	return ""
