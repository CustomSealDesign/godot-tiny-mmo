extends DataRequestHandler
## Client pathfinds to the Sect Elder and requests dialogue / quest turn-in.


func data_request_handler(peer_id: int, instance: ServerInstance, args: Dictionary) -> Dictionary:
	var player: Player = instance.players_by_peer_id.get(peer_id, null)
	if player == null:
		return {"ok": false}

	var npc_id: StringName = StringName(str(args.get("npc", "")))
	if npc_id.is_empty():
		return {"ok": false, "reason": "missing_npc"}

	return OsrsQuestService.handle_interact(peer_id, player, instance, npc_id)
