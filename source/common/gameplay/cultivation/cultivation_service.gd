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


const REALM_THRESHOLDS: Array[Dictionary] = [
	{"qi": 0, "realm": "Mortal"},
	{"qi": 50, "realm": "Qi Condensation"},
	{"qi": 200, "realm": "Foundation Establishment"},
	{"qi": 500, "realm": "Core Formation"},
]


static func grant_qi(resource: PlayerResource, amount: int) -> void:
	if resource == null or amount <= 0:
		return
	resource.qi_level += amount
	resource.cultivation_realm = realm_for_qi(resource.qi_level)


static func realm_for_qi(qi_level: int) -> String:
	var realm: String = "Mortal"
	for entry: Dictionary in REALM_THRESHOLDS:
		if qi_level >= int(entry.get("qi", 0)):
			realm = str(entry.get("realm", realm))
	return realm
