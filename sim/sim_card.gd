class_name SimCard
extends RefCounted
## Immutable card value object, mirroring `Card` in src/game/types.ts.
## `suit` is "" for Jokers (serialized as null, matching the TS shape).

var id: String
var rank: String
var suit: String


func _init(p_id: String = "", p_rank: String = "", p_suit: String = "") -> void:
	id = p_id
	rank = p_rank
	suit = p_suit


func to_dict() -> Dictionary:
	return {
		"id": id,
		"rank": rank,
		"suit": null if suit == "" else suit,
	}


static func from_dict(d: Dictionary) -> SimCard:
	var suit_value: Variant = d.get("suit")
	return SimCard.new(
		d.get("id", ""),
		d.get("rank", ""),
		"" if suit_value == null else String(suit_value)
	)
