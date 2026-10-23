class_name GoalRing
extends Node3D
## The level goal: a glowing ring that activates once enough enemies are down.

const RADIUS := 13.0

var is_active: bool = false

var _ring: MeshInstance3D
var _material: StandardMaterial3D
var _sparkles: CPUParticles3D


func _ready() -> void:
	_material = Effects.glow_material(Color(0.5, 0.5, 0.55), 1.0)
	_ring = MeshInstance3D.new()
	var torus := TorusMesh.new()
	torus.inner_radius = RADIUS - 1.2
	torus.outer_radius = RADIUS
	torus.rings = 32
	torus.ring_segments = 12
	torus.material = _material
	_ring.mesh = torus
	_ring.rotation_degrees.x = 90.0 ## stand the ring up so ships fly through it
	add_child(_ring)

	_sparkles = CPUParticles3D.new()
	_sparkles.amount = 60
	_sparkles.lifetime = 1.6
	_sparkles.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	_sparkles.emission_sphere_radius = RADIUS
	_sparkles.gravity = Vector3.ZERO
	_sparkles.initial_velocity_min = 0.5
	_sparkles.initial_velocity_max = 2.0
	_sparkles.mesh = Effects.small_sphere(0.25)
	_sparkles.color_ramp = Effects.fade_gradient(Color(0.5, 1.0, 1.0, 0.9), Color(0.3, 0.8, 1.0, 0.0))
	_sparkles.emitting = false
	add_child(_sparkles)


func _process(delta: float) -> void:
	_ring.rotate_object_local(Vector3.UP, delta * 0.6)


func set_active(active: bool) -> void:
	is_active = active
	var color := Color(0.3, 1.0, 1.0) if active else Color(0.5, 0.5, 0.55)
	_material.albedo_color = color
	_material.emission = color
	_material.emission_energy_multiplier = 3.5 if active else 1.0
	_sparkles.emitting = active


func contains(world_position: Vector3) -> bool:
	return global_position.distance_to(world_position) < RADIUS
