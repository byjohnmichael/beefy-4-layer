class_name SimState
extends RefCounted
## Mirrors `GameState` in src/game/types.ts. Serialization (to_dict/from_dict)
## uses the exact TS JSON shape so conformance vectors compare directly.

## Array of SimCard. NOTE: draw-to-hand takes from the FRONT (index 0) while
## draw-gamble peeks/takes from the BACK - that quirk comes from the TS source.
var deck: Array = []
## Array of 4 piles, each an Array of SimCard (top of pile = last element).
var center_piles: Array = []
var players: Dictionary = {}  # {"P1": SimPlayerState, "P2": SimPlayerState}
var current_player: String = "P1"
var log: Array = []  # Array of String
var winner: Variant = null  # "P1" | "P2" | null
var selected_card: Variant = null  # {"source": "hand"|"faceDown", "index": int} | null
var revealed_card: Variant = null  # SimCard | null
var pending_pile_index: Variant = null  # int | null
var pending_draw_gamble: Variant = null  # SimCard | null


func clone() -> SimState:
	var c := SimState.new()
	c.deck = deck.duplicate()
	var piles: Array = []
	for pile: Array in center_piles:
		piles.append(pile.duplicate())
	c.center_piles = piles
	c.players = {
		"P1": (players["P1"] as SimPlayerState).clone(),
		"P2": (players["P2"] as SimPlayerState).clone(),
	}
	c.current_player = current_player
	c.log = log.duplicate()
	c.winner = winner
	c.selected_card = null if selected_card == null else (selected_card as Dictionary).duplicate()
	c.revealed_card = revealed_card
	c.pending_pile_index = pending_pile_index
	c.pending_draw_gamble = pending_draw_gamble
	return c


func to_dict() -> Dictionary:
	var deck_arr: Array = []
	for card: SimCard in deck:
		deck_arr.append(card.to_dict())
	var piles_arr: Array = []
	for pile: Array in center_piles:
		var p: Array = []
		for card: SimCard in pile:
			p.append(card.to_dict())
		piles_arr.append(p)
	return {
		"deck": deck_arr,
		"centerPiles": piles_arr,
		"players": {
			"P1": (players["P1"] as SimPlayerState).to_dict(),
			"P2": (players["P2"] as SimPlayerState).to_dict(),
		},
		"currentPlayer": current_player,
		"log": log.duplicate(),
		"winner": winner,
		"selectedCard": null if selected_card == null else {
			"source": selected_card["source"],
			"index": int(selected_card["index"]),
		},
		"revealedCard": null if revealed_card == null else (revealed_card as SimCard).to_dict(),
		"pendingPileIndex": pending_pile_index,
		"pendingDrawGamble": (
			null if pending_draw_gamble == null else (pending_draw_gamble as SimCard).to_dict()
		),
	}


static func from_dict(d: Dictionary) -> SimState:
	var s := SimState.new()
	for entry: Variant in d.get("deck", []):
		s.deck.append(SimCard.from_dict(entry))
	for pile: Variant in d.get("centerPiles", []):
		var p: Array = []
		for entry: Variant in pile:
			p.append(SimCard.from_dict(entry))
		s.center_piles.append(p)
	var players_d: Dictionary = d.get("players", {})
	s.players = {
		"P1": SimPlayerState.from_dict(players_d.get("P1", {})),
		"P2": SimPlayerState.from_dict(players_d.get("P2", {})),
	}
	s.current_player = d.get("currentPlayer", "P1")
	for entry: Variant in d.get("log", []):
		s.log.append(String(entry))
	s.winner = d.get("winner")
	var sel: Variant = d.get("selectedCard")
	s.selected_card = null if sel == null else {
		"source": sel["source"],
		"index": int(sel["index"]),
	}
	var revealed: Variant = d.get("revealedCard")
	s.revealed_card = null if revealed == null else SimCard.from_dict(revealed)
	var ppi: Variant = d.get("pendingPileIndex")
	s.pending_pile_index = null if ppi == null else int(ppi)
	var pdg: Variant = d.get("pendingDrawGamble")
	s.pending_draw_gamble = null if pdg == null else SimCard.from_dict(pdg)
	return s
