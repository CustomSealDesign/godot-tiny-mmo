class_name BankInventory
extends RefCounted
## Stateless helpers for the fixed 200-slot Sect Vault bank array.
##
## Format: Array[Dictionary] length 200, each slot:
##     { "item_id": int, "quantity": int }
## Empty slots use item_id 0 and quantity 0.
##
## Items in the bank ALWAYS stack (even when non-stackable in the player bag).


const SLOT_COUNT: int = 200
const MAX_STACK: int = 2147483647


static func empty_slots() -> Array:
	var slots: Array = []
	slots.resize(SLOT_COUNT)
	for i: int in SLOT_COUNT:
		slots[i] = _empty_slot()
	return slots


static func normalize(raw: Variant) -> Array:
	var slots: Array = empty_slots()
	if raw is Array:
		for i: int in mini(raw.size(), SLOT_COUNT):
			var entry: Variant = raw[i]
			if entry is Dictionary:
				slots[i] = _normalize_slot(entry as Dictionary)
	return slots


static func is_empty_slot(slot: Dictionary) -> bool:
	return int(slot.get("item_id", 0)) <= 0 or int(slot.get("quantity", 0)) <= 0


static func find_first_empty_slot(slots: Array) -> int:
	for i: int in slots.size():
		if is_empty_slot(slots[i] as Dictionary):
			return i
	return -1


static func find_slot_with_item(slots: Array, item_id: int) -> int:
	if item_id <= 0:
		return -1
	for i: int in slots.size():
		var slot: Dictionary = slots[i] as Dictionary
		if int(slot.get("item_id", 0)) == item_id:
			return i
	return -1


## Number of bank slots currently holding an item (unique occupied slots).
static func count_occupied_slots(slots: Array) -> int:
	var count: int = 0
	for slot_v: Variant in slots:
		if not is_empty_slot(slot_v as Dictionary):
			count += 1
	return count


## Returns true when [param amount] of [param item_id] could be added without mutation.
static func can_add_item(slots: Array, item_id: int, amount: int = 1) -> bool:
	if item_id <= 0 or amount <= 0 or not ItemDatabase.has_item(item_id):
		return false

	var existing_index: int = find_slot_with_item(slots, item_id)
	if existing_index >= 0:
		var have: int = int((slots[existing_index] as Dictionary).get("quantity", 0))
		return have + amount <= MAX_STACK

	if amount > MAX_STACK:
		return false
	# New item type needs a free slot — enforce the 200-slot cap on unique entries.
	return count_occupied_slots(slots) < SLOT_COUNT


## Add items to the bank. Bank slots always stack by item_id. Returns { ok, reason, added }.
static func add_item(slots: Array, item_id: int, amount: int = 1) -> Dictionary:
	if item_id <= 0 or amount <= 0:
		return {"ok": false, "reason": "invalid", "added": 0}
	if not ItemDatabase.has_item(item_id):
		return {"ok": false, "reason": "unknown_item", "added": 0}

	var remaining: int = amount
	var existing_index: int = find_slot_with_item(slots, item_id)
	if existing_index >= 0:
		var slot: Dictionary = slots[existing_index] as Dictionary
		var have: int = int(slot.get("quantity", 0))
		var room: int = MAX_STACK - have
		var to_add: int = mini(room, remaining)
		if to_add > 0:
			slot["quantity"] = have + to_add
			slots[existing_index] = slot
			remaining -= to_add

	while remaining > 0:
		var empty_index: int = find_first_empty_slot(slots)
		if empty_index < 0:
			break
		var to_place: int = mini(remaining, MAX_STACK)
		slots[empty_index] = {"item_id": item_id, "quantity": to_place}
		remaining -= to_place

	var added: int = amount - remaining
	if added <= 0:
		return {"ok": false, "reason": "full", "added": 0}
	return {"ok": true, "reason": "", "added": added}


static func remove_amount_from_slot(slots: Array, slot_index: int, amount: int) -> Dictionary:
	if slot_index < 0 or slot_index >= slots.size() or amount <= 0:
		return {"ok": false, "reason": "invalid", "item_id": 0, "removed": 0}

	var slot: Dictionary = slots[slot_index] as Dictionary
	var item_id: int = int(slot.get("item_id", 0))
	var quantity: int = int(slot.get("quantity", 0))
	if item_id <= 0 or quantity <= 0:
		return {"ok": false, "reason": "empty_slot", "item_id": 0, "removed": 0}
	if quantity < amount:
		return {"ok": false, "reason": "insufficient", "item_id": item_id, "removed": 0}

	var remaining: int = quantity - amount
	if remaining <= 0:
		slots[slot_index] = _empty_slot()
	else:
		slots[slot_index] = {"item_id": item_id, "quantity": remaining}

	return {"ok": true, "reason": "", "item_id": item_id, "removed": amount}


static func to_payload(slots: Array) -> Array:
	var out: Array = []
	for slot_v: Variant in slots:
		var slot: Dictionary = slot_v as Dictionary
		out.append({
			"item_id": int(slot.get("item_id", 0)),
			"quantity": int(slot.get("quantity", 0)),
		})
	return out


static func _empty_slot() -> Dictionary:
	return {"item_id": 0, "quantity": 0}


static func _normalize_slot(raw: Dictionary) -> Dictionary:
	var item_id: int = int(raw.get("item_id", 0))
	var quantity: int = int(raw.get("quantity", 0))
	if item_id <= 0 or quantity <= 0:
		return _empty_slot()
	return {"item_id": item_id, "quantity": quantity}
