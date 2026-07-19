class_name MiningService
extends RefCounted
## Server-authoritative mining loop driven by [TickManager] game ticks.


const TICKS_PER_ROLL: int = 3
const INTERACT_RANGE: float = 90.0
const MOVE_TOLERANCE: float = 2.0

class Session:
	var peer_id: int
	var player: Player
	var vein: SpiritVein
	var instance: ServerInstance
	var anchor_position: Vector2
	var ticks_elapsed: int = 0

	func _init(
		p_peer_id: int,
		p_player: Player,
		p_vein: SpiritVein,
		p_instance: ServerInstance
	) -> void:
		peer_id = p_peer_id
		player = p_player
		vein = p_vein
		instance = p_instance
		anchor_position = p_player.global_position


static var _sessions: Dictionary[int, Session] = {}
static var _tick_connected: bool = false


static func success_chance(mining_xp: int) -> float:
	var level: int = SkillManager.get_level_from_xp(mining_xp)
	return clampf(0.05 + float(level - 1) * 0.04, 0.05, 0.90)


static func start(peer_id: int, player: Player, vein: SpiritVein, instance: ServerInstance) -> Dictionary:
	if player == null or vein == null or instance == null or player.is_dead:
		return {"ok": false, "reason": "invalid"}
	if player.global_position.distance_to(vein.global_position) > INTERACT_RANGE:
		return {"ok": false, "reason": "too_far"}

	var resource: PlayerResource = player.player_resource
	if resource == null:
		return {"ok": false, "reason": "invalid"}

	resource.ensure_osrs_skills()
	var mining_level: int = SkillManager.get_level_from_xp(
		resource.get_osrs_skill_xp(SkillManager.MINING)
	)
	if mining_level < vein.required_level:
		_push_system_message(
			peer_id,
			"You need a Spirit Mining level of %d to mine this." % vein.required_level
		)
		return {"ok": false, "reason": "level", "required_level": vein.required_level}

	WoodcuttingService.stop(peer_id, "mining")
	AlchemyService.stop(peer_id, "mining")
	ForgingService.stop(peer_id, "mining")
	OsrsCombatService.stop(peer_id, "mining")
	stop(peer_id, "restart")
	_ensure_tick_hook()
	var session: Session = Session.new(peer_id, player, vein, instance)
	_sessions[peer_id] = session
	_set_activity(player, PlayerActivityState.State.MINING)
	_push_state(peer_id, true, vein.name)
	return {"ok": true}


static func stop(peer_id: int, reason: String = "cancelled") -> void:
	var session: Session = _sessions.get(peer_id, null)
	if session == null:
		return
	_sessions.erase(peer_id)
	if is_instance_valid(session.player):
		_set_activity(session.player, PlayerActivityState.State.IDLE)
	_push_state(peer_id, false, "", reason)


static func stop_for_player(player: Player, reason: String = "cancelled") -> void:
	if player == null or player.player_resource == null:
		return
	stop(int(player.player_resource.current_peer_id), reason)


static func is_mining(peer_id: int) -> bool:
	return _sessions.has(peer_id)


static func _ensure_tick_hook() -> void:
	if _tick_connected:
		return
	_tick_connected = true
	TickManager.game_tick.connect(_on_game_tick)


static func _on_game_tick() -> void:
	if _sessions.is_empty():
		return
	var peer_ids: Array = _sessions.keys()
	for peer_id_v: Variant in peer_ids:
		_tick_session(int(peer_id_v))


static func _tick_session(peer_id: int) -> void:
	var session: Session = _sessions.get(peer_id, null)
	if session == null:
		return
	if not _session_valid(session):
		stop(peer_id, "invalid")
		return
	if _player_moved(session):
		stop(peer_id, "moved")
		return
	if session.player.global_position.distance_to(session.vein.global_position) > INTERACT_RANGE:
		stop(peer_id, "too_far")
		return

	session.ticks_elapsed += 1
	if session.ticks_elapsed % TICKS_PER_ROLL != 0:
		return

	var resource: PlayerResource = session.player.player_resource
	var mining_xp: int = resource.get_osrs_skill_xp(SkillManager.MINING)
	if randf() > success_chance(mining_xp):
		return

	var item_id: int = session.vein.gather_item_id
	var add_result: Dictionary = SlotInventory.add_item(resource.slot_inventory, item_id, 1)
	if not bool(add_result.get("ok", false)):
		_push_error(peer_id, "Your inventory is full")
		stop(peer_id, "inventory_full")
		return

	var gather_xp: int = maxi(1, session.vein.gather_xp)
	var mining_result: Dictionary = OsrsSkillService.add_xp(
		resource,
		SkillManager.MINING,
		gather_xp
	)
	if WorldServer.curr != null:
		WorldServer.curr.database.save_player(resource)
	InventorySlotService.push_to_peer(peer_id, resource)
	OsrsSkillService.push_to_peer(peer_id, resource)
	_push_result(peer_id, {
		"ok": true,
		"vein": session.vein.name,
		"item_id": item_id,
		"item_name": ItemDatabase.get_name(item_id),
		"item_quantity": 1,
		"mining_xp_gained": int(mining_result.get("xp_gained", 0)),
		"mining_level": int(mining_result.get("level", 1)),
		"mining_leveled_up": bool(mining_result.get("leveled_up", false)),
	})


static func _session_valid(session: Session) -> bool:
	return is_instance_valid(session.player) \
		and is_instance_valid(session.vein) \
		and session.player.player_resource != null \
		and not session.player.is_dead


static func _player_moved(session: Session) -> bool:
	return session.player.global_position.distance_to(session.anchor_position) > MOVE_TOLERANCE


static func _set_activity(player: Player, state: int) -> void:
	player.activity_state = state


static func _push_state(peer_id: int, active: bool, vein_name: String = "", reason: String = "") -> void:
	if WorldServer.curr == null or peer_id <= 0:
		return
	WorldServer.curr.data_push.rpc_id(peer_id, &"mining.state", {
		"active": active,
		"vein": vein_name,
		"reason": reason,
	})


static func _push_result(peer_id: int, payload: Dictionary) -> void:
	if WorldServer.curr == null or peer_id <= 0:
		return
	WorldServer.curr.data_push.rpc_id(peer_id, &"mining.result", payload)


static func _push_error(peer_id: int, message: String) -> void:
	if WorldServer.curr == null or peer_id <= 0:
		return
	WorldServer.curr.data_push.rpc_id(peer_id, &"mining.error", {"message": message})


static func _push_system_message(peer_id: int, message: String) -> void:
	if WorldServer.curr == null or peer_id <= 0:
		return
	WorldServer.curr.data_push.rpc_id(peer_id, &"system.message", {"message": message})
