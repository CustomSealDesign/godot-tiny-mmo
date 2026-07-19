class_name DialogueNpc
extends Node2D
## OSRS-style dialogue NPC. The local player pathfinds to an adjacent tile, then the
## client sends [code]interact_npc[/code] to the server for quest dialogue.


const INTERACT_RANGE: float = 90.0
const MARKER_SCENE: PackedScene = preload("res://source/common/gameplay/maps/components/interactable_marker.tscn")

@export var npc_id: StringName = &"sect_elder"
@export var display_name: String = "Sect Elder"
@export var floor_collision_mask: int = 1
@export var floor_probe_height: float = 32.0
@export var floor_probe_depth: float = 64.0

var _interactable_hovered: bool = false

@onready var _visual_root: Node3D = $Visual3D
@onready var _click_area: ClickableArea = $ClickArea
@onready var _name_label: Label = $NameLabel


func _ready() -> void:
	_name_label.text = display_name

	if multiplayer.is_server():
		var map: Map = Map.of(self)
		if map != null:
			map.register_keyed(map.dialogue_npcs, npc_id, self, "dialogue npc")
		return

	_click_area.clicked.connect(_on_clicked)
	_click_area.mouse_entered.connect(_set_interactable_hover.bind(true))
	_click_area.mouse_exited.connect(_set_interactable_hover.bind(false))
	_click_area.tree_exiting.connect(_set_interactable_hover.bind(false))
	_spawn_marker()
	_sync_visual_from_plane()
	if ClientState.local_player != null:
		_mark_tile_solid()
	else:
		ClientState.local_player_ready.connect(_on_local_player_ready, CONNECT_ONE_SHOT)


func get_interact_range() -> float:
	return INTERACT_RANGE


func _on_local_player_ready(_lp: LocalPlayer) -> void:
	_mark_tile_solid()


func _mark_tile_solid() -> void:
	var lp: LocalPlayer = ClientState.local_player
	if lp == null or lp.pathfinder == null:
		return
	lp.pathfinder.mark_solid(GridMovement.plane_to_grid(global_position))


func _on_clicked() -> void:
	if ClientState.menu_open:
		return
	var lp: LocalPlayer = ClientState.local_player
	if lp == null or not is_instance_valid(lp) or lp._dead or lp.pathfinder == null:
		return
	if _player_in_range(lp):
		_request_interact()
		return

	var target_plane: Vector2 = lp.pathfinder.find_nearest_available_tile(
		global_position,
		lp.global_position
	)
	if target_plane == global_position:
		return

	var path: PackedVector2Array = lp.pathfinder.find_path(lp.global_position, target_plane)
	if path.is_empty():
		return

	if lp.camera_3d != null and lp.camera_3d.has_method(&"_update_tile_indicator"):
		lp.camera_3d._update_tile_indicator(target_plane)
	lp.move_to_plane(target_plane, self)


func on_player_arrived() -> void:
	if _player_in_range(ClientState.local_player):
		_request_interact()


func _request_interact() -> void:
	if InstanceClient.current == null:
		return
	Client.request_data(
		&"interact_npc",
		Callable(),
		{"npc": String(npc_id)},
		InstanceClient.current.name
	)


func _player_in_range(lp: LocalPlayer) -> bool:
	if lp == null:
		return false
	return global_position.distance_to(lp.global_position) <= INTERACT_RANGE


func _spawn_marker() -> void:
	var marker: InteractableMarker = MARKER_SCENE.instantiate()
	marker.kind = InteractableMarker.Kind.DIALOG
	marker.position = Vector2(0.0, -72.0)
	add_child(marker)


func _set_interactable_hover(on: bool) -> void:
	if not GameMode.is_client() or on == _interactable_hovered:
		return
	_interactable_hovered = on
	ClientState.world_interactables_hovered += 1 if on else -1


func _sync_visual_from_plane() -> void:
	if _visual_root == null:
		return
	var floor_y: float = _sample_floor_y(global_position)
	_visual_root.global_position = PlaneCoords3D.plane_to_world(global_position, floor_y)


func _sample_floor_y(plane: Vector2) -> float:
	var world: Vector3 = PlaneCoords3D.plane_to_world(plane, 0.0)
	var from: Vector3 = world + Vector3.UP * floor_probe_height
	var to: Vector3 = world - Vector3.UP * floor_probe_depth
	var query: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(
		from, to, floor_collision_mask
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
	var world_3d: World3D = null
	if _visual_root != null and is_instance_valid(_visual_root):
		world_3d = _visual_root.get_world_3d()
	if world_3d == null:
		var viewport: Viewport = get_viewport()
		if viewport != null:
			world_3d = viewport.world_3d
	if world_3d != null:
		return world_3d.direct_space_state
	return null
