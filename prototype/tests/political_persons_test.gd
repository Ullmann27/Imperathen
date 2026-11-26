extends SceneTree
## Historical life/office boundaries and the authoritative clock read path.

const People = preload("res://scripts/domain/political_persons.gd")
const Calendar = preload("res://scripts/domain/world_calendar.gd")
const Clock = preload("res://scripts/domain/world_clock.gd")

var checks := 0
var failures: Array[String] = []


func _initialize() -> void:
	_catalogue()
	_life_boundaries()
	_offices()
	_world_clock()
	for failure: String in failures:
		printerr("FAIL: " + failure)
	print("POLITICAL_PERSONS_%s %d checks, %d failures" % ["PASS" if failures.is_empty() else "FAIL", checks, failures.size()])
	quit(0 if failures.is_empty() else 1)


func _check(value: bool, description: String) -> void:
	checks += 1
	if not value:
		failures.append(description)


func _at(id: String, year: int, month: int, day: int) -> Dictionary:
	return People.at_day(id, Calendar.to_jdn(year, month, day))


func _role(person: Dictionary, id: String) -> Dictionary:
	for role: Dictionary in person.get("roles", []):
		if role.id == id:
			return role
	return {}


func _catalogue() -> void:
	var names := People.ids()
	_check(names.size() == 5 and names == ["hist:caesar", "hist:brutus", "hist:cicero", "hist:pompeius", "hist:octavian"], "five stable historical actor IDs")
	names.pop_back()
	_check(People.ids().size() == 5, "ID list mutation cannot alter the registry")
	_check(People.at_day("hist:unknown", Calendar.campaign_start_jdn()).is_empty(), "unknown entity returns no entry")
	_check(People.at_day(People.CAESAR, Calendar.to_jdn(0, 1, 1)).is_empty(), "year zero rejected by calendar")
	_check(People.at_day(People.CAESAR, Calendar.max_jdn() + 1).is_empty(), "out of range rejected")
	var start := People.at_day(People.CAESAR, Calendar.campaign_start_jdn())
	start.birth.earliest[0] = -60
	start.roles[0].label = "Geändert"
	var original := People.at_day(People.CAESAR, Calendar.campaign_start_jdn())
	_check(original.birth.earliest[0] == -100 and original.roles[0].label != "Geändert", "nested results cannot alter source data")
	for id: String in People.ids():
		var person := People.at_day(id, Calendar.campaign_start_jdn())
		_check(person.id == id and not person.name.is_empty(), "canonical identity for " + id)
		_check(not person.has("family") and not person.has("father"), "no family claims in " + id)
		_check(not person.birth.source.is_empty() and not person.death.source.is_empty(), "auditable date records for " + id)


func _life_boundaries() -> void:
	_check(_at(People.CAESAR, -100, 7, 11).life_status == People.NOT_BORN, "pre-birth Caesar")
	_check(_at(People.CAESAR, -100, 7, 12).life_status == People.BIRTH_WINDOW, "Caesar's disputed birthday stays uncertain")
	_check(_at(People.CAESAR, -100, 7, 13).life_status == People.ALIVE, "Caesar available after birth window")
	_check(_at(People.CAESAR, -58, 5, 1).age == {"min": 41, "max": 41}, "Caesar 41 on campaign opening date")
	_check(_at(People.CAESAR, -58, 7, 12).age == {"min": 41, "max": 42}, "uncertainty carries through birthday")
	_check(_at(People.CAESAR, -44, 3, 14).life_status == People.ALIVE, "Caesar before the Ides")
	_check(_at(People.CAESAR, -44, 3, 15).life_status == People.DEAD and _at(People.CAESAR, -44, 3, 15).roles.is_empty(), "no living Caesar beginning on death day")
	var brutus := _at(People.BRUTUS, -85, 6, 1)
	_check(brutus.life_status == People.BIRTH_WINDOW and brutus.age.is_empty() and brutus.birth.precision == "approximate_year", "Brutus birth is approximate")
	_check(_at(People.BRUTUS, -58, 5, 1).age == {"min": 26, "max": 27}, "Brutus age range rather than fictitious birthday")
	_check(_at(People.BRUTUS, -42, 9, 30).life_status == People.ALIVE, "Brutus before Philippi death window")
	_check(_at(People.BRUTUS, -42, 10, 13).life_status == People.DEATH_WINDOW and _at(People.BRUTUS, -42, 10, 13).age.is_empty(), "Brutus unavailable during uncertain death interval")
	_check(_at(People.BRUTUS, -42, 11, 1).life_status == People.DEAD, "Brutus dead after Philippi")
	_check(_at(People.CICERO, -43, 12, 6).life_status == People.ALIVE, "Cicero before the execution date")
	_check(_at(People.CICERO, -43, 12, 7).life_status == People.DEAD, "Cicero death day")
	_check(_at(People.POMPEIUS, -48, 9, 27).life_status == People.ALIVE, "Pompeius before the disputed day")
	_check(_at(People.POMPEIUS, -48, 9, 28).life_status == People.DEATH_WINDOW, "Pompeius uncertain day")
	_check(_at(People.POMPEIUS, -48, 9, 29).life_status == People.DEAD, "Pompeius dead by latest date")
	_check(_at(People.OCTAVIAN, -63, 9, 22).life_status == People.NOT_BORN and _at(People.OCTAVIAN, -63, 9, 23).life_status == People.ALIVE, "Octavius exact birth boundary")
	_check(_at(People.OCTAVIAN, -58, 5, 1).age == {"min": 4, "max": 4}, "Octavius a child at campaign opening")
	_check(_at(People.OCTAVIAN, 14, 8, 18).age == {"min": 75, "max": 75}, "Augustus age across year-zero boundary")
	_check(_at(People.OCTAVIAN, 14, 8, 19).life_status == People.DEAD, "Augustus death day")
	for id: String in People.ids():
		_check(_at(id, 100, 5, 1).life_status == People.DEAD and _at(id, 100, 5, 1).roles.is_empty(), "no live actor in Trajan-era save: " + id)


func _offices() -> void:
	_check(not _role(_at(People.CAESAR, -59, 6, 1), "consul").is_empty(), "Caesar consul in 59 BCE")
	var caesar := _at(People.CAESAR, -58, 5, 1)
	_check(caesar.roles.size() == 1 and caesar.roles[0].id == "proconsul_gaul", "Caesar alone proconsular role in 58, no later title")
	_check(caesar.roles[0].precision == "year_window", "campaign command identifies year-level evidence")
	_check(_role(_at(People.CAESAR, -44, 2, 14), "dictator_perpetuo").is_empty(), "uncertain first day of perpetual dictatorship is not claimed")
	_check(not _role(_at(People.CAESAR, -44, 2, 15), "dictator_perpetuo").is_empty(), "perpetual dictatorship in attested window")
	_check(_role(_at(People.BRUTUS, -45, 12, 31), "praetor_urbanus").is_empty(), "Brutus not yet city praetor in 45")
	_check(not _role(_at(People.BRUTUS, -44, 3, 14), "praetor_urbanus").is_empty(), "Marcus Brutus city praetor in early 44")
	_check(not _role(_at(People.CICERO, -63, 6, 1), "consul").is_empty(), "Cicero consul in 63")
	_check(_role(_at(People.CICERO, -58, 5, 1), "exile").kind == "context", "Cicero in exile around campaign opening")
	_check(_role(_at(People.CICERO, -57, 8, 4), "exile").is_empty(), "recall is outside exile window")
	_check(_role(_at(People.POMPEIUS, -58, 5, 1), "first_triumvirate").kind == "context", "Pompeius private alliance distinguished from office")
	_check(not _role(_at(People.POMPEIUS, -55, 6, 1), "consul").is_empty(), "Pompeius consul in 55")
	var octavius := _at(People.OCTAVIAN, -58, 5, 1)
	_check(octavius.name == "Gaius Octavius" and octavius.roles.is_empty(), "no future titles on the boy Octavius")
	_check(_at(People.OCTAVIAN, -44, 7, 1).name == "Octavian", "later editorial display name uses same ID")
	_check(_role(_at(People.OCTAVIAN, -43, 11, 26), "triumvir_rpc").is_empty(), "no triumvir before Lex Titia")
	_check(not _role(_at(People.OCTAVIAN, -43, 11, 27), "triumvir_rpc").is_empty(), "Triumvir from attested date")
	_check(not _role(_at(People.OCTAVIAN, -38, 12, 31), "triumvir_rpc").is_empty(), "first Triumvir term runs to its attested end")
	_check(_role(_at(People.OCTAVIAN, -27, 1, 15), "augustus").is_empty(), "no Augustus honor before Senate grant")
	var aug := _at(People.OCTAVIAN, -27, 1, 16)
	_check(aug.id == People.OCTAVIAN and aug.name == "Caesar Augustus" and _role(aug, "augustus").kind == "honor", "honor and title with stable ID")
	_check(_at(People.OCTAVIAN, 14, 8, 19).roles.is_empty(), "no live title from day of death")


func _world_clock() -> void:
	var world := {"village": {"history": {"start_year": -58}}, "world_state": {}}
	Clock.start(world)
	var before := world.duplicate(true)
	var stamp := Clock.jdn(world)
	_check(stamp == Calendar.campaign_start_jdn(), "test uses actual campaign clock")
	var caesar := People.for_world(People.CAESAR, world)
	_check(caesar == People.at_day(People.CAESAR, stamp), "world view queries the exact same JDN")
	_check(world == before, "world-query leaves clock, ledger, and save data unchanged")
	var date := Calendar.to_jdn(-44, 3, 15)
	world.calendar = Clock.new_calendar(-58, date, Clock.NIGHT, Clock.births_for(-58))
	_check(People.for_world(People.CAESAR, world).life_status == People.DEAD, "current date decides death, not origin date")
	_check(People.for_world(People.CAESAR, {}).is_empty(), "missing calendar rejected")
	world.calendar.clock.jdn = -1
	_check(People.for_world(People.CAESAR, world).is_empty(), "invalid clock rejected")
