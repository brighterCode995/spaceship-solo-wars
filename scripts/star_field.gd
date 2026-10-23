class_name StarField
extends Control
## Static decorative star background for the menus.

const STAR_COUNT := 260

var _stars: Array[Dictionary] = []


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var rng := RandomNumberGenerator.new()
	rng.seed = 42
	for i in STAR_COUNT:
		_stars.append({
			"uv": Vector2(rng.randf(), rng.randf()),
			"size": rng.randf_range(1.0, 3.2),
			"alpha": rng.randf_range(0.3, 1.0),
		})
	resized.connect(queue_redraw)


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Color(0.02, 0.03, 0.09))
	for star in _stars:
		var uv: Vector2 = star["uv"]
		draw_circle(uv * size, star["size"], Color(0.8, 0.9, 1.0, star["alpha"]))
