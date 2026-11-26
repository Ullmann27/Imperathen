extends Node
## Presence director: decides how much of the HUD is on screen. In calm
## exploration most information rests (faded or hidden) so the world stays
## visible; it wakes when it matters - a new objective, a resource change,
## damage, danger, a nearby interaction or the player reaching for it.
## The director only changes opacity of registered elements; elements marked
## `owned` are also hidden at zero so they neither draw nor take input.

const Style = preload("res://scripts/ui/roman_hud/hud_style.gd")

const REST := {
	"mission": 0.86, "mission_detail": 0.0, "compass": 0.9, "vitals": 0.0, "resources": 0.0,
	"time": 0.72, "controls_hint": 0.0, "dock": 0.72, "combat": 0.62, "corner": 0.84, "prompt": 0.0,
}
const WAKE_SECONDS := {"mission": 9.0, "mission_detail": 9.0, "resources": 5.0, "vitals": 4.0, "controls_hint": 12.0, "dock": 1.6}

var reduce_motion := false
## Player setting: nothing rests. Everything that applies to the situation
## stays fully visible, for players who do not want information to fade.
var always_visible := false
var context: Dictionary = {}
var _elements: Dictionary = {}
var _awake: Dictionary = {}
var _last: Dictionary = {}


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS


func clear() -> void:
	_elements.clear()


## `owned` elements are hidden when their presence reaches zero.
func register(id: String, node: CanvasItem, owned := false) -> void:
	if not is_instance_valid(node):
		return
	var list: Array = _elements.get(id, [])
	list.append({"node": node, "owned": owned})
	_elements[id] = list
	var value := presence_target(id)
	node.modulate.a = value
	if owned:
		node.visible = value > 0.01


func wake(id: String, seconds := -1.0) -> void:
	_awake[id] = maxf(float(_awake.get(id, 0.0)), seconds if seconds > 0.0 else float(WAKE_SECONDS.get(id, 4.0)))


func is_awake(id: String) -> bool:
	return always_visible or float(_awake.get(id, 0.0)) > 0.0


## Feed the current game facts; changes since the last call wake elements.
func observe(facts: Dictionary) -> void:
	if not _last.is_empty():
		if str(facts.get("objective", "")) != str(_last.get("objective", "")):
			wake("mission")
			wake("mission_detail")
		if facts.get("resources", {}) != _last.get("resources", {}):
			wake("resources")
		if int(facts.get("health", 100)) < int(_last.get("health", 100)):
			wake("vitals", 6.0)
		elif int(facts.get("health", 100)) != int(_last.get("health", 100)) or absf(float(facts.get("stamina", 100.0)) - float(_last.get("stamina", 100.0))) >= 1.0:
			wake("vitals")
	context = facts.duplicate(true)
	_last = context


## Wake the parts a player needs when entering or returning to the game.
func greet() -> void:
	wake("mission")
	wake("mission_detail")
	wake("controls_hint")


func calm() -> bool:
	return str(context.get("mode", "person")) == "person" and not bool(context.get("danger", false)) \
		and not bool(context.get("build", false))


func presence_target(id: String) -> float:
	var awake := is_awake(id)
	var danger := bool(context.get("danger", false))
	var mode := str(context.get("mode", "person"))
	match id:
		"mission":
			return 1.0 if awake or danger or mode != "person" else REST.mission
		"mission_detail":
			return 1.0 if awake or danger or mode != "person" or bool(context.get("pinned_detail", false)) else 0.0
		"compass":
			return 1.0 if awake or float(context.get("announce", 0.0)) > 0.0 else REST.compass
		"vitals":
			var needed := danger or int(context.get("health", 100)) < 100 or float(context.get("stamina", 100.0)) < 99.0
			return 1.0 if needed or awake else 0.0
		"resources":
			if bool(context.get("no_stock", false)):
				return 0.0
			return 1.0 if mode != "person" or awake else 0.0
		"controls_hint":
			return 1.0 if mode != "person" or awake else 0.0
		"dock", "corner", "time":
			return 1.0 if awake or not calm() else float(REST[id])
		"combat":
			return 1.0 if always_visible or danger or bool(context.get("practice", false)) or not calm() else REST.combat
		"prompt":
			return 1.0 if not str(context.get("prompt", "")).is_empty() and mode == "person" and not bool(context.get("overlay", false)) else 0.0
	return 1.0


func _process(delta: float) -> void:
	for id: String in _awake.keys():
		_awake[id] = maxf(0.0, float(_awake[id]) - delta)
	var rate := 1000.0 if reduce_motion else delta / Style.MOTION_SLOW
	for id: String in _elements.keys():
		var target := presence_target(id)
		var alive: Array = []
		for entry: Dictionary in _elements[id]:
			var node: CanvasItem = entry.node
			if not is_instance_valid(node):
				continue
			alive.append(entry)
			var value := move_toward(node.modulate.a, target, rate)
			if not is_equal_approx(value, node.modulate.a):
				node.modulate.a = value
			if entry.owned:
				var show := value > 0.01 or target > 0.01
				if node.visible != show:
					node.visible = show
		_elements[id] = alive
