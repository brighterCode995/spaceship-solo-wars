class_name HUD
extends CanvasLayer
## Heads-up display: hull health, objective, kill counter, timer, crosshair,
## enemy markers, on-screen touch controls and the end-of-level overlays.

signal retry_pressed
signal menu_pressed

var goal_position: Vector3 = Vector3.ZERO:
	set(value):
		goal_position = value
		if _markers != null:
			_markers.goal_position = value

var goal_visible: bool = false:
	set(value):
		goal_visible = value
		if _markers != null:
			_markers.goal_visible = value

var _player: PlayerShip
var _root: Control
var _touch: TouchControls
var _markers: MarkerLayer
var _health_bar: ProgressBar
var _health_label: Label
var _objective_label: Label
var _kills_label: Label
var _time_label: Label
var _message_label: Label
var _countdown_label: Label
var _loading_label: Label
var _warning_label: Label
var _flash: ColorRect
var _overlay: Control
var _message_tween: Tween


func _init() -> void:
	layer = 10


func _ready() -> void:
	_root = Control.new()
	_full_rect(_root)
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.theme = UITheme.build()
	add_child(_root)

	_markers = MarkerLayer.new()
	_full_rect(_markers)
	_root.add_child(_markers)

	_build_crosshair()
	_build_top_bar()
	_build_center_labels()

	_flash = ColorRect.new()
	_full_rect(_flash)
	_flash.color = Color(1.0, 0.1, 0.05, 0.0)
	_flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(_flash)

	_touch = TouchControls.new()
	_full_rect(_touch)
	_root.add_child(_touch)


func setup(player: PlayerShip) -> void:
	_player = player
	player.health_changed.connect(_on_health_changed)
	_update_health(player.health, player.max_health)


func _process(_delta: float) -> void:
	if _player == null or _touch == null:
		return
	_player.touch_steer = _touch.steer
	_player.touch_fire = _touch.firing
	_warning_label.visible = _player.near_bounds and not _player.is_dead()


# --- Public API ---------------------------------------------------------------

func set_objective(text: String) -> void:
	_objective_label.text = text


func set_kills(kills: int, total: int) -> void:
	_kills_label.text = "ENEMIES  %d / %d" % [kills, total]


func set_time(seconds: float) -> void:
	_time_label.text = "TIME  " + format_time(seconds)


func set_countdown(text: String) -> void:
	_countdown_label.text = text


func show_loading(value: bool) -> void:
	_loading_label.visible = value


func show_message(text: String, duration: float = 3.0) -> void:
	_message_label.text = text
	_message_label.modulate.a = 1.0
	if _message_tween != null:
		_message_tween.kill()
	_message_tween = create_tween()
	_message_tween.tween_interval(duration)
	_message_tween.tween_property(_message_label, "modulate:a", 0.0, 0.6)


func show_game_over() -> void:
	_show_overlay("GAME OVER", "Your ship was destroyed.", [
		{"text": "CONTINUE", "callback": func() -> void: retry_pressed.emit()},
		{"text": "QUIT", "callback": func() -> void: menu_pressed.emit()},
	])


func show_level_complete(seconds: float) -> void:
	_show_overlay("LEVEL COMPLETE", "Total time:  " + format_time(seconds), [
		{"text": "REPLAY LEVEL", "callback": func() -> void: retry_pressed.emit()},
		{"text": "MAIN MENU", "callback": func() -> void: menu_pressed.emit()},
	])


static func format_time(seconds: float) -> String:
	return "%02d:%04.1f" % [floori(seconds / 60.0), fmod(seconds, 60.0)]


# --- Building the UI -------------------------------------------------------------

func _build_crosshair() -> void:
	var crosshair := TextureRect.new()
	crosshair.texture = load("res://assets/ui/crosshair.png") as Texture2D
	crosshair.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	crosshair.stretch_mode = TextureRect.STRETCH_SCALE
	crosshair.anchor_left = 0.5
	crosshair.anchor_right = 0.5
	crosshair.anchor_top = 0.5
	crosshair.anchor_bottom = 0.5
	crosshair.offset_left = -36
	crosshair.offset_right = 36
	crosshair.offset_top = -36
	crosshair.offset_bottom = 36
	crosshair.modulate = Color(0.5, 1.0, 1.0, 0.85)
	crosshair.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(crosshair)


func _build_top_bar() -> void:
	# Health (top-left).
	var health_box := VBoxContainer.new()
	health_box.position = Vector2(40, 28)
	health_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(health_box)
	_health_label = _make_label("HULL", 34)
	health_box.add_child(_health_label)
	_health_bar = ProgressBar.new()
	_health_bar.custom_minimum_size = Vector2(440, 30)
	_health_bar.show_percentage = false
	_health_bar.max_value = 100.0
	_health_bar.value = 100.0
	_health_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	health_box.add_child(_health_bar)

	# Objective and kill counter (top-centre).
	var center_box := VBoxContainer.new()
	center_box.anchor_left = 0.0
	center_box.anchor_right = 1.0
	center_box.offset_top = 24
	center_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(center_box)
	_objective_label = _make_label("", 40)
	_objective_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	center_box.add_child(_objective_label)
	_kills_label = _make_label("", 36)
	_kills_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_kills_label.modulate = Color(1.0, 0.8, 0.5)
	center_box.add_child(_kills_label)

	# Timer (top-right).
	_time_label = _make_label("TIME  00:00.0", 40)
	_time_label.anchor_left = 1.0
	_time_label.anchor_right = 1.0
	_time_label.offset_left = -420
	_time_label.offset_right = -40
	_time_label.offset_top = 28
	_time_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_root.add_child(_time_label)


func _build_center_labels() -> void:
	_message_label = _make_label("", 48)
	_anchor_center_label(_message_label, -260)
	_message_label.modulate.a = 0.0
	_message_label.modulate = Color(0.5, 1.0, 1.0, 0.0)

	_countdown_label = _make_label("", 150)
	_anchor_center_label(_countdown_label, -110)

	_loading_label = _make_label("PREPARING AI NAVIGATION...", 56)
	_anchor_center_label(_loading_label, -40)
	_loading_label.visible = false

	_warning_label = _make_label("LEAVING MISSION AREA - TURN BACK", 44)
	_anchor_center_label(_warning_label, 150)
	_warning_label.modulate = Color(1.0, 0.4, 0.3)
	_warning_label.visible = false


func _anchor_center_label(label: Label, y_offset: float) -> void:
	label.anchor_left = 0.0
	label.anchor_right = 1.0
	label.anchor_top = 0.5
	label.anchor_bottom = 0.5
	label.offset_top = y_offset
	label.offset_bottom = y_offset + 160
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_root.add_child(label)


func _make_label(text: String, font_size: int) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", font_size)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return label


func _full_rect(control: Control) -> void:
	control.anchor_right = 1.0
	control.anchor_bottom = 1.0
	control.offset_left = 0.0
	control.offset_top = 0.0
	control.offset_right = 0.0
	control.offset_bottom = 0.0


func _show_overlay(title: String, subtitle: String, buttons: Array[Dictionary]) -> void:
	if _overlay != null:
		_overlay.queue_free()
	_touch.set_enabled(false)

	_overlay = Control.new()
	_full_rect(_overlay)
	_root.add_child(_overlay)

	var dim := ColorRect.new()
	_full_rect(dim)
	dim.color = Color(0.0, 0.0, 0.05, 0.65)
	_overlay.add_child(dim)

	var center := CenterContainer.new()
	_full_rect(center)
	_overlay.add_child(center)

	var panel := PanelContainer.new()
	center.add_child(panel)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 26)
	panel.add_child(box)

	var title_label := _make_label(title, 84)
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(title_label)
	var subtitle_label := _make_label(subtitle, 48)
	subtitle_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	subtitle_label.modulate = Color(0.7, 0.95, 1.0)
	box.add_child(subtitle_label)

	for entry in buttons:
		var button := Button.new()
		button.text = entry["text"]
		button.custom_minimum_size = Vector2(560, 104)
		var callback: Callable = entry["callback"]
		button.pressed.connect(func() -> void:
			AudioManager.play_sfx("ui_click")
			callback.call()
		)
		box.add_child(button)


# --- Signals -----------------------------------------------------------------------

func _on_health_changed(current: float, maximum: float) -> void:
	_update_health(current, maximum)
	_flash.color.a = 0.35
	create_tween().tween_property(_flash, "color:a", 0.0, 0.35)


func _update_health(current: float, maximum: float) -> void:
	_health_bar.max_value = maximum
	_health_bar.value = current
	_health_label.text = "HULL  %d / %d" % [int(current), int(maximum)]
	var ratio := current / maxf(maximum, 1.0)
	var fill_color := Color(0.3, 1.0, 0.45).lerp(Color(1.0, 0.25, 0.2), 1.0 - ratio)
	var fill := StyleBoxFlat.new()
	fill.bg_color = fill_color
	fill.set_corner_radius_all(8)
	_health_bar.add_theme_stylebox_override("fill", fill)
