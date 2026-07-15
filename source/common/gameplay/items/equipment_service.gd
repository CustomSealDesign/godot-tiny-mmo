class_name EquipmentService
extends RefCounted
## Server-side helper for syncing OSRS equipment slots to connected clients.


static func payload(resource: PlayerResource) -> Dictionary:
	resource.ensure_osrs_equipment()
	var out: Dictionary = {}
	for slot_key: StringName in PlayerResource.OSRS_EQUIPMENT_SLOTS:
		out[String(slot_key)] = resource.get_osrs_equipped_item(slot_key)
	return {"equipment": out}


static func push_to_peer(peer_id: int, resource: PlayerResource) -> void:
	if WorldServer.curr == null or peer_id <= 0 or resource == null:
		return
	WorldServer.curr.data_push.rpc_id(peer_id, &"equipment.update", payload(resource))
