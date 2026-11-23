extends RefCounted
## Authored streets and households. Presentation never changes the resource ledger.

const HOUSE_FLOOR := 0.3925
const CITIZEN_LAYER := 8
const CITIZEN_RADIUS := 0.29

const HOMES := [
	{"id":"baker_home", "at":Vector3(-13,0,11), "yaw":0.0, "tint":"e3cbb0"},
	{"id":"carpenter_home", "at":Vector3(-14,0,-11), "yaw":0.0, "tint":"cdbb9c"},
	{"id":"weaver_home", "at":Vector3(-5,0,-19), "yaw":0.0, "tint":"dfd4bd"},
	{"id":"farmer_home", "at":Vector3(20,0,-18), "yaw":0.0, "tint":"c9bd9e"},
	{"id":"potter_home", "at":Vector3(-14,0,-28), "yaw":0.0, "tint":"d4b19a"},
	{"id":"healer_home", "at":Vector3(-14,0,-41), "yaw":0.0, "tint":"d7c8a9"},
	{"id":"elder_home", "at":Vector3(-4,0,-41), "yaw":0.0, "tint":"c8c3a7"},
	{"id":"scribe_home", "at":Vector3(8,0,-43), "yaw":0.0, "tint":"e2d8bf"},
	{"id":"vintner_home", "at":Vector3(24,0,-43), "yaw":0.0, "tint":"c9a692"},
	{"id":"guard_home", "at":Vector3(38,0,-39), "yaw":-PI/2, "tint":"c3bea9"},
	{"id":"smith_home", "at":Vector3(38,0,-26), "yaw":-PI/2, "tint":"b4aba0"},
	{"id":"cloth_home", "at":Vector3(38,0,-10), "yaw":-PI/2, "tint":"d8c1a9"},
	{"id":"wagon_home", "at":Vector3(38,0,8), "yaw":-PI/2, "tint":"d3c9aa"},
	{"id":"charcoal_home", "at":Vector3(-5,0,-29), "yaw":0.0, "tint":"c4b59c"},
	{"id":"leather_home", "at":Vector3(16,0,-43), "yaw":0.0, "tint":"ddc5a5"},
	{"id":"grain_home", "at":Vector3(21,0,-8), "yaw":0.0, "tint":"d5c4a6"},
	{"id":"south_baker_home", "at":Vector3(-14,0,24), "yaw":0.0, "tint":"dfc4a9"},
	{"id":"south_weaver_home", "at":Vector3(-5,0,24), "yaw":0.0, "tint":"c5baa4"},
	{"id":"cooper_home", "at":Vector3(15,0,19), "yaw":0.0, "tint":"e1cdb0"},
	{"id":"dairy_home", "at":Vector3(41,0,23), "yaw":-PI/2, "tint":"cfc6a8"},
]

const VOLUNTEERS := ["marius", "marcellus", "domitius"]
const RESIDENTS := [
	{"id":"livia", "name":"Livia", "occupation":"Händlerin", "appearance":"civilian_woman", "age":38, "at":Vector3(-14,0,4), "route":[], "work":"work", "greeting":"An dieser Straße hängt das ganze Dorf: Was auf den Wagen fehlt, fehlt später in unseren Vorratskammern."},
	{"id":"cassian", "name":"Cassian", "occupation":"Schreiber", "appearance":"civilian_man", "age":44, "at":Vector3(14,0,-22), "route":[], "work":"work", "greeting":"Ein Siegel ersetzt kein ehrliches Wort. Ich schreibe auf, was jemand wirklich gesehen hat."},
	{"id":"aulus", "name":"Aulus", "occupation":"Veteran", "appearance":"officer", "age":54, "at":Vector3(4,0,-25), "route":[], "work":"idle", "greeting":"Eine Legion besteht aus Menschen. Wer ihre Namen kennt, führt besser als jemand, der nur Befehle ruft."},
	{"id":"titus", "name":"Titus", "occupation":"Wagenführer", "appearance":"civilian_man", "age":41, "at":Vector3(3,0,24), "route":[], "work":"work", "greeting":"Der Weg nach Süden beginnt mit einer haltbaren Achse, genügend Wasser und einem verlässlichen Begleiter."},
	{"id":"flavia", "name":"Flavia", "occupation":"Bäckerin", "appearance":"civilian_woman", "age":33, "at":Vector3(-16,0,7), "route":[Vector3(-16,0,4),Vector3(-11,0,4),Vector3(-11,0,1.8)], "work":"work", "greeting":"Das erste Brot gehört den Leuten, die schon vor Sonnenaufgang arbeiten. Danach ist Zeit für Neuigkeiten."},
	{"id":"marius", "name":"Marius", "occupation":"Zimmermann", "appearance":"civilian_man", "age":25, "at":Vector3(-6,0,-6), "route":[Vector3(-4,0,-6),Vector3(-4,0,0),Vector3(-6,0,1)], "work":"work", "greeting":"Eine gerade Fuge macht mehr Arbeit als ein schneller Schnitt. Deine erste Hütte darf ruhig Zeit brauchen."},
	{"id":"sabina", "name":"Sabina", "occupation":"Tuchhändlerin", "appearance":"civilian_woman", "age":29, "at":Vector3(32,0,18), "route":[Vector3(30,0,18),Vector3(30,0,4),Vector3(32,0,4)], "work":"work", "greeting":"Wolle für den Winter, Leinen für den Sommer. Die Farbe allein sagt noch nichts über die Qualität."},
	{"id":"gaius", "name":"Gaius", "occupation":"Töpfer", "appearance":"civilian_man", "age":48, "at":Vector3(-16,0,-24), "route":[Vector3(-10,0,-24),Vector3(-10,0,-34)], "work":"work", "greeting":"Meine Krüge reisen weiter als ich. Manche kommen bis in die Lager an der Grenze."},
	{"id":"nerva", "name":"Nerva", "occupation":"Schmied", "appearance":"elder", "age":61, "at":Vector3(32,0,-11), "route":[Vector3(30,0,-11),Vector3(30,0,-20),Vector3(31,0,-21)], "work":"work", "greeting":"Ein gutes Werkzeug wird gepflegt. Eisen ist teuer; die Hand, die es benutzt, ist unersetzlich."},
	{"id":"priscilla", "name":"Priscilla", "occupation":"Heilerin", "appearance":"civilian_woman", "age":46, "at":Vector3(-7,0,-35), "route":[Vector3(-2,0,-35),Vector3(2,0,-35),Vector3(4,0,-30),Vector3(3,0,-27)], "work":"idle", "greeting":"Sauberes Wasser und Ruhe sind in einem vollen Dorf ebenso wichtig wie Mut an der Straße."},
	{"id":"octavia", "name":"Octavia", "occupation":"Weinbäuerin", "appearance":"civilian_woman", "age":52, "at":Vector3(21,0,-36), "route":[Vector3(27,0,-36),Vector3(30,0,-32),Vector3(30,0,-28)], "work":"work", "greeting":"Die Reben stehen jedes Jahr am selben Hang. Trotzdem verlangt jedes Jahr eine andere Entscheidung."},
	{"id":"publius", "name":"Publius", "occupation":"Bote", "appearance":"civilian_man", "age":22, "at":Vector3(2.6,0,-3), "route":[Vector3(2.6,0,-12),Vector3(0,0,-14),Vector3(0,0,-35)], "work":"idle", "greeting":"Ich bringe Briefe, keine Gewissheiten. Manchmal ist eine Nachricht schon alt, wenn ich den nächsten Ort erreiche."},
	{"id":"lucius", "name":"Lucius", "occupation":"Straßenwache", "appearance":"legionary", "age":31, "at":Vector3(0,0,-46), "route":[Vector3(2,0,-43),Vector3(2,0,-37),Vector3(0,0,-35)], "work":"idle", "greeting":"Die Straße bleibt für Händler und Reisende offen. Verdächtiges melden wir, bevor jemand allein loszieht."},
	{"id":"sergius", "name":"Sergius", "occupation":"Torwache", "appearance":"legionary", "age":36, "at":Vector3(43,0,28), "route":[Vector3(33,0,28),Vector3(30,0,26)], "work":"idle", "greeting":"Am Tor merkt man, wie es einem Ort geht: Wer kommt, wer fehlt und welcher Wagen leer zurückkehrt."},
	{"id":"rufina", "name":"Rufina", "occupation":"Korbmacherin", "appearance":"civilian_woman", "age":43, "at":Vector3(-18,0,20), "route":[Vector3(-18,0,27),Vector3(-14,0,28),Vector3(-4,0,28)], "work":"work", "greeting":"Ein Korb trägt Korn, Werkzeug oder einen halben Haushalt. Die Weiden am Bach liefern uns die Ruten."},
	{"id":"marcellus", "name":"Marcellus", "occupation":"Lagerarbeiter", "appearance":"civilian_man", "age":24, "at":Vector3(23,0,-24), "route":[Vector3(28,0,-24),Vector3(30,0,-19),Vector3(30,0,-6)], "work":"work", "greeting":"Ich zähle jedes Bündel zweimal. Eine fehlende Ladung bemerkt man sonst erst, wenn der Wagen schon fort ist."},
	{"id":"tullia", "name":"Tullia", "occupation":"Weberin", "appearance":"civilian_woman", "age":34, "at":Vector3(32,0,5), "route":[Vector3(30,0,5),Vector3(30,0,-4),Vector3(32,0,-4)], "work":"work", "greeting":"Die Kette muss gespannt bleiben, aber nicht reißen. Das gilt hier nicht nur für den Webstuhl."},
	{"id":"domitius", "name":"Domitius", "occupation":"Feldarbeiter", "appearance":"civilian_man", "age":26, "at":Vector3(17,0,-13), "route":[Vector3(23,0,-13),Vector3(26,0,-13)], "work":"work", "greeting":"Wenn alle fortziehen, erntet niemand das Korn. Darum zählt auch die Arbeit derer, die im Dorf bleiben."},
	{"id":"bassa", "name":"Bassa", "occupation":"Brotverkäuferin", "appearance":"civilian_woman", "age":42, "at":Vector3(-18,0,10), "route":[Vector3(-18,0,14),Vector3(-18,0,17)], "work":"idle", "greeting":"Der Teig ruht seit gestern. Das Brot wird heute noch warm auf dem Markt liegen."},
	{"id":"felix", "name":"Felix", "occupation":"Fassbinder", "appearance":"civilian_man", "age":35, "at":Vector3(18,0,23), "route":[Vector3(21,0,23),Vector3(21,0,27),Vector3(18,0,28)], "work":"work", "greeting":"Ein Fass muss auch auf einer holprigen Straße dicht bleiben. Daran erkennst du meine Arbeit."},
	{"id":"gaia", "name":"Gaia", "occupation":"Köchin", "appearance":"civilian_woman", "age":47, "at":Vector3(-8,0,15), "route":[Vector3(-6,0,15),Vector3(-6,0,17)], "work":"idle", "greeting":"Wir teilen den Herd, aber jede Familie würzt ihren Topf anders. Stell deinen Krug nicht zu nah ans Feuer."},
	{"id":"hilarus", "name":"Hilarus", "occupation":"Müller", "appearance":"civilian_man", "age":39, "at":Vector3(25,0,-6), "route":[Vector3(26.4,0,-6),Vector3(26.4,0,-11)], "work":"work", "greeting":"Wenn das Korn trocken gelagert wird, haben wir auch im Winter genug zu mahlen."},
	{"id":"irena", "name":"Irena", "occupation":"Färberin", "appearance":"civilian_woman", "age":28, "at":Vector3(33,0,12), "route":[Vector3(30,0,12),Vector3(30,0,8)], "work":"work", "greeting":"Die Tücher brauchen frisches Wasser und Zeit zum Trocknen. Heute ist ein guter Tag dafür."},
	{"id":"leontius", "name":"Leontius", "occupation":"Hirte", "appearance":"elder", "age":57, "at":Vector3(33,0,-35), "route":[Vector3(30,0,-35),Vector3(30,0,-39)], "work":"idle", "greeting":"Ich komme vor Einbruch der Dunkelheit zurück. An den leeren Trögen merkt man sofort, wie warm der Tag war."},
	{"id":"mina", "name":"Mina", "occupation":"Spinnerin", "appearance":"civilian_woman", "age":23, "at":Vector3(-.8,0,-24), "route":[Vector3(-.8,0,-20),Vector3(-.8,0,-17)], "work":"idle", "greeting":"Ein ganzer Mantel beginnt mit einem einzigen Faden. Ich kann dir zeigen, wie man ihn gleichmäßig hält."},
	{"id":"naso", "name":"Naso", "occupation":"Ölhändler", "appearance":"civilian_man", "age":51, "at":Vector3(4,0,-38), "route":[Vector3(4,0,-41),Vector3(4,0,-45)], "work":"idle", "greeting":"Die kleinen Krüge sind für die Küchen, die großen reisen mit den Wagen. Jeder Verschluss wird geprüft."},
]

static func resident(id: String) -> Dictionary:
	for item: Dictionary in RESIDENTS:
		if item.id == id:
			return item
	return {}

static func house_footprint(home: Dictionary, margin := 0.0) -> Rect2:
	var dimensions := Vector2(5.9,4.9)
	if not is_zero_approx(float(home.yaw)):
		dimensions = Vector2(dimensions.y,dimensions.x)
	var center := Vector2(home.at.x,home.at.z)
	return Rect2(center-dimensions*.5-Vector2.ONE*margin,dimensions+Vector2.ONE*margin*2)

static func reserved(p: Vector2, margin := 0.0) -> bool:
	for home: Dictionary in HOMES:
		if house_footprint(home,margin).has_point(p):
			return true
	for yard: Rect2 in [Rect2(8,-35.5,12,11), Rect2(31.5,-30,4,8), Rect2(-17,13,5,5),
		Rect2(20.5,-33,7,6.5), Rect2(-46.5,11,7,7), Rect2(44.5,-15,7,8),
		Rect2(21.5,20.5,7,7), Rect2(-3.5,-50.5,7,7)]:
		if yard.grow(margin).has_point(p):
			return true
	return false

static func road(p: Vector2) -> bool:
	# Matching branch streets are also authored into the continuous ground shader.
	return (absf(p.x-30.0)<2.3 and p.y>-46 and p.y<29) or (absf(p.y+36.5)<2.2 and p.x>-18 and p.x<34) or (absf(p.y-28.0)<1.2 and p.x>-19 and p.x<45) or (absf(p.y-24.0)<1.3 and p.x>1 and p.x<29)

static func pose_at(item: Dictionary, seconds: float, index: int) -> Dictionary:
	var origin: Vector3 = item.at
	var route: Array = item.route
	if route.is_empty():
		return {"position":origin,"direction":Vector3.FORWARD,"speed":0.0,"activity":item.work}
	var points: Array[Vector3] = [origin]
	for point: Vector3 in route:
		points.append(point)
	# Retrace the authored safe corridor; a diagonal closing edge could cut through a home.
	for i in range(points.size()-2,-1,-1):
		points.append(points[i])
	var speed := 0.82 + float(index%5)*.085
	var dwell := 6.0+float(index%4)*1.7
	var travel := 0.0
	for i in range(points.size()-1):
		travel += points[i].distance_to(points[i+1])/speed
	var clock := fposmod(maxf(0.0,seconds)+float(index)*5.37,travel+dwell*2)
	if clock < dwell:
		return {"position":origin,"direction":Vector3.FORWARD,"speed":0.0,"activity":item.work}
	clock -= dwell
	var furthest := route.size()-1
	for i in range(points.size()-1):
		var edge := points[i+1]-points[i]
		var duration := edge.length()/speed
		if clock < duration:
			return {"position":points[i].lerp(points[i+1],clock/duration),"direction":edge.normalized(),"speed":speed,"activity":"march"}
		clock -= duration
		if i == furthest:
			if clock < dwell:
				return {"position":points[i+1],"direction":-edge.normalized(),"speed":0.0,"activity":"idle"}
			clock -= dwell
	return {"position":origin,"direction":Vector3.FORWARD,"speed":0.0,"activity":item.work}
