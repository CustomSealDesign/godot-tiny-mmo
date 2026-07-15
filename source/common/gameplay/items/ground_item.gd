class_name GroundItem
extends Node2D
## Floor loot spawned by the server. The local player pathfinds directly onto this tile
## and sends pickup_item on arrival.


const INTERACT_RANGE: float = OsrsCombatService.INTERACT_RANGE

var ground_item_id: int = 0
var item_id: int = 0
var quantity: int = 1

var _interactable_hovered: bool = false

@onready var _visual_root: Node3D = $Visual3D
@onready var _click_area: ClickableArea = $ClickArea
@onready var _sprite: Sprite3D = $Visual3D/Sprite3D
@onready var _quantity_label: Label = $QuantityLabel


func _ready() -> void:
	_refresh_visual()
	_sync_visual_from_plane()

	if multiplayer.is_server():
		return

	_click_area.clicked.connect(_on_clicked)
	_click_area.mouse_entered.connect(_set_interactable_hover.bind(true))
	_click_area.mouse_exited.connect(_set_interactable_hover.bind(false))
	_click_area.tree_exiting.connect(_set_interactable_hover.bind(false))


func get_container() -> ReplicatedPropsContainer:
	var container_v: Variant = get_meta(&"rp_container", null)
	return container_v as ReplicatedPropsContainer


func _refresh_visual() -> void:
	var icon: Texture2D = ItemDatabase.load_icon(item_id)
	if icon != null and _sprite != null:
		_sprite.texture = icon
	if _quantity_label != null:
		if ItemDatabase.is_stackable(item_id) and quantity > 1:
			_quantity_label.text = str(quantity)
			_quantity_label.show()
		else:
			_quantity_label.hide()


func _on_clicked() -> void:
	if ClientState.menu_open:
		return
	var lp: LocalPlayer = ClientState.local_player
	if lp == null or not is_instance_valid(lp) or lp._dead or lp.pathfinder == null:
		return
	if _player_in_range(lp):
		_request_pickup()
		return

	var target_plane: Vector2 = GridMovement.snap_plane(global_position)
	var path: PackedVector2Array = lp.pathfinder.find_path(lp.global_position, target_plane)
	if path.is_empty():
		return

	if lp.camera_3d != null and lp.camera_3d.has_method(&"_update_tile_indicator"):
		lp.camera_3d._update_tile_indicator(target_plane)
	lp.move_to_plane(target_plane, self)


func on_player_arrived() -> void:
	if _player_in_range(ClientState.local_player):
		_request_pickup()


func _request_pickup() -> void:
	if InstanceClient.current == null or ground_item_id <= 0:
		return
	Client.request_data(
		&"pickup_item",
		Callable(),
		{"ground_item_id": ground_item_id},
		InstanceClient.current.name
	)


func _player_in_range(lp: LocalPlayer) -> bool:
	if lp == null:
		return false
	return global_position.distance_to(lp.global_position) <= INTERACT_RANGE


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
	var from: Vector3 = world + Vector3.UP * 32.0
	var to: Vector3 = world - Vector3.UP * 64.0
	var query: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(from, to, 1)
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
