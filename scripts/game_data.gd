extends Node
## Global game state (autoload "GameData").
##
## Holds the ship and level definitions, the player's current selection and
## registers the keyboard input actions used for desktop testing.

const MAIN_MENU_SCENE := "res://scenes/main_menu.tscn"

## The Quaternius ship models have their nose on +Z. Godot's forward is -Z,
## so models are turned by this angle. Change to 0.0 if ships fly backwards.
const MODEL_YAW := PI

const SHIPS: Array[Dictionary] = [
	{
		"name": "BOB",
		"role": "Scout - nimble and quick to accelerate",
		"model": "res://assets/ships/Bob/Bob.gltf",
		"scale": 0.32,
		"max_speed": 45.0,
		"acceleration": 28.0,
		"turn_rate": 1.9,
		"health": 100.0,
	},
	{
		"name": "STRIKER",
		"role": "Interceptor - the fastest ship, slow to recover",
		"model": "res://assets/ships/Striker/Striker.gltf",
		"scale": 0.36,
		"max_speed": 62.0,
		"acceleration": 18.0,
		"turn_rate": 1.6,
		"health": 90.0,
	},
	{
		"name": "SPITFIRE",
		"role": "Gunship - tough hull, heavy handling",
		"model": "res://assets/ships/Spitfire/Spitfire.gltf",
		"scale": 0.32,
		"max_speed": 38.0,
		"acceleration": 12.0,
		"turn_rate": 1.4,
		"health": 150.0,
	},
]

const LEVELS: Array[Dictionary] = [
	{
		"name": "ASTEROID BELT",
		"scene": "res://scenes/level_space.tscn",
		"blurb": "Deep space.\nWeave through a dense asteroid field and destroy the raiders.",
	},
	{
		"name": "CANYON RUN",
		"scene": "res://scenes/level_planet.tscn",
		"blurb": "Planet surface.\nSkim the canyon between towering rocks and hunt the patrol fighters.",
	},
]

## Enemy fighter appearance per level (same behaviour, different model).
const ENEMY_SPACE := {
	"model": "res://assets/ships/Zenith/Zenith.gltf",
	"texture": "res://assets/ships/Zenith/Zenith_Red.png",
	"scale": 0.32,
}
const ENEMY_PLANET := {
	"model": "res://assets/ships/Omen/Omen.gltf",
	"texture": "res://assets/ships/Omen/Omen_Red.png",
	"scale": 0.30,
}

var selected_ship: int = 0
var selected_level: int = 0


func _ready() -> void:
	_register_input_actions()


func get_selected_ship() -> Dictionary:
	return SHIPS[selected_ship]


func get_selected_level() -> Dictionary:
	return LEVELS[selected_level]


## Keyboard bindings so the game can be tested on a desktop without a phone.
func _register_input_actions() -> void:
	var bindings: Dictionary = {
		"steer_left": [KEY_A, KEY_LEFT],
		"steer_right": [KEY_D, KEY_RIGHT],
		"steer_up": [KEY_W, KEY_UP],
		"steer_down": [KEY_S, KEY_DOWN],
		"fire": [KEY_SPACE],
	}
	for action in bindings:
		if not InputMap.has_action(action):
			InputMap.add_action(action)
		for key in bindings[action]:
			var event := InputEventKey.new()
			event.physical_keycode = key as Key
			InputMap.action_add_event(action, event)
