class_name SimDeck
extends RefCounted
## Deck utilities, mirroring src/game/engine/deck.ts exactly.
## Collections are plain Arrays of SimCard (nullable where noted).

const SUITS: Array[String] = ["hearts", "diamonds", "clubs", "spades"]
const RANKS: Array[String] = ["A", "2", "3", "4", "5", "6", "7", "8", "9", "10", "J", "Q", "K"]

## Injectable RNG (a Callable returning float in [0,1)), mirroring setRng() in
## deck.ts. Defaults to the engine RNG when unset - gameplay stays random.
static var _rng := Callable()


static func set_rng(fn: Callable) -> void:
	_rng = fn


static func _rand() -> float:
	if _rng.is_valid():
		return _rng.call()
	return randf()


static func create_deck() -> Array:
	var cards: Array = []
	var id := 0
	for suit in SUITS:
		for rank in RANKS:
			cards.append(SimCard.new("card-%d" % id, rank, suit))
			id += 1
	cards.append(SimCard.new("card-%d" % id, "JOKER", ""))
	id += 1
	cards.append(SimCard.new("card-%d" % id, "JOKER", ""))
	return cards


## Fisher-Yates, identical iteration order and index math to the TS shuffle so
## identical seeds produce identical shuffles.
static func shuffle(array: Array) -> Array:
	var shuffled := array.duplicate()
	var i := shuffled.size() - 1
	while i > 0:
		var j := int(floor(_rand() * (i + 1)))
		var tmp: Variant = shuffled[i]
		shuffled[i] = shuffled[j]
		shuffled[j] = tmp
		i -= 1
	return shuffled


## Returns {"drawn": Array, "remaining": Array} - drawn from the FRONT.
static func draw_cards(deck: Array, count: int) -> Dictionary:
	return {
		"drawn": deck.slice(0, count),
		"remaining": deck.slice(count),
	}


## Returns {"card": SimCard or null, "remaining": Array} - from the FRONT.
static func draw_one(deck: Array) -> Dictionary:
	if deck.is_empty():
		return {"card": null, "remaining": []}
	return {"card": deck[0], "remaining": deck.slice(1)}
