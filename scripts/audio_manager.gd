extends Node
## Audio helper (autoload "AudioManager"): music playback and pooled sound effects.
##
## Sound effects: Kenney "Sci-fi Sounds" and "Impact Sounds" (CC0).
## Music: "8-Bit Video Game Music" by Florian Stracker.

const SFX_PATHS := {
	"laser_player": "res://assets/audio/sfx/laserSmall_003.ogg",
	"laser_enemy": "res://assets/audio/sfx/laserRetro_001.ogg",
	"explosion": "res://assets/audio/sfx/explosionCrunch_000.ogg",
	"player_explosion": "res://assets/audio/sfx/lowFrequency_explosion_000.ogg",
	"impact": "res://assets/audio/sfx/impactMetal_medium_000.ogg",
	"impact_heavy": "res://assets/audio/sfx/impactMetal_heavy_000.ogg",
	"goal_active": "res://assets/audio/sfx/forceField_000.ogg",
	"level_complete": "res://assets/audio/sfx/forceField_002.ogg",
	"ui_click": "res://assets/audio/sfx/ui_click.ogg",
	"engine": "res://assets/audio/sfx/spaceEngineLow_001.ogg",
}

const MUSIC_PATHS := {
	"menu": "res://assets/audio/music/menu_music.ogg",
	"game": "res://assets/audio/music/game_music.ogg",
}

const POOL_SIZE := 12

var _sfx_cache: Dictionary = {}
var _players: Array[AudioStreamPlayer] = []
var _next_player: int = 0
var _music_player: AudioStreamPlayer
var _current_music: String = ""


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_music_player = AudioStreamPlayer.new()
	_music_player.volume_db = -10.0
	add_child(_music_player)
	for i in POOL_SIZE:
		var player := AudioStreamPlayer.new()
		add_child(player)
		_players.append(player)


func play_music(key: String) -> void:
	if key == _current_music and _music_player.playing:
		return
	_current_music = key
	var stream := load(MUSIC_PATHS[key]) as AudioStream
	if stream is AudioStreamOggVorbis:
		(stream as AudioStreamOggVorbis).loop = true
	_music_player.stream = stream
	_music_player.play()


func play_sfx(key: String, volume_db: float = 0.0, pitch: float = 1.0) -> void:
	var stream := _get_stream(key)
	if stream == null:
		return
	var player := _players[_next_player]
	_next_player = (_next_player + 1) % POOL_SIZE
	player.stream = stream
	player.volume_db = volume_db
	player.pitch_scale = pitch
	player.play()


## Creates a looping player (used for the engine hum). The caller owns the node.
func create_loop_player(key: String, volume_db: float) -> AudioStreamPlayer:
	var stream := _get_stream(key)
	var player := AudioStreamPlayer.new()
	if stream is AudioStreamOggVorbis:
		(stream as AudioStreamOggVorbis).loop = true
	player.stream = stream
	player.volume_db = volume_db
	return player


func _get_stream(key: String) -> AudioStream:
	if not _sfx_cache.has(key):
		_sfx_cache[key] = load(SFX_PATHS[key])
	return _sfx_cache[key] as AudioStream
