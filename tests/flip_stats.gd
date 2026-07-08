extends SceneTree
## Measures empirical odds for tuning (docs/combo-spec.md):
##  - classic mode: face-down flip and draw-gamble success rates
##  - combo mode: the same, split by active tolerance, plus the chain-length
##    distribution and how often each tolerance tier is reached/spent.
## Bot games have no combo clock, so combo-mode numbers assume a player fast
## enough to never time out (upper bound on chain lengths).
##
## Run: godot --headless --path . --script res://tests/flip_stats.gd

const NUM_GAMES := 2000
const MAX_TRANSITIONS := 5000


func _init() -> void:
	_run_stats(false)
	_run_stats(true)
	quit(0)


func _run_stats(combo_mode: bool) -> void:
	# Indexed by tolerance (1..3); [successes, attempts]
	var flips := {1: [0, 0], 2: [0, 0], 3: [0, 0]}
	var gambles := {1: [0, 0], 2: [0, 0], 3: [0, 0]}
	var chain_hist := {}  # chain length -> count of combos that ended at it
	var tolerance_spent := 0

	for game_index in NUM_GAMES:
		var rng := Mulberry32.new(0xF11B0000 + game_index)
		var rng_call := Callable(rng, "next")
		SimDeck.set_rng(rng_call)

		var state := SimInitialState.create_initial_state(combo_mode)
		var transitions := 0
		var chain_peak := 0
		while state.winner == null and transitions < MAX_TRANSITIONS:
			var move: Variant = SimBot.get_bot_move(state, rng_call, state.current_player)
			if move == null:
				break
			state = SimReducer.reduce(state, move)
			transitions += 1
			var pile_sel: Variant = SimBot.get_bot_pile_selection(
				state, rng_call, state.current_player
			)
			if pile_sel != null:
				var pre := state
				state = SimReducer.reduce(state, pile_sel)
				transitions += 1
				_record_outcome(pre, state, flips, gambles)
				if state.tolerance < pre.tolerance:
					tolerance_spent += 1
				chain_peak = maxi(chain_peak, state.combo)
				if state.combo == 0 and chain_peak > 0:
					chain_hist[chain_peak] = int(chain_hist.get(chain_peak, 0)) + 1
					chain_peak = 0

	var mode := "combo" if combo_mode else "classic"
	print("=== %s mode (%d games) ===" % [mode, NUM_GAMES])
	for tol in [1, 2, 3]:
		if flips[tol][1] > 0:
			print("Flips at ±%d:   %d/%d landed (%.1f%%)" % [
				tol, flips[tol][0], flips[tol][1], 100.0 * flips[tol][0] / flips[tol][1]
			])
		if gambles[tol][1] > 0:
			print("Gambles at ±%d: %d/%d landed (%.1f%%)" % [
				tol, gambles[tol][0], gambles[tol][1], 100.0 * gambles[tol][0] / gambles[tol][1]
			])
	if combo_mode:
		print("Tolerance spent on a widened play: %d times" % tolerance_spent)
		var lengths := chain_hist.keys()
		lengths.sort()
		var total_chains := 0
		for l: int in lengths:
			total_chains += int(chain_hist[l])
		for l: int in lengths:
			var n := int(chain_hist[l])
			print("Chains ending at %2d: %6d (%.1f%%)" % [l, n, 100.0 * n / total_chains])


## Classifies the transition a pile-selection reduce produced, using the log
## line it appended, and buckets it by the tolerance that was active.
func _record_outcome(pre: SimState, post: SimState, flips: Dictionary, gambles: Dictionary) -> void:
	if post.log.size() == pre.log.size():
		return
	var tol := SimRules.active_tolerance(pre)
	for i in range(pre.log.size(), post.log.size()):
		var line: String = post.log[i]
		if line.contains(" flipped "):
			flips[tol][1] += 1
			if line.contains("(success)"):
				flips[tol][0] += 1
		elif line.contains(" drew and played "):
			gambles[tol][1] += 1
			if line.contains("(success)"):
				gambles[tol][0] += 1
