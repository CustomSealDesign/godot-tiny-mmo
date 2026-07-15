class_name OsrsSkillService
extends RefCounted
## Server-side helper for OSRS-style skill XP persistence and client sync.


static func payload(resource: PlayerResource) -> Dictionary:
	resource.ensure_osrs_skills()
	var out: Dictionary = {}
	for skill_name: StringName in SkillManager.STARTING_SKILLS:
		var xp: int = resource.get_osrs_skill_xp(skill_name)
		out[String(skill_name)] = {
			"xp": xp,
			"level": SkillManager.get_level_from_xp(xp),
		}
	return {"skills": out}


static func push_to_peer(peer_id: int, resource: PlayerResource) -> void:
	if WorldServer.curr == null or peer_id <= 0 or resource == null:
		return
	WorldServer.curr.data_push.rpc_id(peer_id, &"skills.update", payload(resource))


static func add_xp(resource: PlayerResource, skill_name: StringName, amount: int) -> Dictionary:
	if resource == null or amount <= 0:
		return {}
	resource.ensure_osrs_skills()
	var previous_level: int = SkillManager.get_level_from_xp(resource.get_osrs_skill_xp(skill_name))
	var new_xp: int = resource.get_osrs_skill_xp(skill_name) + amount
	resource.osrs_skills[skill_name] = new_xp
	var new_level: int = SkillManager.get_level_from_xp(new_xp)
	return {
		"skill": String(skill_name),
		"xp": new_xp,
		"level": new_level,
		"xp_gained": amount,
		"leveled_up": new_level > previous_level,
	}
