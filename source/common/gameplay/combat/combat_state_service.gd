class_name CombatStateService
extends RefCounted
## Server-side helper for combat stance persistence and client sync.


static func payload(resource: PlayerResource) -> Dictionary:
	resource.ensure_combat_stance()
	return {"combat_stance": resource.get_combat_stance()}


static func push_to_peer(peer_id: int, resource: PlayerResource) -> void:
	if WorldServer.curr == null or peer_id <= 0 or resource == null:
		return
	WorldServer.curr.data_push.rpc_id(peer_id, &"combat.stance.update", payload(resource))
