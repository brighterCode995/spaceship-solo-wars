class_name MarkerLayer
extends Control
## Draws icons over every enemy so they are easy to spot from a distance.
## Off-screen enemies get an arrow at the screen edge pointing their way.
## The goal ring gets a cyan marker once it is active.

const MARGIN := 70.0
const ENEMY_COLOR := Color(1.0, 0.3, 0.25)
const GOAL_COLOR := Color(0.35, 1.0, 1.0)

var goal_position: Vector3 = Vector3.ZERO
var goal_visible: bool = false


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _process(_delta: float) -> void:
	queue_redraw()


func _draw() -> void:
	var camera := get_viewport().get_camera_3d()
	if camera == null:
		return
	for node in get_tree().get_nodes_in_group("enemies"):
		var enemy := node as Node3D
		if enemy != null:
			_draw_marker(camera, enemy.global_position, ENEMY_COLOR, true)
	if goal_visible:
		_draw_marker(camera, goal_position, GOAL_COLOR, false)


func _draw_marker(camera: Camera3D, world_position: Vector3, color: Color, is_enemy: bool) -> void:
	var screen_size := get_viewport_rect().size
	var center := screen_size * 0.5
	var behind := camera.is_position_behind(world_position)
	var screen_point := camera.unproject_position(world_position)
	var on_screen := (
		not behind
		and screen_point.x > MARGIN and screen_point.x < screen_size.x - MARGIN
		and screen_point.y > MARGIN and screen_point.y < screen_size.y - MARGIN
	)
	var distance := camera.global_position.distance_to(world_position)
	var font := ThemeDB.fallback_font

	if on_screen:
		var s := 24.0
		var diamond := PackedVector2Array([
			screen_point + Vector2(0, -s), screen_point + Vector2(s, 0),
			screen_point + Vector2(0, s), screen_point + Vector2(-s, 0),
			screen_point + Vector2(0, -s),
		])
		draw_polyline(diamond, color, 4.0)
		if is_enemy:
			draw_circle(screen_point, 4.0, color)
		draw_string(font, screen_point + Vector2(-30, s + 30), "%dm" % int(distance), HORIZONTAL_ALIGNMENT_LEFT, -1, 26, color)
		return

	# Off-screen: place an arrow on the screen edge in the right direction.
	var direction := screen_point - center
	if behind:
		direction = -direction
	if direction.length() < 1.0:
		direction = Vector2.UP
	direction = direction.normalized()
	var half := center - Vector2(MARGIN, MARGIN)
	var edge_scale := minf(half.x / maxf(absf(direction.x), 0.001), half.y / maxf(absf(direction.y), 0.001))
	var edge_point := center + direction * edge_scale
	var side := Vector2(-direction.y, direction.x)
	var arrow := PackedVector2Array([
		edge_point + direction * 30.0,
		edge_point - direction * 14.0 + side * 22.0,
		edge_point - direction * 14.0 - side * 22.0,
	])
	draw_colored_polygon(arrow, color)
	draw_string(font, edge_point - direction * 50.0 - Vector2(24, -8), "%dm" % int(distance), HORIZONTAL_ALIGNMENT_LEFT, -1, 24, color)
