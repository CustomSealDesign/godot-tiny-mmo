class_name AlchemyService
extends RefCounted
## Server-authoritative alchemy loop driven by [TickManager] game ticks.


const TICKS_PER_CRAFT: int = 3
const INTERACT_RANGE: float = 90.0
const MOVE_TOLERANCE: float = 2.0
const DEFAULT_RECIPE: StringName = RecipeDatabase.RECIPE_MINOR_BLOOD_PILL

class Session:
	var peer_id: int
	var player: Player
	var cauldron: AlchemyCauldron
	var instance: ServerInstance
	var anchor_position: Vector2
	var recipe_id: StringName
	var ticks_elapsed: int = 0

	func _init(
		p_peer_id: int,
		p_player: Player,
		p_cauldron: AlchemyCauldron,
		p_instance: ServerInstance,
		p_recipe_id: StringName
	) -> void:
		peer_id = p_peer_id
		player = p_player
		cauldron = p_cauldron
		instance = p_instance
		anchor_position = p_player.global_position
		recipe_id = p_recipe_id


static var _sessions: Dictionary[int, Session] = {}
static var _tick_connected: bool = false


static func start(
	peer_id: int,
	player: Player,
	cauldron: AlchemyCauldron,
	instance: ServerInstance,
	recipe_id: StringName = DEFAULT_RECIPE
) -> Dictionary:
	if player == null or cauldron == null or instance == null or player.is_dead:
		return {"ok": false, "reason": "invalid"}
	if not RecipeDatabase.has_recipe(recipe_id):
		return {"ok": false, "reason": "unknown_recipe"}
	if player.global_position.distance_to(cauldron.global_position) > INTERACT_RANGE:
		return {"ok": false, "reason": "too_far"}

	var resource: PlayerResource = player.player_resource
	if resource == null:
		return {"ok": false, "reason": "invalid"}

	var recipe: Dictionary = RecipeDatabase.get_recipe(recipe_id)
	var required_level: int = int(recipe.get("level_required", 1))
	var alchemy_level: int = SkillManager.get_level_from_xp(resource.get_osrs_skill_xp(SkillManager.ALCHEMY))
	if alchemy_level < required_level:
		_push_system_message(
			peer_id,
			"You need an Alchemy level of %d to craft this." % required_level
		)
		return {"ok": false, "reason": "level", "required_level": required_level}

	WoodcuttingService.stop(peer_id, "alchemy")
	OsrsCombatService.stop(peer_id, "alchemy")
	stop(peer_id, "restart")

	_ensure_tick_hook()
	var session: Session = Session.new(peer_id, player, cauldron, instance, recipe_id)
	_sessions[peer_id] = session
	_set_activity(player, PlayerActivityState.State.ALCHEMY)
	_push_state(peer_id, true, cauldron.name)
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


static func is_alchemizing(peer_id: int) -> bool:
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
	if session.player.global_position.distance_to(session.cauldron.global_position) > INTERACT_RANGE:
		stop(peer_id, "too_far")
		return

	session.ticks_elapsed += 1
	if session.ticks_elapsed % TICKS_PER_CRAFT != 0:
		return

	var resource: PlayerResource = session.player.player_resource
	var recipe: Dictionary = RecipeDatabase.get_recipe(session.recipe_id)
	if not _has_ingredients(resource.slot_inventory, recipe):
		stop(peer_id, "no_ingredients")
		return

	if not _consume_ingredients(resource.slot_inventory, recipe):
		stop(peer_id, "no_ingredients")
		return

	for output_v: Variant in recipe.get("outputs", []):
		var output: Dictionary = output_v as Dictionary
		var add_result: Dictionary = SlotInventory.add_item(
			resource.slot_inventory,
			int(output.get("item_id", 0)),
			int(output.get("quantity", 1))
		)
		if not bool(add_result.get("ok", false)):
			_push_error(peer_id, "Your inventory is full")
			stop(peer_id, "inventory_full")
			return

	var skill_name: StringName = recipe.get("skill", SkillManager.ALCHEMY) as StringName
	var xp_result: Dictionary = OsrsSkillService.add_xp(resource, skill_name, int(recipe.get("xp_reward", 0)))
	if WorldServer.curr != null:
		WorldServer.curr.database.save_player(resource)
	InventorySlotService.push_to_peer(peer_id, resource)
	OsrsSkillService.push_to_peer(peer_id, resource)
	_push_result(peer_id, {
		"ok": true,
		"recipe": String(session.recipe_id),
		"xp_gained": int(xp_result.get("xp_gained", 0)),
		"skill": str(skill_name),
		"level": int(xp_result.get("level", 1)),
		"xp": int(xp_result.get("xp", 0)),
		"leveled_up": bool(xp_result.get("leveled_up", false)),
	})


static func _has_ingredients(slots: Array, recipe: Dictionary) -> bool:
	for input_v: Variant in recipe.get("inputs", []):
		var input: Dictionary = input_v as Dictionary
		if not SlotInventory.has_amount(
			slots,
			int(input.get("item_id", 0)),
			int(input.get("quantity", 1))
		):
			return false
	return true


static func _consume_ingredients(slots: Array, recipe: Dictionary) -> bool:
	for input_v: Variant in recipe.get("inputs", []):
		var input: Dictionary = input_v as Dictionary
		if not SlotInventory.remove_amount_by_id(
			slots,
			int(input.get("item_id", 0)),
			int(input.get("quantity", 1))
		):
			return false
	return true


static func _session_valid(session: Session) -> bool:
	return is_instance_valid(session.player) \
		and is_instance_valid(session.cauldron) \
		and session.player.player_resource != null \
		and not session.player.is_dead


static func _player_moved(session: Session) -> bool:
	return session.player.global_position.distance_to(session.anchor_position) > MOVE_TOLERANCE


static func _set_activity(player: Player, state: int) -> void:
	player.activity_state = state


static func _push_state(peer_id: int, active: bool, cauldron_name: String = "", reason: String = "") -> void:
	if WorldServer.curr == null or peer_id <= 0:
		return
	WorldServer.curr.data_push.rpc_id(peer_id, &"alchemy.state", {
		"active": active,
		"cauldron": cauldron_name,
		"reason": reason,
	})


static func _push_result(peer_id: int, payload: Dictionary) -> void:
	if WorldServer.curr == null or peer_id <= 0:
		return
	WorldServer.curr.data_push.rpc_id(peer_id, &"alchemy.result", payload)


static func _push_error(peer_id: int, message: String) -> void:
	if WorldServer.curr == null or peer_id <= 0:
		return
	WorldServer.curr.data_push.rpc_id(peer_id, &"alchemy.error", {"message": message})


static func _push_system_message(peer_id: int, message: String) -> void:
	if WorldServer.curr == null or peer_id <= 0:
		return
	WorldServer.curr.data_push.rpc_id(peer_id, &"system.message", {"message": message})
