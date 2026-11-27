extends SceneTree
const Policy := preload("res://scripts/story/key_mission_attempts.gd")
var failures := 0
func check(ok: bool, why: String) -> void:
	if not ok:
		failures+=1
		push_error(why)
func _initialize() -> void:
	var start := Policy.initial()
	var first: Dictionary = Policy.begin(start).record
	check(start.attempts==0 and first.attempts==1,"Attempt begins once without mutating source")
	check(not Policy.begin(first).ok,"Active attempt cannot start twice")
	var failure: Dictionary = Policy.resolve(first,"wounded")
	check(failure.retry and failure.recovery_film and failure.record.state=="retry","First injury permits a real second chance")
	var saved: Dictionary = JSON.parse_string(JSON.stringify(failure.record))
	check(Policy.valid(saved),"JSON round trip preserves consumed attempt")
	var second: Dictionary = Policy.begin(saved).record
	check(second.attempts==2,"Second attempt consumes final slot")
	var exhausted: Dictionary = Policy.resolve(second,"failed")
	check(exhausted.alternate and not exhausted.retry and not Policy.begin(exhausted.record).ok,"Two failures permanently close this path")
	var victory: Dictionary = Policy.resolve(second,"success")
	check(victory.record.state=="succeeded" and not Policy.begin(victory.record).ok,"Success cannot be replayed for duplicate rewards")
	var death: Dictionary = Policy.resolve(first,"death")
	check(death.record.state=="dead" and not death.retry and not Policy.begin(death.record).ok,"Actual death is terminal, not a resurrection")
	check(not Policy.resolve(failure.record,"success").ok,"An inactive attempt cannot grant success")
	check(not Policy.valid({"attempts":3,"state":"retry","last_outcome":"failed"}),"Malformed excessive counter fails closed")
	print("KEY_MISSION_ATTEMPTS_PASS" if failures==0 else "KEY_MISSION_ATTEMPTS_FAIL")
	quit(0 if failures==0 else 1)
