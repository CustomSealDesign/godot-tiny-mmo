class_name Enemy
extends Node2D
## OSRS-style grid combat target. The local player paths to the nearest empty adjacent
## tile and sends start_combat on arrival; the server drives tick-based damage.


enum Animations {
	IDLE,
	RUN,
	DEATH,
}

const INTERACT_RANGE: float = OsrsCombatService.INTERACT_RANGE
const RESPAWN_SECONDS: float = 10.0
const MARKER_SCENE: PackedScene = preload("res://source/common/gameplay/maps/components/interactable_marker.tscn")

const WALK_ANIM_FPS: float = 5.0
const IDLE_SPRITE_FRAME: int = 0
const WALK_SPRITE_FRAME_FIRST: int = 1
const WALK_SPRITE_FRAME_LAST: int = 5

@export var display_name: String = "Spirit Wolf"
@export var max_hp: int = 20
@export var defense_level: int = 2
@export var defense_bonus: int = 0
@export var attack_damage: int = 5
@export var loot_item_id: int = ItemDatabase.WOLF_CORE
@export var loot_quantity: int = 1
@export var move_speed: float = 54.0
@export var floor_collision_mask: int = 1
@export var floor_probe_height: float = 32.0
@export var floor_probe_depth: float = 64.0

var current_hp: int = 20
var is_dead: bool = false

var anim: Animations = Animations.IDLE:
	set = _set_anim

var _interactable_hovered: bool = false
var _respawn_timer: SceneTreeTimer
var _walk_anim_time: float = 0.0
var _walk_sprite_frame: int = WALK_SPRITE_FRAME_FIRST
var _in_combat: bool = false
var _current_path: PackedVector2Array = PackedVector2Array()
var _path_index: int = 0
var _target_plane: Vector2 = Vector2.ZERO
var _is_moving: bool = false
var _move_direction: Vector2 = Vector2.ZERO

@onready var _visual_root: Node3D = $Visual3D
@onready var _sprite_billboard: Sprite3D = $Visual3D/Sprite3D
@onready var _click_area: ClickableArea = $ClickArea
@onready var _health_bar: ProgressBar = $HealthBar
@onready var _name_label: Label = $NameLabel


func _ready() -> void:
	current_hp = max_hp
	_update_health_bar()
	_name_label.text = display_name

	var map: Map = Map.of(self)
	if map != null:
		map.register_keyed(map.enemies, StringName(name), self, "enemy")

	if multiplayer.is_server():
		return

	PixelScale3D.apply_billboard(_sprite_billboard)
	_click_area.clicked.connect(_on_clicked)
	_click_area.mouse_entered.connect(_set_interactable_hover.bind(true))
	_click_area.mouse_exited.connect(_set_interactable_hover.bind(false))
	_click_area.tree_exiting.connect(_set_interactable_hover.bind(false))
	_spawn_marker()
	_sync_visual_from_plane()
	_apply_sprite_anim_state()
	Client.subscribe(&"combat.state", _on_combat_state)
	if ClientState.local_player != null:
		_mark_tile_solid()
	else:
		ClientState.local_player_ready.connect(_on_local_player_ready, CONNECT_ONE_SHOT)


func _on_local_player_ready(_lp: LocalPlayer) -> void:
	if not is_dead:
		_mark_tile_solid()


func _physics_process(delta: float) -> void:
	if multiplayer.is_server():
		return
	_process_grid_movement(delta)
	_sync_visual_from_plane()


func _process(delta: float) -> void:
	if multiplayer.is_server():
		return
	_advance_sprite_animation(delta)
	_update_overhead_ui()


## Keep the 2D health bar + name label pinned over the 3D billboard each frame.
func _update_overhead_ui() -> void:
	var camera: Camera3D = get_viewport().get_camera_3d()
	if camera == null or _visual_root == null:
		return
	var anchor: Vector3 = OverheadUi3D.head_anchor(_visual_root.global_position, _sprite_billboard)
	OverheadUi3D.place(_health_bar, camera, anchor)
	OverheadUi3D.place(_name_label, camera, anchor, Vector2(0.0, -14.0))


func get_attack_damage() -> int:
	return attack_damage


func get_sync_payload() -> Dictionary:
	return {
		"enemy": String(name),
		"hp": current_hp,
		"max_hp": max_hp,
		"dead": is_dead,
		"display_name": display_name,
	}


func apply_damage(amount: int, instance: ServerInstance) -> void:
	if is_dead or amount <= 0:
		return
	current_hp = maxi(0, current_hp - amount)
	_update_health_bar()
	OsrsCombatService.push_enemy_update(instance, self)
	if current_hp <= 0:
		_die(instance)


func apply_sync(payload: Dictionary) -> void:
	current_hp = int(payload.get("hp", current_hp))
	max_hp = int(payload.get("max_hp", max_hp))
	display_name = str(payload.get("display_name", display_name))
	var was_dead: bool = is_dead
	is_dead = bool(payload.get("dead", false))
	_name_label.text = display_name
	_update_health_bar()
	_set_dead_visual(is_dead)
	if was_dead != is_dead:
		if is_dead:
			_clear_tile_solid()
			_stop_grid_movement()
			anim = Animations.DEATH
		else:
			_mark_tile_solid()
			anim = Animations.IDLE


func _die(instance: ServerInstance) -> void:
	if is_dead:
		return
	is_dead = true
	OsrsCombatService.stop_for_enemy(self, "enemy_dead")
	_clear_tile_solid()
	_stop_grid_movement()
	_set_dead_visual(true)
	anim = Animations.DEATH
	OsrsCombatService.push_enemy_update(instance, self)

	var grid: Vector2i = GridMovement.plane_to_grid(global_position)
	GroundItemService.spawn_loot(instance, grid, loot_item_id, loot_quantity)

	_respawn_timer = get_tree().create_timer(RESPAWN_SECONDS)
	_respawn_timer.timeout.connect(_respawn.bind(instance))


func _respawn(instance: ServerInstance) -> void:
	if not is_instance_valid(self):
		return
	is_dead = false
	current_hp = max_hp
	_update_health_bar()
	_set_dead_visual(false)
	_mark_tile_solid()
	anim = Animations.IDLE
	if instance != null and is_instance_valid(instance):
		OsrsCombatService.push_enemy_update(instance, self)


func move_to_plane(destination_plane: Vector2) -> void:
	if is_dead or _in_combat:
		return
	var pathfinder: GridPathfinder = _enemy_pathfinder()
	if pathfinder == null:
		return

	_stop_grid_movement()

	var snapped_destination: Vector2 = GridMovement.snap_plane(destination_plane)
	_current_path = pathfinder.find_path(global_position, snapped_destination)
	if _current_path.is_empty():
		return

	_path_index = 0
	if _current_path.size() > 1 \
			and _current_path[0].distance_to(global_position) < GridMovement.WAYPOINT_REACHED_DIST:
		_path_index = 1
	_set_grid_target()


func _stop_grid_movement() -> void:
	_is_moving = false
	_current_path = PackedVector2Array()
	_path_index = 0
	_move_direction = Vector2.ZERO
	if not is_dead and not _in_combat:
		anim = Animations.IDLE


func _set_grid_target() -> void:
	if _path_index < _current_path.size():
		_target_plane = _current_path[_path_index]
		_is_moving = true
		anim = Animations.RUN
	else:
		_finish_grid_movement()


func _finish_grid_movement() -> void:
	_stop_grid_movement()
	global_position = GridMovement.snap_plane(global_position)
	_sync_visual_from_plane()


func _process_grid_movement(delta: float) -> void:
	if is_dead or _in_combat:
		_stop_grid_movement()
		return

	if not _is_moving or _current_path.is_empty():
		return

	var direction_plane: Vector2 = _target_plane - global_position
	var distance: float = direction_plane.length()
	if distance <= GridMovement.WAYPOINT_REACHED_DIST:
		global_position = _target_plane
		_path_index += 1
		if _path_index < _current_path.size():
			_set_grid_target()
		else:
			_finish_grid_movement()
		return

	_move_direction = direction_plane.normalized()
	global_position += _move_direction * move_speed * delta
	_update_sprite_facing()
	anim = Animations.RUN

	if global_position.distance_to(_target_plane) <= GridMovement.WAYPOINT_REACHED_DIST:
		global_position = _target_plane
		_path_index += 1
		if _path_index < _current_path.size():
			_set_grid_target()
		else:
			_finish_grid_movement()


func _on_combat_state(payload: Dictionary) -> void:
	var active: bool = bool(payload.get("active", false))
	var enemy_name: String = str(payload.get("enemy", ""))
	var was_in_combat: bool = _in_combat
	_in_combat = active and enemy_name == String(name)
	if _in_combat:
		_stop_grid_movement()
		anim = Animations.IDLE
	elif was_in_combat and not is_dead:
		anim = Animations.IDLE


func _on_clicked() -> void:
	if ClientState.menu_open:
		return
	var lp: LocalPlayer = ClientState.local_player
	if lp == null or not is_instance_valid(lp) or lp._dead or lp.pathfinder == null or is_dead:
		return
	if lp.is_in_combat():
		lp.request_stop_combat()
		return
	if _player_in_range(lp):
		_request_start()
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
	if is_dead:
		return
	if _player_in_range(ClientState.local_player):
		_request_start()


func _request_start() -> void:
	if InstanceClient.current == null:
		return
	Client.request_data(
		&"start_combat",
		Callable(),
		{"enemy": String(name)},
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
	if not GameMode.is_client() or on == _interactable_hovered or is_dead:
		return
	_interactable_hovered = on
	ClientState.world_interactables_hovered += 1 if on else -1


func _update_health_bar() -> void:
	_health_bar.max_value = max_hp
	_health_bar.value = current_hp
	_health_bar.visible = not is_dead and current_hp < max_hp


func _set_dead_visual(dead: bool) -> void:
	_visual_root.visible = not dead
	_click_area.visible = not dead
	_health_bar.visible = not dead and current_hp < max_hp


func _mark_tile_solid() -> void:
	var lp: LocalPlayer = ClientState.local_player
	if lp == null or lp.pathfinder == null:
		return
	lp.pathfinder.mark_solid(GridMovement.plane_to_grid(global_position))


func _clear_tile_solid() -> void:
	var lp: LocalPlayer = ClientState.local_player
	if lp == null or lp.pathfinder == null:
		return
	lp.pathfinder.clear_solid(GridMovement.plane_to_grid(global_position))


func _enemy_pathfinder() -> GridPathfinder:
	var lp: LocalPlayer = ClientState.local_player
	if lp == null or lp.pathfinder == null:
		return null
	return lp.pathfinder


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


func _set_anim(new_anim: Animations) -> void:
	if anim == new_anim:
		return
	anim = new_anim
	_apply_sprite_anim_state()


func _apply_sprite_anim_state() -> void:
	if _sprite_billboard == null:
		return
	match anim:
		Animations.IDLE, Animations.DEATH:
			_walk_anim_time = 0.0
			_walk_sprite_frame = WALK_SPRITE_FRAME_FIRST
			_sprite_billboard.frame = IDLE_SPRITE_FRAME
		Animations.RUN:
			_walk_anim_time = 0.0
			_walk_sprite_frame = WALK_SPRITE_FRAME_FIRST
			_sprite_billboard.frame = WALK_SPRITE_FRAME_FIRST


func _advance_sprite_animation(delta: float) -> void:
	if _sprite_billboard == null or anim != Animations.RUN:
		return
	_walk_anim_time += delta
	var frame_duration: float = 1.0 / WALK_ANIM_FPS
	while _walk_anim_time >= frame_duration:
		_walk_anim_time -= frame_duration
		_walk_sprite_frame += 1
		if _walk_sprite_frame > WALK_SPRITE_FRAME_LAST:
			_walk_sprite_frame = WALK_SPRITE_FRAME_FIRST
	_sprite_billboard.frame = _walk_sprite_frame


func _update_sprite_facing() -> void:
	if _sprite_billboard == null or _move_direction.length_squared() <= 0.0001:
		return
	_sprite_billboard.flip_h = _move_direction.x < 0.0
