class_name ClickMoveInput3D
extends Node
## Raycasts LMB clicks from a top-down Camera3D onto walkable floor geometry and
## emits a world-space target for NavigationAgent3D.


signal move_target_selected(world_position: Vector3)
signal look_plane_changed(plane_direction: Vector2)


@export var enabled: bool = true
@export var camera: Camera3D
@export var body: CharacterBody3D
@export var floor_collision_mask: int = 1
@export var click_button: MouseButton = MOUSE_BUTTON_LEFT


func _unhandled_input(event: InputEvent) -> void:
	if not enabled:
		return
	if event is InputEventMouseButton \
			and event.pressed \
			and event.button_index == click_button:
		var hit: Vector3 = raycast_floor(event.position)
		if hit != Vector3.INF:
			move_target_selected.emit(hit)
	if event is InputEventMouseMotion and ui_blocks_combat():
		return
	if event is InputEventMouseMotion and camera != null and body != null:
		var hit: Vector3 = raycast_floor(event.position)
		if hit != Vector3.INF:
			var plane_dir: Vector2 = (PlaneCoords3D.world_to_plane(hit) - PlaneCoords3D.world_to_plane(body.global_position)).normalized()
			if plane_dir != Vector2.ZERO:
				look_plane_changed.emit(plane_dir)


func raycast_floor(screen_pos: Vector2) -> Vector3:
	if camera == null:
		return Vector3.INF
	var from: Vector3 = camera.project_ray_origin(screen_pos)
	var to: Vector3 = from + camera.project_ray_normal(screen_pos) * 10_000.0
	var query: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(from, to, floor_collision_mask)
	query.collide_with_areas = false
	query.collide_with_bodies = true
	var hit: Dictionary = camera.get_world_3d().direct_space_state.intersect_ray(query)
	if hit.is_empty():
		return Vector3.INF
	return hit.get("position", Vector3.INF) as Vector3


func ui_blocks_combat() -> bool:
	if ClientState.world_interactables_hovered > 0:
		return true
	var focused: Control = get_viewport().gui_get_focus_owner()
	if focused is LineEdit or focused is TextEdit:
		return true
	var hovered: Control = get_viewport().gui_get_hovered_control()
	return hovered != null and hovered.mouse_filter == Control.MOUSE_FILTER_STOP
