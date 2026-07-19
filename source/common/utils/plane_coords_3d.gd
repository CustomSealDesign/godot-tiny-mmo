class_name PlaneCoords3D
extends RefCounted
## Bridges the server's authoritative 2D plane (Vector2) and the client's top-down
## 3D world (Vector3). The server keeps using X/Y as the gameplay plane; the client
## maps that to world X/Z and keeps Y for height / floor snapping.


## Server/network plane -> world position on the XZ floor.
static func plane_to_world(plane: Vector2, floor_y: float = 0.0) -> Vector3:
	return Vector3(plane.x, floor_y, plane.y)


## World position -> server/network plane (drops Y).
static func world_to_plane(world: Vector3) -> Vector2:
	return Vector2(world.x, world.z)


## Alias used by movement code when the click target already lives in 3D.
static func click_to_plane(world: Vector3) -> Vector2:
	return world_to_plane(world)
