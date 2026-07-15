extends Node
## Central recipe definitions for OSRS-style production skills.


const RECIPE_MINOR_BLOOD_PILL: StringName = &"minor_blood_pill"

## recipe_id -> recipe dictionary
const RECIPES: Dictionary = {
	RECIPE_MINOR_BLOOD_PILL: {
		"skill": SkillManager.ALCHEMY,
		"level_required": 1,
		"xp_reward": 25,
		"inputs": [
			{"item_id": ItemDatabase.SPIRIT_WOOD, "quantity": 1},
			{"item_id": ItemDatabase.WOLF_CORE, "quantity": 1},
		],
		"outputs": [
			{"item_id": ItemDatabase.MINOR_BLOOD_PILL, "quantity": 1},
		],
	},
}


static func has_recipe(recipe_id: StringName) -> bool:
	return RECIPES.has(recipe_id)


static func get_recipe(recipe_id: StringName) -> Dictionary:
	return RECIPES.get(recipe_id, {}) as Dictionary


static func recipe_for_station(station_recipe_id: StringName) -> Dictionary:
	return get_recipe(station_recipe_id)
