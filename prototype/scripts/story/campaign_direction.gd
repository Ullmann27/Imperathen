extends RefCounted
## New German directing cues derived from Band I's authored story spine.
## These are fictional narration, not historical quotations or completed events.
## A cue never grants a reward, implies a particular choice, or advances time.
const INTRO := {
  "I-02": "Ein Korb ist nur ein kleiner Auftrag. Doch die Menschen hier sind darauf angewiesen, dass sie bekommen, was ihnen zugesagt wurde.",
  "I-03": "Hinter den vertrauten Häusern beginnt ein anderer Teil des Dorfes. Auf dem Markt zählt, was jemand verspricht – und was davon übrig bleibt.",
  "I-04": "Silvanus hat einen Freund, dem er seit Jahren vertraut. In dessen Schmiede kannst du lernen, warum eine ruhige Hand manchmal mehr wert ist als Kraft.",
  "I-05": "Ein gutes Werkzeug entsteht nicht mit dem ersten Schlag. Wer genau hinsieht, erkennt auch die Fehler, die sich unter der Oberfläche verbergen.",
  "I-06": "Ein Werkstück muss seinen Weg zum richtigen Menschen finden. Am Markt zeigt sich, was Arbeit tatsächlich wert ist.",
  "I-07": "Die Wachen kennen die Wege um Valdora. Auch sie brauchen Hilfe, wenn ihre Kraft nicht ausreicht.",
  "I-08": "Der Regen verwischt manche Spuren, andere bleiben im Boden. Erst was du selbst gesehen hast, darf zu deiner Gewissheit werden.",
  "I-09": "Wenn die Arbeit ruht, haben die Menschen noch ihre eigenen Geschichten. Heute Abend ist Zeit für sie.",
  "I-10": "Die Nacht gehört nicht mehr nur den Schlafenden. Was jetzt geschieht, verlangt deine Entscheidung.",
  "I-11": "Die Werkstatt ist mehr als Holz, Stein und eine Esse. Dort zählt jetzt, wem noch geholfen werden kann.",
  "I-12": "In den vertrauten Gassen entscheiden nicht Versprechen allein. Jetzt kommt es darauf an, was du tatsächlich tun kannst.",
  "I-13": "Am Morgen wird sichtbar, was die Nacht zurückgelassen hat. Manche Stimmen fehlen; andere Menschen brauchen dich.",
  "I-14": "Nicht jede Spur führt sofort zu einer Antwort. Was du aus dieser Nacht mitnimmst, wird deinen nächsten Weg bestimmen.",
  "I-15": "Unter den Überresten können Hinweise liegen. Ein Gegenstand ist noch kein Beweis, aber er kann eine Frage beantworten.",
  "I-16": "Ein zerstörtes Haus ist nicht in einem Tag wieder aufgebaut. Valdora braucht Hände, Vorräte und Menschen, die bleiben.",
  "I-17": "Holz, das an einem Ort fehlt, kann an einem anderen ein Dach retten. Entscheide, wofür du Verantwortung übernimmst.",
  "I-18": "Der Winter wartet auf niemanden. Was aus den vergangenen Monaten geworden ist, muss sich nun bewähren.",
  "I-19": "In Aquileia begegnen sich Menschen, die aus ganz verschiedenen Gründen Macht suchen. Beobachte, bevor du urteilst.",
  "I-20": "Ein rotes Siegel lässt sich auf einem Stück Wachs hinterlassen. Wer es trägt und wozu es dient, musst du erst herausfinden.",
  "I-21": "Marcus hat eigene Wünsche. Ein Freund kann einen anderen Weg wählen, ohne dass eure gemeinsame Geschichte verschwindet.",
  "I-22": "Die Arbeit an der zweiten Klinge verlangt dieselbe Aufmerksamkeit wie die erste Lehre. Was du beherrschst, zeigt sich in der Bewegung.",
  "I-23": "Jenseits der Berge liegen neue Wege. Eine Reise besteht aus mehr als der Entfernung zwischen zwei Orten.",
  "I-24": "Du betrittst einen Ort, an dem andere Menschen zu Hause sind. Was für dich eine Entscheidung ist, kann für sie die Zukunft bedeuten.",
  "I-25": "Am Feuer erzählen Menschen von dem, was sie unterwegs gelernt haben. Nicht jeder, der eine Waffe trägt, hat denselben Weg gewählt.",
  "I-26": "Ein Name auf einer Liste bedeutet Verpflichtung. Überlege, welchem Weg du deinen Namen geben willst.",
  "I-27": "Die Menschen, Tiere und Wagen auf der Straße brauchen Versorgung. Ohne sie kommt auch eine große Armee nicht weit.",
  "I-28": "Vor Alesia geht es um mehr als Waffen. Arbeit, Zeit und Vorräte bestimmen, was überhaupt möglich ist.",
  "I-29": "Was zuvor vorbereitet wurde, muss sich nun bewähren. Deine Entscheidungen treffen auf die Wirklichkeit der Schlacht.",
  "I-30": "Nach dem Kampf bleibt die Frage, wie man mit den Menschen umgeht, die ihn überlebt haben.",
  "I-31": "Die Dinge, die du im Dorf gelernt hast, helfen dir jetzt, größere Zusammenhänge zu erkennen."
}

static func introduction(mission_id: String) -> String:
	return str(INTRO.get(mission_id,""))
