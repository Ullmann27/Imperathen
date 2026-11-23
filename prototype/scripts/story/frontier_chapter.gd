extends RefCounted
## An original, finite chapter in the fictional Roman settlement.
## Choices are written only by WorldModel's checked transaction path.
## Its four speakers are stationary: world and rules use the same anchors.

const SCHEMA := 1
const WORK_SECONDS := 12.0
const TALK_RANGE := 3.0
const NPCS := {
	"livia": {"name": "Livia", "role": "Händlerin", "position": [-14.0, 1.0, 4.0]},
	"cassian": {"name": "Cassian", "role": "Schreiber", "position": [14.0, 1.0, -22.0]},
	"aulus": {"name": "Aulus", "role": "Veteran", "position": [4.0, 1.0, -25.0]},
	"titus": {"name": "Titus", "role": "Wagenführer", "position": [3.0, 1.0, 24.0]}
}
const TARGETS := ["livia", "cassian", "titus", "aulus", "titus", ""]
const VOCATIONS := {"guard": "Wachdienst", "supply": "Versorgung", "craft": "Handwerk"}
const YOUTH := {
	"livia": "Livia schiebt einen schweren Sack unter das Vordach. »Die Straße bringt Käufer, aber auch hungrige Reisende. Ein Dorf hält nicht wegen seiner Palisade zusammen. Die Leute müssen einander kennen.« Sie zeigt dir den Weg zum Brunnen. »Marcus wartet dort. Fang mit einem Dach über dem Kopf an.«",
	"cassian": "Cassian streicht eine Wachstafel glatt. »Ein Name, eine Menge, ein Versprechen. Wer etwas aufschreibt, trägt Verantwortung dafür.« Auf seiner Bank liegt ein Brief für die Soldaten an der Straße. Noch ist Rom für dich weit weg; seine Lieferungen führen bereits durch dein Dorf.",
	"aulus": "Aulus legt den Schleifstein beiseite. »Du bist zwölf. Du musst heute niemandem beweisen, dass du kämpfen kannst. Lerne, zuzuhören, zu bauen und eine Zusage einzuhalten.« Sein abgenutzter Schild lehnt an der Mauer. »Wenn du erwachsen bist, reden wir wieder über deinen Weg.«",
	"titus": "Titus prüft einen Lederriemen am Wagen. »Die Leute sehen das Schwert eines Soldaten. Ich sehe die Schuhe, das Brot und das Holz, das hinter ihm herreisen muss.« Er lächelt. »Wenn Marcus dir helfen soll, behandle ihn wie einen Freund, nicht wie ein Werkzeug.«"
}
const TITLES := ["Brot für die Straße", "Was in der Liste steht", "Der Wagen wartet", "Ein eigener Weg", "Der erste Auftrag", "Die Straße steht offen"]


static func new_state() -> Dictionary:
	return {"schema": SCHEMA, "step": 0, "met": [], "provisions": "", "report": "",
		"preparation": "", "work_seconds": 0.0, "vocation": "", "completed": false,
		"completed_at": -1.0}


static func enabled(state: Dictionary) -> bool:
	return state.origin_id == "italia" and not state.progress.career_terminal


static func unlocked(state: Dictionary) -> bool:
	return enabled(state) and state.progress.chapter_complete and state.player.age >= 18


static func npc_position(npc_id: String) -> Vector3:
	if not NPCS.has(npc_id):
		return Vector3(INF, INF, INF)
	var at: Array = NPCS[npc_id].position
	return Vector3(at[0], at[1], at[2])


static func in_range(state: Dictionary, npc_id: String) -> bool:
	if not NPCS.has(npc_id):
		return false
	var at: Array = state.player.position
	return Vector3(at[0], at[1], at[2]).distance_to(npc_position(npc_id)) <= TALK_RANGE


static func talk(state: Dictionary, npc_id: String) -> Dictionary:
	if not enabled(state) or not NPCS.has(npc_id):
		return _result(false, "Diese Person gehört nicht zu diesem Dorfkapitel.")
	if not in_range(state, npc_id):
		return _result(false, "Gehe näher zu %s (höchstens 3 Meter)." % NPCS[npc_id].name)
	var result := _result(true, "Du sprichst mit %s." % NPCS[npc_id].name)
	if npc_id not in state.frontier.met:
		state.frontier.met.append(npc_id)
		result["chronicle"] = "Du lernst %s kennen: %s." % [NPCS[npc_id].name, NPCS[npc_id].role]
	return result


static func choose(state: Dictionary, npc_id: String, choice: String) -> Dictionary:
	if not unlocked(state):
		return _result(false, "Beende zuerst als Erwachsener die Dorfverteidigung und ihre Folgeentscheidung.")
	if not NPCS.has(npc_id) or not in_range(state, npc_id):
		return _result(false, "Für diese Entscheidung musst du bei der betreffenden Person stehen.")
	if npc_id not in state.frontier.met:
		return _result(false, "Sprich zuerst mit dieser Person.")
	var chapter: Dictionary = state.frontier
	if chapter.completed or TARGETS[int(chapter.step)] != npc_id:
		return _result(false, "Dieser Auftrag ist hier nicht offen oder bereits abgeschlossen.")
	var allowed := false
	for option: Dictionary in dialog(state, npc_id).choices:
		if option.id == choice:
			if not option.enabled:
				return _result(false, option.reason)
			allowed = true
			break
	if not allowed:
		return _result(false, "Diese Antwort gehört nicht zum aktuellen Gespräch.")
	var event := ""
	match int(chapter.step):
		0:
			chapter.provisions = choice
			if choice == "share":
				state.resources.grain -= 2
				state.companion.trust += 2
				event = "Du gibst Livia zwei Getreide aus deinem eigenen Vorrat für die Familien. Die versiegelte Lieferung bleibt vollständig. Marcus merkt sich deine Hilfe."
			else:
				event = "Du behältst deinen Vorrat für kommende Wege. Livia findet eine andere Lösung für die Familien; die versiegelte Lieferung bleibt vollständig."
			chapter.step = 1
		1:
			chapter.report = choice
			event = "Du lässt Cassian den beschädigten Verschluss offen im Lieferbericht vermerken. Niemand wird ohne Beleg beschuldigt." if choice == "open" else "Du bittest Cassian um eine gesonderte Nachricht über den beschädigten Verschluss. Die bestätigte Menge wird unverändert aufgeschrieben."
			chapter.step = 2
		2:
			chapter.preparation = choice
			if choice == "pay":
				state.resources.denarii -= 4
				chapter.step = 3
				event = "Du bezahlst vier Denarii an die Dorfhandwerker. Titus bestätigt, dass sie den Wagen für die Übergabe vorbereitet haben."
			else:
				event = "Du übernimmst die Arbeit am Wagen. Titus hält die Achse, während du Riemen und Ladung sicherst. Die Arbeit zählt nur bei deiner Anwesenheit."
		3:
			chapter.vocation = choice
			chapter.step = 4
			event = "Du erklärst Aulus deinen Wunschweg: %s. Er schreibt eine persönliche Empfehlung; Rang, Aufnahme und künftige Beförderungen bleiben offen." % VOCATIONS[choice]
		4:
			chapter.completed = true
			chapter.completed_at = float(state.world_seconds)
			chapter.step = 5
			state.resources.denarii += 8
			event = "Titus übernimmt Lieferung und Empfehlung. Für die abgeschlossene Vorbereitung erhältst du einmalig acht Denarii. Dein Wunschweg %s und deine Entscheidungen bleiben vermerkt; das Dorf bleibt dein Ausgangsort." % VOCATIONS[chapter.vocation]
	var result := _result(true, event)
	result["chronicle"] = event
	return result


## Called only when the existing world simulation advances. Menus pause it.
static func advance(state: Dictionary, delta: float) -> String:
	if not unlocked(state):
		return ""
	var chapter: Dictionary = state.frontier
	if int(chapter.step) != 2 or chapter.preparation != "work" or not in_range(state, "titus"):
		return ""
	chapter.work_seconds = minf(WORK_SECONDS, float(chapter.work_seconds) + delta)
	# Shared village ticks can sum to 11.999999999999984 after exactly 12 s.
	if chapter.work_seconds >= WORK_SECONDS - 0.000001:
		chapter.work_seconds = WORK_SECONDS
		chapter.step = 3
		return "Gemeinsam mit Titus hast du den Wagen vorbereitet. Die Riemen sitzen fest, und die Ladung ist gesichert. Aulus erwartet dich am Übungsplatz."
	return ""


static func dialog(state: Dictionary, npc_id: String) -> Dictionary:
	if not enabled(state) or not NPCS.has(npc_id):
		return {}
	var name: String = NPCS[npc_id].name
	var output := {"npc_id": npc_id, "title": "%s · %s" % [name, NPCS[npc_id].role], "text": "", "choices": []}
	if int(state.player.age) < 18:
		output.text = YOUTH[npc_id]
		return output
	if not unlocked(state):
		output.text = _before_chapter(state, npc_id)
		return output
	var chapter: Dictionary = state.frontier
	var step := int(chapter.step)
	if chapter.completed:
		output.text = _after_chapter(state, npc_id)
		return output
	if TARGETS[step] != npc_id:
		output.text = _between_scenes(state, npc_id)
		return output
	output.title = "%s · %s" % [name, TITLES[step]]
	match step:
		0:
			output.text = "Livia legt ihre Hand auf einen versiegelten Sack. »Die Straße ist wieder sicher, aber die Familien haben ihre Vorräte bei der Verteidigung geteilt. Die Lieferung für die Soldaten ist abgezählt. Daran rühren wir nicht.« Sie sieht zu deinem eigenen Lager. »Kannst du zwei Getreide entbehren? Wenn du für deine Reise vorsorgen musst, sag es offen.«"
			output.choices = [_option("share", "2 Getreide aus meinem Vorrat teilen · Vertrauen +2", int(state.resources.grain) >= 2, "Dir fehlen zwei Getreide aus dem eigenen Vorrat."), _option("reserve", "Meinen Vorrat für den kommenden Weg behalten")]
		1:
			var consequence := "Livia hat den Familien aus deinem Vorrat geholfen. " if chapter.provisions == "share" else "Livia hat selbst nach einer Lösung für die Familien gesucht. "
			output.text = consequence + "Cassian zeigt dir einen beschädigten Verschluss. »Die Menge stimmt, aber der Riemen war lose. Du hast niemanden beim Öffnen gesehen. Ich werde keine Diebstahlgeschichte daraus machen.« Soll der sichtbare Schaden in den offenen Lieferbericht oder in eine gesonderte Nachricht an den Empfänger? Beide Wege halten die bestätigte Menge fest."
			output.choices = [_option("open", "Schaden offen im Lieferbericht vermerken"), _option("letter", "Empfänger mit einer gesonderten Nachricht informieren")]
		2:
			if chapter.preparation == "work":
				output.text = "Titus hält die Achse ruhig. »Bleib hier, wir müssen noch die Riemen sichern.« Arbeit: %d von %d Sekunden. Schließe das Gespräch, damit ihr weiterarbeiten könnt. Wenn du weggehst oder pausierst, ruht auch die Arbeit." % [floori(chapter.work_seconds), int(WORK_SECONDS)]
			else:
				output.text = "Titus hat Cassians Bericht gelesen. »Der Wagen trägt unsere Zusagen. Bevor ich ihn übernehme, müssen die Riemen fest und die Last verteilt sein.« Du kannst selbst helfen oder die Dorfhandwerker bezahlen. Deine Gefährten können währenddessen bei der Wache bleiben."
				output.choices = [_option("work", "Selbst mitarbeiten · 12 Sekunden am Wagen"), _option("pay", "Dorfhandwerker bezahlen · 4 Denarii", int(state.resources.denarii) >= 4, "Dir fehlen vier Denarii. Du kannst stattdessen selbst mitarbeiten.")]
		3:
			var work_line := "Titus lobt deine eigene Arbeit am Wagen." if chapter.preparation == "work" else "Titus bestätigt die bezahlte Arbeit der Dorfhandwerker."
			output.text = "%s Aulus hört deinen Bericht an. »Du kennst nun Menschen hinter einer Lieferung. Der Schutz einer Straße braucht wache Augen, verlässliche Vorräte und gute Hände. Welchen Weg willst du kennenlernen?« Seine Empfehlung öffnet ein Gespräch mit der Legion. Sie verleiht dir keinen Rang und entscheidet nicht dein ganzes Leben." % work_line
			output.choices = [_option("guard", "Wachdienst · Menschen und Straßen schützen"), _option("supply", "Versorgung · Waren und Wege organisieren"), _option("craft", "Handwerk · Ausrüstung und Bauwerke schaffen")]
		4:
			var report_line := "Der beschädigte Verschluss steht offen im Bericht." if chapter.report == "open" else "Die gesonderte Nachricht liegt bei der bestätigten Lieferliste."
			output.text = "%s Titus nimmt Aulus' Empfehlung für deinen Wunschweg %s entgegen. »Ich bringe deinen Namen an die Straße. Acht Denarii für die Vorbereitung; den nächsten Auftrag müssen wir gemeinsam prüfen.« Bestätige die Übergabe. Dein Zuhause und deine Beziehungen bleiben bestehen." % [report_line, VOCATIONS[chapter.vocation]]
			output.choices = [_option("handover", "Lieferung und Empfehlung übergeben · 8 Denarii")]
	return output


static func objective(state: Dictionary) -> Dictionary:
	var result := {"active": false, "complete": false, "title": "Die Straße zur Legion", "text": "", "npc_id": "", "position": [0.0, 1.0, 0.0], "progress": 0.0}
	if not unlocked(state):
		return result
	var chapter: Dictionary = state.frontier
	var step := int(chapter.step)
	result.active = true
	result.complete = chapter.completed
	result.title = TITLES[step]
	result.npc_id = TARGETS[step]
	if chapter.completed:
		result.text = "Vorbereitung abgeschlossen · Wunschweg: %s. Titus hat deine Empfehlung übernommen. Du kannst im Dorf bleiben oder dich der Talstraße und den Regionalaufträgen zuwenden." % VOCATIONS[chapter.vocation]
		result.progress = 1.0
		return result
	result.position = NPCS[result.npc_id].position.duplicate()
	match step:
		0: result.text = "Sprich mit Livia am Markt. Entscheide, ob du den Familien zwei Getreide aus deinem Vorrat gibst."
		1: result.text = "Gehe zu Cassian beim Atrium. Halte fest, was du über die Lieferung wirklich weißt."
		2:
			result.text = "Sprich mit Titus am südlichen Wagenplatz und bereite die Lieferung vor."
			if chapter.preparation == "work":
				result.text = "Hilf Titus am Wagen: %d/%d Sekunden. Bleibe in seiner Nähe; in Menüs und beim Weggehen ruht die Arbeit." % [floori(chapter.work_seconds), int(WORK_SECONDS)]
				result.progress = float(chapter.work_seconds) / WORK_SECONDS
		3: result.text = "Aulus wartet am Übungsplatz. Wähle deinen Wunschweg: Wachdienst, Versorgung oder Handwerk."
		4: result.text = "Kehre zu Titus zurück und übergib Lieferung sowie Empfehlung. Die Vergütung wird einmalig ausgezahlt."
	return result


## All resource and relationship effects derive from persisted choices, never cached totals.
static func effects(chapter: Dictionary) -> Dictionary:
	return {"grain": -2 if chapter.provisions == "share" else 0,
		"denarii": (-4 if chapter.preparation == "pay" else 0) + (8 if chapter.completed else 0),
		"trust": 2 if chapter.provisions == "share" else 0}


static func validate(state: Dictionary) -> String:
	var chapter: Variant = state.frontier
	var fields := ["schema", "step", "met", "provisions", "report", "preparation", "work_seconds", "vocation", "completed", "completed_at"]
	if typeof(chapter) != TYPE_DICTIONARY or chapter.size() != fields.size() or not chapter.has_all(fields):
		return "Ungültiger Geschichtenstand der Straße zur Legion."
	if not _integer(chapter.schema, 1, 1) or not _integer(chapter.step, 0, 5) or typeof(chapter.met) != TYPE_ARRAY or chapter.met.size() > NPCS.size():
		return "Unbekannte Version, Szene oder Personenliste des Dorfkapitels."
	var seen := {}
	for npc_id: Variant in chapter.met:
		if typeof(npc_id) != TYPE_STRING or not NPCS.has(npc_id) or seen.has(npc_id):
			return "Unbekannte oder doppelte Person im Dorfkapitel."
		seen[npc_id] = true
	for key in ["provisions", "report", "preparation", "vocation"]:
		if typeof(chapter[key]) != TYPE_STRING:
			return "Geschichtenentscheidungen benötigen gültige Kennungen."
	if chapter.provisions not in ["", "share", "reserve"] or chapter.report not in ["", "open", "letter"] or chapter.preparation not in ["", "work", "pay"] or chapter.vocation not in ["", "guard", "supply", "craft"]:
		return "Unbekannte Auswahl im Dorfkapitel."
	if typeof(chapter.completed) != TYPE_BOOL or not _number(chapter.work_seconds, 0.0, WORK_SECONDS) or not _number(chapter.completed_at, -1.0, float(state.world_seconds)):
		return "Ungültige Arbeitszeit oder Abschlussdaten des Dorfkapitels."
	var step := int(chapter.step)
	if (step >= 1) != (chapter.provisions != "") or (step >= 2) != (chapter.report != "") or (step >= 4) != (chapter.vocation != "") or (step == 5) != chapter.completed:
		return "Reihenfolge und Entscheidungen des Dorfkapitels widersprechen sich."
	if step < 2 and chapter.preparation != "" or step >= 3 and chapter.preparation == "":
		return "Die Vorbereitung des Wagens passt nicht zur Szene."
	if chapter.preparation != "work" and float(chapter.work_seconds) != 0.0:
		return "Unbelegte Eigenarbeit am Wagen."
	if chapter.preparation == "pay" and step < 3 or chapter.preparation == "work" and ((step >= 3) != (float(chapter.work_seconds) == WORK_SECONDS)):
		return "Der Wagen wurde ohne abgeschlossene Vorbereitung übergeben."
	if chapter.completed and float(chapter.completed_at) < 0.0 or not chapter.completed and float(chapter.completed_at) != -1.0:
		return "Zeitpunkt und Abschluss des Dorfkapitels widersprechen sich."
	if state.origin_id != "italia" and chapter != new_state():
		return "Das römische Dorfkapitel gehört nicht zu dieser Herkunft."
	if step > 0 or chapter.preparation != "":
		if not state.progress.chapter_complete or int(state.player.age) < 18:
			return "Der Erwachsenenauftrag überspringt die Dorfgeschichte."
	for required in mini(step, 4):
		if TARGETS[required] not in chapter.met:
			return "Eine gewählte Szene fehlt in den bestätigten Begegnungen."
	if chapter.preparation != "" and "titus" not in chapter.met:
		return "Die Wagenarbeit überspringt das Gespräch mit Titus."
	return ""


static func _before_chapter(state: Dictionary, npc_id: String) -> String:
	if npc_id == "aulus":
		return "Aulus erkennt dich wieder. »Aus dem Kind ist ein Erwachsener geworden. Beende zuerst die Ausbildung und hilf bei der Verteidigung. Danach sprechen wir darüber, wie du deinen eigenen Weg an der Straße findest.«"
	if npc_id == "livia":
		return "Livia hält ihre Stände offen. »Erst muss das Dorf wieder sicher sein. Danach braucht eine Lieferung verlässliche Hände. Vergiss bei deiner Entscheidung nach dem Gefecht die Menschen hier nicht.«"
	if npc_id == "cassian":
		return "Cassian führt die Liste der Lieferungen weiter. »Ein Gefecht endet nicht mit dem letzten Schlag. Was du danach entscheidest, gehört ebenfalls in die Geschichte dieses Ortes.«"
	return "Titus wartet mit seinem Wagen. »Die Straße läuft nicht davon. Beende, was du im Dorf begonnen hast. Dann machen wir diese Lieferung gemeinsam bereit.«"


static func _between_scenes(state: Dictionary, npc_id: String) -> String:
	var target: String = TARGETS[int(state.frontier.step)]
	var next_name: String = NPCS[target].name
	var recalls := {"livia": "Livia erkennt dich zwischen den Ständen und fragt nach der Lieferung.", "cassian": "Cassian legt die Wachstafel beiseite und hört dir zu.", "aulus": "Aulus betrachtet die Straße. Er lässt dir Zeit, deine Entscheidungen selbst zu treffen.", "titus": "Titus wartet am Wagenplatz. Er hält den Weg für die vorbereitete Lieferung frei."}
	return "%s Dein nächster Schritt führt zu %s. %s" % [recalls[npc_id], next_name, objective(state).text]


static func _after_chapter(state: Dictionary, npc_id: String) -> String:
	var chapter: Dictionary = state.frontier
	match npc_id:
		"livia":
			return "Livia erinnert sich an die zwei Getreide, die du mit den Familien geteilt hast. »Wenn du an der Straße arbeitest, vergiss nicht, wo dein eigenes Dach steht.«" if chapter.provisions == "share" else "Livia hat deine Entscheidung, den eigenen Vorrat zu behalten, nicht vergessen. »Ein langer Weg braucht Vorräte. Ein Zuhause braucht Menschen, die wiederkommen.«"
		"cassian":
			return "Cassian zeigt dir den offenen Vermerk über den beschädigten Verschluss. »Du hast aufgeschrieben, was du wusstest, und niemanden ohne Beleg beschuldigt.«" if chapter.report == "open" else "Cassian hebt eine Kopie deiner gesonderten Nachricht auf. »Die Menge steht in der Liste. Deine Beobachtung liegt beim Empfänger. Jeder Satz hat seinen Platz.«"
		"aulus":
			return "Aulus hat deinen Wunschweg %s in seiner Empfehlung festgehalten. »Ein Schreiben kann eine Tür öffnen. Hindurchgehen und die Arbeit tun musst du selbst. Dein Leben ist damit noch lange nicht entschieden.«" % VOCATIONS[chapter.vocation]
		"titus":
			return "Titus hat Lieferung und Empfehlung übernommen und dir acht Denarii bezahlt. Er erinnert sich an %s. »Dein Zuhause läuft dir nicht davon. Aber an der Talstraße werden verlässliche Menschen gebraucht.«" % ("deine Arbeit am Wagen" if chapter.preparation == "work" else "die von dir bezahlten Dorfhandwerker")
	return ""


static func _option(id: String, label: String, available: bool = true, reason: String = "") -> Dictionary:
	return {"id": id, "label": label, "enabled": available, "reason": reason if not available else ""}


static func _result(ok: bool, message: String) -> Dictionary:
	return {"ok": ok, "message": message}


static func _number(value: Variant, low: float, high: float) -> bool:
	return typeof(value) in [TYPE_INT, TYPE_FLOAT] and is_finite(float(value)) and float(value) >= low and float(value) <= high


static func _integer(value: Variant, low: int, high: int) -> bool:
	return _number(value, float(low), float(high)) and float(value) == floorf(float(value))
