class_name CultivationService
extends RefCounted
## Server-side helper for pushing cultivation / woodcutting state to a connected client.


static func payload(resource: PlayerResource) -> Dictionary:
	return {
		"qi_level": resource.qi_level,
		"cultivation_realm": resource.cultivation_realm,
		"woodcutting_xp": resource.woodcutting_xp,
	}


static func push_to_peer(peer_id: int, resource: PlayerResource) -> void:
	if peer_id <= 0 or resource == null or WorldServer.curr == null:
		return
	WorldServer.curr.data_push.rpc_id(peer_id, &"cultivation.update", payload(resource))


## Xianxia realm progression keyed by total Qi. Sorted ascending; the highest
## threshold the player meets is their current realm.
const REALM_THRESHOLDS: Array[Dictionary] = [
	{"qi": 0, "realm": "Mortal"},
	{"qi": 100, "realm": "Qi Condensation"},
	{"qi": 500, "realm": "Foundation Establishment"},
	{"qi": 2000, "realm": "Core Formation"},
]


## Adds Qi to [param resource] and runs [method check_breakthrough]. Call this
## whenever a player gains Qi so realm crossings are detected in one place.
static func grant_qi(resource: PlayerResource, amount: int) -> Dictionary:
	if resource == null or amount <= 0:
		return {}
	var previous_realm: String = resource.cultivation_realm
	resource.qi_level += amount
	return check_breakthrough(resource.player_id, previous_realm)


## Re-evaluates [param player_id]'s realm from their current Qi total. When the
## realm changes, persists the new tier and pushes [code]cultivation.breakthrough[/code]
## to the connected client for the celebration UI.
static func check_breakthrough(player_id: int, previous_realm: String = "") -> Dictionary:
	var resource: PlayerResource = _resolve_resource(player_id)
	if resource == null:
		return {"broke_through": false}

	if previous_realm.is_empty():
		previous_realm = resource.cultivation_realm

	var new_realm: String = realm_for_qi(resource.qi_level)
	resource.cultivation_realm = new_realm

	var broke_through: bool = new_realm != previous_realm
	var result: Dictionary = {
		"broke_through": broke_through,
		"realm": new_realm,
		"previous_realm": previous_realm,
		"qi_level": resource.qi_level,
	}

	if broke_through:
		if WorldServer.curr != null:
			WorldServer.curr.database.save_player(resource)
		_notify_breakthrough(player_id, result)

	return result


static func realm_for_qi(qi_level: int) -> String:
	var realm: String = "Mortal"
	for entry: Dictionary in REALM_THRESHOLDS:
		if qi_level >= int(entry.get("qi", 0)):
			realm = str(entry.get("realm", realm))
	return realm


static func _resolve_resource(player_id: int) -> PlayerResource:
	if WorldServer.curr == null or player_id <= 0:
		return null
	var peer_id: int = int(WorldServer.curr.player_id_to_peer_id.get(player_id, 0))
	if peer_id > 0 and WorldServer.curr.connected_players.has(peer_id):
		return WorldServer.curr.connected_players[peer_id]
	return WorldServer.curr.database.get_player_resource(player_id)


static func _notify_breakthrough(player_id: int, result: Dictionary) -> void:
	if WorldServer.curr == null:
		return
	var peer_id: int = int(WorldServer.curr.player_id_to_peer_id.get(player_id, 0))
	if peer_id <= 0:
		return

	var plane_position: Vector2 = Vector2.ZERO
	var inst: ServerInstance = WorldServer.curr.instance_manager.find_instance_for_peer(peer_id)
	if inst != null:
		var player: Player = inst.get_player(peer_id)
		if player != null:
			plane_position = player.global_position

	var breakthrough_payload: Dictionary = {
		"realm": str(result.get("realm", "")),
		"previous_realm": str(result.get("previous_realm", "")),
		"qi_level": int(result.get("qi_level", 0)),
		"position": plane_position,
	}
	WorldServer.curr.data_push.rpc_id(peer_id, &"cultivation.breakthrough", breakthrough_payload)

	var resource: PlayerResource = _resolve_resource(player_id)
	if resource != null:
		push_to_peer(peer_id, resource)
