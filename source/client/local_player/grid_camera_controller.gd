class_name GridCameraController
extends Camera3D
## OSRS-style orbit camera with click-to-move and tile indicator, adapted from
## Reference_GodotGrid/camera_controller.gd.


const BASE_CAMERA_SIZE: float = 384.0  # ~12 tiles @ 32 px/tile; the world plane is authored in pixels

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


func position_camera(force: bool = false, delta: float = 0.0) -> void:
	if player == null or player.body == null:
		return
	var offset := Vector3(
		cos(angle) * distance,
		height,
		sin(angle) * distance
	)
	var target_pos: Vector3 = player.body.global_position + offset
	if force:
		current_position = target_pos
	else:
		current_position = current_position.lerp(target_pos, delta * follow_smoothness)
	global_position = current_position
	look_at(player.body.global_position, Vector3.UP)


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
