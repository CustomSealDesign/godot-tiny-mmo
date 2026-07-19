extends Node
## OSRS-style game tick clock. Emits [signal game_tick] exactly every 0.6 seconds on
## both client and server so gameplay systems can align actions to discrete ticks.


signal game_tick

const TICK_INTERVAL_S: float = 0.6


func _ready() -> void:
	var timer: Timer = Timer.new()
	timer.name = "TickTimer"
	timer.wait_time = TICK_INTERVAL_S
	timer.autostart = true
	timer.timeout.connect(_on_tick)
	add_child(timer)


func _on_tick() -> void:
	game_tick.emit()
