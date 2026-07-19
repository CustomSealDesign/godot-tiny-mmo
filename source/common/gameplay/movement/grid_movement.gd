class_name GridMovement
extends RefCounted
## Shared OSRS-style tile grid helpers. The authoritative server plane (Vector2) is
## snapped to integer tile coordinates; client 3D movement maps plane X/Y to world X/Z.


const TILE_SIZE: float = 32.0
const HALF_TILE: float = TILE_SIZE * 0.5
const WAYPOINT_REACHED_DIST: float = 0.35


static func plane_to_grid(plane: Vector2) -> Vector2i:
	return Vector2i(
		int(floor(plane.x / TILE_SIZE)),
		int(floor(plane.y / TILE_SIZE))
	)


static func grid_to_plane(grid: Vector2i) -> Vector2:
	return Vector2(
		(float(grid.x) + 0.5) * TILE_SIZE,
		(float(grid.y) + 0.5) * TILE_SIZE
	)


static func snap_plane(plane: Vector2) -> Vector2:
	return grid_to_plane(plane_to_grid(plane))


static func world_to_grid(world: Vector3) -> Vector2i:
	return plane_to_grid(PlaneCoords3D.world_to_plane(world))


static func grid_to_world(grid: Vector2i, floor_y: float = 0.0) -> Vector3:
	return PlaneCoords3D.plane_to_world(grid_to_plane(grid), floor_y)


static func is_adjacent_step(from_grid: Vector2i, to_grid: Vector2i) -> bool:
	var delta: Vector2i = to_grid - from_grid
	return absi(delta.x) <= 1 and absi(delta.y) <= 1


static func expand_region_around(a: Vector2i, b: Vector2i, padding: int = 8) -> Rect2i:
	var min_x: int = mini(a.x, b.x) - padding
	var min_y: int = mini(a.y, b.y) - padding
	var max_x: int = maxi(a.x, b.x) + padding
	var max_y: int = maxi(a.y, b.y) + padding
	return Rect2i(min_x, min_y, max_x - min_x + 1, max_y - min_y + 1)
