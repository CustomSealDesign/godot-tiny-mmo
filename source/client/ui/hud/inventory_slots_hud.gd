class_name InventorySlotsHud
extends PanelContainer
## Bottom-right 28-slot OSRS-style inventory grid (4 columns × 7 rows).
## Driven by [code]inventory.update[/code] pushes and [code]inventory.slots.get[/code] pulls.


const COLUMNS: int = 4
const SLOT_SIZE: Vector2 = Vector2(40, 40)

var _grid: GridContainer
var _slot_buttons: Array[Button] = []


func _ready() -> void:
	_build_ui()
	ClientState.inventory_changed.connect(_refresh_from_state)
	ClientState.local_player_ready.connect(func(_lp: LocalPlayer) -> void:
		_refresh_inventory())
	_refresh_from_state()


func _refresh_inventory() -> void:
	if InstanceClient.current == null:
		return
	Client.request_data(&"inventory.slots.get", _apply_slots_payload, {}, InstanceClient.current.name)


func _apply_slots_payload(payload: Variant) -> void:
	if payload is Dictionary and payload.has("error"):
		return
	if payload is Array:
		ClientState.apply_inventory({"slots": payload})
	elif payload is Dictionary:
		ClientState.apply_inventory(payload)


func _refresh_from_state() -> void:
	var slots: Array = ClientState.slot_inventory
	for i: int in _slot_buttons.size():
		var button: Button = _slot_buttons[i]
		_clear_slot_button(button)
		if i >= slots.size():
			continue
		var slot: Dictionary = slots[i] as Dictionary
		var item_id: int = int(slot.get("item_id", 0))
		var quantity: int = int(slot.get("quantity", 0))
		if item_id <= 0 or quantity <= 0:
			continue
		var icon: Texture2D = ItemDatabase.load_icon(item_id)
		if icon != null:
			PixelIcon.set_art(button, icon)
		button.tooltip_text = ItemDatabase.get_name(item_id)
		if quantity > 1:
			var qty: Label = Label.new()
			qty.text = str(quantity)
			qty.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT)
			qty.offset_left = -28.0
			qty.offset_top = -16.0
			qty.mouse_filter = Control.MOUSE_FILTER_IGNORE
			qty.add_theme_font_size_override(&"font_size", 11)
			button.add_child(qty)


func _build_ui() -> void:
	anchor_left = 1.0
	anchor_right = 1.0
	anchor_top = 1.0
	anchor_bottom = 1.0
	offset_left = -190.0
	offset_top = -320.0
	offset_right = -10.0
	offset_bottom = -10.0
	grow_horizontal = Control.GROW_DIRECTION_BEGIN
	grow_vertical = Control.GROW_DIRECTION_BEGIN
	mouse_filter = Control.MOUSE_FILTER_IGNORE

	var panel: StyleBoxFlat = StyleBoxFlat.new()
	panel.bg_color = Color(0.06, 0.06, 0.08, 0.65)
	panel.set_corner_radius_all(8)
	panel.content_margin_top = 8
	panel.content_margin_bottom = 8
	panel.content_margin_left = 8
	panel.content_margin_right = 8
	add_theme_stylebox_override(&"panel", panel)

	var box: VBoxContainer = VBoxContainer.new()
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(box)

	var title: Label = Label.new()
	title.text = "Inventory"
	title.add_theme_font_size_override(&"font_size", 13)
	title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(title)

	_grid = GridContainer.new()
	_grid.columns = COLUMNS
	_grid.add_theme_constant_override(&"h_separation", 4)
	_grid.add_theme_constant_override(&"v_separation", 4)
	_grid.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(_grid)

	for _i: int in SlotInventory.SLOT_COUNT:
		var button: Button = Button.new()
		button.custom_minimum_size = SLOT_SIZE
		button.clip_contents = true
		button.focus_mode = Control.FOCUS_NONE
		button.mouse_filter = Control.MOUSE_FILTER_PASS
		_grid.add_child(button)
		_slot_buttons.append(button)


func _clear_slot_button(button: Button) -> void:
	PixelIcon.set_art(button, null)
	button.tooltip_text = ""
	for child: Node in button.get_children():
		child.queue_free()
