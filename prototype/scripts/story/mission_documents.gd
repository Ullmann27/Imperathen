extends RefCounted
## Wording for reading held objects. The carried list remains the sole owner.
## Creative wording follows the actual I-04 delivery and I-07 gate report.
const ENTRIES := {
	"sextus_note":{
		"title":"Sextus’ Wachstäfelchen", "mission":"I-04",
		"text":"Fabius, ich brauche bis zum Markttag zwei Körbe Kohle für die Esse.\n\nSextus",
		"model":"res://assets/legio/sextus_tablet.glb"},
	"gate_message":{
		"title":"Nachricht vom Tor", "mission":"I-07",
		"text":"An Cassia am Markt. Der Weg bis zum Tor ist geprüft. Schick deinen Wagen über diesen Abschnitt.\n\nVom Torposten",
		"model":"res://assets/legio/gate_letter.glb"}
}

static func held(world: Dictionary) -> Array[String]:
	var entries: Array[String] = []
	for id in world.get("village",{}).get("childhood",{}).get("carried",[]):
		if ENTRIES.has(id):
			entries.append(id)
	return entries
