class_name SimPlayerState
extends RefCounted
## Mirrors `PlayerState` in src/game/types.ts.

## Array of SimCard or null (null = empty slot), always length 4 in play.
var face_down: Array = []
## Array of SimCard.
var hand: Array = []


func clone() -> SimPlayerState:
	var c := SimPlayerState.new()
	c.face_down = face_down.duplicate()
	c.hand = hand.duplicate()
	return c


func to_dict() -> Dictionary:
	var fd: Array = []
	for card: SimCard in face_down:
		fd.append(null if card == null else card.to_dict())
	var h: Array = []
	for card: SimCard in hand:
		h.append(card.to_dict())
	return {"faceDown": fd, "hand": h}


static func from_dict(d: Dictionary) -> SimPlayerState:
	var p := SimPlayerState.new()
	for entry: Variant in d.get("faceDown", []):
		p.face_down.append(null if entry == null else SimCard.from_dict(entry))
	for entry: Variant in d.get("hand", []):
		p.hand.append(SimCard.from_dict(entry))
	return p
