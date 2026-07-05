class_name CardView
extends Control
## Procedurally drawn card (face or back). Suit glyphs are drawn as vector
## shapes rather than font glyphs so rendering never depends on font coverage.
## Pure presentation - all game logic lives in the sim.

signal tapped(view: CardView)

var tokens: DesignTokens
var card: SimCard = null
var face_up := false:
	set(value):
		face_up = value
		queue_redraw()
var selected := false:
	set(value):
		selected = value
		queue_redraw()
var dimmed := false:
	set(value):
		dimmed = value
		modulate.a = tokens.dim_alpha if (value and tokens) else 1.0
var interactive := true:
	set(value):
		interactive = value
		mouse_filter = MOUSE_FILTER_STOP if value else MOUSE_FILTER_IGNORE


static func create(p_tokens: DesignTokens, p_card: SimCard, p_face_up: bool) -> CardView:
	var view := CardView.new()
	view.tokens = p_tokens
	view.card = p_card
	view.face_up = p_face_up
	view.custom_minimum_size = p_tokens.card_size
	view.size = p_tokens.card_size
	view.pivot_offset = p_tokens.card_size / 2.0
	return view


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.pressed and mb.button_index == MOUSE_BUTTON_LEFT:
			accept_event()
			tapped.emit(self)


func _draw() -> void:
	if face_up and card != null:
		_draw_face()
	else:
		_draw_back()


func _draw_face() -> void:
	var rect := Rect2(Vector2.ZERO, size)
	var style := StyleBoxFlat.new()
	style.bg_color = tokens.card_face
	style.set_corner_radius_all(int(tokens.card_radius))
	if selected:
		style.set_border_width_all(int(tokens.select_border_width))
		style.border_color = tokens.accent
	else:
		style.set_border_width_all(int(tokens.card_border_width))
		style.border_color = tokens.card_border
	draw_style_box(style, rect)

	var color := _ink_color()
	var font := get_theme_default_font()
	var is_joker := card.rank == "JOKER"

	# Corner rank (star shape for Jokers - no font dependency)
	if is_joker:
		_draw_star(Vector2(size.x * 0.19, size.y * 0.15), size.x * 0.13, color)
	else:
		draw_string(
			font,
			Vector2(size.x * 0.09, size.y * 0.10 + font.get_ascent(tokens.font_size_rank) * 0.72),
			card.rank,
			HORIZONTAL_ALIGNMENT_LEFT,
			-1,
			tokens.font_size_rank,
			color
		)

	# Big center glyph
	var center := Vector2(size.x / 2.0, size.y * 0.60)
	var glyph_size := size.x * 0.46
	if is_joker:
		_draw_star(center, glyph_size * 0.62, color)
	else:
		match card.suit:
			"hearts":
				_draw_heart(center, glyph_size, color)
			"diamonds":
				_draw_diamond(center, glyph_size, color)
			"clubs":
				_draw_club(center, glyph_size, color)
			"spades":
				_draw_spade(center, glyph_size, color)


func _draw_back() -> void:
	var rect := Rect2(Vector2.ZERO, size)
	var style := StyleBoxFlat.new()
	style.bg_color = tokens.card_back
	style.set_corner_radius_all(int(tokens.card_radius))
	if selected:
		style.set_border_width_all(int(tokens.select_border_width))
		style.border_color = tokens.accent
	draw_style_box(style, rect)

	var inner := StyleBoxFlat.new()
	inner.bg_color = Color.TRANSPARENT
	inner.draw_center = false
	inner.set_border_width_all(2)
	inner.border_color = tokens.card_back_inner
	inner.set_corner_radius_all(int(tokens.card_radius * 0.6))
	var margin := size.x * 0.09
	draw_style_box(inner, Rect2(Vector2(margin, margin), size - Vector2(margin, margin) * 2.0))

	_draw_diamond(size / 2.0, size.x * 0.30, tokens.card_back_inner)


func _ink_color() -> Color:
	match SimRules.get_card_color(card):
		"red":
			return tokens.card_red
		"gold":
			return tokens.card_gold
		_:
			return tokens.card_black


func _draw_heart(c: Vector2, s: float, col: Color) -> void:
	draw_circle(c + Vector2(-0.24 * s, -0.20 * s), 0.26 * s, col)
	draw_circle(c + Vector2(0.24 * s, -0.20 * s), 0.26 * s, col)
	draw_colored_polygon(
		PackedVector2Array([
			c + Vector2(-0.49 * s, -0.12 * s),
			c + Vector2(0.49 * s, -0.12 * s),
			c + Vector2(0.0, 0.5 * s),
		]),
		col
	)


func _draw_diamond(c: Vector2, s: float, col: Color) -> void:
	draw_colored_polygon(
		PackedVector2Array([
			c + Vector2(0.0, -0.52 * s),
			c + Vector2(0.38 * s, 0.0),
			c + Vector2(0.0, 0.52 * s),
			c + Vector2(-0.38 * s, 0.0),
		]),
		col
	)


func _draw_spade(c: Vector2, s: float, col: Color) -> void:
	draw_circle(c + Vector2(-0.20 * s, 0.05 * s), 0.24 * s, col)
	draw_circle(c + Vector2(0.20 * s, 0.05 * s), 0.24 * s, col)
	draw_colored_polygon(
		PackedVector2Array([
			c + Vector2(-0.42 * s, 0.10 * s),
			c + Vector2(0.42 * s, 0.10 * s),
			c + Vector2(0.0, -0.52 * s),
		]),
		col
	)
	_draw_stem(c, s, col)


func _draw_club(c: Vector2, s: float, col: Color) -> void:
	draw_circle(c + Vector2(0.0, -0.24 * s), 0.22 * s, col)
	draw_circle(c + Vector2(-0.21 * s, 0.05 * s), 0.22 * s, col)
	draw_circle(c + Vector2(0.21 * s, 0.05 * s), 0.22 * s, col)
	draw_circle(c + Vector2(0.0, -0.02 * s), 0.14 * s, col)
	_draw_stem(c, s, col)


func _draw_stem(c: Vector2, s: float, col: Color) -> void:
	draw_colored_polygon(
		PackedVector2Array([
			c + Vector2(-0.06 * s, 0.10 * s),
			c + Vector2(0.06 * s, 0.10 * s),
			c + Vector2(0.16 * s, 0.52 * s),
			c + Vector2(-0.16 * s, 0.52 * s),
		]),
		col
	)


func _draw_star(c: Vector2, radius: float, col: Color) -> void:
	var points := PackedVector2Array()
	for i in 10:
		var r := radius if i % 2 == 0 else radius * 0.42
		var angle := -PI / 2.0 + TAU * i / 10.0
		points.append(c + Vector2(cos(angle), sin(angle)) * r)
	draw_colored_polygon(points, col)
