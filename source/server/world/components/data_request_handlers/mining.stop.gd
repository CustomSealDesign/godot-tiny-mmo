extends DataRequestHandler
## Client -> server: stop the active mining loop (move away / click elsewhere).


func data_request_handler(peer_id: int, instance: ServerInstance, _args: Dictionary) -> Dictionary:
	if not RateLimiter.check(peer_id, &"mining.stop", 12, 1_000):
		return {"ok": false, "reason": "rate_limited"}

	var player: Player = instance.players_by_peer_id.get(peer_id, null)
	if player == null:
		return {"ok": false, "reason": "invalid"}

	if not MiningService.is_mining(peer_id):
		return {"ok": true, "active": false}

	MiningService.stop(peer_id, "client_cancel")
	return {"ok": true, "active": false}
