class_name SimReducer
extends RefCounted
## Pure reducer, mirroring src/game/reducer.ts exactly - including its quirks:
## - Draw-to-hand and face-down replacement draw from the FRONT of the deck;
##   draw-gamble peeks/removes from the BACK.
## - Deck refresh triggers when a draw empties the deck (draw-to-hand,
##   face-down fail replacement, draw-gamble fail) - but NOT on a successful
##   draw-gamble that empties the deck.
## - Log strings are part of state and must match character-for-character.
##
## Actions are Dictionaries mirroring the TS discriminated union, e.g.
## {"type": "SELECT_PILE", "pileIndex": 2}. No-op guards return the input
## state unchanged, like the TS reducer.


static func check_winner(state: SimState) -> Variant:
	for player_id: String in ["P1", "P2"]:
		var player: SimPlayerState = state.players[player_id]
		var has_face_down := false
		for card: Variant in player.face_down:
			if card != null:
				has_face_down = true
				break
		if not has_face_down and player.hand.is_empty():
			return player_id
	return null


static func get_opponent(player: String) -> String:
	return "P2" if player == "P1" else "P1"


static func _pile_top_rank_display(pile_top: SimCard) -> String:
	if pile_top == null:
		return "?"
	return SimRules.get_rank_display(pile_top.rank)


## Combo-mode bookkeeping after any successful placement (hand play,
## face-down flip, or draw-gamble): consume spent tolerance, grow the chain,
## grant tier boosts. No-op in classic mode.
static func _combo_on_success(next: SimState, card: SimCard, pile_top: SimCard) -> void:
	if not next.combo_mode:
		return
	if next.tolerance > 1 and not SimRules.can_play(card, pile_top):
		# The play needed the widened window - tolerance is spent.
		next.tolerance = 1
		next.log.append("%s spent tolerance" % next.current_player)
	next.combo += 1
	if next.combo % SimRules.COMBO_STEP == 0 and next.tolerance < SimRules.TOLERANCE_MAX:
		next.tolerance += 1
		next.log.append(
			"%s combo x%d - tolerance up to %d" % [
				next.current_player, next.combo, next.tolerance
			]
		)


## Ends any running combo: on flips (the climax), failures, turn passes,
## and timeouts. No-op in classic mode.
static func _combo_reset(next: SimState) -> void:
	if not next.combo_mode:
		return
	next.combo = 0
	next.tolerance = 1


static func reduce(state: SimState, action: Dictionary) -> SimState:
	var action_type: String = action.get("type", "")
	match action_type:
		"START_GAME", "RESET_GAME":
			return SimInitialState.create_initial_state(bool(action.get("comboMode", false)))

		"SELECT_HAND_CARD":
			if state.winner != null:
				return state
			var index := int(action.get("index", -1))
			var player: SimPlayerState = state.players[state.current_player]
			if index < 0 or index >= player.hand.size():
				return state
			var card: SimCard = player.hand[index]
			# Check if card has any legal plays
			var tol := SimRules.active_tolerance(state)
			if SimRules.get_legal_piles(card, state.center_piles, tol).is_empty():
				return state
			var next := state.clone()
			next.selected_card = {"source": "hand", "index": index}
			next.revealed_card = null
			next.pending_pile_index = null
			return next

		"SELECT_FACEDOWN_CARD":
			if state.winner != null:
				return state
			var index := int(action.get("index", -1))
			var player: SimPlayerState = state.players[state.current_player]
			if index < 0 or index >= player.face_down.size():
				return state
			if player.face_down[index] == null:
				return state  # Empty slot
			var next := state.clone()
			next.selected_card = {"source": "faceDown", "index": index}
			next.revealed_card = null
			next.pending_pile_index = null
			return next

		"SELECT_PILE":
			return _reduce_select_pile(state, action)

		"CLEAR_SELECTIONS":
			var next := state.clone()
			next.selected_card = null
			next.revealed_card = null
			next.pending_pile_index = null
			next.pending_draw_gamble = null
			return next

		"DRAW_FROM_DECK":
			return _reduce_draw_from_deck(state)

		"START_DRAW_GAMBLE":
			if state.winner != null:
				return state
			if state.deck.is_empty():
				return state
			var next := state.clone()
			# Peek at the top card of the deck (don't remove it yet).
			# NOTE: "top" here is the BACK of the array, unlike draw-to-hand.
			next.pending_draw_gamble = state.deck[state.deck.size() - 1]
			next.selected_card = null
			return next

		"CANCEL_DRAW_GAMBLE":
			var next := state.clone()
			next.pending_draw_gamble = null
			return next

		"PLAY_DRAW_GAMBLE":
			return _reduce_play_draw_gamble(state, action)

		"COMBO_TIMEOUT":
			if not state.combo_mode or state.winner != null:
				return state
			if state.combo == 0 and state.tolerance == 1:
				return state
			var next := state.clone()
			_combo_reset(next)
			next.log.append("%s's combo fizzled" % state.current_player)
			return next

		"SET_FIRST_PLAYER":
			var next := state.clone()
			next.current_player = action.get("player", state.current_player)
			return next

		"SYNC_STATE":
			var synced: Variant = action.get("state")
			if synced is SimState:
				return synced
			if synced is Dictionary:
				return SimState.from_dict(synced)
			return state

		_:
			return state


static func _reduce_select_pile(state: SimState, action: Dictionary) -> SimState:
	if state.winner != null:
		return state
	if state.selected_card == null:
		return state

	var source: String = state.selected_card["source"]
	var index: int = int(state.selected_card["index"])
	var pile_index := int(action.get("pileIndex", -1))
	var player: SimPlayerState = state.players[state.current_player]
	var pile: Array = state.center_piles[pile_index]
	var pile_top: SimCard = null if pile.is_empty() else pile[pile.size() - 1]

	if source == "hand":
		# Hand play - must be legal (already checked when selecting)
		var card: SimCard = player.hand[index] if index < player.hand.size() else null
		if card == null or not SimRules.can_play(card, pile_top, SimRules.active_tolerance(state)):
			return state

		# Success! Place card on pile
		var next := state.clone()
		var next_player: SimPlayerState = next.players[state.current_player]
		next_player.hand.remove_at(index)
		(next.center_piles[pile_index] as Array).append(card)
		next.selected_card = null
		_combo_on_success(next, card, pile_top)

		next.log.append(
			"%s played %s on pile %s (success)" % [
				state.current_player,
				SimRules.get_rank_display(card.rank),
				_pile_top_rank_display(pile_top),
			]
		)

		var winner: Variant = check_winner(next)
		if winner != null:
			next.log.append("%s wins!" % winner)
			next.winner = winner
			return next

		# Extra turn - stay on same player
		return next
	else:
		# Face-down gamble play
		var card: SimCard = player.face_down[index]
		if card == null:
			return state

		# Reveal the card
		var is_success := SimRules.can_play(card, pile_top, SimRules.active_tolerance(state))

		if is_success:
			# Success! Place card on pile, remove from face-down row.
			var next := state.clone()
			var next_player: SimPlayerState = next.players[state.current_player]
			next_player.face_down[index] = null
			(next.center_piles[pile_index] as Array).append(card)
			next.selected_card = null
			next.revealed_card = card
			next.pending_pile_index = pile_index
			_combo_on_success(next, card, pile_top)

			next.log.append(
				"%s flipped %s on pile %s (success)" % [
					state.current_player,
					SimRules.get_rank_display(card.rank),
					_pile_top_rank_display(pile_top),
				]
			)

			var winner: Variant = check_winner(next)
			if winner != null:
				next.log.append("%s wins!" % winner)
				next.winner = winner
				return next

			# Extra turn - stay on same player
			return next
		else:
			# Failure! Card goes to hand, draw replacement
			var next := state.clone()
			var next_player: SimPlayerState = next.players[state.current_player]
			next_player.hand.append(card)

			# Draw replacement card (from the FRONT of the deck)
			var draw := SimDeck.draw_one(state.deck)
			var replacement: Variant = draw["card"]
			var new_deck: Array = draw["remaining"]

			# Check if deck is now empty - trigger refresh
			var did_refresh := false
			if new_deck.is_empty() and replacement != null:
				var refreshed := SimRefresh.refresh_center_piles(state.center_piles)
				new_deck = refreshed["new_deck"]
				next.center_piles = refreshed["new_center_piles"]
				did_refresh = true

			# Place replacement in face-down slot
			next_player.face_down[index] = replacement

			next.deck = new_deck
			next.current_player = get_opponent(state.current_player)
			next.selected_card = null
			next.revealed_card = card
			next.pending_pile_index = pile_index
			_combo_reset(next)

			next.log.append(
				"%s flipped %s on pile %s (fail), moved to hand" % [
					state.current_player,
					SimRules.get_rank_display(card.rank),
					_pile_top_rank_display(pile_top),
				]
			)
			if did_refresh:
				next.log.append("Deck refreshed (center piles reshuffled)")
			next.log.append("%s's turn" % next.current_player)

			return next


static func _reduce_draw_from_deck(state: SimState) -> SimState:
	if state.winner != null:
		return state
	if state.deck.is_empty():
		return state

	# Draw one card from deck (the FRONT)
	var draw := SimDeck.draw_one(state.deck)
	var drawn: Variant = draw["card"]
	var new_deck: Array = draw["remaining"]
	if drawn == null:
		return state

	var next := state.clone()

	# Check if deck is now empty - trigger refresh
	var did_refresh := false
	if new_deck.is_empty():
		var refreshed := SimRefresh.refresh_center_piles(state.center_piles)
		new_deck = refreshed["new_deck"]
		next.center_piles = refreshed["new_center_piles"]
		did_refresh = true

	var next_player: SimPlayerState = next.players[state.current_player]
	next_player.hand.append(drawn)
	next.deck = new_deck
	next.current_player = get_opponent(state.current_player)
	next.selected_card = null
	_combo_reset(next)

	next.log.append("%s drew a card from deck" % state.current_player)
	if did_refresh:
		next.log.append("Deck refreshed (center piles reshuffled)")
	next.log.append("%s's turn" % next.current_player)

	return next


static func _reduce_play_draw_gamble(state: SimState, action: Dictionary) -> SimState:
	if state.winner != null:
		return state
	if state.pending_draw_gamble == null:
		return state

	var card: SimCard = state.pending_draw_gamble
	var pile_index := int(action.get("pileIndex", -1))
	var pile: Array = state.center_piles[pile_index]
	var pile_top: SimCard = null if pile.is_empty() else pile[pile.size() - 1]

	# Remove the card from deck (the BACK - where START_DRAW_GAMBLE peeked)
	var new_deck: Array = state.deck.slice(0, -1)

	var is_success := SimRules.can_play(card, pile_top, SimRules.active_tolerance(state))

	if is_success:
		# Success! Place card on pile.
		# NOTE (TS quirk): no deck refresh check on this path even if the
		# deck just became empty.
		var next := state.clone()
		next.deck = new_deck
		(next.center_piles[pile_index] as Array).append(card)
		next.pending_draw_gamble = null
		next.revealed_card = card
		next.pending_pile_index = pile_index
		_combo_on_success(next, card, pile_top)

		next.log.append(
			"%s drew and played %s on pile %s (success)" % [
				state.current_player,
				SimRules.get_rank_display(card.rank),
				_pile_top_rank_display(pile_top),
			]
		)

		var winner: Variant = check_winner(next)
		if winner != null:
			next.log.append("%s wins!" % winner)
			next.winner = winner
			return next

		# Extra turn - stay on same player
		return next
	else:
		# Failure! Card goes to hand
		var next := state.clone()
		var next_player: SimPlayerState = next.players[state.current_player]
		next_player.hand.append(card)

		# Check if deck is now empty - trigger refresh
		var did_refresh := false
		if new_deck.is_empty():
			var refreshed := SimRefresh.refresh_center_piles(state.center_piles)
			new_deck = refreshed["new_deck"]
			next.center_piles = refreshed["new_center_piles"]
			did_refresh = true

		next.deck = new_deck
		next.current_player = get_opponent(state.current_player)
		next.pending_draw_gamble = null
		next.revealed_card = card
		next.pending_pile_index = pile_index
		_combo_reset(next)

		next.log.append(
			"%s drew and played %s on pile %s (fail), moved to hand" % [
				state.current_player,
				SimRules.get_rank_display(card.rank),
				_pile_top_rank_display(pile_top),
			]
		)
		if did_refresh:
			next.log.append("Deck refreshed (center piles reshuffled)")
		next.log.append("%s's turn" % next.current_player)

		return next
