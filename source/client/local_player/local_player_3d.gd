class_name LocalPlayer
extends Player3D

signal movement_finished

const PVP_TOAST_COLOR: Color = Color(1.0, 0.5, 0.45)
const SAFE_TOAST_COLOR: Color = Color(0.55, 0.95, 0.6)
const NET_SEND_INTERVAL_S: float = 1.0 / 20.0
const CHANNEL_MOVE_GRACE_MS: int = 850

var speed: float = 90.0
var hand_pivot_speed: float = 17.5

var input_direction: Vector2 = Vector2.ZERO
var look_direction: Vector2 = Vector2.RIGHT
var action_input: bool = false

var _dead: bool = false
var _respawn_position: Vector2
var _was_pvp: bool = false
var _movement_lock_until_ms: int = 0
var _channeling: bool = false
var _channel_until_ms: int = 0
var _channel_mobile: bool = false
var _channel_speed_mult: float = 0.5
var _channel_grace_until_ms: int = 0
var channeling_ability_name: String = ""
var _equip_drawing: bool = false
var _equip_draw_until_ms: int = 0
var _equip_draw_token: int = 0
var _equip_bar: ChannelVisual = null
var _trauma: float = 0.0
var _net_send_accum: float = 0.0
var _woodcutting: bool = false
var _combat: bool = false
var _alchemizing: bool = false
var _mining: bool = false
var _forging: bool = false

var pathfinder: GridPathfinder
var _current_path: PackedVector2Array = PackedVector2Array()
var _path_index: int = 0
var _target_plane: Vector2 = Vector2.ZERO
var _is_moving: bool = false
var _pending_interact: Node = null

var fid_position: int
var fid_flipped: int
var fid_anim: int
var fid_pivot: int

var synchronizer_manager: StateSynchronizerManagerClient

@onready var camera_3d: GridCameraController = $Camera3D


func _ready() -> void:
	ClientState.local_player = self
	ClientState.local_player_ready.emit(self)

	super._ready()

	_was_pvp = is_pvp()

	fid_position = PathRegistry.id_of(":position")
	fid_flipped = PathRegistry.id_of(":flipped")
	fid_anim = PathRegistry.id_of(":anim")
	fid_pivot = PathRegistry.id_of(":pivot")

	pathfinder = GridPathfinder.new()
	await get_tree().physics_frame
	pathfinder.configure(
		body.get_world_3d().direct_space_state,
		floor_collision_mask,
		floor_probe_height,
		floor_probe_depth
	)
	camera_3d.setup(self, pathfinder)

	global_position = GridMovement.snap_plane(global_position)
	_sync_body_from_plane()

	_apply_settings()
	ClientState.settings.setting_changed.connect(_on_settings_changed)
	Client.instance_manager.instance_changed.connect(_on_instance_changed_camera_limits)
	if InstanceClient.current != null:
		_apply_camera_limits(InstanceClient.current.instance_map)

	Client.subscribe(&"player.died", _on_player_died)
	Client.subscribe(&"sparring.match.state", _on_sparring_match_state)
	Client.subscribe(&"player.teleport", _on_teleport)
	Client.subscribe(&"player.stunned", func(payload: Dictionary) -> void:
		freeze_movement(float(payload.get("ms", 1000)) / 1000.0))
	Client.subscribe(&"channel.start", _on_channel_start)
	Client.subscribe(&"channel.end", _on_channel_end)
	Client.subscribe(&"equip.cast", _on_equip_cast)
	Client.subscribe(&"equip.done", _on_equip_done)
	Client.subscribe(&"woodcutting.state", _on_woodcutting_state)
	Client.subscribe(&"alchemy.state", _on_alchemy_state)
	Client.subscribe(&"mining.state", _on_mining_state)
	Client.subscribe(&"forging.state", _on_forging_state)
	Client.subscribe(&"combat.state", _on_combat_state)
	Client.subscribe(&"combat.enemy_update", _on_combat_enemy_update)
	Client.subscribe(&"system.message", _on_system_message)
	Client.subscribe(&"group.roster", _on_group_roster)
	Client.subscribe(&"dungeon.cleared", func(payload: Dictionary) -> void:
		ClientState.open_menu_requested.emit(&"dungeon_recap", payload))
	Client.subscribe(&"dungeon.failed", func(payload: Dictionary) -> void:
		ClientState.open_menu_requested.emit(&"dungeon_recap", payload))
	Client.subscribe(&"dungeon.entered", func(payload: Dictionary) -> void:
		Toaster.toast_group(
			"Entered %s" % str(payload.get("dungeon", "the dungeon")),
			PackedStringArray(["Clear each room. Defeat the boss to escape."]),
			4.0))
	Client.subscribe(&"boss.enrage", func(payload: Dictionary) -> void:
		Toaster.toast("%s enrages!" % str(payload.get("name", "The boss")), 3.0, PVP_TOAST_COLOR)
		shake_camera(0.6))


func _apply_team_bar_color() -> void:
	set_health_bar_fill(BAR_COLOR_SELF)


func wants_net_smoothing() -> bool:
	return false


func is_moving_on_grid() -> bool:
	return _is_moving


func move_to_plane(destination_plane: Vector2, interact_target: Node = null) -> void:
	if _dead or ClientState.menu_open or Time.get_ticks_msec() < _movement_lock_until_ms:
		return
	if _woodcutting:
		request_stop_woodcutting()
	if _combat:
		request_stop_combat()
	if _alchemizing:
		request_stop_alchemy()
	if _mining:
		request_stop_mining()
	if _forging:
		request_stop_forging()
	if _channeling and not _channel_mobile:
		_cancel_channel()

	_pending_interact = interact_target
	_stop_grid_movement()

	var snapped_destination: Vector2 = GridMovement.snap_plane(destination_plane)
	_current_path = pathfinder.find_path(global_position, snapped_destination)
	if _current_path.is_empty():
		movement_finished.emit()
		return

	_path_index = 0
	if _current_path.size() > 1 and _current_path[0].distance_to(global_position) < GridMovement.WAYPOINT_REACHED_DIST:
		_path_index = 1
	_set_grid_target()


func _stop_grid_movement() -> void:
	_is_moving = false
	_current_path = PackedVector2Array()
	_path_index = 0
	body.velocity = Vector3.ZERO


func _set_grid_target() -> void:
	if _path_index < _current_path.size():
		_target_plane = _current_path[_path_index]
		_is_moving = true
	else:
		_finish_grid_movement()


func _finish_grid_movement() -> void:
	_stop_grid_movement()
	global_position = GridMovement.snap_plane(global_position)
	_sync_body_from_plane()
	input_direction = Vector2.ZERO

	var interact_target: Node = _pending_interact
	_pending_interact = null
	movement_finished.emit()
	if interact_target != null and is_instance_valid(interact_target) \
			and interact_target.has_method(&"on_player_arrived"):
		interact_target.on_player_arrived()


func _physics_process(delta: float) -> void:
	process_movement(delta)
	process_input()
	process_animation(delta)
	process_synchronization()
	_notify_zone_transition()


func _process(delta: float) -> void:
	if _trauma <= 0.0:
		return
	_trauma = maxf(0.0, _trauma - 3.5 * delta)
	var shake: float = _trauma * _trauma * 0.35
	camera_3d.h_offset = randf_range(-1.0, 1.0) * shake
	camera_3d.v_offset = randf_range(-1.0, 1.0) * shake


func process_movement(delta: float) -> void:
	if _dead or ClientState.menu_open or Time.get_ticks_msec() < _movement_lock_until_ms \
			or (_channeling and not _channel_mobile) or _woodcutting or _combat or _alchemizing:
		_stop_grid_movement()
		body.velocity = Vector3.ZERO
		body.move_and_slide()
		return

	if not _is_moving or _current_path.is_empty():
		body.velocity = Vector3.ZERO
		body.move_and_slide()
		input_direction = Vector2.ZERO
		return

	var move_speed: float = stats_component.get_stat(Stat.MOVE_SPEED)
	if move_speed <= 0.0:
		move_speed = speed
	if _channeling and _channel_mobile:
		move_speed *= _channel_speed_mult

	var direction_plane: Vector2 = _target_plane - global_position
	var distance: float = direction_plane.length()
	if distance <= GridMovement.WAYPOINT_REACHED_DIST:
		global_position = _target_plane
		_sync_body_from_plane()
		_path_index += 1
		if _path_index < _current_path.size():
			_set_grid_target()
		else:
			_finish_grid_movement()
		return

	var direction_world: Vector3 = PlaneCoords3D.plane_to_world(direction_plane.normalized(), 0.0)
	body.velocity = direction_world * move_speed
	body.move_and_slide()
	global_position = PlaneCoords3D.world_to_plane(body.global_position)
	input_direction = direction_plane.normalized()

	if body.global_position.distance_to(
			PlaneCoords3D.plane_to_world(_target_plane, body.global_position.y)
		) <= GridMovement.WAYPOINT_REACHED_DIST:
		global_position = _target_plane
		_sync_body_from_plane()
		_path_index += 1
		if _path_index < _current_path.size():
			_set_grid_target()
		else:
			_finish_grid_movement()

	# Face movement direction on the model rig.
	if direction_plane.length_squared() > 0.0001:
		var target_rotation: float = atan2(direction_plane.x, direction_plane.y)
		hand_pivot.rotation.y = lerp_angle(hand_pivot.rotation.y, target_rotation, delta * 10.0)


func process_input() -> void:
	if _dead or _has_gui_focus() or ClientState.menu_open or Time.get_ticks_msec() < _movement_lock_until_ms:
		action_input = false
		return

	if _woodcutting or _combat or _alchemizing:
		action_input = false
		return

	action_input = Input.is_action_pressed(&"player_shoot") and not _ui_blocks_combat()

	if is_equip_drawing():
		action_input = false
		return

	if Input.is_action_just_pressed(&"player_recall"):
		request_recall()

	if _channeling:
		if Time.get_ticks_msec() > _channel_until_ms:
			_channeling = false
			channeling_ability_name = ""
		elif not _channel_mobile:
			if input_direction != Vector2.ZERO and Time.get_ticks_msec() >= _channel_grace_until_ms:
				_cancel_channel()
			else:
				action_input = false
				return
		else:
			if Time.get_ticks_msec() >= _channel_grace_until_ms and (
					Input.is_action_just_pressed(&"player_special")
					or Input.is_action_just_pressed(&"player_special_2")):
				_cancel_channel()
			action_input = false
			return

	if action_input and equipment_component.can_use(&"weapon", 0):
		Client.request_data(&"action.perform", Callable(),
			{"d": look_direction, "i": 0}, InstanceClient.current.name)


func _ui_blocks_combat() -> bool:
	if ClientState.world_interactables_hovered > 0:
		return true
	var focused: Control = get_viewport().gui_get_focus_owner()
	if focused is LineEdit or focused is TextEdit:
		return true
	var hovered: Control = get_viewport().gui_get_hovered_control()
	return hovered != null and hovered.mouse_filter == Control.MOUSE_FILTER_STOP


func process_animation(delta: float) -> void:
	if _dead:
		if anim != Animations.DEATH:
			anim = Animations.DEATH
		return
	flipped = look_direction.x < 0.0
	_update_hand_pivot(delta)
	if _woodcutting or _combat or _alchemizing:
		anim = Animations.IDLE
		return
	anim = Animations.RUN if input_direction != Vector2.ZERO else Animations.IDLE


func _update_hand_pivot(delta: float) -> void:
	if _channeling and not _channel_mobile:
		return
	var to_flip: int = -1 if flipped else 1
	var look_angle: float = atan2(look_direction.y, look_direction.x * to_flip)
	hand_pivot.rotation.y = lerp_angle(hand_pivot.rotation.y, look_angle, delta * hand_pivot_speed)


func process_synchronization() -> void:
	var plane_position: Vector2 = GridMovement.snap_plane(get_plane_position())
	var pairs: Array[Array] = [
		[fid_position, plane_position],
		[fid_flipped, flipped],
		[fid_anim, anim],
		[fid_pivot, snappedf(hand_pivot.rotation.y, 0.05)],
	]
	state_synchronizer.mark_many_by_id(pairs, true)

	_net_send_accum += get_physics_process_delta_time()
	if _net_send_accum < NET_SEND_INTERVAL_S:
		return
	_net_send_accum = fmod(_net_send_accum, NET_SEND_INTERVAL_S)
	var collected_pairs: Array = state_synchronizer.collect_dirty_pairs()
	if not collected_pairs.is_empty():
		synchronizer_manager.send_my_delta(multiplayer.get_unique_id(), collected_pairs)


func _on_player_died(data: Dictionary) -> void:
	_dead = true
	_respawn_position = data.get("spawn", get_plane_position())
	await get_tree().create_timer(float(data.get("respawn_in", 3.0))).timeout
	if not is_instance_valid(self):
		return
	apply_plane_position(_respawn_position)
	_stop_grid_movement()
	_dead = false


func _on_sparring_match_state(payload: Dictionary) -> void:
	var pos: Variant = payload.get("position", null)
	if pos is Vector2 and pos != Vector2.ZERO:
		apply_plane_position(pos)
		_stop_grid_movement()
		_movement_lock_until_ms = Time.get_ticks_msec() + int(payload.get("countdown_ms", 500))
	if bool(payload.get("in_match", false)):
		Character.spar_ally_peers = payload.get("allies", [])
		Character.spar_opponent_peers = payload.get("opponents", [])
	else:
		Character.spar_ally_peers = []
		Character.spar_opponent_peers = []
	var map: Node = get_parent()
	if map != null:
		for child: Node in map.get_children():
			if child.has_method(&"_apply_team_bar_color"):
				child.call(&"_apply_team_bar_color")


func _on_group_roster(payload: Dictionary) -> void:
	Character.group_peers = payload.get("members", [])
	var map: Node = get_parent()
	if map != null:
		for child: Node in map.get_children():
			if child.has_method(&"_apply_team_bar_color"):
				child.call(&"_apply_team_bar_color")


func _on_teleport(payload: Dictionary) -> void:
	var pos: Variant = payload.get("position", null)
	if pos is Vector2:
		apply_plane_position(pos)
		_stop_grid_movement()
		_movement_lock_until_ms = Time.get_ticks_msec() + 500


func _on_channel_start(payload: Dictionary) -> void:
	if int(payload.get("p", -1)) != multiplayer.get_unique_id():
		return
	_channeling = true
	channeling_ability_name = String(payload.get("an", ""))
	_channel_mobile = bool(payload.get("mob", false))
	_channel_speed_mult = float(payload.get("msm", 0.5))
	_channel_grace_until_ms = Time.get_ticks_msec() + CHANNEL_MOVE_GRACE_MS
	_channel_until_ms = Time.get_ticks_msec() + int(float(payload.get("d", 6.0)) * 1000.0) + 750


func _on_channel_end(payload: Dictionary) -> void:
	if int(payload.get("p", -1)) != multiplayer.get_unique_id():
		return
	_channeling = false
	_channel_mobile = false
	channeling_ability_name = ""


func request_recall() -> void:
	if _channeling or _woodcutting or _combat or _alchemizing or _mining or _forging or InstanceClient.current == null:
		return
	Client.request_data(&"recall.start", Callable(), {}, InstanceClient.current.name)


func is_woodcutting() -> bool:
	return _woodcutting


func is_in_combat() -> bool:
	return _combat


func request_stop_woodcutting() -> void:
	if not _woodcutting or InstanceClient.current == null:
		return
	Client.request_data(&"woodcutting.stop", Callable(), {}, InstanceClient.current.name)


func _on_woodcutting_state(payload: Dictionary) -> void:
	var active: bool = bool(payload.get("active", false))
	_woodcutting = active
	if active:
		_stop_grid_movement()
		input_direction = Vector2.ZERO


func is_alchemizing() -> bool:
	return _alchemizing


func request_stop_alchemy() -> void:
	if not _alchemizing or InstanceClient.current == null:
		return
	Client.request_data(&"alchemy.stop", Callable(), {}, InstanceClient.current.name)


func _on_alchemy_state(payload: Dictionary) -> void:
	var active: bool = bool(payload.get("active", false))
	_alchemizing = active
	if active:
		_stop_grid_movement()
		input_direction = Vector2.ZERO


func is_mining() -> bool:
	return _mining


func request_stop_mining() -> void:
	if not _mining or InstanceClient.current == null:
		return
	Client.request_data(&"mining.stop", Callable(), {}, InstanceClient.current.name)


func _on_mining_state(payload: Dictionary) -> void:
	var active: bool = bool(payload.get("active", false))
	_mining = active
	if active:
		_stop_grid_movement()
		input_direction = Vector2.ZERO


func is_forging() -> bool:
	return _forging


func request_stop_forging() -> void:
	if not _forging or InstanceClient.current == null:
		return
	Client.request_data(&"forging.stop", Callable(), {}, InstanceClient.current.name)


func _on_forging_state(payload: Dictionary) -> void:
	var active: bool = bool(payload.get("active", false))
	_forging = active
	if active:
		_stop_grid_movement()
		input_direction = Vector2.ZERO


func request_stop_combat() -> void:
	if not _combat or InstanceClient.current == null:
		return
	Client.request_data(&"combat.stop", Callable(), {}, InstanceClient.current.name)


func _on_combat_state(payload: Dictionary) -> void:
	var active: bool = bool(payload.get("active", false))
	_combat = active
	if active:
		_stop_grid_movement()
		input_direction = Vector2.ZERO


func _on_combat_enemy_update(payload: Dictionary) -> void:
	var enemy_name: StringName = StringName(str(payload.get("enemy", "")))
	if enemy_name.is_empty() or InstanceClient.current == null:
		return
	var map: Map = InstanceClient.current.instance_map
	if map == null or not map.enemies.has(enemy_name):
		return
	var enemy: Enemy = map.enemies[enemy_name] as Enemy
	if enemy != null and is_instance_valid(enemy):
		enemy.apply_sync(payload)


func _on_system_message(payload: Dictionary) -> void:
	var message: String = str(payload.get("message", ""))
	if not message.is_empty():
		Toaster.toast(message)


func _cancel_channel() -> void:
	_channeling = false
	channeling_ability_name = ""
	if InstanceClient.current != null:
		Client.request_data(&"channel.cancel", Callable(), {}, InstanceClient.current.name)


func freeze_movement(seconds: float) -> void:
	if seconds <= 0.0:
		return
	_movement_lock_until_ms = maxi(_movement_lock_until_ms, Time.get_ticks_msec() + int(seconds * 1000.0))


func is_armed() -> bool:
	var weapon: Weapon = equipment_component.mounted_nodes.get(&"weapon", null) as Weapon
	return weapon != null and not weapon.abilities.is_empty() and weapon.abilities[0] != null


func _on_equip_cast(payload: Dictionary) -> void:
	var ms: int = int(payload.get("ms", 500))
	_equip_drawing = true
	_equip_draw_until_ms = Time.get_ticks_msec() + ms
	_equip_draw_token += 1
	var token: int = _equip_draw_token
	_show_equip_bar(float(ms) / 1000.0)
	await get_tree().create_timer(float(ms) / 1000.0 + 0.6).timeout
	if _equip_draw_token == token:
		_clear_equip_draw()


func _on_equip_done(_payload: Dictionary) -> void:
	_equip_draw_token += 1
	_clear_equip_draw()


func _clear_equip_draw() -> void:
	_equip_drawing = false
	if is_instance_valid(_equip_bar):
		_equip_bar.queue_free()
	_equip_bar = null


func _show_equip_bar(duration: float) -> void:
	if is_instance_valid(_equip_bar):
		_equip_bar.queue_free()
	var bar: ChannelVisual = ChannelVisual.new()
	bar.name = "EquipCastVisual"
	bar.kind = &"equip"
	bar.duration = maxf(0.1, duration)
	add_child(bar)
	_equip_bar = bar


func is_equip_drawing() -> bool:
	return _equip_drawing and Time.get_ticks_msec() < _equip_draw_until_ms


func shake_camera(amount: float) -> void:
	_trauma = clampf(_trauma + amount, 0.0, 1.0)


func _notify_zone_transition() -> void:
	var now_pvp: bool = is_pvp()
	if now_pvp == _was_pvp:
		return
	_was_pvp = now_pvp
	if now_pvp:
		Toaster.toast("Entered a PvP zone. Other players can attack you here.", 3.0, PVP_TOAST_COLOR)
	else:
		Toaster.toast("Back in a safe zone. You're protected from other players.", 3.0, SAFE_TOAST_COLOR)


func set_camera_zoom(zoom: float) -> void:
	var clamped: float = clampf(zoom, 1.0, 4.0)
	camera_3d.size = 12.0 / clamped


func _on_instance_changed_camera_limits(_instance: InstanceClient) -> void:
	pass


func _apply_camera_limits(_map: Map) -> void:
	pass


func set_input_active(active: bool) -> void:
	if not active:
		Input.action_release(&"player_shoot")


func _apply_settings() -> void:
	var settings: Dictionary = ClientState.settings.data.get(&"general", {})
	for property_name: StringName in settings:
		_on_settings_changed(&"general", property_name, settings[property_name])


func _on_settings_changed(section: StringName, property: StringName, value: Variant) -> void:
	match [section, property]:
		[&"general", &"camera_zoom"]:
			set_camera_zoom(value)


func _has_gui_focus() -> bool:
	var focus: Control = get_viewport().gui_get_focus_owner()
	return focus is LineEdit or focus is TextEdit
