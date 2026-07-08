extends Control
## Title screen: logo, play button, and a small fanned-card flourish.
## All styling comes from the DesignTokens resource.

@export var tokens: DesignTokens


func _ready() -> void:
	_build_background()
	_build_content()


func _build_background() -> void:
	var bg := TextureRect.new()
	var gradient := Gradient.new()
	gradient.colors = PackedColorArray([tokens.bg_top, tokens.bg_bottom])
	gradient.offsets = PackedFloat32Array([0.0, 1.0])
	var tex := GradientTexture2D.new()
	tex.gradient = gradient
	tex.fill_from = Vector2(0, 0)
	tex.fill_to = Vector2(0, 1)
	bg.texture = tex
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)


func _build_content() -> void:
	var title_top := _make_label("BEEFY", tokens.font_size_title, tokens.hud_text)
	title_top.position = Vector2(0, 420)
	title_top.size = Vector2(1080, 160)
	title_top.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(title_top)

	var title_bottom := _make_label("4 LAYER", tokens.font_size_title, tokens.accent)
	title_bottom.position = Vector2(0, 560)
	title_bottom.size = Vector2(1080, 160)
	title_bottom.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(title_bottom)

	var subtitle := _make_label("the card game", tokens.font_size_subtitle, tokens.hud_text_dim)
	subtitle.position = Vector2(0, 720)
	subtitle.size = Vector2(1080, 60)
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(subtitle)

	# Decorative fanned cards
	var ranks: Array = [
		SimCard.new("deco-0", "K", "spades"),
		SimCard.new("deco-1", "A", "hearts"),
		SimCard.new("deco-2", "2", "clubs"),
		SimCard.new("deco-3", "Q", "diamonds"),
	]
	for i in 4:
		var view := CardView.create(tokens, ranks[i], true)
		view.interactive = false
		view.position = Vector2(540 - tokens.card_size.x / 2.0 + (i - 1.5) * 90.0, 950.0)
		view.rotation_degrees = (i - 1.5) * 9.0
		view.pivot_offset = Vector2(tokens.card_size.x / 2.0, tokens.card_size.y * 1.2)
		add_child(view)

	var play := Button.new()
	play.text = "PLAY"
	play.add_theme_font_size_override("font_size", tokens.font_size_button)
	play.add_theme_color_override("font_color", tokens.card_black)
	play.add_theme_color_override("font_pressed_color", tokens.card_black)
	play.add_theme_color_override("font_hover_color", tokens.card_black)
	for state_name in ["normal", "hover", "pressed"]:
		var style := StyleBoxFlat.new()
		style.bg_color = tokens.accent.darkened(0.12) if state_name == "pressed" else tokens.accent
		style.set_corner_radius_all(int(tokens.button_radius))
		style.content_margin_left = 120
		style.content_margin_right = 120
		style.content_margin_top = 26
		style.content_margin_bottom = 26
		play.add_theme_stylebox_override(state_name, style)
	play.pressed.connect(func() -> void:
		get_tree().change_scene_to_file("res://ui/game_screen.tscn")
	)
	add_child(play)

	var mode := Button.new()
	mode.add_theme_font_size_override("font_size", tokens.font_size_log)
	mode.add_theme_color_override("font_color", tokens.accent)
	mode.add_theme_color_override("font_pressed_color", tokens.accent)
	mode.add_theme_color_override("font_hover_color", tokens.accent)
	mode.flat = true
	var sync_mode_text := func() -> void:
		mode.text = "mode: COMBO" if GameConfig.combo_mode else "mode: CLASSIC"
	sync_mode_text.call()
	mode.pressed.connect(func() -> void:
		GameConfig.combo_mode = not GameConfig.combo_mode
		sync_mode_text.call()
		mode.position.x = (1080.0 - mode.size.x) / 2.0
	)
	add_child(mode)

	await get_tree().process_frame
	play.position = Vector2((1080.0 - play.size.x) / 2.0, 1420.0)
	mode.position = Vector2((1080.0 - mode.size.x) / 2.0, 1620.0)

	var footer := _make_label(
		"singleplayer vs bot · godot prototype", tokens.font_size_log, tokens.hud_text_dim
	)
	footer.position = Vector2(0, 1800)
	footer.size = Vector2(1080, 44)
	footer.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(footer)


func _make_label(text: String, font_size: int, color: Color) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return label
