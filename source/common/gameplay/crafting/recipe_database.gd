extends Node
## Central recipe definitions for OSRS-style production skills.


# --- Alchemy (Tier 1–5) ---
const RECIPE_MARROW_CLEANSING_PILL: StringName = &"marrow_cleansing_pill"
const RECIPE_SOUL_FORGING_PILL: StringName = &"soul_forging_pill"
const RECIPE_GOLDEN_CORE_CONDENSING_PILL: StringName = &"golden_core_condensing_pill"
const RECIPE_NASCENT_SOUL_ASCENSION_PILL: StringName = &"nascent_soul_ascension_pill"
const RECIPE_TRIBULATION_DEFYING_PILL: StringName = &"tribulation_defying_pill"

# --- Forging: Weapons (Tier 1–5) ---
const RECIPE_IRON_BROADSWORD: StringName = &"iron_broadsword"
const RECIPE_FROST_SPIRIT_SWORD: StringName = &"frost_spirit_sword"
const RECIPE_FLYING_FROST_SWORD: StringName = &"flying_frost_sword"
const RECIPE_HEAVEN_SPLITTING_SABER: StringName = &"heaven_splitting_saber"
const RECIPE_VOID_ANNIHILATION_BLADE: StringName = &"void_annihilation_blade"

# --- Forging: Chest Armor (Tier 1–5) ---
const RECIPE_COARSE_CLOTH_ROBE: StringName = &"coarse_cloth_robe"
const RECIPE_SILK_DAOIST_ROBE: StringName = &"silk_daoist_robe"
const RECIPE_GOLDEN_SILK_ARMOR: StringName = &"golden_silk_armor"
const RECIPE_NASCENT_SOUL_ROBE: StringName = &"nascent_soul_robe"
const RECIPE_TRIBULATION_WARD_ARMOR: StringName = &"tribulation_ward_armor"

# Legacy aliases — keep existing station/service references working.
const RECIPE_MINOR_BLOOD_PILL: StringName = RECIPE_MARROW_CLEANSING_PILL
const RECIPE_IRONBONE_PILL: StringName = RECIPE_SOUL_FORGING_PILL
const RECIPE_BLOOD_REFINING_PILL: StringName = RECIPE_GOLDEN_CORE_CONDENSING_PILL
const RECIPE_HEAVENLY_TRIBULATION_PILL: StringName = RECIPE_NASCENT_SOUL_ASCENSION_PILL
const RECIPE_VOID_DAO_PILL: StringName = RECIPE_TRIBULATION_DEFYING_PILL
const RECIPE_COPPER_SWORD: StringName = RECIPE_IRON_BROADSWORD
const RECIPE_METEOR_IRON_CHESTPLATE: StringName = RECIPE_SILK_DAOIST_ROBE

## recipe_id -> recipe dictionary
const RECIPES: Dictionary = {
	# Tier 1 — Qi Condensation (Lv 1)
	RECIPE_MARROW_CLEANSING_PILL: {
		"skill": SkillManager.ALCHEMY,
		"level_required": 1,
		"xp_reward": 200,
		"inputs": [
			{"item_id": ItemDatabase.SPIRIT_WOOD, "quantity": 1},
			{"item_id": ItemDatabase.WOLF_CORE, "quantity": 1},
		],
		"outputs": [
			{"item_id": ItemDatabase.MINOR_BLOOD_PILL, "quantity": 1},
		],
	},
	RECIPE_IRON_BROADSWORD: {
		"skill": SkillManager.FORGING,
		"level_required": 1,
		"xp_reward": 250,
		"inputs": [
			{"item_id": ItemDatabase.SPIRIT_COPPER_ORE, "quantity": 2},
		],
		"outputs": [
			{"item_id": ItemDatabase.COPPER_SWORD, "quantity": 1},
		],
	},
	RECIPE_COARSE_CLOTH_ROBE: {
		"skill": SkillManager.FORGING,
		"level_required": 1,
		"xp_reward": 200,
		"inputs": [
			{"item_id": ItemDatabase.SPIRIT_COPPER_ORE, "quantity": 3},
		],
		"outputs": [
			{"item_id": ItemDatabase.COARSE_CLOTH_ROBE, "quantity": 1},
		],
	},

	# Tier 2 — Foundation Establishment (Lv 25)
	RECIPE_SOUL_FORGING_PILL: {
		"skill": SkillManager.ALCHEMY,
		"level_required": 25,
		"xp_reward": 2800,
		"inputs": [
			{"item_id": ItemDatabase.IRONWOOD, "quantity": 1},
			{"item_id": ItemDatabase.DEMONIC_BEAR_CORE, "quantity": 1},
		],
		"outputs": [
			{"item_id": ItemDatabase.IRONBONE_PILL, "quantity": 1},
		],
	},
	RECIPE_FROST_SPIRIT_SWORD: {
		"skill": SkillManager.FORGING,
		"level_required": 25,
		"xp_reward": 3500,
		"inputs": [
			{"item_id": ItemDatabase.METEOR_IRON_ORE, "quantity": 3},
		],
		"outputs": [
			{"item_id": ItemDatabase.FROST_SPIRIT_SWORD, "quantity": 1},
		],
	},
	RECIPE_SILK_DAOIST_ROBE: {
		"skill": SkillManager.FORGING,
		"level_required": 25,
		"xp_reward": 3200,
		"inputs": [
			{"item_id": ItemDatabase.METEOR_IRON_ORE, "quantity": 4},
		],
		"outputs": [
			{"item_id": ItemDatabase.METEOR_IRON_CHESTPLATE, "quantity": 1},
		],
	},

	# Tier 3 — Golden Core (Lv 50)
	RECIPE_GOLDEN_CORE_CONDENSING_PILL: {
		"skill": SkillManager.ALCHEMY,
		"level_required": 50,
		"xp_reward": 32000,
		"inputs": [
			{"item_id": ItemDatabase.BLOODWOOD, "quantity": 1},
			{"item_id": ItemDatabase.WYRM_CORE, "quantity": 1},
		],
		"outputs": [
			{"item_id": ItemDatabase.BLOOD_REFINING_PILL, "quantity": 1},
		],
	},
	RECIPE_FLYING_FROST_SWORD: {
		"skill": SkillManager.FORGING,
		"level_required": 50,
		"xp_reward": 40000,
		"inputs": [
			{"item_id": ItemDatabase.HEAVENLY_STAR_SILVER_ORE, "quantity": 4},
		],
		"outputs": [
			{"item_id": ItemDatabase.FLYING_FROST_SWORD, "quantity": 1},
		],
	},
	RECIPE_GOLDEN_SILK_ARMOR: {
		"skill": SkillManager.FORGING,
		"level_required": 50,
		"xp_reward": 38000,
		"inputs": [
			{"item_id": ItemDatabase.HEAVENLY_STAR_SILVER_ORE, "quantity": 5},
		],
		"outputs": [
			{"item_id": ItemDatabase.GOLDEN_SILK_ARMOR, "quantity": 1},
		],
	},

	# Tier 4 — Nascent Soul (Lv 75)
	RECIPE_NASCENT_SOUL_ASCENSION_PILL: {
		"skill": SkillManager.ALCHEMY,
		"level_required": 75,
		"xp_reward": 125000,
		"inputs": [
			{"item_id": ItemDatabase.HEAVENLY_ASH, "quantity": 1},
			{"item_id": ItemDatabase.DRAGON_CORE, "quantity": 1},
		],
		"outputs": [
			{"item_id": ItemDatabase.HEAVENLY_TRIBULATION_PILL, "quantity": 1},
		],
	},
	RECIPE_HEAVEN_SPLITTING_SABER: {
		"skill": SkillManager.FORGING,
		"level_required": 75,
		"xp_reward": 155000,
		"inputs": [
			{"item_id": ItemDatabase.AZURE_GOLD_ORE, "quantity": 5},
		],
		"outputs": [
			{"item_id": ItemDatabase.HEAVEN_SPLITTING_SABER, "quantity": 1},
		],
	},
	RECIPE_NASCENT_SOUL_ROBE: {
		"skill": SkillManager.FORGING,
		"level_required": 75,
		"xp_reward": 145000,
		"inputs": [
			{"item_id": ItemDatabase.AZURE_GOLD_ORE, "quantity": 6},
		],
		"outputs": [
			{"item_id": ItemDatabase.NASCENT_SOUL_ROBE, "quantity": 1},
		],
	},

	# Tier 5 — Void Tribulation (Lv 90)
	RECIPE_TRIBULATION_DEFYING_PILL: {
		"skill": SkillManager.ALCHEMY,
		"level_required": 90,
		"xp_reward": 280000,
		"inputs": [
			{"item_id": ItemDatabase.VOID_TIMBER, "quantity": 1},
			{"item_id": ItemDatabase.VOID_BEAST_CORE, "quantity": 1},
		],
		"outputs": [
			{"item_id": ItemDatabase.VOID_DAO_PILL, "quantity": 1},
		],
	},
	RECIPE_VOID_ANNIHILATION_BLADE: {
		"skill": SkillManager.FORGING,
		"level_required": 90,
		"xp_reward": 350000,
		"inputs": [
			{"item_id": ItemDatabase.CHAOS_VOID_METAL_ORE, "quantity": 6},
		],
		"outputs": [
			{"item_id": ItemDatabase.VOID_ANNIHILATION_BLADE, "quantity": 1},
		],
	},
	RECIPE_TRIBULATION_WARD_ARMOR: {
		"skill": SkillManager.FORGING,
		"level_required": 90,
		"xp_reward": 330000,
		"inputs": [
			{"item_id": ItemDatabase.CHAOS_VOID_METAL_ORE, "quantity": 7},
		],
		"outputs": [
			{"item_id": ItemDatabase.TRIBULATION_WARD_ARMOR, "quantity": 1},
		],
	},
}


static func has_recipe(recipe_id: StringName) -> bool:
	return RECIPES.has(recipe_id)


static func get_recipe(recipe_id: StringName) -> Dictionary:
	return RECIPES.get(recipe_id, {}) as Dictionary


static func recipe_for_station(station_recipe_id: StringName) -> Dictionary:
	return get_recipe(station_recipe_id)
