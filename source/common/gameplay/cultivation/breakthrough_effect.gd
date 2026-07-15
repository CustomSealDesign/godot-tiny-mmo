class_name BreakthroughEffect
extends Node3D
## Client-only Xianxia breakthrough celebration: a golden Qi pillar, rising motes,
## and an expanding ring at the cultivator's 3D position. Spawned by
## [code]ClientState[/code] on the [code]cultivation.breakthrough[/code] push;
## frees itself when the burst finishes.


const DURATION: float = 2.4
const FLOOR_PROBE_HEIGHT: float = 32.0
const FLOOR_PROBE_DEPTH: float = 64.0
const FLOOR_COLLISION_MASK: int = 1

const QI_GOLD: Color = Color(1.0, 0.82, 0.28, 0.95)
const QI_WHITE: Color = Color(1.0, 1.0, 0.92, 0.9)

var _elapsed: float = 0.0
var _radius: float = 1.4


## Instantiate at the server-sent gameplay plane position (Vector2 X/Y → world X/Z).
static func spawn_at_plane(plane: Vector2, parent: Node) -> BreakthroughEffect:
	var effect: BreakthroughEffect = BreakthroughEffect.new()
	parent.add_child(effect)
	effect.setup_at_plane(plane)
	return effect


func setup_at_plane(plane: Vector2) -> void:
	var floor_y: float = _sample_floor_y(plane)
	global_position = PlaneCoords3D.plane_to_world(plane, floor_y)
	_spawn_particles()
	set_process(true)


func _spawn_particles() -> void:
	_spawn_pillar()
	_spawn_motes()
	_spawn_shockwave()


## Vertical Qi column — the "heaven and earth respond" pillar.
func _spawn_pillar() -> void:
	var pillar: CPUParticles3D = CPUParticles3D.new()
	pillar.emitting = true
	pillar.one_shot = true
	pillar.amount = 36
	pillar.lifetime = DURATION * 0.85
	pillar.explosiveness = 0.15
	pillar.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	pillar.emission_sphere_radius = 0.35
	pillar.direction = Vector3(0, 1, 0)
	pillar.spread = 8.0
	pillar.gravity = Vector3(0, 18.0, 0)
	pillar.initial_velocity_min = 4.0
	pillar.initial_velocity_max = 14.0
	pillar.scale_amount_min = 0.08
	pillar.scale_amount_max = 0.22
	var ramp: Gradient = Gradient.new()
	ramp.set_color(0, QI_WHITE)
	ramp.set_color(1, Color(QI_GOLD, 0.0))
	pillar.color_ramp = ramp
	add_child(pillar)


## Orbiting motes that spiral upward around the cultivator.
func _spawn_motes() -> void:
	var motes: CPUParticles3D = CPUParticles3D.new()
	motes.emitting = true
	motes.one_shot = true
	motes.amount = 48
	motes.lifetime = DURATION
	motes.explosiveness = 0.75
	motes.emission_shape = CPUParticles3D.EMISSION_SHAPE_RING
	motes.emission_ring_radius = 0.6
	motes.emission_ring_inner_radius = 0.2
	motes.emission_ring_axis = Vector3(0, 1, 0)
	motes.direction = Vector3(0, 1, 0)
	motes.spread = 35.0
	motes.gravity = Vector3(0, 6.0, 0)
	motes.initial_velocity_min = 2.5
	motes.initial_velocity_max = 9.0
	motes.angular_velocity_min = -180.0
	motes.angular_velocity_max = 180.0
	motes.scale_amount_min = 0.06
	motes.scale_amount_max = 0.16
	var ramp: Gradient = Gradient.new()
	ramp.offsets = PackedFloat32Array([0.0, 0.4, 1.0])
	ramp.colors = PackedColorArray([
		Color(QI_GOLD, 0.0), Color(QI_GOLD, 0.9), Color(0.6, 0.2, 0.9, 0.0),
	])
	motes.color_ramp = ramp
	add_child(motes)


## Ground-level burst ring for the initial breakthrough shock.
func _spawn_shockwave() -> void:
	var shock: CPUParticles3D = CPUParticles3D.new()
	shock.emitting = true
	shock.one_shot = true
	shock.amount = 24
	shock.lifetime = 0.7
	shock.explosiveness = 1.0
	shock.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	shock.emission_sphere_radius = 0.15
	shock.direction = Vector3(0, 0.2, 0)
	shock.spread = 90.0
	shock.gravity = Vector3(0, -2.0, 0)
	shock.initial_velocity_min = 3.0
	shock.initial_velocity_max = 8.0
	shock.scale_amount_min = 0.12
	shock.scale_amount_max = 0.28
	var ramp: Gradient = Gradient.new()
	ramp.set_color(0, QI_WHITE)
	ramp.set_color(1, Color(QI_GOLD, 0.0))
	shock.color_ramp = ramp
	add_child(shock)


func _process(delta: float) -> void:
	_elapsed += delta
	if _elapsed >= DURATION:
		queue_free()


func _sample_floor_y(plane: Vector2) -> float:
	var world: Vector3 = PlaneCoords3D.plane_to_world(plane, 0.0)
	var from: Vector3 = world + Vector3.UP * FLOOR_PROBE_HEIGHT
	var to: Vector3 = world - Vector3.UP * FLOOR_PROBE_DEPTH
	var query: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(
		from, to, FLOOR_COLLISION_MASK
	)
	query.collide_with_areas = false
	query.collide_with_bodies = true
	var space: PhysicsDirectSpaceState3D = _physics_space()
	if space == null:
		return world.y
	var hit: Dictionary = space.intersect_ray(query)
	if hit.is_empty():
		return world.y
	return (hit.get("position", world) as Vector3).y


func _physics_space() -> PhysicsDirectSpaceState3D:
	var lp: LocalPlayer = ClientState.local_player
	if lp != null and is_instance_valid(lp) and lp.body != null:
		return lp.body.get_world_3d().direct_space_state
	var world_3d: World3D = get_world_3d()
	if world_3d != null:
		return world_3d.direct_space_state
	return null
