class_name ItemDatabase
extends RefCounted
## Centralized item definitions for the OSRS-style 28-slot inventory.
## Shared by server and client — lookup by [member item_id] only; no scene resources required.


const SPIRIT_WOOD: int = 9001
const LOW_GRADE_SPIRIT_STONE: int = 9002

## item_id -> { "name": String, "stackable": bool, "icon": String }
const ITEMS: Dictionary = {
	SPIRIT_WOOD: {
		"name": "Spirit Wood",
		"stackable": false,
		"icon": "res://assets/sprites/items/icons/mystic/Inventory_10.png",
	},
	LOW_GRADE_SPIRIT_STONE: {
		"name": "Low-Grade Spirit Stone",
		"stackable": true,
		"icon": "res://assets/sprites/items/icons/mystic/Inventory_19.png",
	},
}


static func has_item(item_id: int) -> bool:
	return ITEMS.has(item_id)


static func get_name(item_id: int) -> String:
	return str(ITEMS.get(item_id, {}).get("name", "Unknown"))


static func is_stackable(item_id: int) -> bool:
	return bool(ITEMS.get(item_id, {}).get("stackable", false))


static func get_icon_path(item_id: int) -> String:
	return str(ITEMS.get(item_id, {}).get("icon", ""))


static func load_icon(item_id: int) -> Texture2D:
	var path: String = get_icon_path(item_id)
	if path.is_empty():
		return null
	return load(path) as Texture2D
