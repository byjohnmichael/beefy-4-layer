class_name SimRules
extends RefCounted
## Core game rules, mirroring src/game/engine/rules.ts exactly.

## Rank values for adjacency checking (A=1, J=11, Q=12, K=13)
const RANK_VALUES: Dictionary = {
	"A": 1,
	"2": 2,
	"3": 3,
	"4": 4,
	"5": 5,
	"6": 6,
	"7": 7,
	"8": 8,
	"9": 9,
	"10": 10,
	"J": 11,
	"Q": 12,
	"K": 13,
	"JOKER": 0,
}

## Unicode Variation Selector-15 forces text rendering instead of emoji.
const VS15 := "\ufe0e"


## Adjacent if difference is 1, or wrap-around (K-A = 12). Jokers always match.
static func is_adjacent(rank1: String, rank2: String) -> bool:
	if rank1 == "JOKER" or rank2 == "JOKER":
		return true
	var diff: int = absi(RANK_VALUES[rank1] - RANK_VALUES[rank2])
	return diff == 1 or diff == 12


static func can_play(card: SimCard, pile_top: SimCard) -> bool:
	if card == null or pile_top == null:
		return false
	if card.rank == "JOKER":
		return true
	if pile_top.rank == "JOKER":
		return true
	return is_adjacent(card.rank, pile_top.rank)


static func get_legal_piles(card: SimCard, center_piles: Array) -> Array:
	if card == null:
		return []
	var legal: Array = []
	for i in center_piles.size():
		var pile: Array = center_piles[i]
		if pile.size() > 0:
			if can_play(card, pile[pile.size() - 1]):
				legal.append(i)
	return legal


static func has_legal_hand_play(hand: Array, center_piles: Array) -> bool:
	for card: SimCard in hand:
		if get_legal_piles(card, center_piles).size() > 0:
			return true
	return false


static func get_rank_display(rank: String) -> String:
	if rank == "JOKER":
		return "★" + VS15
	return rank


static func get_suit_symbol(suit: String) -> String:
	match suit:
		"hearts":
			return "♥" + VS15
		"diamonds":
			return "♦" + VS15
		"clubs":
			return "♣" + VS15
		"spades":
			return "♠" + VS15
		_:
			return ""


## "red", "black" or "gold" (Jokers).
static func get_card_color(card: SimCard) -> String:
	if card.rank == "JOKER":
		return "gold"
	if card.suit == "hearts" or card.suit == "diamonds":
		return "red"
	return "black"
