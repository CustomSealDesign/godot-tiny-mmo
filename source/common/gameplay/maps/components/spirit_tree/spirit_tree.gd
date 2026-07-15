class_name SpiritTree
extends Node2D
## A 3D spirit tree the local player can click to pathfind toward and woodcut.
## Server registers each instance on its Map by node name; the client handles
## pursuit + start_woodcutting once within [constant INTERACT_RANGE].


const INTERACT_RANGE: float = WoodcuttingService.INTERACT_RANGE
const MARKER_SCENE: PackedScene = preload("res://source/common/gameplay/maps/components/interactable_marker.tscn")

@export var floor_collision_mask: int = 1
@export var floor_probe_height: float = 32.0
@export var floor_probe_depth: float = 64.0

var _pursuing: bool = false
var _interactable_hovered: bool = false

@onready var _visual_root: Node3D = $Visual3D
@onready var _click_area: ClickableArea = $ClickArea


func _ready() -> void:
	if multiplayer.is_server():
		var map: Map = Map.of(self)
		if map != null:
			map.register_keyed(map.spirit_trees, StringName(name), self, "spirit tree")
		return

	_click_area.clicked.connect(_on_clicked)
	_click_area.mouse_entered.connect(_set_interactable_hover.bind(true))
	_click_area.mouse_exited.connect(_set_interactable_hover.bind(false))
	_click_area.tree_exiting.connect(_set_interactable_hover.bind(false))
	_spawn_marker()
	_sync_visual_from_plane()
	set_process(true)


func _process(_delta: float) -> void:
	if not _pursuing:
		return
	var lp: LocalPlayer = ClientState.local_player
	if lp == null or not is_instance_valid(lp):
		_pursuing = false
		return
	if ClientState.menu_open or lp._dead:
		_pursuing = false
		return
	if _player_in_range(lp):
		_pursuing = false
		_request_start()


func _on_clicked() -> void:
	if ClientState.menu_open:
		return
	var lp: LocalPlayer = ClientState.local_player
	if lp == null or not is_instance_valid(lp) or lp._dead:
		return
	if lp.is_woodcutting():
		lp.request_stop_woodcutting()
		return
	if _player_in_range(lp):
		_request_start()
		return
	_pursuing = true
	var target: Vector3 = _visual_root.global_position
	lp.nav_agent.target_position = target
	lp._has_nav_target = true


func _request_start() -> void:
	if InstanceClient.current == null:
		return
	Client.request_data(
		&"woodcutting.start",
		Callable(),
		{"tree": String(name)},
		InstanceClient.current.name
	)


func _player_in_range(lp: LocalPlayer) -> bool:
	return global_position.distance_to(lp.global_position) <= INTERACT_RANGE


func _spawn_marker() -> void:
	var marker: InteractableMarker = MARKER_SCENE.instantiate()
	marker.kind = InteractableMarker.Kind.GATHER
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
	var world_3d: World3D = get_world_3d()
	if world_3d != null:
		return world_3d.direct_space_state
	return null
