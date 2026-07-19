extends DataRequestHandler
## Client -> server: fetch the authoritative 28-slot inventory array.


func data_request_handler(
	peer_id: int,
	instance: ServerInstance,
	args: Dictionary
) -> Dictionary:
	var player: PlayerResource = instance.world_server.connected_players.get(peer_id)
	if player == null:
		return {"error": 1, "ok": false, "message": "Player not registered."}

	return {"slots": SlotInventory.to_payload(player.slot_inventory)}
