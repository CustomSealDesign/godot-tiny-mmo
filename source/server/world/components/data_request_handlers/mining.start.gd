extends DataRequestHandler
## Client -> server: begin mining at a spirit vein once in range.


func data_request_handler(peer_id: int, instance: ServerInstance, args: Dictionary) -> Dictionary:
	if not RateLimiter.check(peer_id, &"mining.start", 6, 1_000):
		return {"ok": false, "reason": "rate_limited"}

	var player: Player = instance.players_by_peer_id.get(peer_id, null)
	if player == null or player.is_dead:
		return {"ok": false, "reason": "invalid"}
	if player.get_node_or_null(^"ChannelInstance") != null:
		return {"ok": false, "reason": "channeling"}

	var vein_name: StringName = StringName(str(args.get("vein", "")))
	if vein_name.is_empty():
		return {"ok": false, "reason": "no_vein"}

	var map: Map = instance.instance_map
	if map == null or not map.spirit_veins.has(vein_name):
		return {"ok": false, "reason": "unknown_vein"}

	var vein: SpiritVein = map.spirit_veins[vein_name] as SpiritVein
	return MiningService.start(peer_id, player, vein, instance)
