extends Control
## Main menu with three sub-menus: play, ship selection and level selection.
## Ship selection shows a rotating 3D preview and the ship's max speed and
## acceleration (plus handling and hull) as bars.

const STAT_MAX := {"max_speed": 70.0, "acceleration": 40.0, "turn_rate": 2.5, "health": 160.0}
const STAT_ROWS := [
	["max_speed", "MAX SPEED", "%d m/s"],
	["acceleration", "ACCELERATION", "%d m/s²"],
	["turn_rate", "HANDLING", "%.1f"],
	["health", "HULL", "%d"],
]

var _pages: Dictionary = {}
var _status_label: Label
var _preview_holder: Node3D
var _preview_model: Node3D
var _ship_name_label: Label
var _ship_role_label: Label
var _ship_select_button: Button
var _stat_bars: Dictionary = {}
var _stat_values: Dictionary = {}
var _level_buttons: Array[Button] = []
var _browsing_ship: int = 0


func _ready() -> void:
	theme = UITheme.build()
	AudioManager.play_music("menu")

	var stars := StarField.new()
	_full_rect(stars)
	add_child(stars)

	_pages["main"] = _build_main_page()
	_pages["ship"] = _build_ship_page()
	_pages["level"] = _build_level_page()
	for page in _pages.values():
		add_child(page)

	_browsing_ship = GameData.selected_ship
	_show_page("main")


func _process(delta: float) -> void:
	if _preview_holder != null and _pages["ship"].visible:
		_preview_holder.rotate_y(delta * 0.8)


# --- Pages -----------------------------------------------------------------------

func _build_main_page() -> Control:
	var page := _new_page()
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 22)
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	page.get_child(0).add_child(box)

	var title := _label("STAR STRIKE", 130)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.modulate = Color(0.45, 0.9, 1.0)
	box.add_child(title)
	var subtitle := _label("SPACE COMBAT", 44)
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(subtitle)

	_status_label = _label("", 36)
	_status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_status_label.modulate = Color(1.0, 0.85, 0.55)
	box.add_child(_status_label)

	box.add_child(_button("PLAY", _on_play_pressed))
	box.add_child(_button("SELECT SHIP", func() -> void: _open_ship_page()))
	box.add_child(_button("SELECT LEVEL", func() -> void: _show_page("level")))
	box.add_child(_button("QUIT", func() -> void: get_tree().quit()))
	return page


func _build_ship_page() -> Control:
	var page := _new_page()
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 40)
	page.get_child(0).add_child(row)

	row.add_child(_build_preview())

	var panel := PanelContainer.new()
	row.add_child(panel)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 14)
	panel.add_child(box)

	_ship_name_label = _label("", 80)
	_ship_name_label.modulate = Color(0.45, 0.9, 1.0)
	box.add_child(_ship_name_label)
	_ship_role_label = _label("", 30)
	_ship_role_label.custom_minimum_size = Vector2(760, 0)
	_ship_role_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(_ship_role_label)

	for row_def in STAT_ROWS:
		var stat_row := HBoxContainer.new()
		stat_row.add_theme_constant_override("separation", 16)
		var name_label := _label(row_def[1], 32)
		name_label.custom_minimum_size = Vector2(290, 0)
		stat_row.add_child(name_label)
		var bar := ProgressBar.new()
		bar.custom_minimum_size = Vector2(300, 30)
		bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		bar.show_percentage = false
		bar.max_value = STAT_MAX[row_def[0]]
		stat_row.add_child(bar)
		var value_label := _label("", 32)
		value_label.custom_minimum_size = Vector2(150, 0)
		stat_row.add_child(value_label)
		box.add_child(stat_row)
		_stat_bars[row_def[0]] = bar
		_stat_values[row_def[0]] = value_label

	var nav_row := HBoxContainer.new()
	nav_row.add_theme_constant_override("separation", 16)
	nav_row.add_child(_button("<  PREV", func() -> void: _browse_ship(-1)))
	nav_row.add_child(_button("NEXT  >", func() -> void: _browse_ship(1)))
	box.add_child(nav_row)
	_ship_select_button = _button("SELECT", _on_ship_confirmed)
	box.add_child(_ship_select_button)
	box.add_child(_button("BACK", func() -> void: _show_page("main")))
	return page


func _build_level_page() -> Control:
	var page := _new_page()
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 30)
	page.get_child(0).add_child(box)

	var title := _label("SELECT LEVEL", 90)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(title)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 40)
	box.add_child(row)
	for i in GameData.LEVELS.size():
		var level: Dictionary = GameData.LEVELS[i]
		var button := Button.new()
		button.text = "%s\n\n%s" % [level["name"], level["blurb"]]
		button.custom_minimum_size = Vector2(760, 380)
		button.add_theme_font_size_override("font_size", 38)
		var index := i
		button.pressed.connect(func() -> void:
			AudioManager.play_sfx("ui_click")
			GameData.selected_level = index
			_refresh_level_buttons()
			_refresh_status()
		)
		row.add_child(button)
		_level_buttons.append(button)

	box.add_child(_button("BACK", func() -> void: _show_page("main")))
	return page


func _build_preview() -> SubViewportContainer:
	var container := SubViewportContainer.new()
	container.stretch = true
	container.custom_minimum_size = Vector2(820, 700)

	var viewport := SubViewport.new()
	viewport.own_world_3d = true
	viewport.transparent_bg = true
	viewport.size = Vector2i(820, 700)
	container.add_child(viewport)

	var environment := Environment.new()
	environment.background_mode = Environment.BG_CLEAR_COLOR
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color(0.6, 0.65, 0.8)
	environment.ambient_light_energy = 0.8
	var world_environment := WorldEnvironment.new()
	world_environment.environment = environment
	viewport.add_child(world_environment)

	var light := DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-35, -30, 0)
	light.light_energy = 1.3
	viewport.add_child(light)

	var camera := Camera3D.new()
	camera.position = Vector3(0, 2.6, 9.5)
	camera.rotation_degrees = Vector3(-14, 0, 0)
	camera.fov = 45.0
	viewport.add_child(camera)

	_preview_holder = Node3D.new()
	viewport.add_child(_preview_holder)
	return container


# --- Behaviour -----------------------------------------------------------------

func _show_page(page_name: String) -> void:
	for key in _pages:
		(_pages[key] as Control).visible = (key == page_name)
	if page_name == "main":
		_refresh_status()
	elif page_name == "level":
		_refresh_level_buttons()


func _open_ship_page() -> void:
	_browsing_ship = GameData.selected_ship
	_show_ship(_browsing_ship)
	_show_page("ship")


func _browse_ship(step: int) -> void:
	AudioManager.play_sfx("ui_click")
	_browsing_ship = wrapi(_browsing_ship + step, 0, GameData.SHIPS.size())
	_show_ship(_browsing_ship)


func _show_ship(index: int) -> void:
	var ship: Dictionary = GameData.SHIPS[index]
	_ship_name_label.text = ship["name"] + ("   (SELECTED)" if index == GameData.selected_ship else "")
	_ship_role_label.text = ship["role"]
	for row_def in STAT_ROWS:
		var key: String = row_def[0]
		(_stat_bars[key] as ProgressBar).value = ship[key]
		(_stat_values[key] as Label).text = row_def[2] % ship[key]

	if _preview_model != null:
		_preview_model.queue_free()
	var model := (load(ship["model"]) as PackedScene).instantiate() as Node3D
	var aabb := Effects.get_model_aabb(model)
	var fit := 6.0 / maxf(aabb.get_longest_axis_size(), 0.001)
	model.scale = Vector3.ONE * fit
	model.position = -aabb.get_center() * fit
	_preview_holder.add_child(model)
	_preview_model = model


func _on_ship_confirmed() -> void:
	AudioManager.play_sfx("ui_click")
	GameData.selected_ship = _browsing_ship
	_show_ship(_browsing_ship)
	_show_page("main")


func _on_play_pressed() -> void:
	AudioManager.play_sfx("ui_click")
	get_tree().change_scene_to_file(GameData.get_selected_level()["scene"])


func _refresh_status() -> void:
	_status_label.text = "Ship: %s     Level: %s" % [
		GameData.get_selected_ship()["name"],
		GameData.get_selected_level()["name"],
	]


func _refresh_level_buttons() -> void:
	for i in _level_buttons.size():
		_level_buttons[i].modulate = Color(0.6, 1.0, 0.7) if i == GameData.selected_level else Color.WHITE


# --- UI helpers -----------------------------------------------------------------

func _new_page() -> Control:
	var page := Control.new()
	_full_rect(page)
	var center := CenterContainer.new()
	_full_rect(center)
	page.add_child(center)
	return page


func _button(text: String, callback: Callable) -> Button:
	var button := Button.new()
	button.text = text
	button.custom_minimum_size = Vector2(620, 100)
	button.pressed.connect(func() -> void:
		if text != "SELECT" and text != "PLAY":
			AudioManager.play_sfx("ui_click")
		callback.call()
	)
	return button


func _label(text: String, font_size: int) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", font_size)
	return label


func _full_rect(control: Control) -> void:
	control.anchor_right = 1.0
	control.anchor_bottom = 1.0
