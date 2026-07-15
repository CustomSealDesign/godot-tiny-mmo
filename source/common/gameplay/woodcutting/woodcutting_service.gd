class_name WoodcuttingService
extends RefCounted
## Server-authoritative woodcutting loop driven by [TickManager] game ticks.


const TICKS_PER_ROLL: int = 3
const INTERACT_RANGE: float = 90.0
const MOVE_TOLERANCE: float = 2.0
const XP_PER_SUCCESS: int = 10
const QI_PER_SUCCESS: int = 5

class Session:
	var peer_id: int
	var player: Player
	var tree: SpiritTree
	var instance: ServerInstance
	var anchor_position: Vector2
	var ticks_elapsed: int = 0

	func _init(
		p_peer_id: int,
		p_player: Player,
		p_tree: SpiritTree,
		p_instance: ServerInstance
	) -> void:
		peer_id = p_peer_id
		player = p_player
		tree = p_tree
		instance = p_instance
		anchor_position = p_player.global_position


static var _sessions: Dictionary[int, Session] = {}
static var _tick_connected: bool = false


static func level_from_xp(xp: int) -> int:
	return maxi(1, 1 + xp / 25)


static func success_chance(xp: int) -> float:
	var level: int = level_from_xp(xp)
	return clampf(0.05 + float(level - 1) * 0.04, 0.05, 0.90)


static func start(peer_id: int, player: Player, tree: SpiritTree, instance: ServerInstance) -> Dictionary:
	if player == null or tree == null or instance == null or player.is_dead:
		return {"ok": false, "reason": "invalid"}
	if player.global_position.distance_to(tree.global_position) > INTERACT_RANGE:
		return {"ok": false, "reason": "too_far"}
	stop(peer_id, "restart")
	_ensure_tick_hook()
	var session: Session = Session.new(peer_id, player, tree, instance)
	_sessions[peer_id] = session
	_set_activity(player, PlayerActivityState.State.WOODCUTTING)
	_push_state(peer_id, true, tree.name)
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


static func is_woodcutting(peer_id: int) -> bool:
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
	if session.player.global_position.distance_to(session.tree.global_position) > INTERACT_RANGE:
		stop(peer_id, "too_far")
		return

	session.ticks_elapsed += 1
	if session.ticks_elapsed % TICKS_PER_ROLL != 0:
		return

	var resource: PlayerResource = session.player.player_resource
	var roll: float = randf()
	if roll > success_chance(resource.woodcutting_xp):
		return

	resource.woodcutting_xp += XP_PER_SUCCESS
	CultivationService.grant_qi(resource, QI_PER_SUCCESS)
	if WorldServer.curr != null:
		WorldServer.curr.database.save_player(resource)
	CultivationService.push_to_peer(peer_id, resource)
	_push_result(peer_id, {
		"ok": true,
		"woodcutting_xp": resource.woodcutting_xp,
		"qi_level": resource.qi_level,
		"cultivation_realm": resource.cultivation_realm,
		"xp_gained": XP_PER_SUCCESS,
		"qi_gained": QI_PER_SUCCESS,
		"tree": session.tree.name,
	})


static func _session_valid(session: Session) -> bool:
	return is_instance_valid(session.player) \
		and is_instance_valid(session.tree) \
		and session.player.player_resource != null \
		and not session.player.is_dead


static func _player_moved(session: Session) -> bool:
	return session.player.global_position.distance_to(session.anchor_position) > MOVE_TOLERANCE


static func _set_activity(player: Player, state: int) -> void:
	player.activity_state = state


static func _push_state(peer_id: int, active: bool, tree_name: String = "", reason: String = "") -> void:
	if WorldServer.curr == null or peer_id <= 0:
		return
	WorldServer.curr.data_push.rpc_id(peer_id, &"woodcutting.state", {
		"active": active,
		"tree": tree_name,
		"reason": reason,
	})


static func _push_result(peer_id: int, payload: Dictionary) -> void:
	if WorldServer.curr == null or peer_id <= 0:
		return
	WorldServer.curr.data_push.rpc_id(peer_id, &"woodcutting.result", payload)
