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
