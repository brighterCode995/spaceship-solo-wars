class_name LevelBase
extends Node3D
## Base class for both levels.
##
## Builds the world in code, bakes the Flight Navigation 3D voxel octree at
## start-up, spawns the player and enemies and runs the objective:
## destroy every enemy, then fly through the goal ring.
## Subclasses override _configure(), _build_environment(), _build_world()
## and _get_enemy_region().

enum Phase { LOADING, COUNTDOWN, PLAYING, GAME_OVER, COMPLETE }
enum ColliderKind { SPHERE, CYLINDER, BOX }

const NAV_SCENE: PackedScene = preload("res://src/flight_navigation_3d.tscn")
const VOXELIZER_SCENE: PackedScene = preload("res://src/svo_voxelizer.tscn")
const TARGET_SCENE: PackedScene = preload("res://src/voxelization_target.tscn")
const GREEDY_A_STAR_SCRIPT: GDScript = preload("res://src/greedy_a_star.gd")
const PATH_COOLDOWN_MS := 250
const BOUNDS_MARGIN := 12.0

# Level settings (overridden in _configure()).
var level_size: float = 400.0
var nav_layers: int = 6
var volume_center: Vector3 = Vector3.ZERO
var player_start: Vector3 = Vector3(0, 0, 165)
var goal_position: Vector3 = Vector3(0, 0, -165)
var enemy_count: int = 5
var enemy_definition: Dictionary = {}
var floor_y: float = -INF
var ceiling_y: float = INF
var dust_color: Color = Color(0.8, 0.9, 1.0)

var rng: RandomNumberGenerator = RandomNumberGenerator.new()
var player: PlayerShip
var camera: FollowCamera
var hud: HUD
var goal_ring: GoalRing

var _bounds: AABB
var _phase: Phase = Phase.LOADING
var _nav: Node
var _nav_ready: bool = false
var _next_path_ms: int = 0
var _obstacles: Array[Dictionary] = []
var _kills: int = 0
var _elapsed: float = 0.0
var _goal_active: bool = false


func _ready() -> void:
	_configure()
	_compute_bounds()
	_build_environment()
	_build_world()
	_spawn_player()
	_spawn_goal()
	_create_hud()
	AudioManager.play_music("game")

	hud.show_loading(true)
	await get_tree().process_frame
	await _build_navigation()
	hud.show_loading(false)

	_spawn_enemies()
	hud.set_kills(0, enemy_count)
	await _run_countdown()
	_begin_play()


func _process(delta: float) -> void:
	if _phase != Phase.PLAYING:
		return
	_elapsed += delta
	hud.set_time(_elapsed)
	if _goal_active and goal_ring.contains(player.global_position):
		_complete_level()


# --- Interface for enemies ----------------------------------------------------

func get_play_bounds() -> AABB:
	return _bounds


func can_request_path() -> bool:
	return _nav_ready and Time.get_ticks_msec() >= _next_path_ms


## Path from the Flight Navigation 3D plugin (empty when none was found).
func request_path(from: Vector3, to: Vector3) -> PackedVector3Array:
	_next_path_ms = Time.get_ticks_msec() + PATH_COOLDOWN_MS
	if not _nav_ready:
		return PackedVector3Array()
	return _nav.find_path(from, to)


# --- Virtual functions -----------------------------------------------------------

func _configure() -> void:
	pass


func _build_environment() -> void:
	pass


func _build_world() -> void:
	pass


func _get_enemy_region() -> AABB:
	return AABB(Vector3(-100, -50, -100), Vector3(200, 100, 200))


# --- Setup helpers -----------------------------------------------------------

func _compute_bounds() -> void:
	var half := Vector3.ONE * (level_size * 0.5 - BOUNDS_MARGIN)
	var low := volume_center - half
	var high := volume_center + half
	low.y = maxf(low.y, floor_y)
	high.y = minf(high.y, ceiling_y)
	_bounds = AABB(low, high - low)


func make_world_environment(environment: Environment) -> void:
	var world_environment := WorldEnvironment.new()
	world_environment.environment = environment
	add_child(world_environment)


func make_sun(rotation_deg: Vector3, color: Color, energy: float, shadows: bool) -> void:
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = rotation_deg
	sun.light_color = color
	sun.light_energy = energy
	sun.shadow_enabled = shadows
	sun.directional_shadow_max_distance = 220.0
	add_child(sun)


## Instantiates a model scaled so that its longest side (or height) matches
## [param target_size]. Returns {model, aabb, scale}.
func instantiate_scaled(path: String, target_size: float, use_height: bool = false) -> Dictionary:
	var model := (load(path) as PackedScene).instantiate() as Node3D
	var aabb := Effects.get_model_aabb(model)
	var reference := aabb.size.y if use_height else aabb.get_longest_axis_size()
	var model_scale := target_size / maxf(reference, 0.001)
	model.scale = Vector3.ONE * model_scale
	return {"model": model, "aabb": aabb, "scale": model_scale}


## Visual-only prop (no collision, not used for navigation).
func add_decor(path: String, spot: Vector3, target_size: float, yaw: float = 0.0, use_height: bool = false) -> void:
	var data := instantiate_scaled(path, target_size, use_height)
	var model: Node3D = data["model"]
	model.position = spot
	model.rotation.y = yaw
	add_child(model)


## Solid obstacle: model + static collider + navigation voxelization target.
func add_obstacle(
	path: String,
	spot: Vector3,
	target_size: float,
	kind: ColliderKind,
	use_height: bool = false,
	grounded: bool = false,
	yaw: float = 0.0
) -> void:
	var data := instantiate_scaled(path, target_size, use_height)
	var model: Node3D = data["model"]
	var aabb: AABB = data["aabb"]
	var model_scale: float = data["scale"]

	var body := StaticBody3D.new()
	body.collision_layer = 1
	body.collision_mask = 0
	if grounded:
		spot.y -= aabb.position.y * model_scale
	body.position = spot
	body.rotation.y = yaw
	body.add_child(model)

	var shape := CollisionShape3D.new()
	var size := aabb.size * model_scale
	match kind:
		ColliderKind.SPHERE:
			var sphere := SphereShape3D.new()
			sphere.radius = size[size.max_axis_index()] * 0.5 * 0.8
			shape.shape = sphere
		ColliderKind.CYLINDER:
			var cylinder := CylinderShape3D.new()
			cylinder.height = size.y
			cylinder.radius = maxf(size.x, size.z) * 0.5 * 0.6
			shape.shape = cylinder
		ColliderKind.BOX:
			var box := BoxShape3D.new()
			box.size = size * 0.85
			shape.shape = box
	shape.position = aabb.get_center() * model_scale
	body.add_child(shape)
	body.add_child(_make_voxel_target())
	add_child(body)

	_obstacles.append({
		"position": spot + shape.position.rotated(Vector3.UP, yaw),
		"radius": size[size.max_axis_index()] * 0.5,
	})


## A solid box that only exists for collision and navigation (e.g. the ground).
func add_collision_box(box_position: Vector3, size: Vector3) -> void:
	var body := StaticBody3D.new()
	body.collision_layer = 1
	body.collision_mask = 0
	body.position = box_position
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = size
	shape.shape = box
	body.add_child(shape)
	body.add_child(_make_voxel_target())
	add_child(body)


## Random position inside [param region] that is clear of every obstacle.
func find_free_position(region: AABB, clearance: float, avoid: Array[Vector3] = []) -> Vector3:
	for attempt in 60:
		var candidate := region.position + Vector3(
			rng.randf() * region.size.x,
			rng.randf() * region.size.y,
			rng.randf() * region.size.z
		)
		if _is_position_free(candidate, clearance, avoid):
			return candidate
	return region.get_center()


## Marks a collider for the navigation bake (coarser shapes keep the bake fast).
func _make_voxel_target() -> Node:
	var target := TARGET_SCENE.instantiate()
	target.radial_segments = 10
	target.rings = 5
	return target


func _is_position_free(candidate: Vector3, clearance: float, avoid: Array[Vector3]) -> bool:
	if candidate.distance_to(player_start) < 50.0 or candidate.distance_to(goal_position) < 50.0:
		return false
	for obstacle in _obstacles:
		var obstacle_position: Vector3 = obstacle["position"]
		var radius: float = obstacle["radius"]
		if candidate.distance_to(obstacle_position) < radius + clearance:
			return false
	for point in avoid:
		if candidate.distance_to(point) < clearance * 2.0:
			return false
	return true


# --- Navigation (Flight Navigation 3D plugin) ------------------------------------

## Bakes the sparse voxel octree from every VoxelizationTarget in the level.
## If baking fails the game still works: enemies fall back to direct pursuit.
func _build_navigation() -> void:
	_nav = NAV_SCENE.instantiate()
	_nav.size = Vector3.ONE * level_size
	_nav.position = volume_center
	add_child(_nav)

	var voxelizer := VOXELIZER_SCENE.instantiate()
	voxelizer.layer_count = nav_layers
	_nav.add_child(voxelizer)
	_nav.pathfinder = GREEDY_A_STAR_SCRIPT.new()

	await _nav.build_navigation()
	_nav_ready = _nav.sparse_voxel_octree != null
	if not _nav_ready:
		push_warning("Flight navigation bake failed - enemies will use direct pursuit.")
	_nav.visible = false


# --- Spawning ---------------------------------------------------------------

func _spawn_player() -> void:
	player = PlayerShip.new()
	player.setup(GameData.get_selected_ship())
	player.invulnerable = true # safe until the countdown ends
	player.bounds = _bounds
	add_child(player)
	player.global_position = player_start
	player.died.connect(_on_player_died)

	camera = FollowCamera.new()
	camera.target = player
	add_child(camera)
	camera.snap_to_target()

	var dust := Effects.make_dust(dust_color, Vector3(60, 40, 60), 140)
	camera.add_child(dust)
	dust.position = Vector3(0, 0, -25)
	dust.emitting = true


func _spawn_goal() -> void:
	goal_ring = GoalRing.new()
	add_child(goal_ring)
	goal_ring.global_position = goal_position


func _spawn_enemies() -> void:
	var placed: Array[Vector3] = []
	for i in enemy_count:
		var spawn_position := find_free_position(_get_enemy_region(), 16.0, placed)
		placed.append(spawn_position)
		var enemy := EnemyShip.new()
		enemy.setup(self, player, enemy_definition)
		add_child(enemy)
		enemy.global_position = spawn_position
		enemy.destroyed.connect(_on_enemy_destroyed)


func _create_hud() -> void:
	hud = HUD.new()
	add_child(hud)
	hud.setup(player)
	hud.goal_position = goal_position
	hud.set_objective("DESTROY ALL ENEMY FIGHTERS")
	hud.retry_pressed.connect(_on_retry_pressed)
	hud.menu_pressed.connect(_on_menu_pressed)


# --- Game flow ------------------------------------------------------------------

func _run_countdown() -> void:
	_phase = Phase.COUNTDOWN
	for step in ["3", "2", "1", "GO!"]:
		hud.set_countdown(step)
		await get_tree().create_timer(0.8).timeout
	hud.set_countdown("")


func _begin_play() -> void:
	_phase = Phase.PLAYING
	_elapsed = 0.0
	player.controls_enabled = true
	player.invulnerable = false


func _on_enemy_destroyed(_enemy: EnemyShip) -> void:
	_kills += 1
	hud.set_kills(_kills, enemy_count)
	if _kills >= enemy_count and not _goal_active:
		_goal_active = true
		goal_ring.set_active(true)
		hud.goal_visible = true
		hud.set_objective("FLY THROUGH THE GOAL RING")
		hud.show_message("ALL ENEMIES DOWN - HEAD TO THE GOAL!")
		AudioManager.play_sfx("goal_active")


func _on_player_died() -> void:
	if _phase == Phase.COMPLETE:
		return
	_phase = Phase.GAME_OVER
	await get_tree().create_timer(1.4).timeout
	hud.show_game_over()


func _complete_level() -> void:
	_phase = Phase.COMPLETE
	player.controls_enabled = false
	player.invulnerable = true
	get_tree().call_group("enemies", "set_physics_process", false)
	AudioManager.play_sfx("level_complete")
	hud.show_level_complete(_elapsed)


func _on_retry_pressed() -> void:
	get_tree().reload_current_scene()


func _on_menu_pressed() -> void:
	get_tree().change_scene_to_file(GameData.MAIN_MENU_SCENE)
