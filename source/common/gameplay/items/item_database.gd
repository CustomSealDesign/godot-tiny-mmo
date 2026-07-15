class_name ItemDatabase
extends RefCounted
## Centralized item definitions for the OSRS-style 28-slot inventory.
## Shared by server and client — lookup by [member item_id] only; no scene resources required.


const SPIRIT_WOOD: int = 9001
const LOW_GRADE_SPIRIT_STONE: int = 9002
const WOLF_CORE: int = 9003
const SPIRIT_COINS: int = 9004

## item_id -> { "name": String, "stackable": bool, "icon": String, "qi_value": int }
const ITEMS: Dictionary = {
	SPIRIT_WOOD: {
		"name": "Spirit Wood",
		"stackable": false,
		"icon": "res://assets/sprites/items/icons/mystic/Inventory_10.png",
		"qi_value": 5,
	},
	LOW_GRADE_SPIRIT_STONE: {
		"name": "Low-Grade Spirit Stone",
		"stackable": true,
		"icon": "res://assets/sprites/items/icons/mystic/Inventory_19.png",
		"qi_value": 0,
	},
	WOLF_CORE: {
		"name": "Wolf Core",
		"stackable": false,
		"icon": "res://assets/sprites/items/icons/mystic/Inventory_14.png",
		"qi_value": 50,
	},
	SPIRIT_COINS: {
		"name": "Spirit Coins",
		"stackable": true,
		"icon": "res://assets/sprites/items/icons/mystic/Inventory_19.png",
		"qi_value": 0,
	},
}


static func has_item(item_id: int) -> bool:
	return ITEMS.has(item_id)


static func get_name(item_id: int) -> String:
	return str(ITEMS.get(item_id, {}).get("name", "Unknown"))


static func is_stackable(item_id: int) -> bool:
	return bool(ITEMS.get(item_id, {}).get("stackable", false))


static func get_qi_value(item_id: int) -> int:
	return int(ITEMS.get(item_id, {}).get("qi_value", 0))


static func is_consumable(item_id: int) -> bool:
	return get_qi_value(item_id) > 0


static func get_icon_path(item_id: int) -> String:
	return str(ITEMS.get(item_id, {}).get("icon", ""))


static func load_icon(item_id: int) -> Texture2D:
	var path: String = get_icon_path(item_id)
	if path.is_empty():
		return null
	return load(path) as Texture2D
