extends RefCounted
## Which outfit of the original youth a game state shows (D-032).
## Presentation only: the rule reads the save and never writes it, so every
## existing save loads unchanged and shows the outfit its state implies.
##
## Plugging in a later outfit (an armoured recruit or an adult): build its LOD
## set and retarget report with the youth pipeline, add one entry to
## village_person.gd MESHY_YOUTH_OUTFITS, and return its id here for the state
## that earns it (enlistment, equipment, band or age). Order the rules from the
## most specific to the most general.

const Childhood = preload("res://scripts/story/village_childhood.gd")
const CIVIL := "civil"
const ARMOURED := "armoured"


static func for_state(state: Dictionary) -> String:
	# Band I childhood: 58 BC, Valdora near Aquileia, a twelve-year-old
	# villager in a wool tunic. No armour, no weapon (handbook "Der erste
	# Morgen"; segmented plate armour is anachronistic before about AD 9).
	if Childhood.enabled(state):
		return CIVIL
	# Older saves without the childhood campaign keep the look they had.
	return ARMOURED
