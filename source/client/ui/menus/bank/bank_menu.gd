class_name BankHud
extends MenuShell
## Sect Vault bank UI — inventory (28 slots) on the left, bank grid (200 slots) on
## the right. Click inventory to deposit; click bank to withdraw one item.


const INVENTORY_COLUMNS: int = 4
const BANK_COLUMNS: int = 8
const SLOT_SIZE: Vector2 = Vector2(40, 40)
const SLOT_FRAME_TEXTURE: Texture2D = preload("res://assets/ui/menus/ui_slot_frame.svg")

var _vault_key: String = ""
var _inventory_buttons: Array[Button] = []
var _bank_buttons: Array[Button] = []
var _inventory_grid: GridContainer
var _bank_grid: GridContainer
var _busy: bool = false


func _ready() -> void:
	build_shell("Sect Vault", $Body, true)
	_build_panels()
	ClientState.inventory_changed.connect(_refresh_inventory)
	ClientState.bank_changed.connect(_refresh_bank)
	visibility_changed.connect(_on_visibility_changed)


func open(arg: Variant) -> void:
	if arg is Dictionary:
		_vault_key = str((arg as Dictionary).get("vault", ""))
	else:
		_vault_key = ""
	_refresh_all()


func _on_visibility_changed() -> void:
	if visible:
		_refresh_all()


func _build_panels() -> void:
	var body: HBoxContainer = $Body as HBoxContainer
	body.add_child(_make_panel(
		"Your Inventory",
		"Click an item to deposit it into the vault.",
		INVENTORY_COLUMNS,
		SlotInventory.SLOT_COUNT,
		true,
	))
	body.add_child(_make_panel(
		"Sect Vault",
		"Click an item to withdraw one into your bag.",
		BANK_COLUMNS,
		BankInventory.SLOT_COUNT,
		false,
	))


func _make_panel(
	title_text: String,
	hint_text: String,
	columns: int,
	slot_count: int,
	is_inventory: bool,
) -> PanelContainer:
	var panel: PanelContainer = PanelContainer.new()
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.size_flags_vertical = Control.SIZE_EXPAND_FILL

	var panel_style: StyleBoxFlat = StyleBoxFlat.new()
	panel_style.bg_color = Color(0.08, 0.08, 0.1, 0.92)
	panel_style.set_corner_radius_all(8)
	panel_style.content_margin_left = 12
	panel_style.content_margin_right = 12
	panel_style.content_margin_top = 10
	panel_style.content_margin_bottom = 12
	panel.add_theme_stylebox_override(&"panel", panel_style)

	var box: VBoxContainer = VBoxContainer.new()
	box.add_theme_constant_override(&"separation", 8)
	panel.add_child(box)

	var title: Label = Label.new()
	title.text = title_text
	title.add_theme_font_size_override(&"font_size", 15)
	box.add_child(title)

	var hint: Label = Label.new()
	hint.text = hint_text
	hint.add_theme_font_size_override(&"font_size", 11)
	hint.add_theme_color_override(&"font_color", Color(0.65, 0.68, 0.75))
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(hint)

	var scroll: ScrollContainer = ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.scroll_deadzone = 5
	box.add_child(scroll)

	var grid: GridContainer = GridContainer.new()
	grid.columns = columns
	grid.add_theme_constant_override(&"h_separation", 4)
	grid.add_theme_constant_override(&"v_separation", 4)
	grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(grid)

	var buttons: Array[Button] = []
	for slot_index: int in slot_count:
		var button: Button = Button.new()
		button.custom_minimum_size = SLOT_SIZE
		button.clip_contents = true
		button.focus_mode = Control.FOCUS_NONE
		_apply_slot_frame(button)
		button.pressed.connect(_on_slot_pressed.bind(slot_index, is_inventory))
		_ensure_slot_icon(button)
		grid.add_child(button)
		buttons.append(button)

	if is_inventory:
		_inventory_grid = grid
		_inventory_buttons = buttons
	else:
		_bank_grid = grid
		_bank_buttons = buttons

	return panel


func _on_slot_pressed(slot_index: int, is_inventory: bool) -> void:
	if _busy or InstanceClient.current == null or _vault_key.is_empty():
		return
	if is_inventory:
		_deposit_slot(slot_index)
	else:
		_withdraw_slot(slot_index)


func _deposit_slot(slot_index: int) -> void:
	if slot_index < 0 or slot_index >= ClientState.slot_inventory.size():
		return
	var slot: Dictionary = ClientState.slot_inventory[slot_index] as Dictionary
	if int(slot.get("item_id", 0)) <= 0:
		return
	_busy = true
	Client.request_data(
		&"deposit_item",
		_on_transaction_response,
		{"vault": _vault_key, "slot_index": slot_index},
		InstanceClient.current.name,
	)


func _withdraw_slot(bank_slot_index: int) -> void:
	if bank_slot_index < 0 or bank_slot_index >= ClientState.bank_inventory.size():
		return
	var slot: Dictionary = ClientState.bank_inventory[bank_slot_index] as Dictionary
	if int(slot.get("item_id", 0)) <= 0:
		return
	_busy = true
	Client.request_data(
		&"withdraw_item",
		_on_transaction_response,
		{"vault": _vault_key, "bank_slot_index": bank_slot_index},
		InstanceClient.current.name,
	)


func _on_transaction_response(payload: Variant) -> void:
	_busy = false
	if not (payload is Dictionary):
		return
	var data: Dictionary = payload as Dictionary
	if not bool(data.get("ok", false)):
		match str(data.get("reason", "")):
			"inventory_full":
				Toaster.toast("Your inventory is full.")
			"bank_full":
				Toaster.toast("The vault has no room for that item.")
			"too_far":
				Toaster.toast("You moved too far from the vault.")
				hide()
		return
	if data.has("slots"):
		ClientState.apply_inventory({"slots": data.get("slots", [])})
	if data.has("bank_slots"):
		ClientState.apply_bank({"slots": data.get("bank_slots", [])})


func _refresh_all() -> void:
	_refresh_inventory()
	_refresh_bank()


func _refresh_inventory() -> void:
	_paint_slots(_inventory_buttons, ClientState.slot_inventory)


func _refresh_bank() -> void:
	_paint_slots(_bank_buttons, ClientState.bank_inventory)


func _paint_slots(buttons: Array[Button], slots: Array) -> void:
	for i: int in buttons.size():
		var button: Button = buttons[i]
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
			PixelIcon.set_art(_slot_icon(button), icon)
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


func _clear_slot_button(button: Button) -> void:
	PixelIcon.set_art(_slot_icon(button), null)
	button.tooltip_text = ""
	for child: Node in button.get_children():
		if child.name == &"Icon":
			continue
		child.queue_free()


func _ensure_slot_icon(button: Button) -> TextureRect:
	var existing: Node = button.get_node_or_null("Icon")
	if existing is TextureRect:
		return existing as TextureRect
	var icon: TextureRect = PixelIcon.mount(button)
	icon.name = "Icon"
	return icon


func _slot_icon(button: Button) -> TextureRect:
	return _ensure_slot_icon(button)


func _apply_slot_frame(button: Button) -> void:
	var style: StyleBoxTexture = StyleBoxTexture.new()
	style.texture = SLOT_FRAME_TEXTURE
	for state: StringName in [&"normal", &"hover", &"pressed", &"focus", &"disabled"]:
		button.add_theme_stylebox_override(state, style)
