class_name SimRefresh
extends RefCounted
## Deck refresh, mirroring src/game/engine/refresh.ts exactly.


## Collects all center-pile cards, shuffles them into a new deck, and deals 4
## new single-card piles. Returns {"new_deck": Array, "new_center_piles": Array}.
static func refresh_center_piles(center_piles: Array) -> Dictionary:
	var all_cards: Array = []
	for pile: Array in center_piles:
		all_cards.append_array(pile)

	var shuffled_deck := SimDeck.shuffle(all_cards)
	var result := SimDeck.draw_cards(shuffled_deck, 4)

	var new_center_piles: Array = []
	for card: SimCard in result["drawn"]:
		new_center_piles.append([card])

	return {
		"new_deck": result["remaining"],
		"new_center_piles": new_center_piles,
	}
