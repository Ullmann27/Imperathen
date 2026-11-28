extends RefCounted
## Per-command scratch space, not another save or inventory.

static func _valid_fields(fields: Array) -> bool:
	var seen: Dictionary = {}
	if fields.is_empty():
		return false
	for value: Variant in fields:
		if not value is String:
			return false
		var field: String = value
		if field.is_empty() or seen.has(field):
			return false
		seen[field] = true
	return true


static func stage(screenplay: Dictionary, fields: Array) -> Dictionary:
	if not _valid_fields(fields):
		return {}
	var draft: Dictionary = {}
	for field: String in fields:
		if not screenplay.has(field):
			return {}
		draft[field] = screenplay[field]
	return draft.duplicate(true)


## Synchronous: no callbacks or awaits between validation and publication.
static func commit(screenplay: Dictionary, fields: Array, draft: Dictionary, ledger: String, events: Array[String]) -> bool:
	if not _valid_fields(fields) or screenplay.is_read_only():
		return false
	if draft.size() != fields.size() or ledger not in fields or not screenplay.get(ledger) is Array:
		return false
	for field: String in fields:
		if not draft.has(field) or not screenplay.has(field) or typeof(draft[field]) != typeof(screenplay[field]):
			return false
	var receipts: Array = screenplay[ledger]
	if receipts.is_read_only() or (receipts.is_typed() and receipts.get_typed_builtin() != TYPE_STRING):
		return false
	if draft[ledger] != receipts:
		return false
	# Validate existing receipts too. A malformed save must never receive new events.
	var seen: Dictionary = {}
	for value: Variant in receipts:
		if not value is String:
			return false
		var receipt: String = value
		if receipt.is_empty() or receipt.strip_edges() != receipt or seen.has(receipt):
			return false
		seen[receipt] = true
	for receipt: String in events:
		if receipt.is_empty() or receipt.strip_edges() != receipt or seen.has(receipt):
			return false
		seen[receipt] = true
	# Keep the scratch dictionary detached even after publication.
	var prepared: Dictionary = draft.duplicate(true)
	for field: String in fields:
		if field != ledger:
			screenplay[field] = prepared[field]
	receipts.append_array(events)
	return true
