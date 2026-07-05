extends Node
## Drives the real rendered game and captures screenshots of key states.
## Run (windowed, NOT headless - it needs a real viewport):
##   /Applications/Godot.app/Contents/MacOS/Godot --path godot \
##     res://tests/screenshot_harness.tscn

const OUT := "res://screenshots"

var game: Control
var _hit_stalemate := false


func _ready() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))

	var title: Control = load("res://ui/title_screen.tscn").instantiate()
	add_child(title)
	await _settle(0.6)
	await _shot("01-title.png")
	title.queue_free()

	game = load("res://ui/game_screen.tscn").instantiate()
	add_child(game)
	await _wait_unlocked()
	await _shot("02-opening-deal.png")

	# Fast-forward until it's my turn with a legal hand play, restarting the
	# game if it finishes first, so every shot below is guaranteed to land.
	for attempt in 5:
		await _ensure_playing()
		Engine.time_scale = 6.0
		for i in 120:
			if _game_over():
				break
			await _advance_one()
			if (
				game.state.current_player == "P1"
				and not game._input_locked
				and game._p("P1").hand.size() >= 3
				and SimRules.has_legal_hand_play(game._p("P1").hand, game.state.center_piles)
			):
				break
		Engine.time_scale = 1.0
		if not _game_over():
			break
	await _wait_my_turn()
	await _shot("03-midgame.png")

	# Selection highlight + resolution (hand play when available)
	if not _game_over():
		var move: Variant = SimBot.get_bot_move(game.state, Callable(), "P1")
		if move != null and move["type"] == "SELECT_HAND_CARD":
			await game._run_action(move)
			await _wait_unlocked()
			await _shot("04-selection-highlight.png")
			var pile_sel: Variant = SimBot.get_bot_pile_selection(game.state, Callable(), "P1")
			if pile_sel != null:
				await game._run_action(pile_sel)
				await _wait_unlocked()

	# Face-down gamble reveal (forced, so the state is always captured)
	for attempt in 3:
		await _ensure_playing()
		await _wait_my_turn()
		if _game_over():
			continue
		var fd_index := -1
		for i in 4:
			if game._p("P1").face_down[i] != null:
				fd_index = i
				break
		if fd_index < 0:
			# All slots already emptied this game: restart and retry
			await game._start_new_game()
			await _wait_unlocked()
			continue
		await game._run_action({"type": "SELECT_FACEDOWN_CARD", "index": fd_index})
		await _wait_unlocked()
		game._run_action({"type": "SELECT_PILE", "pileIndex": randi() % 4})
		await _settle(0.42)  # mid reveal pause
		await _shot("05-gamble-reveal.png")
		await _wait_unlocked()
		break

	# Deck prompt
	await _ensure_playing()
	await _wait_my_turn()
	if not _game_over() and game.state.deck.size() > 0 and game.state.selected_card == null:
		game._on_deck_tapped()
		await _settle(0.25)
		await _shot("06-deck-prompt.png")
		game._hide_deck_prompt()

	# Play to completion
	Engine.time_scale = 10.0
	var deadline := Time.get_ticks_msec() + 240000
	while not _game_over() and Time.get_ticks_msec() < deadline:
		await _advance_one()
	Engine.time_scale = 1.0
	await _settle(0.4)
	await _shot("07-end-overlay.png")

	print("HARNESS DONE winner=%s stalemate=%s transitions=%d" % [
		str(game.state.winner), str(_hit_stalemate), game.state.log.size()
	])
	get_tree().quit(0)


func _game_over() -> bool:
	return game.state.winner != null or _hit_stalemate


func _ensure_playing() -> void:
	if _game_over():
		_hit_stalemate = false
		await game._start_new_game()
		await _wait_unlocked()


func _advance_one() -> void:
	if _hit_stalemate:
		return
	if game._overlay.visible and game.state.winner == null:
		_hit_stalemate = true
		return
	if game.state.current_player == "P1" and not game._input_locked and not game._bot_running:
		var move: Variant = SimBot.get_bot_move(game.state, Callable(), "P1")
		if move == null:
			_hit_stalemate = true
			return
		await game._run_action(move)
		await _wait_unlocked()
		var pile_sel: Variant = SimBot.get_bot_pile_selection(game.state, Callable(), "P1")
		if pile_sel != null:
			await game._run_action(pile_sel)
			await _wait_unlocked()
	else:
		await get_tree().process_frame


func _wait_unlocked() -> void:
	while game._input_locked or game._bot_running:
		await get_tree().process_frame


func _wait_my_turn() -> void:
	while not _game_over():
		await _wait_unlocked()
		if game._overlay.visible and game.state.winner == null:
			_hit_stalemate = true
			return
		if game.state.winner != null or game.state.current_player == "P1":
			return
		await get_tree().process_frame


func _settle(seconds: float) -> void:
	await get_tree().create_timer(seconds, true, false, true).timeout


func _shot(file_name: String) -> void:
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	img.save_png(OUT + "/" + file_name)
	print("shot %s" % file_name)
