extends DataRequestHandler
## Client -> server: begin alchemy at a cauldron once in range.


func data_request_handler(peer_id: int, instance: ServerInstance, args: Dictionary) -> Dictionary:
	if not RateLimiter.check(peer_id, &"alchemy.start", 6, 1_000):
		return {"ok": false, "reason": "rate_limited"}

	var player: Player = instance.players_by_peer_id.get(peer_id, null)
	if player == null or player.is_dead:
		return {"ok": false, "reason": "invalid"}
	if player.get_node_or_null(^"ChannelInstance") != null:
		return {"ok": false, "reason": "channeling"}

	var cauldron_name: StringName = StringName(str(args.get("cauldron", "")))
	if cauldron_name.is_empty():
		return {"ok": false, "reason": "no_cauldron"}

	var map: Map = instance.instance_map
	if map == null or not map.alchemy_cauldrons.has(cauldron_name):
		return {"ok": false, "reason": "unknown_cauldron"}

	var cauldron: AlchemyCauldron = map.alchemy_cauldrons[cauldron_name] as AlchemyCauldron
	var recipe_id: StringName = StringName(str(args.get("recipe", RecipeDatabase.RECIPE_MINOR_BLOOD_PILL)))
	return AlchemyService.start(peer_id, player, cauldron, instance, recipe_id)
