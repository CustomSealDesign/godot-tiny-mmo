class_name EquipmentService
extends RefCounted
## Server-side helper for syncing OSRS equipment slots to connected clients.


static func payload(resource: PlayerResource) -> Dictionary:
	resource.ensure_osrs_equipment()
	var out: Dictionary = {}
	for slot_key: StringName in PlayerResource.OSRS_EQUIPMENT_SLOTS:
		out[String(slot_key)] = resource.get_osrs_equipped_item(slot_key)
	return {"equipment": out}


static func get_total_equipment_stats(resource: PlayerResource) -> Dictionary:
	resource.ensure_osrs_equipment()
	var totals: Dictionary = {}
	for slot_key: StringName in PlayerResource.OSRS_EQUIPMENT_SLOTS:
		var item_id: int = resource.get_osrs_equipped_item(slot_key)
		if item_id <= 0:
			continue
		for stat_key: String in ItemDatabase.get_equipment_stats(item_id):
			totals[stat_key] = int(totals.get(stat_key, 0)) + ItemDatabase.get_equipment_stat(item_id, stat_key)
	return totals


static func push_to_peer(peer_id: int, resource: PlayerResource) -> void:
	if WorldServer.curr == null or peer_id <= 0 or resource == null:
		return
	WorldServer.curr.data_push.rpc_id(peer_id, &"equipment.update", payload(resource))
