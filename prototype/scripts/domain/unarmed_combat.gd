extends RefCounted
## Compatibility entry point for the family chapter.
## All rules and the eleven-field v1 state belong to CombatActions.
## WorldModel advances that authority once; presentation never calls this clock.

const Actions = preload("res://scripts/domain/combat_actions.gd")
const PRACTICE_POINT = Actions.PRACTICE_POINT
const TECHNIQUES = Actions.TECHNIQUES
const COMMAND_FIELDS = Actions.COMMAND_FIELDS
const STATE_FIELDS = Actions.STATE_FIELDS


static func start(data: Dictionary) -> void:
	Actions.start(data)


static func enabled(data: Dictionary) -> bool:
	return Actions.enabled(data)


static func available(data: Dictionary, id: String) -> bool:
	return Actions.available(data, id)


static func validate_arguments(command: String, args: Dictionary) -> String:
	return Actions.validate_arguments(command, args)


static func execute(data: Dictionary, command: String, args: Dictionary) -> Dictionary:
	return Actions.execute(data, command, args)


static func advance(data: Dictionary, delta: float, sight_check: Callable = Callable(), apply_hit: Callable = Callable()) -> Dictionary:
	return Actions.advance(data, delta, sight_check, apply_hit)


static func interrupt(data: Dictionary) -> bool:
	return Actions.interrupt(data)


static func busy(data: Dictionary) -> bool:
	return Actions.busy(data)


static func phase(id: String, elapsed: float) -> String:
	return Actions.phase(id, elapsed)


static func view(data: Dictionary) -> Dictionary:
	return Actions.view(data)


static func validate(data: Dictionary) -> String:
	return Actions.validate(data)
