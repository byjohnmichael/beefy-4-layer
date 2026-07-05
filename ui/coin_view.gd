class_name CoinView
extends Control
## Flat coin used for the first-player flip. Two faces: "YOU" (accent) and
## "BOT" (card back blue). Flipping is animated externally via scale.x.

var tokens: DesignTokens
var showing_you := true:
	set(value):
		showing_you = value
		queue_redraw()


static func create(p_tokens: DesignTokens, diameter: float) -> CoinView:
	var coin := CoinView.new()
	coin.tokens = p_tokens
	coin.custom_minimum_size = Vector2(diameter, diameter)
	coin.size = Vector2(diameter, diameter)
	coin.pivot_offset = coin.size / 2.0
	coin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return coin


func _draw() -> void:
	var center := size / 2.0
	var radius := size.x / 2.0
	draw_circle(center + Vector2(0, 6), radius, tokens.shadow_color)
	var fill := tokens.accent if showing_you else tokens.card_back
	var rim := fill.darkened(0.25)
	draw_circle(center, radius, rim)
	draw_circle(center, radius * 0.88, fill)
	var font := get_theme_default_font()
	var text := "YOU" if showing_you else "BOT"
	var font_size := int(size.x * 0.30)
	var text_size := font.get_string_size(text, HORIZONTAL_ALIGNMENT_CENTER, -1, font_size)
	var ink := tokens.card_black if showing_you else tokens.card_face
	draw_string(
		font,
		Vector2(center.x - text_size.x / 2.0, center.y + font.get_ascent(font_size) * 0.36),
		text,
		HORIZONTAL_ALIGNMENT_LEFT,
		-1,
		font_size,
		ink
	)
