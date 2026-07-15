class_name GridMovementValidator
extends RefCounted
## Server-side guard for client-owned :position updates. Rejects any delta that is not
## a single adjacent integer grid step (8-directional, OSRS-style).


static func validate_step(previous_plane: Vector2, proposed_plane: Vector2) -> Dictionary:
	var previous_grid: Vector2i = GridMovement.plane_to_grid(previous_plane)
	var proposed_grid: Vector2i = GridMovement.plane_to_grid(proposed_plane)
	var snapped_plane: Vector2 = GridMovement.grid_to_plane(proposed_grid)

	if proposed_grid == previous_grid:
		return {"ok": true, "position": snapped_plane}

	if not GridMovement.is_adjacent_step(previous_grid, proposed_grid):
		return {"ok": false, "position": GridMovement.grid_to_plane(previous_grid)}

	return {"ok": true, "position": snapped_plane}
