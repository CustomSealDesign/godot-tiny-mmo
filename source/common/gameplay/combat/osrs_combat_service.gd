class_name OsrsCombatService
extends RefCounted
## Server-authoritative OSRS-style melee combat driven by [TickManager] game ticks.


const TICKS_PER_ATTACK: int = 4
const INTERACT_RANGE: float = 90.0
const MOVE_TOLERANCE: float = 2.0
const DEFAULT_DAMAGE: int = 5

class Session:
	var peer_id: int
	var player: Player
	var enemy: Enemy
	var instance: ServerInstance
	var anchor_position: Vector2
	var ticks_elapsed: int = 0

	func _init(
		p_peer_id: int,
		p_player: Player,
		p_enemy: Enemy,
		p_instance: ServerInstance
	) -> void:
		peer_id = p_peer_id
		player = p_player
		enemy = p_enemy
		instance = p_instance
		anchor_position = p_player.global_position


static var _sessions: Dictionary[int, Session] = {}
static var _tick_connected: bool = false


static func start(peer_id: int, player: Player, enemy: Enemy, instance: ServerInstance) -> Dictionary:
	if player == null or enemy == null or instance == null or player.is_dead:
		return {"ok": false, "reason": "invalid"}
	if enemy.is_dead:
		return {"ok": false, "reason": "enemy_dead"}
	if player.global_position.distance_to(enemy.global_position) > INTERACT_RANGE:
		return {"ok": false, "reason": "too_far"}

	WoodcuttingService.stop(peer_id, "combat")
	MiningService.stop(peer_id, "combat")
	AlchemyService.stop(peer_id, "combat")
	ForgingService.stop(peer_id, "combat")
	stop(peer_id, "restart")

	_ensure_tick_hook()
	var session: Session = Session.new(peer_id, player, enemy, instance)
	_sessions[peer_id] = session
	_set_activity(player, PlayerActivityState.State.COMBAT)
	_push_state(peer_id, true, enemy.name)
	OsrsCombatService.push_enemy_update(instance, enemy)
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


static func stop_for_enemy(enemy: Enemy, reason: String = "enemy_gone") -> void:
	if enemy == null:
		return
	var peer_ids: Array = _sessions.keys()
	for peer_id_v: Variant in peer_ids:
		var peer_id: int = int(peer_id_v)
		var session: Session = _sessions.get(peer_id, null)
		if session != null and session.enemy == enemy:
			stop(peer_id, reason)


static func is_in_combat(peer_id: int) -> bool:
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
	if session.player.global_position.distance_to(session.enemy.global_position) > INTERACT_RANGE:
		stop(peer_id, "too_far")
		return
	if session.enemy.is_dead:
		stop(peer_id, "enemy_dead")
		return

	session.ticks_elapsed += 1
	if session.ticks_elapsed % TICKS_PER_ATTACK != 0:
		return

	var damage: int = session.enemy.get_attack_damage()
	session.enemy.apply_damage(damage, session.instance)


static func _session_valid(session: Session) -> bool:
	return is_instance_valid(session.player) \
		and is_instance_valid(session.enemy) \
		and session.player.player_resource != null \
		and not session.player.is_dead


static func _player_moved(session: Session) -> bool:
	return session.player.global_position.distance_to(session.anchor_position) > MOVE_TOLERANCE


static func _set_activity(player: Player, state: int) -> void:
	player.activity_state = state


static func _push_state(peer_id: int, active: bool, enemy_name: String = "", reason: String = "") -> void:
	if WorldServer.curr == null or peer_id <= 0:
		return
	WorldServer.curr.data_push.rpc_id(peer_id, &"combat.state", {
		"active": active,
		"enemy": enemy_name,
		"reason": reason,
	})


static func push_enemy_update(instance: ServerInstance, enemy: Enemy) -> void:
	if WorldServer.curr == null or instance == null or enemy == null:
		return
	var payload: Dictionary = enemy.get_sync_payload()
	WorldServer.curr.propagate_rpc(
		WorldServer.curr.data_push.bind(&"combat.enemy_update", payload),
		instance.name
	)
