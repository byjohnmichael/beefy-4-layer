class_name PileSlot
extends Control
## Empty slot outline (center piles, deck spot, face-down slots) with a
## highlight state for legal targets. Pure presentation.

signal tapped(slot: PileSlot)

var tokens: DesignTokens
var highlighted := false:
	set(value):
		highlighted = value
		queue_redraw()


static func create(p_tokens: DesignTokens) -> PileSlot:
	var slot := PileSlot.new()
	slot.tokens = p_tokens
	slot.custom_minimum_size = p_tokens.card_size
	slot.size = p_tokens.card_size
	return slot


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.pressed and mb.button_index == MOUSE_BUTTON_LEFT:
			accept_event()
			tapped.emit(self)


func _draw() -> void:
	var style := StyleBoxFlat.new()
	style.set_corner_radius_all(int(tokens.slot_radius))
	if highlighted:
		style.bg_color = tokens.accent_soft
		style.set_border_width_all(5)
		style.border_color = tokens.accent
		# Ring sits outside the card footprint so it stays visible when a
		# card view covers the slot exactly.
		var margin := 10.0
		draw_style_box(
			style, Rect2(Vector2(-margin, -margin), size + Vector2(margin, margin) * 2.0)
		)
	else:
		style.bg_color = Color.TRANSPARENT
		style.set_border_width_all(3)
		style.border_color = tokens.slot_outline
		draw_style_box(style, Rect2(Vector2.ZERO, size))
