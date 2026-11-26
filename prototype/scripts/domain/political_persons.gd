extends RefCounted
## Read-only catalogue of historical persons. Dates are nominal Julian days on
## the shared world clock. A life-window uncertainty is not spawn permission.

const Calendar = preload("res://scripts/domain/world_calendar.gd")
const Clock = preload("res://scripts/domain/world_clock.gd")

const CAESAR := "hist:caesar"
const BRUTUS := "hist:brutus"
const CICERO := "hist:cicero"
const POMPEIUS := "hist:pompeius"
const OCTAVIAN := "hist:octavian"
const IDS := [CAESAR, BRUTUS, CICERO, POMPEIUS, OCTAVIAN]

const NOT_BORN := "not_born"
const BIRTH_WINDOW := "birth_window"
const ALIVE := "alive"
const DEATH_WINDOW := "death_window"
const DEAD := "dead"

# Life bounds list the earliest and latest attested or estimated calendar day.
# Roles are selected attested windows, inclusive start / exclusive end. Year
# windows describe documented service without implying a dated appointment.
# See docs/37_world_calendar/POLITICAL_PERSONS.md for the evidence keys.
const PEOPLE := {
	CAESAR: {
		"name": "Gaius Julius Caesar",
		"birth": {"earliest": [-100, 7, 12], "latest": [-100, 7, 13], "precision": "disputed_day", "source": "caesar_life"},
		"death": {"earliest": [-44, 3, 15], "latest": [-44, 3, 15], "precision": "day", "source": "caesar_life"},
		"roles": [
			{"id": "consul", "label": "Konsul", "kind": "office", "from": [-59, 1, 1], "before": [-58, 1, 1], "precision": "consular_year", "source": "caesar_life"},
			{"id": "proconsul_gaul", "label": "Prokonsul in Gallien und Illyricum", "kind": "office", "from": [-58, 1, 1], "before": [-49, 1, 1], "precision": "year_window", "source": "caesar_life"},
			{"id": "dictator_perpetuo", "label": "Diktator auf Lebenszeit", "kind": "office", "from": [-44, 2, 15], "before": [-44, 3, 15], "precision": "attested_window", "source": "caesar_dictatorship"},
		],
	},
	BRUTUS: {
		"name": "Marcus Junius Brutus",
		"birth": {"earliest": [-85, 1, 1], "latest": [-85, 12, 31], "precision": "approximate_year", "source": "brutus_praetor"},
		"death": {"earliest": [-42, 10, 1], "latest": [-42, 10, 31], "precision": "month", "source": "brutus_philippi"},
		"roles": [
			{"id": "praetor_urbanus", "label": "Stadtprätor von Rom", "kind": "office", "from": [-44, 1, 1], "before": [-44, 3, 15], "precision": "attested_window", "source": "brutus_praetor"},
		],
	},
	CICERO: {
		"name": "Marcus Tullius Cicero",
		"birth": {"earliest": [-106, 1, 3], "latest": [-106, 1, 3], "precision": "day", "source": "cicero_chronology"},
		"death": {"earliest": [-43, 12, 7], "latest": [-43, 12, 7], "precision": "day", "source": "cicero_death"},
		"roles": [
			{"id": "consul", "label": "Konsul", "kind": "office", "from": [-63, 1, 1], "before": [-62, 1, 1], "precision": "consular_year", "source": "cicero_chronology"},
			{"id": "exile", "label": "Im Exil", "kind": "context", "from": [-58, 4, 29], "before": [-57, 8, 4], "precision": "attested_window", "source": "cicero_exile"},
		],
	},
	POMPEIUS: {
		"name": "Gnaeus Pompeius Magnus",
		"birth": {"earliest": [-106, 9, 29], "latest": [-106, 9, 29], "precision": "day", "source": "pompeius_chronology"},
		"death": {"earliest": [-48, 9, 28], "latest": [-48, 9, 29], "precision": "disputed_day", "source": "pompeius_death"},
		"roles": [
			{"id": "consul", "label": "Konsul", "kind": "office", "from": [-70, 1, 1], "before": [-69, 1, 1], "precision": "consular_year", "source": "pompeius_chronology"},
			{"id": "first_triumvirate", "label": "Politisches Bündnis mit Caesar und Crassus", "kind": "context", "from": [-59, 1, 1], "before": [-53, 1, 1], "precision": "year_window", "source": "caesar_life"},
			{"id": "consul", "label": "Konsul", "kind": "office", "from": [-55, 1, 1], "before": [-54, 1, 1], "precision": "consular_year", "source": "pompeius_chronology"},
		],
	},
	OCTAVIAN: {
		"name": "Gaius Octavius",
		"birth": {"earliest": [-63, 9, 23], "latest": [-63, 9, 23], "precision": "day", "source": "augustan_fasti"},
		"death": {"earliest": [14, 8, 19], "latest": [14, 8, 19], "precision": "day", "source": "augustan_fasti"},
		"display_names": [
			{"from": [-44, 7, 1], "label": "Octavian", "precision": "display_window", "source": "octavian_name"},
			{"from": [-27, 1, 16], "label": "Caesar Augustus", "precision": "day", "source": "augustan_fasti"},
		],
		"roles": [
			{"id": "triumvir_rpc", "label": "Triumvir zur Neuordnung des Staates", "kind": "office", "from": [-43, 11, 27], "before": [-37, 1, 1], "precision": "day", "source": "augustan_fasti"},
			{"id": "augustus", "label": "Augustus", "kind": "honor", "from": [-27, 1, 16], "before": [14, 8, 19], "precision": "day", "source": "augustan_fasti"},
		],
	},
}


static func ids() -> Array[String]:
	var result: Array[String] = []
	result.assign(IDS)
	return result


## Read through the authoritative world clock without modifying the save.
static func for_world(person_id: String, world: Dictionary) -> Dictionary:
	if not Calendar.validate_world_time(world.get("calendar")):
		return {}
	return at_day(person_id, Clock.jdn(world))


## A catalogue result exists for the whole timeline, including before birth
## and after death. Only life_status == ALIVE allows use as a living person.
static func at_day(person_id: String, jdn: int) -> Dictionary:
	if not PEOPLE.has(person_id) or jdn < 0 or jdn > Calendar.max_jdn():
		return {}
	var person: Dictionary = PEOPLE[person_id]
	var birth: Dictionary = person.birth
	var death: Dictionary = person.death
	var status := _life_status(birth, death, jdn)
	var name := str(person.name)
	for choice: Dictionary in person.get("display_names", []):
		if jdn >= _jdn(choice.from):
			name = str(choice.label)
	var result := {
		"id": person_id,
		"name": name,
		"life_status": status,
		"birth": birth.duplicate(true),
		"death": death.duplicate(true),
		"age": {},
		"roles": [],
	}
	if status == ALIVE:
		result.age = {
			"min": Calendar.age_on(Calendar.from_jdn(_jdn(birth.latest)), jdn),
			"max": Calendar.age_on(Calendar.from_jdn(_jdn(birth.earliest)), jdn),
		}
		for role: Dictionary in person.roles:
			if _jdn(role.from) <= jdn and jdn < _jdn(role.before):
				result.roles.append(role.duplicate(true))
	return result


static func _life_status(birth: Dictionary, death: Dictionary, jdn: int) -> String:
	if jdn < _jdn(birth.earliest):
		return NOT_BORN
	if jdn < _jdn(birth.latest):
		return BIRTH_WINDOW
	if jdn >= _jdn(death.latest):
		return DEAD
	if jdn >= _jdn(death.earliest):
		return DEATH_WINDOW
	return ALIVE


static func _jdn(date: Array) -> int:
	return Calendar.to_jdn(int(date[0]), int(date[1]), int(date[2]))
