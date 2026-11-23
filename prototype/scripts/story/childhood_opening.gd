extends RefCounted
## Authored introduction to the existing village. It does not change campaign time.

static func sequence() -> Dictionary:
	var chapter := "Kapitel I · Menschen, die dich kennen"
	var location := "Ein fiktives Dorf im Donauraum · um 100 n. Chr."
	var beats: Array[Dictionary] = []
	for item in [
		["home_morning", "valley", "Chronik", "Dein erster Tag · 12 Jahre", "Du kennst diese Wege seit deiner Kindheit. Hinter den Häusern liegen die Felder; auf dem Markt werden Vorräte und Nachrichten getauscht. Heute wartet deine Mutter auf dich."],
		["family_roof", "plot", "Julia", "Deine Mutter", "Komm nach Hause, bevor du zum Brunnen gehst. Für die Nachbarn liegt etwas bereit. Du kannst helfen – und wenn etwas schiefgeht, reden wir darüber."],
		["familiar_friend", "well", "Marcus", "Dein Freund", "Später zeige ich dir den Weg zur Werkstatt. Sextus lässt niemanden einfach an die Esse. Erst sehen wir zu, dann dürfen wir mithelfen."],
		["childhood_handoff", "player", "Chronik", "Ein Platz im Dorf", "Du hast ein Zuhause und Menschen, die dich kennen. Besuche Julia im südlichen Wohnviertel. Der Wegweiser führt zuerst zum Hauseingang. Den nächsten Tag beginnst du erst, wenn du zu Hause schlafen gehst."]]:
		beats.append({"id":item[0],"shot_id":item[1],"speaker":item[2],"role":item[3],"text":item[4],
			"duration":maxf(7.0, 2.0 + str(item[4]).length() / 17.0),"chapter":chapter,"location":location})
	return {"id":"childhood_first_day","version":1,"origin_id":"italia","title":"Ein Morgen zu Hause",
		"chapter":chapter,"location":location,"beats":beats,"objective_title":"Julia wartet zu Hause",
		"objective_text":"Geh zu deiner Mutter ins südliche Wohnhaus. Interagieren öffnet das Gespräch. Du kannst lesen, umhergehen und später zurückkommen; dadurch vergehen keine Lebensjahre."}
