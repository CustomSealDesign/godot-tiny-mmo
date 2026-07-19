class_name GridCameraController
extends Camera3D
## OSRS-style orbit camera with click-to-move and tile indicator, adapted from
## Reference_GodotGrid/camera_controller.gd.


const BASE_CAMERA_SIZE: float = PixelScale3D.CAMERA_ORTHO_SIZE  # ~12 tiles; world plane authored in pixels

@export var distance: float = 240.0
@export var height: float = 320.0
@export var rotation_speed: float = 1.0
@export var zoom_speed: float = 10.0
@export var scroll_zoom_speed: float = 2.0
@export var min_distance: float = 120.0
@export var max_distance: float = 480.0
@export var follow_smoothness: float = 5.0

var player: LocalPlayer
var pathfinder: GridPathfinder
var tile_indicator_scene: PackedScene = preload("res://source/client/local_player/tile_indicator.tscn")

var tile_indicator: TileIndicator = null
var angle: float = 0.0
var current_position: Vector3 = Vector3.ZERO

## Per-map focus clamp in WORLD space (plane left/right -> world X, top/bottom -> world Z).
## The camera frames this clamped point instead of the raw player position, so it never
## pans past the map edge into black. Defaults to effectively unbounded.
var _limits_enabled: bool = false
var _limit_min: Vector2 = Vector2(-1e12, -1e12)  # (world x, world z)
var _limit_max: Vector2 = Vector2(1e12, 1e12)


func setup(local_player: LocalPlayer, grid_pathfinder: GridPathfinder) -> void:
	player = local_player
	pathfinder = grid_pathfinder
	current_position = global_position
	position_camera(true)


func _ready() -> void:
	current_position = global_position


func _process(delta: float) -> void:
	if Input.is_action_pressed(&"ui_left"):
		angle -= rotation_speed * delta
	elif Input.is_action_pressed(&"ui_right"):
		angle += rotation_speed * delta

	if Input.is_action_pressed(&"ui_up"):
		distance = maxf(min_distance, distance - zoom_speed * delta)
	elif Input.is_action_pressed(&"ui_down"):
		distance = minf(max_distance, distance + zoom_speed * delta)

	if player != null and is_instance_valid(player):
		position_camera(false, delta)


func _unhandled_input(event: InputEvent) -> void:
	if player == null or not is_instance_valid(player):
		return
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			distance = maxf(min_distance, distance - scroll_zoom_speed)
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			distance = minf(max_distance, distance + scroll_zoom_speed)
		elif event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
			_handle_mouse_click(event.position)


## Set the per-map camera focus limits from a [Map]'s plane-space camera_limit_* edges.
## left/right map to world X, top/bottom to world Z. The sentinel ±10,000,000 defaults
## (unbounded) simply produce a clamp wide enough to never engage.
func set_plane_limits(left: float, top: float, right: float, bottom: float) -> void:
	_limit_min = Vector2(minf(left, right), minf(top, bottom))
	_limit_max = Vector2(maxf(left, right), maxf(top, bottom))
	_limits_enabled = true


func clear_plane_limits() -> void:
	_limits_enabled = false


## The point the camera frames: the player, clamped into the map bounds inset by the
## view half-extent so the visible area stops at the map edge. When an axis is narrower
## than the view, the map is centered on that axis.
func _focus_point() -> Vector3:
	var focus: Vector3 = player.body.global_position
	if not _limits_enabled:
		return focus
	var half: float = size * 0.5  # orthographic half-height in world units
	focus.x = _clamp_axis(focus.x, _limit_min.x, _limit_max.x, half)
	focus.z = _clamp_axis(focus.z, _limit_min.y, _limit_max.y, half)
	return focus


func _clamp_axis(value: float, lo: float, hi: float, margin: float) -> float:
	if hi - lo <= margin * 2.0:
		return (lo + hi) * 0.5
	return clampf(value, lo + margin, hi - margin)


func position_camera(force: bool = false, delta: float = 0.0) -> void:
	if player == null or player.body == null:
		return
	var focus: Vector3 = _focus_point()
	var offset := Vector3(
		cos(angle) * distance,
		height,
		sin(angle) * distance
	)
	var target_pos: Vector3 = focus + offset
	if force:
		current_position = target_pos
	else:
		current_position = current_position.lerp(target_pos, delta * follow_smoothness)
	global_position = current_position
	look_at(focus, Vector3.UP)


func _handle_mouse_click(mouse_pos: Vector2) -> void:
	if player._dead or ClientState.menu_open:
		return

	var from: Vector3 = project_ray_origin(mouse_pos)
	var to: Vector3 = from + project_ray_normal(mouse_pos) * 10_000.0
	var space_state: PhysicsDirectSpaceState3D = get_world_3d().direct_space_state
	var query: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(
		from, to, player.floor_collision_mask
	)
	query.collide_with_areas = true
	query.collide_with_bodies = true
	var result: Dictionary = space_state.intersect_ray(query)

	var plane_hit: Variant = Plane(Vector3.UP, player.body.global_position.y).intersects_ray(from, to)
	if plane_hit == null:
		return

	var target_plane: Vector2 = PlaneCoords3D.world_to_plane(plane_hit as Vector3)
	if not pathfinder.is_walkable_plane(target_plane):
		return

	var snapped_plane: Vector2 = GridMovement.snap_plane(target_plane)
	_update_tile_indicator(snapped_plane)
	player.move_to_plane(snapped_plane)


func _update_tile_indicator(target_plane: Vector2) -> void:
	if tile_indicator == null:
		tile_indicator = tile_indicator_scene.instantiate() as TileIndicator
		var map: Node = player.get_parent()
		if map != null:
			map.add_child(tile_indicator)
	var floor_y: float = player.body.global_position.y
	tile_indicator.show_at_world(GridMovement.grid_to_world(
		GridMovement.plane_to_grid(target_plane),
		floor_y
	))
