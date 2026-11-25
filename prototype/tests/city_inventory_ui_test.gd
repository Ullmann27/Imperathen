extends SceneTree
## Isolated regression for a previously blocked equipment interaction.
## The existing city_trade_test.gd separately verifies real adult training,
## accounting and WorldModel atomicity; this fixture targets UI -> command wiring.
const Model = preload("res://scripts/domain/world_model.gd")
const Trade = preload("res://scripts/city_trade.gd")
const MarketPanel = preload("res://scripts/city_support_panel.gd")

var checks := 0
var failures: Array[String] = []
var panel: CanvasLayer
var requested: Array[Dictionary] = []


func _initialize() -> void:
	if OS.get_environment("IMPERATHEN_ISOLATED_TEST") != "1":
		printerr("The equipment UI regression requires isolated account data.")
		quit(2)
		return
	_run.call_deferred()


func _check(condition: bool, why: String) -> void:
	checks += 1
	if not condition:
		failures.append(why)
		printerr("FAIL " + why)


func _button(caption: String) -> Button:
	for candidate: Button in panel.modal.find_children("*", "Button", true, false):
		if candidate.text == caption:
			return candidate
	return null


func _on_command(command: String, arguments: Dictionary) -> void:
	requested.append({"command":command, "args":arguments.duplicate(true)})


func _run() -> void:
	root.size = Vector2i(1280, 720)
	var model = Model.new()
	model.new_game("italia", true, true)
	var started: Dictionary = model.execute("city_trade_enable", {})
	_check(bool(started.get("ok", false)), "The optional market activates through the real model.")
	var state: Dictionary = model.data.duplicate(true)
	# This is an isolated UI fixture, not a forged career progression or a
	# claim that the campaign character has completed soldier training.
	state.player.age = 18
	state.village.city_trade.inventory.linen_tunic = 1
	state.village.city_trade.purchases.clothier.linen_tunic = 1
	state.village.city_trade.equipment.body = "linen_tunic"
	_check(Trade.validate(state).is_empty(), "One purchased and equipped tunic has a valid trade ledger.")
	var original_money := int(state.resources.denarii)
	panel = MarketPanel.new()
	panel.command_requested.connect(_on_command)
	root.add_child(panel)
	await process_frame
	panel.update_state(state)
	panel.open_inventory()
	await process_frame
	_check(panel.is_open() and panel.inventory_open, "An inventory panel is actually open.")
	var worn := _button("Ablegen")
	_check(is_instance_valid(worn), "Equipped tunic offers an 'Ablegen' action.")
	_check(is_instance_valid(worn) and not worn.disabled, "The action is enabled rather than a dead button.")
	if is_instance_valid(worn) and not worn.disabled:
		worn.pressed.emit()
	_check(requested.size() == 1, "One press emits exactly one command.")
	if requested.size() == 1:
		_check(requested[0].command == "city_equip" and requested[0].args == {"item_id":"linen_tunic"}, "Unequip uses the existing domain command, not direct UI mutation.")
		var removed: Dictionary = Trade.apply(state, str(requested[0].command), requested[0].args)
		_check(bool(removed.get("ok", false)), "The domain supports toggling off the worn tunic.")
		_check(str(state.village.city_trade.equipment.body).is_empty(), "The body slot is now empty.")
		_check(Trade.validate(state).is_empty(), "Unequipping preserves the valid trade ledger.")
		panel.update_state(state)
		await process_frame
		var unworn := _button("Anlegen")
		_check(is_instance_valid(unworn) and not unworn.disabled, "The same owned tunic can be equipped again.")
		if is_instance_valid(unworn) and not unworn.disabled:
			unworn.pressed.emit()
		_check(requested.size() == 2, "Re-equipping emits one additional command.")
		if requested.size() == 2:
			var equipped: Dictionary = Trade.apply(state, str(requested[1].command), requested[1].args)
			_check(bool(equipped.get("ok", false)), "The domain supports equipping the tunic again.")
			_check(str(state.village.city_trade.equipment.body) == "linen_tunic", "The body slot is equipped.")
			_check(Trade.validate(state).is_empty(), "Re-equipping preserves the valid trade ledger.")
			panel.update_state(state)
			await process_frame
			_check(is_instance_valid(_button("Ablegen")), "The UI returns to the appropriate action label.")
	_check(int(state.resources.denarii) == original_money, "Equipment toggling does not create or destroy denarii.")
	_check(int(state.village.city_trade.inventory.linen_tunic) == 1, "Equipment toggling does not create or destroy items.")
	state.village.raid.active = true
	panel.update_state(state)
	await process_frame
	_check(_button("Ablegen") == null and _button("Anlegen") == null, "Combat disables equipment actions in the panel.")
	state.village.raid.active = false
	panel.update_state(state)
	await process_frame
	_check(is_instance_valid(_button("Ablegen")), "The equipment control returns after the combat lock.")
	panel.free()
	print("CITY_INVENTORY_UI_RESULT checks=%d failures=%d" % [checks, failures.size()])
	print("CITY_INVENTORY_UI_PASS" if failures.is_empty() else "CITY_INVENTORY_UI_FAIL")
	quit(0 if failures.is_empty() else 1)
