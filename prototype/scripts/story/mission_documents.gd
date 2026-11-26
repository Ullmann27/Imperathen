extends RefCounted
## Read-only inventory views of existing story objects. No existence, ownership
## or quest progress is saved here. The individual sources are evaluated by held().
const I01 := preload("res://scripts/story/i01_three_cups.gd")
const ENTRIES := {
	"household_coin":{
		"title":"Reservierter Haushaltsdenar", "mission":"I-01 · I-03", "view":"flat",
		"text":"Julias Denar ist für die Familienbestellung bei Cassia bestimmt. Halte ihn für diesen Einkauf zurück.",
		"model":"res://assets/legio/household_denar.glb"},
	"neighbor_basket":{
		"title":"Julias Nachbarschaftskorb", "mission":"I-01 · I-02",
		"text":"Der Korb ist für Aurelia bestimmt. Vor der Übergabe kannst du mit ihr prüfen, ob Julia dir den richtigen mitgegeben hat.",
		"model":"res://assets/legio/neighbour_basket.glb"},
	"water_jug":{
		"title":"Familienkrug", "mission":"I-01",
		"text":"Mit diesem Krug holst du Wasser für den Familientisch oder trägst es zu Silvanus.",
		"model":"res://assets/legio/water_pitcher.glb"},
	"family_parcel":{
		"title":"Cassias Familienbestellung", "mission":"I-03",
		"text":"Cassia hat das Päckchen für eure Küche verschnürt. Julia nimmt es im Familienhaus entgegen.",
		"model":"res://assets/legio/kitchen_parcel.glb"},
	"stall_water":{
		"title":"Wasserkrug für Cassias Stand", "mission":"I-03",
		"text":"Das Wasser kommt vom Brunnen. Wenn du es bei Cassia abgibst, rechnet sie den Gang auf Marcus’ fehlendes As an.",
		"model":"res://assets/legio/water_pitcher.glb"},
	"kindling_bundle":{
		"title":"Kleinholzbündel für Sextus", "mission":"I-04",
		"text":"Kleine gespaltene Stücke aus dem westlichen Holzlager. Sextus erwartet sie an der Schmiede.",
		"model":"res://assets/legio/split_kindling.glb"},
	"sextus_note":{
		"title":"Sextus’ Wachstäfelchen", "mission":"I-04", "document":true, "view":"flat",
		"text":"Fabius, ich brauche bis zum Markttag zwei Körbe Kohle für die Esse.\n\nSextus",
		"model":"res://assets/legio/sextus_tablet.glb"},
	"checked_hinge":{
		"title":"Geprüfter Truhengriff", "mission":"I-05 · I-06", "view":"flat",
		"text":"Mit Sextus hast du den beschädigten Griff am Amboss gerichtet und am Kühlbottich geprüft. Cassia braucht ihn für ihre Markttruhe.",
		"model":"res://assets/legio/chest_handle.glb"},
	"medicine_parcel":{
		"title":"Aurelias Versorgungspäckchen", "mission":"I-07",
		"text":"Aurelia hat das geschlossene Päckchen für den erkrankten Wachmann vorbereitet. Er wartet bei ihrem Haus.",
		"model":"res://assets/legio/healer_parcel.glb"},
	"gate_message":{
		"title":"Nachricht vom Tor", "mission":"I-07", "document":true, "view":"flat",
		"text":"An Cassia am Markt. Der Weg bis zum Tor ist geprüft. Schick deinen Wagen über diesen Abschnitt.\n\nVom Torposten",
		"model":"res://assets/legio/gate_letter.glb"},
	"memory_token":{
		"title":"Erinnerungsstück aus Valdora", "mission":"I-14", "view":"flat",
		"text":"Am Waldrand oberhalb Valdoras hast du dieses Stück bei deinem Schwur aufgehoben. Die gebrochene Scherbe trägt keine Inschrift.",
		"model":"res://assets/legio/valdora_keepsake.glb"},
	"cup_julia":{
		"title":"Julias Becher", "mission":"I-01", "text":"Dieser Tonbecher gehört an Julias Platz am Familientisch.",
		"model":"res://assets/legio/cup_julia.glb"},
	"cup_silvanus":{
		"title":"Silvanus’ Becher", "mission":"I-01", "text":"Dieser Tonbecher gehört an den Platz deines Vaters.",
		"model":"res://assets/legio/cup_silvanus.glb"},
	"cup_player":{
		"title":"Dein schiefer Becher", "mission":"I-01", "text":"Der obere Rand neigt sich zu einer Seite. Du stellst ihn an deinen Platz am Familientisch.",
		"model":"res://assets/legio/cup_player.glb"},
	"stack_armful":{
		"title":"Eine Armvoll Kleinholz", "mission":"I-04", "text":"Du trägst einen Teil des Holzes vom Kühlbottich zum Stapel neben dem Blasebalg.",
		"model":"res://assets/legio/split_kindling.glb"},
	"watch_water":{
		"title":"Wasser für den Torposten", "mission":"I-07", "text":"Du hast den Krug am Haus gefüllt. Das Wasser gehört an den vereinbarten Torabschnitt.",
		"model":"res://assets/legio/water_pitcher.glb"},
	"watch_helmet":{
		"title":"Leihhelm der Wache", "mission":"I-07", "text":"Severus leiht dir den Helm für den beaufsichtigten Dienst. Danach gibst du ihn zurück.",
		"model":"res://assets/viva_roma/props/helmet_lod1.glb"},
	"watch_shield":{
		"title":"Hölzerner Leihschild", "mission":"I-07", "view":"flat", "text":"Der kleine Schild gehört der Wache. Er wird zusammen mit dem Helm zurückgegeben.",
		"model":"res://assets/legio/watch_wood_shield.glb"}
}

static func held(world: Dictionary) -> Array[String]:
	var items: Array[String] = []
	var child: Dictionary = world.get("village",{}).get("childhood",{})
	if child.is_empty():
		return items
	for id: String in child.get("carried",[]):
		if ENTRIES.has(id):
			items.append(id)
	var opening := I01.presentation(world)
	for owner: String in opening.cups:
		if opening.cups[owner] == "hand":
			items.append("cup_"+owner)
	if opening.jug == "hand" and not items.has("water_jug"):
		items.append("water_jug")
	if child.get("screenplay",{}).get("i04_hand",false):
		items.append("stack_armful")
	if child.get("screenplay",{}).get("i07_water","") == "carry":
		items.append("watch_water")
	if child.get("gear","none") == "loaned":
		items.append_array(["watch_helmet","watch_shield"])
	return items

static func held_documents(world: Dictionary) -> Array[String]:
	var documents: Array[String] = []
	for id: String in world.get("village",{}).get("childhood",{}).get("carried",[]):
		if ENTRIES.get(id,{}).get("document",false):
			documents.append(id)
	return documents
