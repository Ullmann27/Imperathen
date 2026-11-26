extends RefCounted
## One route on the existing eastern road. Goods and money remain in the
## village economy. This contract only holds the shipping receipt and position.
const Road = preload("res://scripts/world/regional_footpath.gd")
const DESK := Road.FREIGHT_DESK
const LOADING_BAY := Vector2(241,112)
const RECEIVING_BAY := Vector2(51,-13)
const DEPOT := Road.GATE_DEPOT
const SPEED := 1.65
const LOAD := 16
const READY := "ready"
const OUTBOUND := "to_valdora"
const RETURNING := "to_weidenhof"
const POINTS := [LOADING_BAY,Road.WAYPOINTS[2],Road.WAYPOINTS[1],RECEIVING_BAY]

static func length_m() -> float:
	var length := 0.0
	for i in range(1,POINTS.size()):
		length += (POINTS[i] as Vector2).distance_to(POINTS[i-1])
	return length

static func empty_receipt() -> Dictionary:
	return {"leg":READY,"metres":0.0,"sent":0,"received":0,"price":0}

static func valid(value: Variant) -> bool:
	if not value is Dictionary or value.size() != 5:
		return false
	for key in ["sent","received","price","metres"]:
		var n: Variant = value.get(key)
		if typeof(n) not in [TYPE_FLOAT,TYPE_INT] or not is_finite(float(n)) or float(n) < 0:
			return false
		if key != "metres" and (float(n) != floor(float(n)) or float(n) > 1000000000):
			return false
	var leg: String = str(value.get("leg",""))
	return leg in [READY,OUTBOUND,RETURNING] and float(value.metres) <= length_m() + .0001 \
		and (leg != READY or float(value.metres) == 0.0) and (value.sent == 0 or int(value.price) in [5,6]) \
		and int(value.sent) == int(value.received) + int(leg == OUTBOUND) and (value.sent > 0 or (leg == READY and value.price == 0))

static func point_at(metres: float) -> Vector2:
	var remaining := maxf(0,metres)
	for i in range(1,POINTS.size()):
		var start: Vector2 = POINTS[i-1]
		var end: Vector2 = POINTS[i]
		var length := start.distance_to(end)
		if remaining <= length:
			return start.lerp(end,remaining/length)
		remaining -= length
	return RECEIVING_BAY

static func pose(receipt: Dictionary) -> Dictionary:
	var leg: String = str(receipt.get("leg",READY))
	var metres := float(receipt.get("metres",0.0))
	var distance := length_m() - metres if leg == RETURNING else metres
	var forward := point_at(distance-1.4).direction_to(point_at(distance+1.4))
	if leg == RETURNING:
		forward = -forward
	return {"position":point_at(distance),"direction":forward,"loaded":leg == OUTBOUND,"moving":leg != READY and metres < length_m()}

static func status(economy: Dictionary) -> String:
	var receipt: Dictionary = economy.get("freight",{})
	match str(receipt.get("leg",READY)):
		OUTBOUND:
			var left := maxf(0.0,length_m()-float(receipt.metres))
			if left < .001:
				return "Fahrt %d · 16 Getreide warten am Osttor auf freien Lagerplatz." % int(receipt.sent)
			return "Fahrt %d · 16 Getreide zum Osttor · noch %d m, etwa %d s." % [int(receipt.sent),ceili(left),ceili(left/SPEED)]
		RETURNING:
			return "Fahrt %d quittiert · 16 Getreide in Valdora. Der leere Wagen kommt zurück." % int(receipt.received)
	var delivered := int(receipt.get("received",0))
	return "Wagen am Weidenhof · %d Lieferungen in Valdora quittiert." % delivered
