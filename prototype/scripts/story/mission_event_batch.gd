extends RefCounted
## Per-command scratch space, not another save or inventory.

static func stage(screenplay: Dictionary, fields: Array) -> Dictionary:
	var draft: Dictionary = {}
	for field: String in fields:
		if not screenplay.has(field):
			return {}
		draft[field] = screenplay[field]
	return draft.duplicate(true)


## Synchronous: no callbacks or awaits between validation and publication.
static func commit(screenplay: Dictionary, fields: Array, draft: Dictionary, ledger: String, events: Array[String]) -> bool:
	if draft.size() != fields.size() or ledger not in fields or not screenplay.get(ledger) is Array:
		return false
	for field: String in fields:
		if not draft.has(field) or not screenplay.has(field) or typeof(draft[field]) != typeof(screenplay[field]):
			return false
	var receipts: Array = screenplay[ledger]
	if draft[ledger] != receipts:
		return false
	var pending: Dictionary = {}
	for receipt: String in events:
		if receipt.is_empty() or receipts.has(receipt) or pending.has(receipt):
			return false
		pending[receipt] = true
	for field: String in fields:
		if field != ledger:
			screenplay[field] = draft[field]
	receipts.append_array(events)
	return true
