class_name GridPathfinder
extends RefCounted
## AStarGrid2D pathfinding over the gameplay plane, adapted from Reference_GodotGrid/pathfinding.gd.
## Walkability is probed with downward physics raycasts on the client's 3D floor mesh.


const DIRECTIONS: Array[Vector2i] = [
	Vector2i(-1, -1), Vector2i(0, -1), Vector2i(1, -1),
	Vector2i(-1, 0), Vector2i(1, 0),
	Vector2i(-1, 1), Vector2i(0, 1), Vector2i(1, 1),
]

var _astar: AStarGrid2D = AStarGrid2D.new()
var _space_state: PhysicsDirectSpaceState3D
var _floor_mask: int = 1
var _floor_probe_height: float = 32.0
var _floor_probe_depth: float = 64.0
var _built_region: Rect2i = Rect2i()
var _solid_cells: Dictionary = {}


func configure(
	space_state: PhysicsDirectSpaceState3D,
	floor_mask: int = 1,
	floor_probe_height: float = 32.0,
	floor_probe_depth: float = 64.0
) -> void:
	_space_state = space_state
	_floor_mask = floor_mask
	_floor_probe_height = floor_probe_height
	_floor_probe_depth = floor_probe_depth


func find_path(from_plane: Vector2, to_plane: Vector2) -> PackedVector2Array:
	var start_grid: Vector2i = GridMovement.plane_to_grid(from_plane)
	var end_grid: Vector2i = GridMovement.plane_to_grid(to_plane)
	if start_grid == end_grid:
		return PackedVector2Array([GridMovement.grid_to_plane(end_grid)])

	_ensure_region(start_grid, end_grid)
	if not _is_walkable(end_grid):
		return PackedVector2Array()

	var id_path: PackedVector2Array = _astar.get_id_path(
		Vector2(start_grid),
		Vector2(end_grid)
	)
	if id_path.is_empty():
		return PackedVector2Array()

	var path: PackedVector2Array = PackedVector2Array()
	for point: Vector2 in id_path:
		path.append(GridMovement.grid_to_plane(Vector2i(point)))
	return path


func find_nearest_available_tile(target_plane: Vector2, seeker_plane: Vector2) -> Vector2:
	var target_grid: Vector2i = GridMovement.plane_to_grid(target_plane)
	var seeker_grid: Vector2i = GridMovement.plane_to_grid(seeker_plane)
	_ensure_region(target_grid, seeker_grid)

	var nearest_grid: Vector2i = target_grid
	var shortest_distance: float = INF

	for direction: Vector2i in DIRECTIONS:
		var neighbor_grid: Vector2i = target_grid + direction
		if not _is_walkable(neighbor_grid):
			continue
		if neighbor_grid == seeker_grid:
			continue
		var dist: float = float(seeker_grid.distance_to(neighbor_grid))
		if dist < shortest_distance:
			shortest_distance = dist
			nearest_grid = neighbor_grid

	if nearest_grid == target_grid:
		return target_plane
	return GridMovement.grid_to_plane(nearest_grid)


func is_walkable_plane(plane: Vector2) -> bool:
	var grid: Vector2i = GridMovement.plane_to_grid(plane)
	_ensure_region(grid, grid)
	return _is_walkable(grid)


func mark_solid(grid: Vector2i) -> void:
	_solid_cells[grid] = true
	if _built_region.has_point(grid):
		_astar.set_point_solid(grid, true)


func clear_solid(grid: Vector2i) -> void:
	_solid_cells.erase(grid)
	if _built_region.has_point(grid):
		_astar.set_point_solid(grid, false)


func _ensure_region(a: Vector2i, b: Vector2i) -> void:
	var needed: Rect2i = GridMovement.expand_region_around(a, b)
	if _built_region.has_area() and _built_region.has_point(a) and _built_region.has_point(b):
		return
	_build_region(needed)


func _build_region(region: Rect2i) -> void:
	_astar.region = region
	_astar.cell_size = Vector2(GridMovement.TILE_SIZE, GridMovement.TILE_SIZE)
	_astar.offset = Vector2(GridMovement.HALF_TILE, GridMovement.HALF_TILE)
	_astar.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_ONLY_IF_NO_OBSTACLES
	_astar.update()

	for y: int in range(region.position.y, region.position.y + region.size.y):
		for x: int in range(region.position.x, region.position.x + region.size.x):
			var cell: Vector2i = Vector2i(x, y)
			var solid: bool = _solid_cells.has(cell) or not _probe_walkable(cell)
			_astar.set_point_solid(cell, solid)

	_built_region = region


func _is_walkable(grid: Vector2i) -> bool:
	if not _built_region.has_point(grid):
		return _probe_walkable(grid)
	return not _astar.is_point_solid(grid)


func _probe_walkable(grid: Vector2i) -> bool:
	if _space_state == null:
		return true
	var plane: Vector2 = GridMovement.grid_to_plane(grid)
	var world: Vector3 = PlaneCoords3D.plane_to_world(plane, 0.0)
	var from: Vector3 = world + Vector3.UP * _floor_probe_height
	var to: Vector3 = world - Vector3.UP * _floor_probe_depth
	var query: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(
		from, to, _floor_mask
	)
	query.collide_with_areas = false
	query.collide_with_bodies = true
	var hit: Dictionary = _space_state.intersect_ray(query)
	return not hit.is_empty()
