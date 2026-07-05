extends SceneTree
## Generates the app icon (1024x1024 PNG): background gradient with four
## stacked card shapes and a gold star - same palette as the DesignTokens.
## Run: godot --headless --path godot --script res://tests/make_icon.gd

const SIZE := 1024


func _init() -> void:
	var tokens: DesignTokens = load("res://ui/theme/tokens.tres")
	var img := Image.create(SIZE, SIZE, false, Image.FORMAT_RGBA8)

	# Four stacked cards, bottom to top, slightly offset
	var card_w := 560.0
	var card_h := 700.0
	var radius := 56.0
	var offsets: Array = [Vector2(-90, 96), Vector2(-30, 62), Vector2(30, 28), Vector2(90, -6)]
	var shades: Array = [0.62, 0.75, 0.88, 1.0]

	var star := _star_points(Vector2(SIZE / 2.0 + 90.0, SIZE / 2.0 - 40.0), 180.0)

	for y in SIZE:
		var t := float(y) / SIZE
		var bg := tokens.bg_top.lerp(tokens.bg_bottom, t)
		for x in SIZE:
			var p := Vector2(x, y)
			var color := bg
			for k in 4:
				var center: Vector2 = Vector2(SIZE / 2.0, SIZE / 2.0) + offsets[k]
				if _in_rounded_rect(p, center, card_w, card_h, radius):
					color = tokens.card_face.darkened(1.0 - shades[k])
			if Geometry2D.is_point_in_polygon(p, star):
				color = tokens.card_gold
			img.set_pixel(x, y, color)

	img.save_png(ProjectSettings.globalize_path("res://icon_1024.png"))
	print("icon written")
	quit(0)


func _in_rounded_rect(p: Vector2, center: Vector2, w: float, h: float, r: float) -> bool:
	var d := (p - center).abs() - Vector2(w / 2.0 - r, h / 2.0 - r)
	var outside := Vector2(maxf(d.x, 0.0), maxf(d.y, 0.0)).length()
	return outside + minf(maxf(d.x, d.y), 0.0) <= r


func _star_points(c: Vector2, radius: float) -> PackedVector2Array:
	var points := PackedVector2Array()
	for i in 10:
		var r := radius if i % 2 == 0 else radius * 0.42
		var angle := -PI / 2.0 + TAU * i / 10.0
		points.append(c + Vector2(cos(angle), sin(angle)) * r)
	return points
