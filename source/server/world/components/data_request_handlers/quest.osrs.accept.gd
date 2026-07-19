extends DataRequestHandler
## Client accepted an OSRS-style dialogue quest from the DialogueHUD.


func data_request_handler(peer_id: int, instance: ServerInstance, args: Dictionary) -> Dictionary:
	var player: Player = instance.players_by_peer_id.get(peer_id, null)
	if player == null:
		return {"ok": false}

	var quest_id: StringName = StringName(str(args.get("quest", "")))
	if quest_id.is_empty():
		return {"ok": false, "reason": "missing_quest"}

	return OsrsQuestService.accept_quest(peer_id, player.player_resource, quest_id)
