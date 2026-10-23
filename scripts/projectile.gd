class_name Projectile
extends Node3D
## A laser bolt. Moves in a straight line and ray-casts every physics frame so
## fast bolts can never tunnel through thin targets.
##
## Idea based on the KidsCanCode "3D shooting" recipe
## (https://kidscancode.org/godot_recipes/3.x/3d/3d_shooting/index.html);
## re-implemented here with ray queries instead of physics bodies.

const MAX_LIFETIME := 2.5

var _velocity: Vector3 = Vector3.ZERO
var _damage: float = 10.0
var _hit_mask: int = 1
var _shooter: CollisionObject3D = null
var _life: float = MAX_LIFETIME


## Creates, places and launches a bolt below [param parent].
static func fire(
	parent: Node,
	origin: Vector3,
	direction: Vector3,
	speed: float,
	damage: float,
	hit_mask: int,
	color: Color,
	shooter: CollisionObject3D = null
) -> void:
	var bolt := Projectile.new()
	bolt._velocity = direction.normalized() * speed
	bolt._damage = damage
	bolt._hit_mask = hit_mask
	bolt._shooter = shooter

	var mesh_instance := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(0.16, 0.16, 3.4)
	box.material = Effects.glow_material(color, 3.5)
	mesh_instance.mesh = box
	bolt.add_child(mesh_instance)

	parent.add_child(bolt)
	var up := Vector3.UP if absf(direction.normalized().y) < 0.98 else Vector3.RIGHT
	bolt.look_at_from_position(origin, origin + direction, up)


func _physics_process(delta: float) -> void:
	var from := global_position
	var to := from + _velocity * delta
	var query := PhysicsRayQueryParameters3D.create(from, to, _hit_mask)
	if _shooter != null:
		query.exclude = [_shooter.get_rid()]
	var hit: Dictionary = get_world_3d().direct_space_state.intersect_ray(query)
	if not hit.is_empty():
		_on_hit(hit)
		return
	global_position = to
	_life -= delta
	if _life <= 0.0:
		queue_free()


func _on_hit(hit: Dictionary) -> void:
	var collider: Object = hit["collider"]
	var hit_position: Vector3 = hit["position"]
	if collider != null and collider.has_method("take_damage"):
		collider.take_damage(_damage, _velocity.normalized())
	else:
		Effects.spawn_sparks(get_parent(), hit_position)
		AudioManager.play_sfx("impact", -12.0)
	queue_free()
