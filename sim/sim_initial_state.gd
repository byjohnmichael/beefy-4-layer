class_name SimInitialState
extends RefCounted
## Mirrors src/game/initialState.ts exactly.


static func create_initial_state() -> SimState:
	var deck := SimDeck.shuffle(SimDeck.create_deck())

	# Deal 4 face-down cards to each player
	var p1_draw := SimDeck.draw_cards(deck, 4)
	var p2_draw := SimDeck.draw_cards(p1_draw["remaining"], 4)

	# Deal 4 face-up cards as center piles
	var center_draw := SimDeck.draw_cards(p2_draw["remaining"], 4)
	var center_piles: Array = []
	for card: SimCard in center_draw["drawn"]:
		center_piles.append([card])

	var state := SimState.new()
	state.deck = center_draw["remaining"]
	state.center_piles = center_piles

	var p1 := SimPlayerState.new()
	p1.face_down = p1_draw["drawn"]
	var p2 := SimPlayerState.new()
	p2.face_down = p2_draw["drawn"]
	state.players = {"P1": p1, "P2": p2}

	state.current_player = "P1"
	state.log = ["Game started! P1's turn"]
	return state
