class_name SlotInventory
extends RefCounted
## Stateless helpers for the fixed 28-slot OSRS-style inventory array.
##
## Format: Array[Dictionary] length 28, each slot:
##     { "item_id": int, "quantity": int }
## Empty slots use item_id 0 and quantity 0.


const SLOT_COUNT: int = 28
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


## Returns true when [param amount] of [param item_id] could be added without mutation.
static func can_add_item(slots: Array, item_id: int, amount: int = 1) -> bool:
	if item_id <= 0 or amount <= 0 or not ItemDatabase.has_item(item_id):
		return false

	var remaining: int = amount
	if ItemDatabase.is_stackable(item_id):
		for slot_v: Variant in slots:
			var slot: Dictionary = slot_v as Dictionary
			if int(slot.get("item_id", 0)) != item_id:
				continue
			var have: int = int(slot.get("quantity", 0))
			if have >= MAX_STACK:
				continue
			var room: int = MAX_STACK - have
			remaining -= mini(room, remaining)
			if remaining <= 0:
				return true
		while remaining > 0:
			if find_first_empty_slot(slots) < 0:
				return false
			var to_place: int = mini(remaining, MAX_STACK)
			remaining -= to_place
		return true

	while remaining > 0:
		if find_first_empty_slot(slots) < 0:
			return false
		remaining -= 1
	return true


## Add items to the bag. Returns { ok, reason, added }.
## reason is "full" when no room remains.
static func add_item(slots: Array, item_id: int, amount: int = 1) -> Dictionary:
	if item_id <= 0 or amount <= 0:
		return {"ok": false, "reason": "invalid", "added": 0}
	if not ItemDatabase.has_item(item_id):
		return {"ok": false, "reason": "unknown_item", "added": 0}

	var remaining: int = amount
	if ItemDatabase.is_stackable(item_id):
		remaining = _stack_into_existing(slots, item_id, remaining)
		while remaining > 0:
			var empty_index: int = find_first_empty_slot(slots)
			if empty_index < 0:
				break
			var to_place: int = mini(remaining, MAX_STACK)
			slots[empty_index] = {"item_id": item_id, "quantity": to_place}
			remaining -= to_place
	else:
		while remaining > 0:
			var empty_index: int = find_first_empty_slot(slots)
			if empty_index < 0:
				break
			slots[empty_index] = {"item_id": item_id, "quantity": 1}
			remaining -= 1

	var added: int = amount - remaining
	if added <= 0:
		return {"ok": false, "reason": "full", "added": 0}
	return {"ok": true, "reason": "", "added": added}


static func remove_one_from_slot(slots: Array, slot_index: int) -> Dictionary:
	if slot_index < 0 or slot_index >= slots.size():
		return {"ok": false, "reason": "invalid_slot", "item_id": 0, "quantity_remaining": 0}

	var slot: Dictionary = slots[slot_index] as Dictionary
	var item_id: int = int(slot.get("item_id", 0))
	var quantity: int = int(slot.get("quantity", 0))
	if item_id <= 0 or quantity <= 0:
		return {"ok": false, "reason": "empty_slot", "item_id": 0, "quantity_remaining": 0}

	var remaining: int = quantity - 1
	if remaining <= 0:
		slots[slot_index] = _empty_slot()
	else:
		slots[slot_index] = {"item_id": item_id, "quantity": remaining}

	return {
		"ok": true,
		"reason": "",
		"item_id": item_id,
		"quantity_remaining": maxi(remaining, 0),
	}


static func count_item(slots: Array, item_id: int) -> int:
	if item_id <= 0:
		return 0
	var total: int = 0
	for slot_v: Variant in slots:
		var slot: Dictionary = slot_v as Dictionary
		if int(slot.get("item_id", 0)) == item_id:
			total += int(slot.get("quantity", 0))
	return total


static func has_amount(slots: Array, item_id: int, amount: int) -> bool:
	return count_item(slots, item_id) >= amount


## Remove [param amount] of [param item_id] across slots. Returns false if insufficient.
static func remove_amount_by_id(slots: Array, item_id: int, amount: int) -> bool:
	if item_id <= 0 or amount <= 0:
		return false
	if count_item(slots, item_id) < amount:
		return false
	var remaining: int = amount
	for i: int in slots.size():
		if remaining <= 0:
			break
		var slot: Dictionary = slots[i] as Dictionary
		if int(slot.get("item_id", 0)) != item_id:
			continue
		var have: int = int(slot.get("quantity", 0))
		var to_remove: int = mini(have, remaining)
		var left: int = have - to_remove
		if left <= 0:
			slots[i] = _empty_slot()
		else:
			slots[i] = {"item_id": item_id, "quantity": left}
		remaining -= to_remove
	return remaining <= 0


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


static func _stack_into_existing(slots: Array, item_id: int, amount: int) -> int:
	var remaining: int = amount
	for i: int in slots.size():
		var slot: Dictionary = slots[i] as Dictionary
		if int(slot.get("item_id", 0)) != item_id:
			continue
		var have: int = int(slot.get("quantity", 0))
		if have >= MAX_STACK:
			continue
		var room: int = MAX_STACK - have
		var to_add: int = mini(room, remaining)
		slot["quantity"] = have + to_add
		slots[i] = slot
		remaining -= to_add
		if remaining <= 0:
			break
	return remaining
