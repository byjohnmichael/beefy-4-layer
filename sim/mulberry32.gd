class_name Mulberry32
extends RefCounted
## Seedable PRNG, bit-for-bit identical to scripts/mulberry32.mjs (JS mulberry32).
## GDScript ints are 64-bit, so JS 32-bit semantics (|0, >>>, Math.imul) are
## emulated by keeping state as an unsigned 32-bit value and doing the
## multiplication in 16-bit limbs to avoid signed-64 overflow.

const MASK32 := 0xFFFFFFFF

var _state: int


func _init(seed_value: int) -> void:
	_state = seed_value & MASK32


## Low 32 bits of a * b, matching JS Math.imul (as an unsigned value).
static func _imul32(a: int, b: int) -> int:
	var al := a & 0xFFFF
	var ah := (a >> 16) & 0xFFFF
	var bl := b & 0xFFFF
	var bh := (b >> 16) & 0xFFFF
	return ((al * bl) + (((al * bh + ah * bl) & 0xFFFF) << 16)) & MASK32


## Next float in [0, 1), identical sequence to the JS implementation.
func next() -> float:
	_state = (_state + 0x6D2B79F5) & MASK32
	var a := _state
	var t := _imul32(a ^ (a >> 15), (1 | a) & MASK32)
	t = ((t + _imul32(t ^ (t >> 7), (61 | t) & MASK32)) & MASK32) ^ t
	return float((t ^ (t >> 14)) & MASK32) / 4294967296.0
