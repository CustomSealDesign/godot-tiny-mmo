class_name LocalPlayer
extends Player3D

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
var _has_nav_target: bool = false
var _woodcutting: bool = false

var fid_position: int
var fid_flipped: int
var fid_anim: int
var fid_pivot: int

var synchronizer_manager: StateSynchronizerManagerClient

@onready var camera_3d: Camera3D = $Camera3D
@onready var nav_agent: NavigationAgent3D = $Body/NavigationAgent3D
@onready var click_input: ClickMoveInput3D = $ClickMoveInput3D


func _ready() -> void:
	ClientState.local_player = self
	ClientState.local_player_ready.emit(self)

	super._ready()

	_was_pvp = is_pvp()

	fid_position = PathRegistry.id_of(":position")
	fid_flipped = PathRegistry.id_of(":flipped")
	fid_anim = PathRegistry.id_of(":anim")
	fid_pivot = PathRegistry.id_of(":pivot")

	click_input.camera = camera_3d
	click_input.body = body
	click_input.floor_collision_mask = floor_collision_mask
	click_input.move_target_selected.connect(_on_move_target_selected)
	click_input.look_plane_changed.connect(_on_look_plane_changed)

	nav_agent.path_desired_distance = 0.35
	nav_agent.target_desired_distance = 0.35
	nav_agent.avoidance_enabled = true
	nav_agent.velocity_computed.connect(_on_nav_velocity_computed)

	await get_tree().physics_frame
	nav_agent.target_position = body.global_position

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


func _physics_process(delta: float) -> void:
	process_input()
	process_movement()
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


func _on_move_target_selected(world_position: Vector3) -> void:
	if _dead or ClientState.menu_open or Time.get_ticks_msec() < _movement_lock_until_ms:
		return
	if _woodcutting:
		request_stop_woodcutting()
	if _channeling and not _channel_mobile:
		_cancel_channel()
	nav_agent.target_position = world_position
	_has_nav_target = true


func _on_look_plane_changed(plane_direction: Vector2) -> void:
	look_direction = plane_direction


func process_movement() -> void:
	if _dead or ClientState.menu_open or Time.get_ticks_msec() < _movement_lock_until_ms \
			or (_channeling and not _channel_mobile) or _woodcutting:
		body.velocity = Vector3.ZERO
		body.move_and_slide()
		_publish_plane_from_body()
		return

	var move_speed: float = stats_component.get_stat(Stat.MOVE_SPEED)
	if move_speed <= 0.0:
		move_speed = speed
	if _channeling and _channel_mobile:
		move_speed *= _channel_speed_mult

	if _has_nav_target and not nav_agent.is_navigation_finished():
		var next_position: Vector3 = nav_agent.get_next_path_position()
		var direction: Vector3 = next_position - body.global_position
		direction.y = 0.0
		if direction.length_squared() > 0.0001:
			var desired_velocity: Vector3 = direction.normalized() * move_speed
			if nav_agent.avoidance_enabled:
				nav_agent.set_velocity(desired_velocity)
			else:
				body.velocity = desired_velocity
				body.move_and_slide()
				_publish_plane_from_body()
			input_direction = PlaneCoords3D.world_to_plane(desired_velocity).normalized()
		else:
			body.velocity = Vector3.ZERO
			body.move_and_slide()
			_publish_plane_from_body()
			input_direction = Vector2.ZERO
	else:
		_has_nav_target = false
		body.velocity = Vector3.ZERO
		body.move_and_slide()
		_publish_plane_from_body()
		input_direction = Vector2.ZERO


func _on_nav_velocity_computed(safe_velocity: Vector3) -> void:
	safe_velocity.y = 0.0
	body.velocity = safe_velocity
	body.move_and_slide()
	_publish_plane_from_body()
	input_direction = PlaneCoords3D.world_to_plane(safe_velocity).normalized()


func _publish_plane_from_body() -> void:
	global_position = PlaneCoords3D.world_to_plane(body.global_position)


func process_input() -> void:
	click_input.enabled = not (_dead or _has_gui_focus() or ClientState.menu_open \
			or Time.get_ticks_msec() < _movement_lock_until_ms)

	if _dead or _has_gui_focus() or ClientState.menu_open or Time.get_ticks_msec() < _movement_lock_until_ms:
		action_input = false
		return

	if _woodcutting:
		action_input = false
		return

	action_input = Input.is_action_pressed(&"player_shoot") and not click_input.ui_blocks_combat()

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


func process_animation(delta: float) -> void:
	if _dead:
		if anim != Animations.DEATH:
			anim = Animations.DEATH
		return
	flipped = look_direction.x < 0.0
	_update_hand_pivot(delta)
	if _woodcutting:
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
	var plane_position: Vector2 = get_plane_position()
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
	nav_agent.target_position = body.global_position
	_has_nav_target = false
	_dead = false


func _on_sparring_match_state(payload: Dictionary) -> void:
	var pos: Variant = payload.get("position", null)
	if pos is Vector2 and pos != Vector2.ZERO:
		apply_plane_position(pos)
		nav_agent.target_position = body.global_position
		_has_nav_target = false
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
		nav_agent.target_position = body.global_position
		_has_nav_target = false
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
	if _channeling or _woodcutting or InstanceClient.current == null:
		return
	Client.request_data(&"recall.start", Callable(), {}, InstanceClient.current.name)


func is_woodcutting() -> bool:
	return _woodcutting


func request_stop_woodcutting() -> void:
	if not _woodcutting or InstanceClient.current == null:
		return
	Client.request_data(&"woodcutting.stop", Callable(), {}, InstanceClient.current.name)


func _on_woodcutting_state(payload: Dictionary) -> void:
	var active: bool = bool(payload.get("active", false))
	_woodcutting = active
	if active:
		_has_nav_target = false
		nav_agent.target_position = body.global_position
		input_direction = Vector2.ZERO


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
	click_input.enabled = active
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
