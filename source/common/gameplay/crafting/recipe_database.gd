extends Node
## Central recipe definitions for OSRS-style production skills.


const RECIPE_MINOR_BLOOD_PILL: StringName = &"minor_blood_pill"
const RECIPE_IRONBONE_PILL: StringName = &"ironbone_pill"
const RECIPE_BLOOD_REFINING_PILL: StringName = &"blood_refining_pill"
const RECIPE_HEAVENLY_TRIBULATION_PILL: StringName = &"heavenly_tribulation_pill"
const RECIPE_VOID_DAO_PILL: StringName = &"void_dao_pill"
const RECIPE_COPPER_SWORD: StringName = &"copper_sword"
const RECIPE_METEOR_IRON_CHESTPLATE: StringName = &"meteor_iron_chestplate"

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
	RECIPE_IRONBONE_PILL: {
		"skill": SkillManager.ALCHEMY,
		"level_required": 25,
		"xp_reward": 400,
		"inputs": [
			{"item_id": ItemDatabase.IRONWOOD, "quantity": 1},
			{"item_id": ItemDatabase.DEMONIC_BEAR_CORE, "quantity": 1},
		],
		"outputs": [
			{"item_id": ItemDatabase.IRONBONE_PILL, "quantity": 1},
		],
	},
	RECIPE_BLOOD_REFINING_PILL: {
		"skill": SkillManager.ALCHEMY,
		"level_required": 50,
		"xp_reward": 2500,
		"inputs": [
			{"item_id": ItemDatabase.BLOODWOOD, "quantity": 1},
			{"item_id": ItemDatabase.WYRM_CORE, "quantity": 1},
		],
		"outputs": [
			{"item_id": ItemDatabase.BLOOD_REFINING_PILL, "quantity": 1},
		],
	},
	RECIPE_HEAVENLY_TRIBULATION_PILL: {
		"skill": SkillManager.ALCHEMY,
		"level_required": 75,
		"xp_reward": 12000,
		"inputs": [
			{"item_id": ItemDatabase.HEAVENLY_ASH, "quantity": 1},
			{"item_id": ItemDatabase.DRAGON_CORE, "quantity": 1},
		],
		"outputs": [
			{"item_id": ItemDatabase.HEAVENLY_TRIBULATION_PILL, "quantity": 1},
		],
	},
	RECIPE_VOID_DAO_PILL: {
		"skill": SkillManager.ALCHEMY,
		"level_required": 90,
		"xp_reward": 35000,
		"inputs": [
			{"item_id": ItemDatabase.VOID_TIMBER, "quantity": 1},
			{"item_id": ItemDatabase.VOID_BEAST_CORE, "quantity": 1},
		],
		"outputs": [
			{"item_id": ItemDatabase.VOID_DAO_PILL, "quantity": 1},
		],
	},
	RECIPE_COPPER_SWORD: {
		"skill": SkillManager.FORGING,
		"level_required": 1,
		"xp_reward": 50,
		"inputs": [
			{"item_id": ItemDatabase.SPIRIT_COPPER_ORE, "quantity": 2},
		],
		"outputs": [
			{"item_id": ItemDatabase.COPPER_SWORD, "quantity": 1},
		],
	},
	RECIPE_METEOR_IRON_CHESTPLATE: {
		"skill": SkillManager.FORGING,
		"level_required": 25,
		"xp_reward": 500,
		"inputs": [
			{"item_id": ItemDatabase.METEOR_IRON_ORE, "quantity": 3},
		],
		"outputs": [
			{"item_id": ItemDatabase.METEOR_IRON_CHESTPLATE, "quantity": 1},
		],
	},
}


static func has_recipe(recipe_id: StringName) -> bool:
	return RECIPES.has(recipe_id)


static func get_recipe(recipe_id: StringName) -> Dictionary:
	return RECIPES.get(recipe_id, {}) as Dictionary


static func recipe_for_station(station_recipe_id: StringName) -> Dictionary:
	return get_recipe(station_recipe_id)
