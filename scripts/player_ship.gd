class_name PlayerShip
extends CharacterBody3D
## The player's spaceship: constant forward flight steered with a 2D input vector
## (virtual joystick on Android, WASD / arrow keys on desktop).
##
## The ship pitches and yaws towards the stick direction, banks into turns and
## shoots lasers while the fire input is held. Max speed and acceleration come
## from the chosen ship definition in GameData.

signal health_changed(current: float, maximum: float)
signal died

const CRASH_DAMAGE := 12.0
const CRASH_COOLDOWN := 0.8
const FIRE_INTERVAL := 0.16
const LASER_SPEED := 150.0
const LASER_DAMAGE := 10.0
const LASER_HIT_MASK := 5 ## world (1) + enemies (4)
const AIM_ASSIST_COS := 0.985 ## roughly a 10 degree cone
const MAX_PITCH := 1.1345 ## 65 degrees in radians
const BOUNDS_WARNING_DISTANCE := 20.0

## Set by the HUD touch controls every frame.
var touch_steer: Vector2 = Vector2.ZERO
var touch_fire: bool = false

var controls_enabled: bool = false
var invulnerable: bool = false
var bounds: AABB = AABB(Vector3(-500, -500, -500), Vector3(1000, 1000, 1000))
var near_bounds: bool = false

var max_speed: float = 45.0
var acceleration: float = 25.0
var turn_rate: float = 1.8
var max_health: float = 100.0
var health: float = 100.0

var _definition: Dictionary = {}
var _speed: float = 0.0
var _fire_timer: float = 0.0
var _crash_timer: float = 0.0
var _muzzle_side: float = 1.0
var _dead: bool = false
var _pivot: Node3D
var _engine_player: AudioStreamPlayer


func setup(ship_definition: Dictionary) -> void:
	_definition = ship_definition
	max_speed = ship_definition["max_speed"]
	acceleration = ship_definition["acceleration"]
	turn_rate = ship_definition["turn_rate"]
	max_health = ship_definition["health"]
	health = max_health


func _ready() -> void:
	collision_layer = 2
	collision_mask = 1
	motion_mode = CharacterBody3D.MOTION_MODE_FLOATING

	var shape := CollisionShape3D.new()
	var sphere := SphereShape3D.new()
	sphere.radius = 1.5
	shape.shape = sphere
	add_child(shape)

	_pivot = Node3D.new()
	add_child(_pivot)
	var model := (load(_definition["model"]) as PackedScene).instantiate() as Node3D
	model.scale = Vector3.ONE * float(_definition["scale"])
	model.rotation.y = GameData.MODEL_YAW
	_pivot.add_child(model)

	for side: float in [-0.7, 0.7]:
		var trail := Effects.make_engine_trail(Color(0.35, 0.75, 1.0))
		trail.position = Vector3(side, 0.0, 1.3)
		_pivot.add_child(trail)

	_engine_player = AudioManager.create_loop_player("engine", -16.0)
	add_child(_engine_player)
	_engine_player.play()

	health_changed.emit(health, max_health)


func _physics_process(delta: float) -> void:
	if _dead or not controls_enabled:
		return
	_crash_timer = maxf(_crash_timer - delta, 0.0)

	var steer := _get_steer()
	rotation.y -= steer.x * turn_rate * delta
	rotation.x = clampf(rotation.x - steer.y * turn_rate * delta, -MAX_PITCH, MAX_PITCH)
	_pivot.rotation.z = lerp_angle(_pivot.rotation.z, -steer.x * 0.7, 6.0 * delta)

	# Turning hard costs speed, so a higher acceleration recovers faster.
	var target_speed := max_speed * (1.0 - 0.3 * minf(steer.length(), 1.0))
	_speed = move_toward(_speed, target_speed, acceleration * delta)
	velocity = -global_transform.basis.z * _speed
	move_and_slide()

	_handle_collisions()
	_clamp_to_bounds()
	_handle_firing(delta)


func take_damage(amount: float, _direction: Vector3 = Vector3.ZERO) -> void:
	if _dead or invulnerable:
		return
	health = maxf(health - amount, 0.0)
	health_changed.emit(health, max_health)
	AudioManager.play_sfx("impact_heavy", -4.0)
	Effects.spawn_sparks(get_parent(), global_position)
	if health <= 0.0:
		_die()


func is_dead() -> bool:
	return _dead


func get_speed_ratio() -> float:
	return clampf(_speed / max_speed, 0.0, 1.0)


func _die() -> void:
	_dead = true
	velocity = Vector3.ZERO
	_engine_player.stop()
	Effects.spawn_explosion(get_parent(), global_position, 2.5)
	AudioManager.play_sfx("player_explosion")
	_pivot.visible = false
	died.emit()


func _get_steer() -> Vector2:
	if touch_steer.length() > 0.05:
		return touch_steer
	return Input.get_vector("steer_left", "steer_right", "steer_up", "steer_down")


func _handle_collisions() -> void:
	if get_slide_collision_count() > 0 and _crash_timer <= 0.0:
		_crash_timer = CRASH_COOLDOWN
		_speed *= 0.2
		take_damage(CRASH_DAMAGE)


func _clamp_to_bounds() -> void:
	var inner := bounds.grow(-BOUNDS_WARNING_DISTANCE)
	near_bounds = not inner.has_point(global_position)
	var clamped := global_position.clamp(bounds.position, bounds.end)
	if not clamped.is_equal_approx(global_position):
		global_position = clamped


func _handle_firing(delta: float) -> void:
	_fire_timer -= delta
	var wants_to_fire := touch_fire or Input.is_action_pressed("fire")
	if wants_to_fire and _fire_timer <= 0.0:
		_fire_timer = FIRE_INTERVAL
		_shoot()


func _shoot() -> void:
	_muzzle_side = -_muzzle_side
	var muzzle := global_transform * Vector3(1.2 * _muzzle_side, -0.2, -1.8)
	var direction := _get_aim_direction(muzzle)
	Projectile.fire(get_parent(), muzzle, direction, LASER_SPEED, LASER_DAMAGE, LASER_HIT_MASK, Color(0.25, 0.9, 1.0), self)
	AudioManager.play_sfx("laser_player", -9.0, randf_range(0.95, 1.1))


## Light aim assist: bend the shot towards an enemy inside a narrow cone,
## which makes aiming with a thumb much more forgiving.
func _get_aim_direction(muzzle: Vector3) -> Vector3:
	var forward := -global_transform.basis.z
	var best_direction := forward
	var best_dot := AIM_ASSIST_COS
	for node in get_tree().get_nodes_in_group("enemies"):
		var enemy := node as Node3D
		if enemy == null:
			continue
		var to_enemy := enemy.global_position - muzzle
		var direction := to_enemy.normalized()
		var alignment := direction.dot(forward)
		if alignment > best_dot and to_enemy.length() < 320.0:
			best_dot = alignment
			best_direction = direction
	return best_direction
