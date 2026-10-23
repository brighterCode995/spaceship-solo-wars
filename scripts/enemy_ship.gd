class_name EnemyShip
extends CharacterBody3D
## Enemy fighter driven by a finite state machine (FSM) and steering behaviours.
##
## States:
##   WANDER - the player is far away: drift around using the wander behaviour.
##   CHASE  - the player is close enough to be chased: follow a path found with
##            the Flight Navigation 3D plugin (path following), or pursue
##            directly when there is a clear line of sight.
##   ATTACK - the player is in weapon range: pursue, orbit and shoot lasers.
## Obstacle avoidance is blended into every state.

signal destroyed(enemy: EnemyShip)

enum State { WANDER, CHASE, ATTACK, DEAD }

const LASER_HIT_MASK := 3 ## world (1) + player (2)
const WANDER_DISTANCE := 30.0
const WANDER_RADIUS := 12.0
const WANDER_JITTER := 14.0
const PATH_REFRESH_TIME := 1.2
const WAYPOINT_REACH_RADIUS := 6.0
const MIN_ATTACK_DISTANCE := 30.0

var max_speed: float = 27.0
var acceleration: float = 14.0
var health: float = 30.0
var detect_range: float = 150.0
var lose_range: float = 200.0
var attack_range: float = 80.0
var fire_interval: float = 1.4
var laser_damage: float = 7.0
var laser_speed: float = 85.0

var _state: State = State.WANDER
var _level: Node
var _player: PlayerShip
var _definition: Dictionary = {}
var _current_velocity: Vector3 = Vector3.ZERO
var _wander_offset: Vector3 = Vector3.FORWARD * WANDER_RADIUS
var _path_follower: PathFollower = PathFollower.new()
var _path_timer: float = 0.0
var _fire_timer: float = 0.0


func setup(level: Node, player: PlayerShip, definition: Dictionary) -> void:
	_level = level
	_player = player
	_definition = definition


func get_state() -> State:
	return _state


func _ready() -> void:
	collision_layer = 4
	collision_mask = 1
	motion_mode = CharacterBody3D.MOTION_MODE_FLOATING
	add_to_group("enemies")

	var shape := CollisionShape3D.new()
	var sphere := SphereShape3D.new()
	sphere.radius = 1.8
	shape.shape = sphere
	add_child(shape)

	var model := (load(_definition["model"]) as PackedScene).instantiate() as Node3D
	model.scale = Vector3.ONE * float(_definition["scale"])
	model.rotation.y = GameData.MODEL_YAW
	add_child(model)
	_apply_red_texture(model, _definition["texture"])

	var trail := Effects.make_engine_trail(Color(1.0, 0.45, 0.2))
	trail.position = Vector3(0.0, 0.0, 1.4)
	add_child(trail)

	_wander_offset = _wander_offset.rotated(Vector3.UP, randf() * TAU)
	_fire_timer = randf() * fire_interval
	_path_timer = randf() * PATH_REFRESH_TIME
	# Start with a random heading so the fighters do not all fly the same way.
	rotation.y = randf() * TAU
	_current_velocity = -global_transform.basis.z * max_speed * 0.4


func _physics_process(delta: float) -> void:
	if _state == State.DEAD:
		return

	var to_player := Vector3.ZERO
	var distance := INF
	if _player != null and not _player.is_dead():
		to_player = _player.global_position - global_position
		distance = to_player.length()

	_update_state(distance)

	var desired := Vector3.ZERO
	match _state:
		State.WANDER:
			desired = _steer_wander(delta)
		State.CHASE:
			desired = _steer_chase(delta)
		State.ATTACK:
			desired = _steer_attack(to_player, distance)

	var forward := _current_velocity.normalized() if _current_velocity.length() > 1.0 else -global_transform.basis.z
	var look_ahead := clampf(_current_velocity.length() * 1.3, 14.0, 45.0)
	var avoidance := Steering.avoid_obstacles(self, forward, look_ahead, 1)
	desired = (desired + avoidance * max_speed * 1.8).limit_length(max_speed)

	_current_velocity = _current_velocity.move_toward(desired, acceleration * delta)
	velocity = _current_velocity
	move_and_slide()
	_face_direction(delta, to_player)

	if _state == State.ATTACK:
		_try_fire(delta, to_player, distance)


func take_damage(amount: float, _direction: Vector3 = Vector3.ZERO) -> void:
	if _state == State.DEAD:
		return
	health -= amount
	Effects.spawn_sparks(get_parent(), global_position)
	AudioManager.play_sfx("impact", -8.0)
	if _state == State.WANDER:
		_change_state(State.CHASE) # being shot alerts the enemy
	if health <= 0.0:
		_die()


# --- Finite state machine ---------------------------------------------------

func _update_state(distance: float) -> void:
	match _state:
		State.WANDER:
			if distance < detect_range:
				_change_state(State.CHASE)
		State.CHASE:
			if distance < attack_range:
				_change_state(State.ATTACK)
			elif distance > lose_range:
				_change_state(State.WANDER)
		State.ATTACK:
			if distance > attack_range * 1.3:
				_change_state(State.CHASE)


func _change_state(new_state: State) -> void:
	if new_state == _state:
		return
	_state = new_state
	_path_follower.clear()
	_path_timer = 0.0


# --- Steering per state -----------------------------------------------------

## Wander (steering behaviour 1): drift on a random sphere in front, stay in bounds.
func _steer_wander(delta: float) -> Vector3:
	var play_bounds: AABB = _level.get_play_bounds()
	if not play_bounds.grow(-30.0).has_point(global_position):
		return Steering.arrive(global_position, play_bounds.get_center(), max_speed * 0.6, 40.0)
	_wander_offset = Steering.wander_offset(_wander_offset, WANDER_JITTER, WANDER_RADIUS, delta)
	var forward := -global_transform.basis.z
	var direction := (forward * WANDER_DISTANCE + _wander_offset).normalized()
	return direction * max_speed * 0.5


## Path following (steering behaviour 2) with pursue (behaviour 3) as fallback.
func _steer_chase(delta: float) -> Vector3:
	_path_timer -= delta
	var clear_view := _has_line_of_sight()
	if clear_view and global_position.distance_to(_player.global_position) < 100.0:
		_path_follower.clear()
		return Steering.pursue(global_position, _player.global_position, _player.velocity, max_speed)

	if _path_timer <= 0.0 and _level.can_request_path():
		_path_timer = PATH_REFRESH_TIME
		var path: PackedVector3Array = _level.request_path(global_position, _player.global_position)
		_path_follower.set_path(path)

	if _path_follower.has_path():
		return _path_follower.get_desired_velocity(global_position, max_speed, WAYPOINT_REACH_RADIUS)
	return Steering.pursue(global_position, _player.global_position, _player.velocity, max_speed)


## Pursue + orbit: stay at a firing distance and circle the player.
func _steer_attack(to_player: Vector3, distance: float) -> Vector3:
	var direction := to_player.normalized()
	var orbit := direction.cross(Vector3.UP).normalized() * max_speed * 0.5
	if distance < MIN_ATTACK_DISTANCE:
		return -direction * max_speed * 0.6 + orbit
	var chase := Steering.pursue(global_position, _player.global_position, _player.velocity, max_speed)
	return chase * 0.7 + orbit


# --- Combat -------------------------------------------------------------------

func _try_fire(delta: float, to_player: Vector3, distance: float) -> void:
	_fire_timer -= delta
	if _fire_timer > 0.0 or distance > attack_range * 1.2:
		return
	var forward := -global_transform.basis.z
	if forward.dot(to_player.normalized()) < 0.95:
		return
	if not _has_line_of_sight():
		return
	_fire_timer = fire_interval * randf_range(0.8, 1.2)
	var muzzle := global_transform * Vector3(0.0, -0.2, -2.0)
	var travel_time := distance / laser_speed
	var aim_point := _player.global_position + _player.velocity * travel_time * 0.6
	aim_point += Vector3(randf_range(-2.0, 2.0), randf_range(-2.0, 2.0), randf_range(-2.0, 2.0))
	var direction := (aim_point - muzzle).normalized()
	Projectile.fire(get_parent(), muzzle, direction, laser_speed, laser_damage, LASER_HIT_MASK, Color(1.0, 0.25, 0.2), self)
	AudioManager.play_sfx("laser_enemy", -12.0, randf_range(0.9, 1.1))


func _die() -> void:
	_state = State.DEAD
	remove_from_group("enemies")
	Effects.spawn_explosion(get_parent(), global_position, 1.6)
	AudioManager.play_sfx("explosion", -3.0)
	destroyed.emit(self)
	queue_free()


# --- Helpers ----------------------------------------------------------------

func _has_line_of_sight() -> bool:
	if _player == null:
		return false
	var query := PhysicsRayQueryParameters3D.create(global_position, _player.global_position, 1)
	query.exclude = [get_rid()]
	return get_world_3d().direct_space_state.intersect_ray(query).is_empty()


func _face_direction(delta: float, to_player: Vector3) -> void:
	var direction := _current_velocity
	if _state == State.ATTACK:
		direction = to_player
	if direction.length() < 0.5:
		return
	direction = direction.normalized()
	var up := Vector3.UP if absf(direction.y) < 0.98 else Vector3.RIGHT
	var target_rotation := Basis.looking_at(direction, up).get_rotation_quaternion()
	quaternion = quaternion.slerp(target_rotation, 1.0 - exp(-5.0 * delta))


func _apply_red_texture(model: Node, texture_path: String) -> void:
	var material := StandardMaterial3D.new()
	material.albedo_texture = load(texture_path) as Texture2D
	material.metallic = 0.3
	material.roughness = 0.6
	var meshes: Array[MeshInstance3D] = []
	Effects.find_meshes(model, meshes)
	for mesh_instance in meshes:
		mesh_instance.material_override = material
