extends DataRequestHandler
## Client -> server: begin forging at an anvil once in range.


func data_request_handler(peer_id: int, instance: ServerInstance, args: Dictionary) -> Dictionary:
	if not RateLimiter.check(peer_id, &"forging.start", 6, 1_000):
		return {"ok": false, "reason": "rate_limited"}

	var player: Player = instance.players_by_peer_id.get(peer_id, null)
	if player == null or player.is_dead:
		return {"ok": false, "reason": "invalid"}
	if player.get_node_or_null(^"ChannelInstance") != null:
		return {"ok": false, "reason": "channeling"}

	var anvil_name: StringName = StringName(str(args.get("anvil", "")))
	if anvil_name.is_empty():
		return {"ok": false, "reason": "no_anvil"}

	var map: Map = instance.instance_map
	if map == null or not map.forging_anvils.has(anvil_name):
		return {"ok": false, "reason": "unknown_anvil"}

	var anvil: ForgingAnvil = map.forging_anvils[anvil_name] as ForgingAnvil
	var recipe_id: StringName = StringName(str(args.get("recipe", RecipeDatabase.RECIPE_COPPER_SWORD)))
	return ForgingService.start(peer_id, player, anvil, instance, recipe_id)
