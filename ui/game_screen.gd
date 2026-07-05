extends Control
## Game screen: a pure view over the sim. UI dispatches actions to
## SimReducer, renders the resulting state, and animates the diff.
## No game rules live here - legality always comes from SimRules/SimReducer.

@export var tokens: DesignTokens

# --- Layout (base resolution 1080x1920) ---
const W := 1080.0
const H := 1920.0
const OPP_HAND_CENTER_Y := 64.0
const OPP_ROW_Y := 168.0
const MID_Y := 560.0
const MID_START_X := 84.0
const MID_GAP := 28.0
const MY_ROW_Y := 1120.0
const HAND_Y := 1560.0
const ROW_GAP := 32.0
const HAND_MAX_WIDTH := 960.0

var state: SimState
var card_views: Dictionary = {}  # card id -> CardView
var pile_slots: Array = []  # 4 PileSlot
var my_slots: Array = []
var opp_slots: Array = []

var _input_locked := true
var _bot_running := false

var _card_layer: Control
var _slot_layer: Control
var _hud_layer: Control
var _deck_view: CardView
var _deck_slot: PileSlot
var _deck_label: Label
var _opp_count: Label
var _turn_label: Label
var _turn_bar_top: ColorRect
var _turn_bar_bottom: ColorRect
var _deck_prompt: PanelContainer
var _overlay: Control
var _overlay_label: Label
var _banner: Label


func _ready() -> void:
	_build_background()
	_slot_layer = _make_layer()
	_card_layer = _make_layer()
	_hud_layer = _make_layer()
	_build_slots()
	_build_hud()
	_build_deck_prompt()
	_build_overlay()
	_build_banner()
	_start_new_game()


# ---------------------------------------------------------------- build

func _make_layer() -> Control:
	var layer := Control.new()
	layer.set_anchors_preset(Control.PRESET_FULL_RECT)
	layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(layer)
	return layer


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
	bg.mouse_filter = Control.MOUSE_FILTER_STOP
	bg.gui_input.connect(_on_background_input)
	add_child(bg)


func _build_slots() -> void:
	for i in 4:
		var opp := PileSlot.create(tokens)
		opp.position = _opp_slot_pos(i)
		opp.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_slot_layer.add_child(opp)
		opp_slots.append(opp)

		var pile := PileSlot.create(tokens)
		pile.position = _pile_pos(i)
		pile.tapped.connect(_on_pile_slot_tapped)
		_slot_layer.add_child(pile)
		pile_slots.append(pile)

		var mine := PileSlot.create(tokens)
		mine.position = _my_slot_pos(i)
		mine.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_slot_layer.add_child(mine)
		my_slots.append(mine)

	_deck_slot = PileSlot.create(tokens)
	_deck_slot.position = _deck_pos()
	_deck_slot.tapped.connect(func(_slot: PileSlot) -> void: _on_deck_tapped())
	_slot_layer.add_child(_deck_slot)

	_deck_view = CardView.create(tokens, null, false)
	_deck_view.position = _deck_pos()
	_deck_view.tapped.connect(func(_view: CardView) -> void: _on_deck_tapped())
	_slot_layer.add_child(_deck_view)


func _build_hud() -> void:
	_opp_count = _make_label("", tokens.font_size_hud, tokens.hud_text_dim)
	_opp_count.position = Vector2(
		W / 2.0 + tokens.opp_hand_max_width / 2.0 + 46.0, OPP_HAND_CENTER_Y - 26.0
	)
	_opp_count.size = Vector2(160, 50)
	_hud_layer.add_child(_opp_count)

	_deck_label = _make_label("", tokens.font_size_log, tokens.hud_text_dim)
	_deck_label.position = Vector2(_deck_pos().x, _deck_pos().y + tokens.card_size.y + 10)
	_deck_label.size = Vector2(tokens.card_size.x, 40)
	_deck_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_hud_layer.add_child(_deck_label)

	_turn_label = _make_label("", tokens.font_size_hud, tokens.accent)
	_turn_label.position = Vector2(0, HAND_Y + tokens.card_size.y + 40)
	_turn_label.size = Vector2(W, 50)
	_turn_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_hud_layer.add_child(_turn_label)

	_turn_bar_top = ColorRect.new()
	_turn_bar_top.color = tokens.accent
	_turn_bar_top.position = Vector2(0, 0)
	_turn_bar_top.size = Vector2(W, 10)
	_turn_bar_top.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hud_layer.add_child(_turn_bar_top)

	_turn_bar_bottom = ColorRect.new()
	_turn_bar_bottom.color = tokens.accent
	_turn_bar_bottom.position = Vector2(0, H - 10)
	_turn_bar_bottom.size = Vector2(W, 10)
	_turn_bar_bottom.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hud_layer.add_child(_turn_bar_bottom)

	# Subtle breathing pulse on whichever turn bar is visible
	for bar: ColorRect in [_turn_bar_top, _turn_bar_bottom]:
		var tw := create_tween().set_loops()
		tw.tween_property(bar, "modulate:a", 0.45, tokens.pulse_time) \
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		tw.tween_property(bar, "modulate:a", 1.0, tokens.pulse_time) \
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)


func _build_deck_prompt() -> void:
	_deck_prompt = PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = tokens.panel_bg
	style.set_corner_radius_all(int(tokens.button_radius))
	style.content_margin_left = 18
	style.content_margin_right = 18
	style.content_margin_top = 18
	style.content_margin_bottom = 18
	_deck_prompt.add_theme_stylebox_override("panel", style)
	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 14)
	var draw_btn := _make_button("Draw to hand")
	draw_btn.pressed.connect(func() -> void:
		_hide_deck_prompt()
		_run_action({"type": "DRAW_FROM_DECK"})
	)
	var gamble_btn := _make_button("Flip onto a pile")
	gamble_btn.pressed.connect(func() -> void:
		_hide_deck_prompt()
		_run_action({"type": "START_DRAW_GAMBLE"})
	)
	vbox.add_child(draw_btn)
	vbox.add_child(gamble_btn)
	_deck_prompt.add_child(vbox)
	_deck_prompt.position = _deck_pos() + Vector2(0, tokens.card_size.y + 64)
	_deck_prompt.visible = false
	_hud_layer.add_child(_deck_prompt)


func _build_overlay() -> void:
	_overlay = Control.new()
	_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	_overlay.visible = false
	add_child(_overlay)

	var dim := ColorRect.new()
	dim.color = tokens.overlay_dim
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	_overlay.add_child(dim)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	_overlay.add_child(center)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 40)
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	center.add_child(vbox)

	_overlay_label = _make_label("", tokens.font_size_overlay, tokens.hud_text)
	_overlay_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(_overlay_label)

	var again := _make_button("Play again")
	again.pressed.connect(func() -> void: _start_new_game())
	vbox.add_child(again)

	var title := _make_button("Title screen")
	title.pressed.connect(func() -> void:
		get_tree().change_scene_to_file("res://ui/title_screen.tscn")
	)
	vbox.add_child(title)


func _build_banner() -> void:
	_banner = _make_label("", tokens.font_size_overlay, tokens.hud_text)
	_banner.position = Vector2(0, 940)
	_banner.size = Vector2(W, 100)
	_banner.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_banner.modulate.a = 0.0
	_hud_layer.add_child(_banner)


func _make_label(text: String, font_size: int, color: Color) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return label


func _make_button(text: String) -> Button:
	var button := Button.new()
	button.text = text
	button.add_theme_font_size_override("font_size", tokens.font_size_button)
	button.add_theme_color_override("font_color", tokens.card_black)
	button.add_theme_color_override("font_pressed_color", tokens.card_black)
	button.add_theme_color_override("font_hover_color", tokens.card_black)
	for state_name in ["normal", "hover", "pressed"]:
		var style := StyleBoxFlat.new()
		style.bg_color = tokens.accent.darkened(0.12) if state_name == "pressed" else tokens.accent
		style.set_corner_radius_all(int(tokens.button_radius))
		style.content_margin_left = 40
		style.content_margin_right = 40
		style.content_margin_top = 16
		style.content_margin_bottom = 16
		button.add_theme_stylebox_override(state_name, style)
	button.pressed.connect(func() -> void: Sfx.play("tap"))
	return button


# ---------------------------------------------------------------- layout

func _card_w() -> float:
	return tokens.card_size.x


func _row_start_x() -> float:
	return (W - (4.0 * _card_w() + 3.0 * ROW_GAP)) / 2.0


func _opp_slot_pos(i: int) -> Vector2:
	return Vector2(_row_start_x() + i * (_card_w() + ROW_GAP), OPP_ROW_Y)


func _my_slot_pos(i: int) -> Vector2:
	return Vector2(_row_start_x() + i * (_card_w() + ROW_GAP), MY_ROW_Y)


func _deck_pos() -> Vector2:
	return Vector2(MID_START_X, MID_Y)


func _pile_pos(i: int) -> Vector2:
	return Vector2(MID_START_X + (i + 1) * (_card_w() + MID_GAP), MID_Y)


## Top-left position for a full-size card whose visual center sits at the
## middle of the opponent's hand fan (used as a fly target).
func _opp_hand_anchor() -> Vector2:
	return Vector2(W / 2.0, OPP_HAND_CENTER_Y) - tokens.card_size / 2.0


## Fanned layout for my hand: cards sit on an arc, rotated along it.
## Returns [{ "pos": Vector2, "rot": float_degrees }].
func _hand_layout(count: int) -> Array:
	var out: Array = []
	if count == 0:
		return out
	var w := _card_w()
	var spacing := w + 18.0
	if count > 1:
		spacing = minf(spacing, (HAND_MAX_WIDTH - w) / (count - 1))
	var radius: float = tokens.hand_fan_radius
	for i in count:
		var t := i - (count - 1) / 2.0
		var ang := t * spacing / radius  # radians along the arc
		var cx := W / 2.0 + sin(ang) * radius
		var cy := HAND_Y + (1.0 - cos(ang)) * radius
		out.append({"pos": Vector2(cx - w / 2.0, cy), "rot": rad_to_deg(ang)})
	return out


## Small face-down fan for the bot's hand, centered at the top.
func _opp_hand_layout(count: int) -> Array:
	var out: Array = []
	if count == 0:
		return out
	var step: float = tokens.opp_hand_step
	if count > 1:
		step = minf(step, tokens.opp_hand_max_width / (count - 1))
	for i in count:
		var t := i - (count - 1) / 2.0
		var center := Vector2(W / 2.0 + t * step, OPP_HAND_CENTER_Y)
		out.append({
			"pos": center - tokens.card_size / 2.0,
			"rot": t * tokens.opp_hand_rot_step,
		})
	return out


func _my_hand_end_target(post_hand_size: int) -> Dictionary:
	var layout := _hand_layout(post_hand_size)
	if layout.is_empty():
		return {"pos": Vector2(W / 2.0, HAND_Y), "rot": 0.0}
	return layout.back()


# ---------------------------------------------------------------- game flow

func _p(player_id: String) -> SimPlayerState:
	return state.players[player_id]


func _start_new_game() -> void:
	_input_locked = true
	_overlay.visible = false
	_hide_deck_prompt()
	SimDeck.set_rng(Callable())  # live games use the engine RNG
	state = SimReducer.reduce(SimState.new(), {"type": "START_GAME"})
	_clear_views()
	_sync_hud()
	await _animate_deal()
	var first := "P1" if randi() % 2 == 0 else "P2"
	state = SimReducer.reduce(state, {"type": "SET_FIRST_PLAYER", "player": first})
	_sync_board()
	await _animate_coin_flip(first == "P1")
	_input_locked = false
	_kick_bot()


func _run_action(action: Dictionary) -> void:
	if _input_locked or _bot_running:
		return
	_input_locked = true
	await _do_action(action)
	_input_locked = false
	_kick_bot()


## Dispatch + animate one transition. Callers manage input locking.
func _do_action(action: Dictionary) -> void:
	var pre := state
	state = SimReducer.reduce(state, action)
	await _animate_transition(pre, action)
	# Clear transient reveal bookkeeping (the web UI does the same after
	# its reveal animations); never during selection/pending states.
	if state.revealed_card != null:
		state = SimReducer.reduce(state, {"type": "CLEAR_SELECTIONS"})
	_sync_board()


func _kick_bot() -> void:
	if state.winner != null or state.current_player != "P2" or _bot_running:
		return
	_bot_loop()


func _bot_loop() -> void:
	_bot_running = true
	_input_locked = true
	while state.winner == null and state.current_player == "P2":
		await get_tree().create_timer(tokens.bot_delay).timeout
		var move: Variant = SimBot.get_bot_move(state, Callable(), "P2")
		if move == null:
			_show_overlay("Stalemate - no moves left", "fail")
			break
		await _do_action(move)
		var pile_sel: Variant = SimBot.get_bot_pile_selection(state, Callable(), "P2")
		if pile_sel != null:
			await get_tree().create_timer(tokens.bot_pile_delay).timeout
			await _do_action(pile_sel)
	_bot_running = false
	_input_locked = false
	_sync_board()


# ---------------------------------------------------------------- input

func _on_card_tapped(view: CardView) -> void:
	if _input_locked or _bot_running or state.winner != null:
		return
	if state.current_player != "P1":
		return
	if view.card == null:
		return
	var id := view.card.id

	# Pile top card acts as a pile tap target
	for p in 4:
		var pile: Array = state.center_piles[p]
		if not pile.is_empty() and (pile.back() as SimCard).id == id:
			_on_pile_tapped(p)
			return

	var hand: Array = _p("P1").hand
	for i in hand.size():
		if (hand[i] as SimCard).id == id:
			_hide_deck_prompt()
			if _is_selected("hand", i):
				_run_action({"type": "CLEAR_SELECTIONS"})
			else:
				_run_action({"type": "SELECT_HAND_CARD", "index": i})
			return

	var face_down: Array = _p("P1").face_down
	for i in 4:
		var fd: Variant = face_down[i]
		if fd != null and (fd as SimCard).id == id:
			_hide_deck_prompt()
			if _is_selected("faceDown", i):
				_run_action({"type": "CLEAR_SELECTIONS"})
			else:
				_run_action({"type": "SELECT_FACEDOWN_CARD", "index": i})
			return


func _on_pile_slot_tapped(slot: PileSlot) -> void:
	var index := pile_slots.find(slot)
	if index >= 0:
		_on_pile_tapped(index)


func _on_pile_tapped(pile_index: int) -> void:
	if _input_locked or _bot_running or state.winner != null:
		return
	if state.current_player != "P1":
		return
	_hide_deck_prompt()
	if state.pending_draw_gamble != null:
		_run_action({"type": "PLAY_DRAW_GAMBLE", "pileIndex": pile_index})
	elif state.selected_card != null:
		_run_action({"type": "SELECT_PILE", "pileIndex": pile_index})


func _on_deck_tapped() -> void:
	if _input_locked or _bot_running or state.winner != null:
		return
	if state.current_player != "P1":
		return
	if state.pending_draw_gamble != null:
		_run_action({"type": "CANCEL_DRAW_GAMBLE"})
		return
	if state.deck.is_empty():
		return
	if state.selected_card != null:
		_run_action({"type": "CLEAR_SELECTIONS"})
	Sfx.play("tap")
	_deck_prompt.visible = not _deck_prompt.visible


func _on_background_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.pressed and mb.button_index == MOUSE_BUTTON_LEFT:
			_hide_deck_prompt()
			if _input_locked or _bot_running or state.winner != null:
				return
			if state.current_player != "P1":
				return
			if state.pending_draw_gamble != null:
				_run_action({"type": "CANCEL_DRAW_GAMBLE"})
			elif state.selected_card != null:
				_run_action({"type": "CLEAR_SELECTIONS"})


func _hide_deck_prompt() -> void:
	_deck_prompt.visible = false


## Whether `player` currently has this card selected. The sim's selected_card
## has no player field - it always belongs to state.current_player - so
## selection visuals must be gated on whose turn it is.
func _is_selected_by(player: String, source: String, index: int) -> bool:
	return (
		state.current_player == player
		and state.selected_card != null
		and state.selected_card["source"] == source
		and int(state.selected_card["index"]) == index
	)


func _is_selected(source: String, index: int) -> bool:
	return _is_selected_by("P1", source, index)


# ---------------------------------------------------------------- rendering

func _clear_views() -> void:
	for id: String in card_views:
		(card_views[id] as CardView).queue_free()
	card_views.clear()


func _spawn(card: SimCard, face_up: bool, pos: Vector2) -> CardView:
	var view := CardView.create(tokens, card, face_up)
	view.position = pos
	view.tapped.connect(_on_card_tapped)
	_card_layer.add_child(view)
	card_views[card.id] = view
	return view


## Reconcile every card view with the current state (positions, rotations,
## scales, faces, highlights, HUD). Small diffs tween smoothly.
func _sync_board() -> void:
	var specs: Dictionary = {}
	var order: Array = []

	# Opponent's hand: small face-down fan at the top
	var opp_hand: Array = _p("P2").hand
	var opp_layout := _opp_hand_layout(opp_hand.size())
	for i in opp_hand.size():
		var card: SimCard = opp_hand[i]
		specs[card.id] = {
			"card": card, "pos": opp_layout[i]["pos"], "rot": opp_layout[i]["rot"],
			"scale": Vector2.ONE * tokens.opp_hand_scale,
			"face_up": false, "selected": _is_selected_by("P2", "hand", i),
			"dim": false, "interactive": false,
		}
		order.append(card.id)

	# Center piles: top two cards for depth
	for p in 4:
		var pile: Array = state.center_piles[p]
		for depth in [1, 0]:
			if pile.size() > depth:
				var card: SimCard = pile[pile.size() - 1 - depth]
				specs[card.id] = {
					"card": card, "pos": _pile_pos(p), "face_up": true,
					"selected": false, "dim": false, "interactive": depth == 0,
				}
				order.append(card.id)

	# Opponent face-down row
	for i in 4:
		var fd: Variant = _p("P2").face_down[i]
		if fd != null:
			var card := fd as SimCard
			specs[card.id] = {
				"card": card, "pos": _opp_slot_pos(i), "face_up": false,
				"selected": _is_selected_by("P2", "faceDown", i),
				"dim": false, "interactive": false,
			}
			order.append(card.id)

	# My face-down row
	for i in 4:
		var fd: Variant = _p("P1").face_down[i]
		if fd != null:
			var card := fd as SimCard
			specs[card.id] = {
				"card": card, "pos": _my_slot_pos(i), "face_up": false,
				"selected": _is_selected("faceDown", i), "dim": false, "interactive": true,
			}
			order.append(card.id)

	# My hand: fanned arc
	var hand: Array = _p("P1").hand
	var layout := _hand_layout(hand.size())
	for i in hand.size():
		var card: SimCard = hand[i]
		var selected := _is_selected("hand", i)
		var pos: Vector2 = layout[i]["pos"]
		if selected:
			pos += Vector2(0, -tokens.hand_select_lift)
		specs[card.id] = {
			"card": card,
			"pos": pos,
			"rot": layout[i]["rot"],
			"face_up": true,
			"selected": selected,
			"dim": SimRules.get_legal_piles(card, state.center_piles).is_empty(),
			"interactive": true,
		}
		order.append(card.id)

	# Pending draw-gamble card hovers above the deck
	if state.pending_draw_gamble != null:
		var card := state.pending_draw_gamble as SimCard
		specs[card.id] = {
			"card": card, "pos": _deck_pos() + Vector2(0, -48), "face_up": false,
			"selected": true, "dim": false, "interactive": false,
		}
		order.append(card.id)

	# Reconcile views
	for id: String in card_views.keys():
		if not specs.has(id):
			(card_views[id] as CardView).queue_free()
			card_views.erase(id)
	for id: String in specs:
		var spec: Dictionary = specs[id]
		var target_pos: Vector2 = spec["pos"]
		var target_rot: float = spec.get("rot", 0.0)
		var target_scale: Vector2 = spec.get("scale", Vector2.ONE)
		var view: CardView = card_views.get(id)
		if view == null:
			view = _spawn(spec["card"], spec["face_up"], target_pos)
			view.rotation_degrees = target_rot
			view.scale = target_scale
		elif (
			view.position.distance_to(target_pos) > 1.0
			or absf(view.rotation_degrees - target_rot) > 0.5
			or view.scale.distance_to(target_scale) > 0.01
		):
			var tw := create_tween().set_parallel(true)
			tw.tween_property(view, "position", target_pos, tokens.dur_fast) \
				.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
			tw.tween_property(view, "rotation_degrees", target_rot, tokens.dur_fast) \
				.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
			tw.tween_property(view, "scale", target_scale, tokens.dur_fast) \
				.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		view.face_up = spec["face_up"]
		view.selected = spec["selected"]
		view.dimmed = spec["dim"]
		view.interactive = spec["interactive"]
	for id: String in order:
		if card_views.has(id):
			(card_views[id] as CardView).move_to_front()

	_sync_highlights()
	_sync_hud()

	# Stalemate for the human player: non-empty hand with no legal play,
	# no face-down cards, empty deck (a quirk carried over from the TS engine).
	if state.winner == null and state.current_player == "P1" and not _bot_running:
		var stuck := (
			state.deck.is_empty()
			and not _p("P1").hand.is_empty()
			and not SimRules.has_legal_hand_play(_p("P1").hand, state.center_piles)
			and _p("P1").face_down.all(func(c: Variant) -> bool: return c == null)
		)
		if stuck:
			_show_overlay("Stalemate - no moves left", "fail")


func _sync_highlights() -> void:
	var targets: Array = []
	if state.winner == null and state.current_player == "P1" and not _bot_running:
		if state.pending_draw_gamble != null:
			targets = [0, 1, 2, 3]
		elif state.selected_card != null:
			if state.selected_card["source"] == "hand":
				var card: SimCard = _p("P1").hand[int(state.selected_card["index"])]
				targets = SimRules.get_legal_piles(card, state.center_piles)
			else:
				targets = [0, 1, 2, 3]
	for p in 4:
		(pile_slots[p] as PileSlot).highlighted = p in targets


func _sync_hud() -> void:
	_deck_view.visible = not state.deck.is_empty()
	_deck_label.text = str(state.deck.size())
	_opp_count.text = "×%d" % _p("P2").hand.size()
	_opp_count.visible = _p("P2").hand.size() > 0
	var my_turn := state.winner == null and state.current_player == "P1"
	var bot_turn := state.winner == null and state.current_player == "P2"
	_turn_bar_bottom.visible = my_turn
	_turn_bar_top.visible = bot_turn
	_turn_label.text = "Your turn" if my_turn else ("Bot is thinking..." if bot_turn else "")
	if state.winner != null:
		_show_overlay(
			"You win!" if state.winner == "P1" else "Bot wins!",
			"win" if state.winner == "P1" else "lose"
		)


func _show_overlay(text: String, sound_name := "") -> void:
	if _overlay.visible:
		return
	_overlay_label.text = text
	_overlay.visible = true
	_overlay.modulate.a = 0.0
	var tw := create_tween()
	tw.tween_property(_overlay, "modulate:a", 1.0, tokens.dur_slow)
	if sound_name != "":
		Sfx.play(sound_name)


func _show_banner(text: String) -> void:
	_banner.text = text
	_banner.move_to_front()
	var tw := create_tween()
	tw.tween_property(_banner, "modulate:a", 1.0, tokens.dur_med)
	tw.tween_interval(tokens.banner_hold)
	tw.tween_property(_banner, "modulate:a", 0.0, tokens.dur_med)
	await tw.finished


# ---------------------------------------------------------------- animations

## Fly a card view to a target, straightening rotation and scale in flight.
## `pop` adds a landing scale-pop and the "place" sound (for pile landings).
func _fly(view: CardView, to: Vector2, duration: float, rot := 0.0, pop := false) -> void:
	view.move_to_front()
	var tw := create_tween().set_parallel(true)
	tw.tween_property(view, "position", to, duration) \
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tw.tween_property(view, "rotation_degrees", rot, duration) \
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tw.tween_property(view, "scale", Vector2.ONE, duration) \
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	await tw.finished
	if pop:
		Sfx.play("place")
		var tp := create_tween()
		tp.tween_property(view, "scale", Vector2.ONE * tokens.pop_scale, tokens.pop_time)
		tp.tween_property(view, "scale", Vector2.ONE, tokens.pop_time + 0.02)
		await tp.finished


func _flip(view: CardView, to_face_up: bool, reveal: SimCard = null) -> void:
	Sfx.play("flip")
	var restore_x := view.scale.x  # fan cards are scaled down; keep their scale
	var tw := create_tween()
	tw.tween_property(view, "scale:x", 0.0, tokens.dur_fast) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	await tw.finished
	if reveal != null:
		view.card = reveal
		card_views[reveal.id] = view
	view.face_up = to_face_up
	view.queue_redraw()
	var tw2 := create_tween()
	tw2.tween_property(view, "scale:x", restore_x, tokens.dur_fast) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	await tw2.finished


func _animate_deal() -> void:
	Sfx.play("shuffle")
	var items: Array = []
	for i in 4:
		items.append({"card": _p("P2").face_down[i], "target": _opp_slot_pos(i), "face": false})
	for i in 4:
		items.append({"card": _p("P1").face_down[i], "target": _my_slot_pos(i), "face": false})
	for p in 4:
		items.append({"card": state.center_piles[p][0], "target": _pile_pos(p), "face": true})

	var last_tween: Tween = null
	for k in items.size():
		var item: Dictionary = items[k]
		var view := _spawn(item["card"], false, _deck_pos())
		view.interactive = false
		var tw := create_tween()
		tw.tween_interval(k * tokens.deal_stagger)
		tw.tween_callback(func() -> void: Sfx.play("slide", randf_range(0.92, 1.1), -6.0))
		tw.tween_property(view, "position", item["target"], tokens.dur_slow) \
			.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		if item["face"]:
			tw.tween_property(view, "scale:x", 0.0, tokens.dur_fast) \
				.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
			tw.tween_callback(func() -> void: view.face_up = true)
			tw.tween_property(view, "scale:x", 1.0, tokens.dur_fast) \
				.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
		last_tween = tw
	if last_tween != null:
		await last_tween.finished


## Coin flip deciding the first player: a coin flips a few times mid-screen,
## settles on YOU/BOT, then a short banner confirms it.
func _animate_coin_flip(you_first: bool) -> void:
	var coin := CoinView.create(tokens, 240.0)
	coin.position = Vector2(W / 2.0 - 120.0, 850.0)
	coin.modulate.a = 0.0
	_hud_layer.add_child(coin)
	coin.move_to_front()
	Sfx.play("coin")

	var fade_in := create_tween()
	fade_in.tween_property(coin, "modulate:a", 1.0, tokens.dur_fast)
	await fade_in.finished

	var flips := 5 if (coin.showing_you != you_first) else 6
	for k in flips:
		var half := create_tween()
		half.tween_property(coin, "scale:x", 0.0, 0.07) \
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
		await half.finished
		coin.showing_you = not coin.showing_you
		var half2 := create_tween()
		half2.tween_property(coin, "scale:x", 1.0, 0.07) \
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
		await half2.finished

	# Settle pop
	var pop := create_tween()
	pop.tween_property(coin, "scale", Vector2.ONE * 1.12, tokens.pop_time)
	pop.tween_property(coin, "scale", Vector2.ONE, tokens.pop_time)
	await pop.finished

	_show_banner("You go first!" if you_first else "Bot goes first")
	await get_tree().create_timer(tokens.banner_hold * 0.6).timeout
	var fade_out := create_tween()
	fade_out.tween_property(coin, "modulate:a", 0.0, tokens.dur_med)
	await fade_out.finished
	coin.queue_free()


func _animate_transition(pre: SimState, action: Dictionary) -> void:
	var acting := pre.current_player
	match action.get("type", ""):
		"SELECT_HAND_CARD", "SELECT_FACEDOWN_CARD":
			if state != pre:
				Sfx.play("tap")
			return

		"SELECT_PILE":
			if state == pre or pre.selected_card == null:
				return  # reducer no-op (illegal target): selection stays
			var pile_index := int(action["pileIndex"])
			var source: String = pre.selected_card["source"]
			var index := int(pre.selected_card["index"])
			if source == "hand":
				await _animate_hand_play(pre, acting, index, pile_index)
			else:
				await _animate_facedown_gamble(pre, acting, index, pile_index)

		"DRAW_FROM_DECK":
			if state == pre:
				return
			await _animate_draw_to_hand(pre, acting)

		"START_DRAW_GAMBLE":
			if state == pre:
				return
			Sfx.play("slide")
			var card := state.pending_draw_gamble as SimCard
			var view := _spawn(card, false, _deck_pos())
			view.selected = true
			await _fly(view, _deck_pos() + Vector2(0, -48), tokens.dur_fast)

		"CANCEL_DRAW_GAMBLE":
			if pre.pending_draw_gamble != null:
				var view: CardView = card_views.get((pre.pending_draw_gamble as SimCard).id)
				if view != null:
					view.selected = false
					await _fly(view, _deck_pos(), tokens.dur_fast)
					_fade_out_and_free(view)

		"PLAY_DRAW_GAMBLE":
			if state == pre:
				return
			await _animate_draw_gamble(pre, acting, int(action["pileIndex"]))

		_:
			return


func _animate_hand_play(pre: SimState, acting: String, index: int, pile_index: int) -> void:
	var card: SimCard = pre.players[acting].hand[index]
	var view: CardView = card_views.get(card.id)
	if view == null:
		view = _spawn(card, true, _opp_hand_anchor())
	view.selected = false
	view.dimmed = false
	if acting == "P2":
		# Reveal the bot's card out of its face-down fan before it flies
		await _flip(view, true, card)
	await _fly(view, _pile_pos(pile_index), tokens.dur_med, 0.0, true)


func _animate_facedown_gamble(pre: SimState, acting: String, index: int, pile_index: int) -> void:
	var card: SimCard = pre.players[acting].face_down[index]
	var slot_pos := _my_slot_pos(index) if acting == "P1" else _opp_slot_pos(index)
	var view: CardView = card_views.get(card.id)
	if view == null:
		view = _spawn(card, false, slot_pos)
	view.selected = false
	await _flip(view, true, card)
	await get_tree().create_timer(tokens.reveal_pause).timeout

	var pile: Array = state.center_piles[pile_index]
	var success := not pile.is_empty() and (pile.back() as SimCard).id == card.id
	if success:
		await _fly(view, _pile_pos(pile_index), tokens.dur_med, 0.0, true)
	else:
		Sfx.play("fail")
		if acting == "P1":
			var target := _my_hand_end_target(_p("P1").hand.size())
			await _fly(view, target["pos"], tokens.dur_med, target["rot"])
		else:
			await _fly(view, _opp_hand_anchor(), tokens.dur_med)
		# Replacement slides from the deck into the slot
		var replacement: Variant = state.players[acting].face_down[index]
		if replacement != null:
			Sfx.play("slide")
			var new_view := _spawn(replacement, false, _deck_pos())
			await _fly(new_view, slot_pos, tokens.dur_med)
	await _maybe_animate_refresh(pre)


func _animate_draw_to_hand(pre: SimState, acting: String) -> void:
	Sfx.play("slide")
	var card: SimCard = pre.deck[0]
	var view := _spawn(card, false, _deck_pos())
	if acting == "P1":
		var target := _my_hand_end_target(_p("P1").hand.size())
		await _fly(view, target["pos"], tokens.dur_med, target["rot"])
		await _flip(view, true)
	else:
		await _fly(view, _opp_hand_anchor(), tokens.dur_med)
	await _maybe_animate_refresh(pre)


func _animate_draw_gamble(pre: SimState, acting: String, pile_index: int) -> void:
	var card := pre.pending_draw_gamble as SimCard
	var view: CardView = card_views.get(card.id)
	if view == null:
		view = _spawn(card, false, _deck_pos())
	view.selected = false
	await _flip(view, true, card)
	await get_tree().create_timer(tokens.reveal_pause).timeout

	var pile: Array = state.center_piles[pile_index]
	var success := not pile.is_empty() and (pile.back() as SimCard).id == card.id
	if success:
		await _fly(view, _pile_pos(pile_index), tokens.dur_med, 0.0, true)
	else:
		Sfx.play("fail")
		if acting == "P1":
			var target := _my_hand_end_target(_p("P1").hand.size())
			await _fly(view, target["pos"], tokens.dur_med, target["rot"])
		else:
			await _fly(view, _opp_hand_anchor(), tokens.dur_med)
	await _maybe_animate_refresh(pre)


func _fade_out_and_free(view: CardView) -> void:
	card_views.erase(view.card.id if view.card != null else "")
	var tw := create_tween()
	tw.tween_property(view, "modulate:a", 0.0, tokens.dur_fast)
	await tw.finished
	view.queue_free()


## When the transition included a deck refresh, gather the old pile cards
## into the deck and deal the 4 new single-card piles back out.
func _maybe_animate_refresh(pre: SimState) -> void:
	var refreshed := false
	for i in range(pre.log.size(), state.log.size()):
		if (state.log[i] as String).begins_with("Deck refreshed"):
			refreshed = true
			break
	if not refreshed:
		return

	# Gather old pile views into the deck
	Sfx.play("shuffle")
	var last_tween: Tween = null
	var gathered: Array = []
	for pile: Array in pre.center_piles:
		for entry: Variant in pile:
			var view: CardView = card_views.get((entry as SimCard).id)
			if view != null:
				var tw := create_tween()
				tw.tween_property(view, "position", _deck_pos(), tokens.dur_med) \
					.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
				last_tween = tw
				gathered.append(view)
	if last_tween != null:
		await last_tween.finished
	for view: CardView in gathered:
		card_views.erase(view.card.id)
		view.queue_free()
	_sync_hud()

	# Deal the new piles
	last_tween = null
	for p in 4:
		var pile: Array = state.center_piles[p]
		if pile.is_empty():
			continue
		var card: SimCard = pile.back()
		var view := _spawn(card, true, _deck_pos())
		var tw := create_tween()
		tw.tween_interval(p * tokens.deal_stagger * 2.0)
		tw.tween_callback(func() -> void: Sfx.play("slide", randf_range(0.92, 1.1), -6.0))
		tw.tween_property(view, "position", _pile_pos(p), tokens.dur_slow) \
			.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		last_tween = tw
	if last_tween != null:
		await last_tween.finished
