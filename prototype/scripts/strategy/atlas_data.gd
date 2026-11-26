extends RefCounted
## Site coordinates anchor representative regions. Edges are fictional campaign routes.
## Named communities and archaeological traditions do not imply unified states.
## REGIONS carries the names and notes of the 100 AD reference timeline.
## ERA_VARIANTS replaces a name or note where it would be an anachronism on
## the world date (58 BC campaign); `region_view` chooses by the era registry
## where it has a state for the region, otherwise by year. First match wins.
const Era = preload("res://scripts/domain/era_registry.gd")
const WorldCalendar = preload("res://scripts/domain/world_calendar.gd")
const REGIONS := {
	"italia":{"name":"Rom · Italia","lat":41.9,"lon":12.5,"links":["gallia","germania","aegyptus","greek","africa"],"note":"Unter Trajan ist Rom das Zentrum des Reiches. Beginn der Referenzkampagne um 100 n. Chr."},
	"gallia":{"name":"Lugdunum · Gallien","lat":45.76,"lon":4.83,"links":["italia","britannia","hispania","germania"],"note":"Römische Provinzlandschaft am Zusammenfluss von Rhône und Saône."},
	"britannia":{"name":"Britannia · Londinium","lat":51.51,"lon":-0.09,"links":["gallia","woodlands"],"note":"Londinium liegt in der römisch beherrschten Provinz. Die Atlantikpassage ist ein späteres Spielziel."},
	"hispania":{"name":"Hispania · Baetica","lat":37.9,"lon":-4.8,"links":["gallia","africa"],"note":"Städte und Landgüter der römischen Baetica am Baetis."},
	"germania":{"name":"Gemeinschaften östlich des Rheins","lat":51.4,"lon":10.1,"links":["gallia","italia","vistula","northern"],"note":"Mehrere Gemeinschaften mit unterschiedlichen Bündnissen. Germania bezeichnet hier die Region."},
	"northern":{"name":"Südskandinavien","lat":55.6,"lon":12.0,"links":["germania","vistula"],"note":"Höfe und Austauschplätze der nordischen römischen Eisenzeit."},
	"vistula":{"name":"Weichselraum · Przeworsk-Kultur","lat":50.1,"lon":20.1,"links":["germania","northern","steppe"],"note":"Archäologischer Fundzusammenhang im heutigen Polen. Eine politische Einheit ist daraus nicht abzuleiten."},
	"greek":{"name":"Ägäis · Achaia","lat":37.98,"lon":23.73,"links":["italia","parthia","aegyptus","steppe"],"note":"Griechische Städte innerhalb des römischen Provinzsystems."},
	"africa":{"name":"Africa Proconsularis · Karthago","lat":36.85,"lon":10.33,"links":["hispania","aegyptus","sahel","italia"],"note":"Karthago ist eine bedeutende Stadt der römischen Provinz."},
	"aegyptus":{"name":"Alexandria · Ägypten","lat":31.2,"lon":29.9,"links":["africa","italia","greek","kush","parthia"],"note":"Hafen und Verwaltungszentrum des römischen Ägypten."},
	"kush":{"name":"Kusch · Meroë","lat":16.94,"lon":33.75,"links":["aegyptus","aksum","sahel"],"note":"Das meroitische Königreich am mittleren Nil."},
	"aksum":{"name":"Aksum · Horn von Afrika","lat":14.13,"lon":38.72,"links":["kush","indus","eastafrica"],"note":"Frühes Aksum und der Handel im Roten Meer."},
	"sahel":{"name":"Mittlerer Niger","lat":13.9,"lon":-4.55,"links":["africa","kush","eastafrica"],"note":"Siedlungsräume am Binnendelta. Der Atlas fasst mehrere Gemeinschaften zusammen."},
	"eastafrica":{"name":"Ostafrikanische Küste","lat":-6.4,"lon":38.9,"links":["aksum","sahel","southafrica"],"note":"Ein geographischer Knoten für die frühe Küstenbesiedlung."},
	"southafrica":{"name":"Südliches Afrika","lat":-28.6,"lon":23.8,"links":["eastafrica"],"note":"Regionaler Spielknoten für verschiedene Gemeinschaften."},
	"parthia":{"name":"Arsakiden · Ktesiphon","lat":33.09,"lon":44.58,"links":["greek","aegyptus","indus","steppe"],"note":"Die Arsakiden herrschen über das Partherreich."},
	"steppe":{"name":"Pontische Steppe","lat":47.3,"lon":40.0,"links":["vistula","greek","parthia","tarim"],"note":"Sarmatisch geprägte Gruppen und wechselnde Verbindungen über die Steppe."},
	"indus":{"name":"Kuschan · Gandhāra","lat":34.01,"lon":71.58,"links":["parthia","aksum","tarim","deccan"],"note":"Kuschanzeitlicher Kulturraum im Nordwesten des indischen Subkontinents."},
	"deccan":{"name":"Dekkan · Sātavāhana","lat":19.5,"lon":75.4,"links":["indus","mekong"],"note":"Herrschaftsraum auf dem Dekkan mit regional wechselnden Machtzentren."},
	"tarim":{"name":"Oasen des Tarimbeckens","lat":39.47,"lon":75.99,"links":["steppe","indus","han"],"note":"Oasenreiche zwischen den westlichen und östlichen Handelswegen."},
	"han":{"name":"Östliche Han · Luoyang","lat":34.68,"lon":112.45,"links":["tarim","mekong","korea"],"note":"Luoyang ist Hauptstadt der Östlichen Han. Die Dynastie regiert von 25 bis 220 n. Chr."},
	"korea":{"name":"Südliche Halbinsel · Samhan","lat":35.23,"lon":128.88,"links":["han","wa"],"note":"Mahan, Jinhan und Byeonhan bezeichnen mehrere Gemeinschaften der südlichen koreanischen Halbinsel."},
	"wa":{"name":"Wa · nördliches Kyūshū","lat":33.32,"lon":130.38,"links":["korea","pacific"],"note":"Gemeinschaften der Yayoi-Zeit mit Reisanbau und umgrabenen Siedlungen. Wa ist eine historische Fremdbezeichnung."},
	"mekong":{"name":"Unterer Mekong","lat":10.8,"lon":105.1,"links":["han","deccan","sunda"],"note":"Regionale Fluss- und Küstenverbindungen in Südostasien."},
	"sunda":{"name":"Sundainseln","lat":-7.5,"lon":110.8,"links":["mekong","australia","pacific"],"note":"Maritime Gemeinschaften im Inselraum. Der Knoten steht für einen regionalen Auftrag."},
	"australia":{"name":"Australische Nordküste","lat":-12.4,"lon":132.9,"links":["sunda","pacific"],"note":"Aboriginal-Gemeinschaften mit eigenen Ländern und Überlieferungen."},
	"pacific":{"name":"Westpolynesien · Tonga","lat":-21.14,"lon":-175.2,"links":["sunda","australia","wa","andes"],"note":"Schon lange besiedelte Inseln Westpolynesiens. Die transozeanischen Kanten gehören zur Spielsimulation."},
	"woodlands":{"name":"Ohio-Tal · Hopewell","lat":39.35,"lon":-82.99,"links":["britannia","mesoamerica"],"note":"Archäologische Tradition mit weitreichendem Austausch und monumentalen Erdwerken."},
	"mesoamerica":{"name":"Hochland · Teotihuacán","lat":19.69,"lon":-98.84,"links":["woodlands","maya"],"note":"Im zentralmexikanischen Hochland wächst ein urbanes Zentrum."},
	"maya":{"name":"Maya-Tiefland","lat":17.75,"lon":-89.9,"links":["mesoamerica","andes"],"note":"Spätpräklassische Maya-Gemeinschaften und städtische Zentren."},
	"andes":{"name":"Anden · Nordküste","lat":-8.1,"lon":-79.0,"links":["maya","pacific","amazon"],"note":"Regionale Gesellschaften der Andenküste in einer Zeit früher Moche-Traditionen."},
	"amazon":{"name":"Amazonasbecken","lat":-3.15,"lon":-59.9,"links":["andes"],"note":"Vielfältige Flussgemeinschaften. Der Kartenknoten fasst ein sehr großes Gebiet zusammen."}
}

## "state": [slot, id] matches the registry state of the date ("" = none);
## "before": year matches dates before 1 January of that historical year.
## Variants without a registry state are authored defaults (literature not
## verified: Hispania Ulterior, pre-Roman Iron Age, Africa/Utica, Gandhāra,
## Andean coast); see docs/37_world_calendar/WORLD_STATE.md.
const ERA_VARIANTS := {
	"italia": [
		{"state": ["rome.power_bloc", "political.rome.first_triumvirate"], "name": "Rom · Italia", "note": "Rom ist das Zentrum der Republik. Caesar, Pompeius und Crassus teilen die Macht. Die Kampagne beginnt 58 v. Chr. im Raum Aquileia."},
		{"state": ["rome.dictatorship", "political.rome.caesar_dictatorship"], "name": "Rom · Italia", "note": "Rom ist das Zentrum der Republik. Caesar herrscht als Diktator."},
		{"state": ["rome.princeps", "political.rome.principate_augustus"], "name": "Rom · Italia", "note": "Rom ist das Zentrum des Reiches unter Augustus."},
		{"before": 98, "name": "Rom · Italia", "note": "Rom ist das Zentrum der römischen Welt."}],
	"gallia": [
		{"state": ["gallia.status", "political.gallia.gallic_war"], "name": "Gallien · Rhône und Saône", "note": "Gallische Stammesgebiete am Zusammenfluss von Rhône und Saône. Caesar führt Krieg in Gallien."},
		{"state": ["gallia.lugdunum", ""], "name": "Gallien · Rhône und Saône", "note": "Gallische Stammesgebiete am Zusammenfluss von Rhône und Saône."}],
	"britannia": [
		{"state": ["britannia.rule", ""], "name": "Britannien · Themse", "note": "Britannische Stammesgebiete an der Themse, außerhalb römischer Herrschaft. Die Atlantikpassage ist ein späteres Spielziel."}],
	"hispania": [
		{"before": -27, "name": "Hispania Ulterior · Baetis", "note": "Städte und Landgüter der römischen Provinz Hispania Ulterior am Baetis."}],
	"northern": [
		{"before": 1, "name": "Südskandinavien", "note": "Höfe und Austauschplätze der vorrömischen Eisenzeit im Norden."}],
	"greek": [
		{"state": ["achaia.rule", ""], "name": "Ägäis · Griechenland", "note": "Griechische Städte unter der Aufsicht des römischen Statthalters von Macedonia."}],
	"africa": [
		{"before": -44, "name": "Africa · Utica", "note": "Römische Provinz Africa mit dem Statthaltersitz Utica. Karthago liegt seit 146 v. Chr. zerstört."}],
	"aegyptus": [
		{"state": ["aegyptus.rule", "region.aegyptus.ptolemaic_kingdom"], "name": "Alexandria · Ägypten", "note": "Hafen und Hauptstadt des Ptolemäerreiches."}],
	"indus": [
		{"state": ["indus.rule", ""], "name": "Gandhāra", "note": "Indo-griechische und sakische Herrschaften im Nordwesten des indischen Subkontinents."}],
	"han": [
		{"state": ["china.dynasty", "region.han.western_han"], "name": "Westliche Han · Luoyang", "note": "Luoyang ist eine der großen Städte der Westlichen Han; Hauptstadt ist Chang'an. Die Dynastie regiert von 202 v. Chr. bis 9 n. Chr."},
		{"state": ["china.dynasty", "region.han.xin"], "name": "Xin · Luoyang", "note": "Wang Mang regiert als Kaiser der Xin von Chang'an aus."}],
	"andes": [
		{"before": 100, "name": "Anden · Nordküste", "note": "Regionale Gesellschaften der Andenküste vor den Moche-Zentren."}]
}


## Political geography for the opening campaign year. Dates with later
## regimes retain their own era-specific descriptions. Sources in ATLAS_58.md.
const OPENING_YEAR := {
	"italia":"In der Römischen Republik bestimmen unter anderem Konsuln und Senat die Politik. Caesar, Pompeius und Crassus verbindet ein privates Bündnis. Caesar führt als Prokonsul Truppen in Gallien. Ein persönliches Gefolge begründet keinen staatlichen Oberbefehl.",
	"gallia":"Jenseits der römischen Provinz handeln gallische Gemeinschaften selbständig. Der Zug der Helvetier und die Beziehungen der Haeduer zu Rom prägen das Jahr. Bei den Haeduern führt ein jährlich bestellter Vergobret die Regierung.",
	"germania":"Am Rhein treffen lokale Gefolgschaften, Sueben und Verbündete Ariovists auf gallische Nachbarn. Persönliche Bindungen und Abgaben verbinden politisch eigenständige Gruppen.",
	"hispania":"Rom verwaltet Hispania Citerior und Hispania Ulterior. Der Baetis liegt in Ulterior. Gemeinschaften im nordwestlichen Binnenland liegen außerhalb der römischen Provinzherrschaft.",
	"britannia":"Südliche Gemeinschaften stehen über den Ärmelkanal mit Gallien in Verbindung. Caesars Expeditionen auf die Insel beginnen erst 55 v. Chr.",
	"greek":"Griechische Städte besitzen unterschiedliche Bündnisverträge und Rechte. Der Statthalter von Macedonia übt Aufsicht aus. Auf der südlichen Halbinsel wird erst 27 v. Chr. eine eigene Provinz eingerichtet.",
	"africa":"Utica ist Sitz des römischen Statthalters in Africa. Westlich der Provinz liegt das Königreich Numidien mit eigener Führung und eigenen Truppen.",
	"aegyptus":"Alexandria ist das Zentrum des ptolemäischen Königreichs. Im Laufe des Jahres 58 v. Chr. verliert Ptolemaios XII. die Herrschaft in Alexandria. Berenike IV. besteigt den Thron.",
	"parthia":"Östlich des Euphrat herrschen die Arsakiden. Adlige Gefolgschaften stellen berittene Bogenschützen und gepanzerte Reiter für das königliche Aufgebot."
}

## Name and note of a region on a world date. `jdn` < 0 (no clock) keeps the
## reference timeline.
static func region_view(id: String, jdn: int = -1) -> Dictionary:
	var base: Dictionary = REGIONS[id]
	var opening: String = OPENING_YEAR.get(id, "") if jdn >= 0 and int(WorldCalendar.from_jdn(jdn).year) == -58 else ""
	if jdn >= 0:
		for variant: Dictionary in ERA_VARIANTS.get(id, []):
			var matches := false
			if variant.has("state"):
				matches = Era.state_at(str(variant.state[0]), jdn) == str(variant.state[1])
			elif variant.has("before"):
				matches = jdn < WorldCalendar.to_jdn(int(variant.before), 1, 1)
			if matches:
				return {"name": str(variant.name), "note": str(variant.note) if opening.is_empty() else opening}
	return {"name": str(base.name), "note": str(base.note) if opening.is_empty() else opening}
