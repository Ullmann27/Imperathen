extends RefCounted
## Reusable mission-local contract. No automatic rollback of the world.
## Callers must own the authored mission and persist its returned record.
## Do not use this for the protected childhood raid or repeatable sandbox work.
const MAX_ATTEMPTS := 2
const STATES := ["available","active","retry","succeeded","alternate","dead"]
const OUTCOMES := ["success","failed","wounded","death"]

static func initial() -> Dictionary:
	return {"attempts":0,"state":"available","last_outcome":""}

static func valid(record: Variant) -> bool:
	if not record is Dictionary or record.size()!=3 or not record.has_all(["attempts","state","last_outcome"]):
		return false
	var count: Variant = record.attempts
	if not (count is int or count is float) or not is_finite(float(count)) or float(count)!=floorf(float(count)) or int(count)<0 or int(count)>MAX_ATTEMPTS:
		return false
	match str(record.state):
		"available": return int(count)==0 and record.last_outcome==""
		"active": return int(count) in [1,2] and (record.last_outcome=="" if int(count)==1 else record.last_outcome in ["failed","wounded"])
		"retry": return int(count)==1 and record.last_outcome in ["failed","wounded"]
		"succeeded": return int(count)>0 and record.last_outcome=="success"
		"alternate": return int(count)==MAX_ATTEMPTS and record.last_outcome in ["failed","wounded"]
		"dead": return int(count)>0 and record.last_outcome=="death"
	return false

static func begin(record: Dictionary) -> Dictionary:
	if not valid(record) or record.state not in ["available","retry"]:
		return {"ok":false,"reason":"mission_closed_or_active"}
	var next := record.duplicate(true)
	next.attempts = int(next.attempts)+1
	next.state = "active"
	return {"ok":true,"record":next}

static func resolve(record: Dictionary, outcome: String) -> Dictionary:
	if not valid(record) or record.state!="active" or outcome not in OUTCOMES:
		return {"ok":false,"reason":"no_active_attempt_or_invalid_outcome"}
	var next := record.duplicate(true)
	next.last_outcome = outcome
	match outcome:
		"success": next.state = "succeeded"
		"death": next.state = "dead"
		_: next.state = "retry" if int(next.attempts)<MAX_ATTEMPTS else "alternate"
	return {"ok":true,"record":next,"recovery_film":outcome=="wounded","retry":next.state=="retry","alternate":next.state=="alternate"}
