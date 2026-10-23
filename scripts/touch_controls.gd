class_name TouchControls
extends Control
## On-screen touch controls: a virtual joystick (left) and a FIRE button (right).
##
## Both are drawn with images so the player can see where to touch. Multi-touch
## is supported: each control remembers the finger (touch index) that owns it.
## On desktop, mouse clicks are emulated as touches (see project settings).

const PAD_SIZE := 320.0
const NUB_SIZE := 140.0
const FIRE_SIZE := 230.0
const EDGE_MARGIN := 80.0
const DEAD_ZONE := 0.12

## Joystick deflection, each axis -1..1 (up on screen is negative y).
var steer: Vector2 = Vector2.ZERO
var firing: bool = false

var _pad: TextureRect
var _nub: TextureRect
var _fire: TextureRect
var _steer_label: Label
var _fire_label: Label
var _stick_index: int = -1
var _fire_index: int = -1
var _enabled: bool = true


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_pad = _make_image("res://assets/ui/joystick_pad.png", PAD_SIZE, 0.55)
	_nub = _make_image("res://assets/ui/joystick_nub.png", NUB_SIZE, 0.85)
	_fire = _make_image("res://assets/ui/fire_button.png", FIRE_SIZE, 0.6)
	_fire.modulate = Color(1.0, 0.45, 0.4, 0.65)
	_steer_label = _make_label("STEER")
	_fire_label = _make_label("FIRE")
	resized.connect(_layout)
	_layout()


func set_enabled(value: bool) -> void:
	_enabled = value
	visible = value
	if not value:
		_release_all()


func _input(event: InputEvent) -> void:
	if not _enabled:
		return
	if event is InputEventScreenTouch:
		var touch := make_input_local(event) as InputEventScreenTouch
		if touch.pressed:
			_on_press(touch.index, touch.position)
		else:
			_on_release(touch.index)
	elif event is InputEventScreenDrag:
		var drag := make_input_local(event) as InputEventScreenDrag
		if drag.index == _stick_index:
			_update_stick(drag.position)


func _on_press(index: int, point: Vector2) -> void:
	if _stick_index == -1 and point.distance_to(_pad_center()) < PAD_SIZE * 0.75:
		_stick_index = index
		_update_stick(point)
	elif _fire_index == -1 and point.distance_to(_fire_center()) < FIRE_SIZE * 0.75:
		_fire_index = index
		firing = true
		_fire.modulate.a = 1.0


func _on_release(index: int) -> void:
	if index == _stick_index:
		_stick_index = -1
		steer = Vector2.ZERO
		_nub.position = _pad_center() - Vector2.ONE * NUB_SIZE * 0.5
	elif index == _fire_index:
		_fire_index = -1
		firing = false
		_fire.modulate.a = 0.65


func _release_all() -> void:
	_stick_index = -1
	_fire_index = -1
	steer = Vector2.ZERO
	firing = false


func _update_stick(point: Vector2) -> void:
	var offset := (point - _pad_center()) / (PAD_SIZE * 0.5)
	if offset.length() > 1.0:
		offset = offset.normalized()
	steer = offset if offset.length() > DEAD_ZONE else Vector2.ZERO
	_nub.position = _pad_center() + offset * PAD_SIZE * 0.4 - Vector2.ONE * NUB_SIZE * 0.5


func _pad_center() -> Vector2:
	return Vector2(EDGE_MARGIN + PAD_SIZE * 0.5, size.y - EDGE_MARGIN - PAD_SIZE * 0.5)


func _fire_center() -> Vector2:
	return Vector2(size.x - EDGE_MARGIN - FIRE_SIZE * 0.5, size.y - EDGE_MARGIN - FIRE_SIZE * 0.5)


func _layout() -> void:
	_pad.position = _pad_center() - Vector2.ONE * PAD_SIZE * 0.5
	_nub.position = _pad_center() - Vector2.ONE * NUB_SIZE * 0.5
	_fire.position = _fire_center() - Vector2.ONE * FIRE_SIZE * 0.5
	_steer_label.position = _pad_center() + Vector2(-80, -PAD_SIZE * 0.5 - 56)
	_fire_label.position = _fire_center() + Vector2(-50, -28)


func _make_image(path: String, image_size: float, alpha: float) -> TextureRect:
	var rect := TextureRect.new()
	rect.texture = load(path) as Texture2D
	rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	rect.stretch_mode = TextureRect.STRETCH_SCALE
	rect.size = Vector2.ONE * image_size
	rect.custom_minimum_size = Vector2.ONE * image_size
	rect.modulate.a = alpha
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(rect)
	return rect


func _make_label(text: String) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", 44)
	label.modulate.a = 0.9
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(label)
	return label
