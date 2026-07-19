class_name OverheadUi3D
extends RefCounted
## Places a 2D overhead Control (health bar, name label) at the on-screen position of
## an entity's 3D head, so the existing Control-based UI tracks the billboard under a
## Camera3D. Entities keep their 2D ProgressBar/Label (and all their styling, tweens
## and show/hide logic) — this only repositions them each client frame.
##
## Why not Label3D / 3D bars: the health-bar code (styleboxes, value tweens, hit-flash,
## auto-hide) is Control-based and battle-tested. Reprojecting is far less invasive than
## reimplementing all of that in 3D, and gives the same result for a top-down camera.


## Screen position (viewport pixels) for a world point, or a far-offscreen sentinel when
## the point is behind the camera (so the caller's Control simply vanishes without
## fighting the game's own `visible` flag).
const OFFSCREEN: Vector2 = Vector2(-100000.0, -100000.0)


## Center [param control] horizontally on the projected [param world_pos], applying
## [param screen_offset] (e.g. to stack a name above the bar). Top-anchored controls
## keep their own vertical extent.
static func place(control: Control, camera: Camera3D, world_pos: Vector3, screen_offset: Vector2 = Vector2.ZERO) -> void:
	if camera == null or control == null or not control.is_inside_tree():
		return
	if camera.is_position_behind(world_pos):
		control.global_position = OFFSCREEN
		return
	var screen: Vector2 = camera.unproject_position(world_pos)
	# Center on the projected point, accounting for the control's own scale (the name
	# label is drawn at 0.2 scale).
	control.global_position = screen + screen_offset - Vector2(control.size.x * control.scale.x * 0.5, 0.0)


## World-space anchor above a billboard: the top of the sprite plus a small margin.
## [param visual_world] is the sprite's ground position; [param sprite] supplies its
## scaled height (its local y is half-height by the PixelScale3D convention).
static func head_anchor(visual_world: Vector3, sprite: Sprite3D, margin: float = 8.0) -> Vector3:
	var height: float = 0.0
	if sprite != null:
		height = sprite.position.y * 2.0
	return Vector3(visual_world.x, visual_world.y + height + margin, visual_world.z)
