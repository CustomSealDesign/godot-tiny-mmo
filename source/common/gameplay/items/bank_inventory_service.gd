class_name BankInventoryService
extends RefCounted
## Server-side helper for syncing the Sect Vault bank to connected clients.


static func payload(resource: PlayerResource) -> Dictionary:
	return {"slots": BankInventory.to_payload(resource.bank_inventory)}


static func push_to_peer(peer_id: int, resource: PlayerResource) -> void:
	if WorldServer.curr == null or peer_id <= 0 or resource == null:
		return
	WorldServer.curr.data_push.rpc_id(peer_id, &"bank.update", payload(resource))
