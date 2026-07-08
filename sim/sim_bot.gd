class_name SimBot
extends RefCounted
## Bot AI, mirroring src/game/bot.ts.
## Strategy: 1) legal hand play, 2) random face-down gamble, 3) draw gamble.
##
## `rng` is a Callable returning float in [0,1) (the TS bot calls Math.random
## directly); pass an empty Callable to use the engine RNG. `player_id` is a
## generalization over the TS source (which hardcodes P2) so the soak tests
## can run bot-vs-bot; defaults preserve TS behavior.


static func _rand(rng: Callable) -> float:
	if rng.is_valid():
		return rng.call()
	return randf()


## Returns an action Dictionary, or null when no move is possible.
static func get_bot_move(state: SimState, rng := Callable(), player_id := "P2") -> Variant:
	if state.current_player != player_id:
		return null
	if state.winner != null:
		return null

	var bot: SimPlayerState = state.players[player_id]

	# Strategy 1: Play from hand if we have legal moves
	if bot.hand.size() > 0:
		var tol := SimRules.active_tolerance(state)
		for i in bot.hand.size():
			var card: SimCard = bot.hand[i]
			if SimRules.get_legal_piles(card, state.center_piles, tol).size() > 0:
				return {"type": "SELECT_HAND_CARD", "index": i}

	# Strategy 2: Gamble with face-down card
	var face_down_indices: Array = []
	for i in bot.face_down.size():
		if bot.face_down[i] != null:
			face_down_indices.append(i)
	if face_down_indices.size() > 0:
		var random_index: int = face_down_indices[
			int(floor(_rand(rng) * face_down_indices.size()))
		]
		return {"type": "SELECT_FACEDOWN_CARD", "index": random_index}

	# Strategy 3: Draw and gamble from deck
	if state.deck.size() > 0:
		return {"type": "START_DRAW_GAMBLE"}

	return null


## Returns the pile-selection action after a card selection or draw gamble.
static func get_bot_pile_selection(state: SimState, rng := Callable(), player_id := "P2") -> Variant:
	if state.current_player != player_id:
		return null

	# Handle draw gamble pile selection
	if state.pending_draw_gamble != null:
		return {"type": "PLAY_DRAW_GAMBLE", "pileIndex": int(floor(_rand(rng) * 4))}

	if state.selected_card == null:
		return null

	var source: String = state.selected_card["source"]
	var index: int = int(state.selected_card["index"])
	var bot: SimPlayerState = state.players[player_id]

	if source == "hand":
		# For hand plays, pick the first legal pile
		var card: SimCard = bot.hand[index] if index < bot.hand.size() else null
		if card == null:
			return null
		var legal := SimRules.get_legal_piles(
			card, state.center_piles, SimRules.active_tolerance(state)
		)
		if legal.size() > 0:
			return {"type": "SELECT_PILE", "pileIndex": legal[0]}
	else:
		# For face-down gamble, pick a random pile
		return {"type": "SELECT_PILE", "pileIndex": int(floor(_rand(rng) * 4))}

	return null
