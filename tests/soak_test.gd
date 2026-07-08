extends SceneTree
## Bot-vs-bot soak + property test: plays full games headless and checks
## invariants on every transition.
##
## Run: /Applications/Godot.app/Contents/MacOS/Godot --headless --path godot \
##        --script res://tests/soak_test.gd
##
## Invariants:
##  - Card conservation: exactly 52 cards with unique ids across deck +
##    center piles + hands + face-down slots, after every transition.
##  - Structure: always 4 non-empty center piles, face-down rows of length 4,
##    valid current player / winner.
##  - Termination: games end (win or a known empty-deck stalemate) within
##    MAX_TRANSITIONS.

const NUM_GAMES := 1000
const MAX_TRANSITIONS := 5000
## Chance per bot move to inject a COMBO_TIMEOUT in combo-mode games,
## simulating a player who ran out the combo clock.
const TIMEOUT_CHANCE := 0.05

var _violations := 0


func _init() -> void:
	var ok := true
	ok = _run_soak(false) and ok
	ok = _run_soak(true) and ok
	print("SOAK %s" % ("PASSED" if ok else "FAILED"))
	quit(0 if ok else 1)


func _run_soak(combo_mode: bool) -> bool:
	var wins := {"P1": 0, "P2": 0}
	var stalemates := 0
	var capped := 0
	var total_transitions := 0
	var max_game_transitions := 0
	var start := Time.get_ticks_msec()

	for game_index in NUM_GAMES:
		var rng := Mulberry32.new((0xC0DE0000 if combo_mode else 0x50AC0000) + game_index)
		var rng_call := Callable(rng, "next")
		SimDeck.set_rng(rng_call)

		var state := SimInitialState.create_initial_state(combo_mode)
		_check_invariants(state, game_index, 0)

		var transitions := 0
		while state.winner == null and transitions < MAX_TRANSITIONS:
			if combo_mode and rng_call.call() < TIMEOUT_CHANCE:
				state = SimReducer.reduce(state, {"type": "COMBO_TIMEOUT"})
				transitions += 1
				_check_invariants(state, game_index, transitions)
			var move: Variant = SimBot.get_bot_move(state, rng_call, state.current_player)
			if move == null:
				stalemates += 1
				break
			state = SimReducer.reduce(state, move)
			transitions += 1
			_check_invariants(state, game_index, transitions)

			var pile_sel: Variant = SimBot.get_bot_pile_selection(
				state, rng_call, state.current_player
			)
			if pile_sel != null:
				state = SimReducer.reduce(state, pile_sel)
				transitions += 1
				_check_invariants(state, game_index, transitions)

		if state.winner != null:
			wins[state.winner] += 1
		elif transitions >= MAX_TRANSITIONS:
			capped += 1
			push_error("Game %d hit the %d-transition cap" % [game_index, MAX_TRANSITIONS])
		total_transitions += transitions
		max_game_transitions = maxi(max_game_transitions, transitions)

	var elapsed := (Time.get_ticks_msec() - start) / 1000.0
	var mode := "combo" if combo_mode else "classic"
	print("Soak (%s): %d games in %.1fs | P1 wins %d, P2 wins %d, stalemates %d, capped %d" % [
		mode, NUM_GAMES, elapsed, wins["P1"], wins["P2"], stalemates, capped
	])
	print("Transitions: total %d, avg %.1f, max %d | invariant violations: %d" % [
		total_transitions, float(total_transitions) / NUM_GAMES, max_game_transitions, _violations
	])
	return _violations == 0 and capped == 0


func _check_invariants(state: SimState, game_index: int, step: int) -> void:
	var ids := {}
	var count := 0
	for card: SimCard in state.deck:
		ids[card.id] = true
		count += 1
	for pile: Array in state.center_piles:
		for card: SimCard in pile:
			ids[card.id] = true
			count += 1
	for player_id: String in ["P1", "P2"]:
		var player: SimPlayerState = state.players[player_id]
		for card: SimCard in player.hand:
			ids[card.id] = true
			count += 1
		for entry: Variant in player.face_down:
			if entry != null:
				ids[(entry as SimCard).id] = true
				count += 1
		if player.face_down.size() != 4:
			_fail(game_index, step, "face-down row length %d" % player.face_down.size())

	if count != 52 or ids.size() != 52:
		_fail(game_index, step, "card conservation broken: %d cards, %d unique" % [
			count, ids.size()
		])
	if state.center_piles.size() != 4:
		_fail(game_index, step, "%d center piles" % state.center_piles.size())
	for pile: Array in state.center_piles:
		if pile.is_empty():
			_fail(game_index, step, "empty center pile")
	if state.current_player != "P1" and state.current_player != "P2":
		_fail(game_index, step, "bad current player %s" % state.current_player)
	if state.winner != null and state.winner != "P1" and state.winner != "P2":
		_fail(game_index, step, "bad winner %s" % state.winner)
	if state.combo_mode:
		if state.combo < 0 or state.tolerance < 1 or state.tolerance > SimRules.TOLERANCE_MAX:
			_fail(game_index, step, "bad combo state: combo %d, tolerance %d" % [
				state.combo, state.tolerance
			])
	elif state.combo != 0 or state.tolerance != 1:
		_fail(game_index, step, "combo fields leaked into classic mode")


func _fail(game_index: int, step: int, message: String) -> void:
	_violations += 1
	if _violations <= 10:
		push_error("Invariant violation (game %d, step %d): %s" % [game_index, step, message])
