class_name InventorySlotService
extends RefCounted
## Server-side helper for syncing the 28-slot inventory to connected clients.


static func payload(resource: PlayerResource) -> Dictionary:
	return {"slots": SlotInventory.to_payload(resource.slot_inventory)}


static func push_to_peer(peer_id: int, resource: PlayerResource) -> void:
	if WorldServer.curr == null or peer_id <= 0 or resource == null:
		return
	WorldServer.curr.data_push.rpc_id(peer_id, &"inventory.update", payload(resource))
