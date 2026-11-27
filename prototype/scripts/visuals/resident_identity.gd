extends RefCounted
## Visual identity of every named village resident and of generic villagers.
## Data only: face shape weights, build, skin, hair, beard and clothing by
## role, age and standing. ResidentLook applies it to the imported model.
##
## Era notes (Cisalpine colony, 58 BC; design assumptions, not reconstructions):
## * Adult citizen men are mostly clean-shaven; young men and rural workers may
##   keep a short beard; herders and older craftsmen a fuller one.
## * Clothing is a belted wool/linen tunic; working people wear it shorter and
##   undyed or in cheap earth/madder/weld dyes; traders and the administrator
##   wear better-dyed cloth, a mantle (pallium/sagum type) with a brooch.
## * Married women keep the hair parted and bound; outdoors and in work many
##   cover it with a palla or a working headscarf. Jewellery is modest bronze.
## * Smiths and labourers: leather apron, felt cap (pileus) as working wear.
## Story roles are not invented here; "role" quotes the existing game data.

const FACE_KEYS := ["ID_NoseLength", "ID_NoseWidth", "ID_NoseBridge", "ID_JawWidth", "ID_Chin",
	"ID_FaceLength", "ID_Cheeks", "ID_Cheekbones", "ID_Brow", "ID_Lips", "ID_Ears", "ID_EyeDepth"]
const KINDS := ["civilian_man", "civilian_woman", "elder"]
const TONES := {
	"fair": Color(1.00, 0.96, 0.93), "light": Color(0.97, 0.91, 0.85), "olive": Color(0.91, 0.82, 0.71),
	"tan": Color(0.85, 0.74, 0.62), "deep": Color(0.76, 0.63, 0.51), "ruddy": Color(0.99, 0.87, 0.81)}
## Plain colour words keep the catalog legible; values are dyes on undyed cloth.
const DYES := {
	"undyed": "e6ddca", "bleached": "f1ebdd", "oatmeal": "cdbf9f", "natural_grey": "a69a88",
	"natural_brown": "7a6553", "dark_brown": "54443a", "walnut": "7b5a40", "madder": "a24a3b",
	"faded_madder": "b47566", "madder_brown": "8a4b37", "weld": "c6a650", "ochre": "b78c46",
	"woad": "5c7594", "faded_woad": "8196aa", "deep_woad": "3f5673", "green": "6d7d52",
	"olive": "7c7a4c", "plum": "6c4b5d", "charcoal": "403833", "rust": "9a5a35",
	"leather": "b08a62", "dark_leather": "6a4a33", "oxblood": "79392b",
	"bronze": "c08a4a", "copper": "b87050", "iron": "7c7b78", "silver": "c8ccd1"}
const HAIR := {
	"black": "1b130e", "dark_brown": "2c1c12", "brown": "47301e", "chestnut": "5a3420",
	"auburn": "6c3119", "light_brown": "7b5b3b", "ash": "6a6158", "dark_blond": "8c6f45"}

## Iris colours; brown dominates, lighter eyes are rare in the region.
const EYES := {"dark_brown": "2a180c", "brown": "4a2b15", "hazel": "6a5528", "green": "4f6036", "grey_blue": "56687a"}
const EYE_ODDS := [["dark_brown", 0.55], ["brown", 0.80], ["hazel", 0.90], ["green", 0.96], ["grey_blue", 1.0]]

## Named residents. "face" values are authored features; the remaining face
## controls are filled deterministically from the id at a lower strength.
const PEOPLE := {
	# --- village life chapter (economy roster + Decimus) ---
	"aelia": {"kind": "civilian_woman", "role": "Steinmetzin", "look_age": 34, "height": 1.01,
		"face": {"ID_JawWidth": 0.5, "ID_Cheekbones": 0.6, "ID_Brow": 0.2, "ID_NoseBridge": 0.4},
		"build": {"ID_Heavy": 0.15, "ID_Shoulders": 0.6},
		"skin": {"tone": "tan", "sun": 0.75, "flush": 0.2}, "hair": {"style": "bound", "color": "dark_brown"},
		"wear": {"tunic": "natural_grey", "belt": "dark_leather", "IdentityApron": "leather", "IdentityVeil": "oatmeal"},
		"veil_long": 0.0},
	"varro": {"kind": "civilian_man", "role": "Späher und Jäger", "look_age": 31, "height": 1.02,
		"face": {"ID_Cheeks": -0.7, "ID_Cheekbones": 0.7, "ID_NoseBridge": 0.6, "ID_EyeDepth": 0.7, "ID_FaceLength": 0.4},
		"build": {"ID_Heavy": -0.6, "ID_Shoulders": 0.1},
		"skin": {"tone": "tan", "sun": 0.85, "stubble": 0.5}, "hair": {"style": "short", "color": "brown", "keys": {"HAIR_Volume": 0.5}},
		"beard": {"color": "brown", "full": 0.15},
		"wear": {"tunic": "green", "belt": "dark_leather", "IdentityMantle": "walnut", "IdentityPouch": "dark_leather"}},
	"vibius": {"kind": "civilian_man", "role": "Feldarbeiter", "look_age": 27, "height": 0.99,
		"face": {"ID_NoseWidth": 0.6, "ID_Lips": 0.5, "ID_Ears": 0.6, "ID_Chin": -0.4},
		"build": {"ID_Heavy": -0.2, "ID_Shoulders": 0.4},
		"skin": {"tone": "deep", "sun": 0.9, "stubble": 0.35, "flush": 0.2}, "hair": {"style": "short", "color": "black", "keys": {"HAIR_Short": 0.6}},
		"wear": {"tunic": "undyed", "belt": "leather", "IdentityCap": "natural_brown"}, "hem": -0.45},
	"aurelia": {"kind": "civilian_woman", "role": "Heilerin", "look_age": 44, "height": 0.98,
		"face": {"ID_FaceLength": 0.6, "ID_NoseBridge": 0.5, "ID_Cheeks": -0.3, "ID_Lips": -0.2, "ID_EyeDepth": 0.4},
		"build": {"ID_Heavy": -0.2, "ID_Shoulders": -0.3},
		"skin": {"tone": "light", "sun": 0.25, "flush": 0.25}, "hair": {"style": "bound", "color": "brown", "grey": 0.18},
		"wear": {"tunic": "faded_woad", "belt": "dark_leather", "IdentityVeil": "bleached", "IdentityPouch": "leather"},
		"veil_long": 1.0},
	"fabius": {"kind": "civilian_man", "role": "Holzfäller", "look_age": 38, "height": 1.04,
		"face": {"ID_JawWidth": 0.9, "ID_Brow": 0.8, "ID_NoseWidth": 0.5, "ID_Cheeks": 0.4},
		"build": {"ID_Heavy": 0.55, "ID_Shoulders": 1.0},
		"skin": {"tone": "ruddy", "sun": 0.7, "flush": 0.55}, "hair": {"style": "short", "color": "chestnut", "keys": {"HAIR_Volume": 0.8}},
		"beard": {"color": "chestnut", "full": 0.85},
		"wear": {"tunic": "rust", "belt": "dark_leather", "IdentityCap": "dark_brown"}, "hem": -0.25},
	"cassia": {"kind": "civilian_woman", "role": "Händlerin", "look_age": 35, "height": 1.0,
		"face": {"ID_Cheekbones": 0.8, "ID_Lips": 0.6, "ID_NoseLength": -0.3, "ID_Chin": 0.3, "ID_Brow": -0.6},
		"build": {"ID_Heavy": -0.1, "ID_Shoulders": -0.2},
		"skin": {"tone": "olive", "sun": 0.3, "flush": 0.3}, "hair": {"style": "bound", "color": "black"},
		"wear": {"tunic": "madder", "belt": "oxblood", "IdentityMantle": "ochre", "IdentityBrooch": "bronze",
			"IdentityEarrings": "bronze", "IdentityPouch": "oxblood"}},
	"quintus": {"kind": "civilian_man", "role": "Steinbrecher", "look_age": 33, "height": 1.01,
		"face": {"ID_NoseLength": 0.5, "ID_NoseBridge": -0.5, "ID_JawWidth": 0.6, "ID_Lips": -0.4, "ID_Ears": -0.4},
		"build": {"ID_Heavy": 0.3, "ID_Shoulders": 0.8},
		"skin": {"tone": "tan", "sun": 0.85, "stubble": 0.7}, "hair": {"style": "short", "color": "dark_brown", "keys": {"HAIR_Short": 1.0}},
		"wear": {"tunic": "natural_brown", "belt": "leather", "IdentityApron": "dark_leather"}, "hem": -0.35},
	"drusa": {"kind": "civilian_woman", "role": "Zimmerin", "look_age": 30, "height": 1.02,
		"face": {"ID_NoseWidth": 0.4, "ID_Chin": 0.5, "ID_Cheeks": 0.5, "ID_Ears": 0.3},
		"build": {"ID_Heavy": 0.1, "ID_Shoulders": 0.4},
		"skin": {"tone": "light", "sun": 0.55, "flush": 0.45}, "hair": {"style": "bound", "color": "auburn"},
		"wear": {"tunic": "oatmeal", "belt": "leather", "IdentityApron": "leather", "IdentityVeil": "faded_madder"},
		"veil_long": 0.0},
	"julia": {"kind": "civilian_woman", "role": "Mutter des Jungen (Bäuerin)", "eyes": "hazel", "look_age": 36, "height": 0.97,
		"face": {"ID_NoseLength": -0.45, "ID_NoseWidth": -0.35, "ID_NoseBridge": -0.35, "ID_Lips": 0.35, "ID_Cheeks": 0.45, "ID_Brow": -0.85,
			"ID_Chin": -0.6, "ID_JawWidth": -0.75, "ID_Cheekbones": 0.35, "ID_FaceLength": -0.4, "ID_EyeDepth": 0.15},
		"build": {"ID_Heavy": 0.05, "ID_Shoulders": -0.75},
		"face_age": 0.30, "skin": {"tone": "olive", "sun": 0.4, "flush": 0.35, "age": 0.31, "brow": 0.35, "stubble": 0.0},
		"hair": {"style": "bound", "color": "dark_brown", "grey": 0.02, "keys": {"HAIR_Volume": 0.08}},
		"wear": {"tunic": "woad", "belt": "dark_leather", "IdentityEarrings": "bronze"}, "hem": 0.15},
	"silvanus": {"kind": "civilian_man", "role": "Vater des Jungen (Lastenträger)", "look_age": 40, "height": 1.03,
		"face": {"ID_JawWidth": 0.85, "ID_Chin": 0.45, "ID_NoseBridge": 0.65, "ID_NoseLength": 0.35, "ID_Brow": 0.6, "ID_Cheeks": -0.4, "ID_EyeDepth": 0.4, "ID_FaceLength": 0.4},
		"build": {"ID_Heavy": 0.25, "ID_Shoulders": 0.9},
		"face_age": 0.44, "skin": {"tone": "olive", "sun": 0.75, "flush": 0.25, "age": 0.42, "stubble": 0.65},
		"hair": {"style": "short", "color": "dark_brown", "grey": 0.05, "keys": {"HAIR_Short": 0.55, "HAIR_Recede": 0.12}},
		"beard": {"color": "dark_brown", "full": 0.20, "grey": 0.06},
		"wear": {"tunic": "walnut", "belt": "dark_leather"}},
	"valeria": {"kind": "civilian_woman", "role": "Wächterin", "eyes": "grey_blue", "look_age": 29, "height": 1.03,
		"face": {"ID_Brow": 0.3, "ID_Cheekbones": 0.6, "ID_Chin": 0.5, "ID_NoseBridge": 0.3, "ID_Lips": -0.3},
		"build": {"ID_Heavy": -0.3, "ID_Shoulders": 0.5},
		"skin": {"tone": "light", "sun": 0.6, "flush": 0.2}, "hair": {"style": "bound", "color": "light_brown"},
		"wear": {"tunic": "deep_woad", "belt": "dark_leather", "IdentityMantle": "natural_brown", "IdentityBrooch": "iron"}},
	"antonia": {"kind": "civilian_woman", "role": "Töpferin", "look_age": 45, "height": 0.96,
		"face": {"ID_Cheeks": 0.8, "ID_NoseWidth": 0.5, "ID_FaceLength": -0.5, "ID_Lips": 0.3},
		"build": {"ID_Heavy": 0.7, "ID_Shoulders": 0.1},
		"skin": {"tone": "ruddy", "sun": 0.45, "flush": 0.6}, "hair": {"style": "bound", "color": "brown", "grey": 0.25},
		"wear": {"tunic": "faded_madder", "belt": "leather", "IdentityApron": "dark_leather", "IdentityVeil": "undyed"},
		"veil_long": 0.0},
	"sextus": {"kind": "civilian_man", "role": "Dorfschmied, Freund des Vaters", "look_age": 45, "height": 1.02,
		"face": {"ID_NoseBridge": 0.9, "ID_NoseLength": 0.4, "ID_Brow": 0.9, "ID_JawWidth": 0.6, "ID_EyeDepth": 0.6},
		"build": {"ID_Heavy": 0.4, "ID_Shoulders": 1.0},
		"skin": {"tone": "ruddy", "sun": 0.55, "flush": 0.5, "stubble": 0.6}, "hair": {"style": "short", "color": "black", "grey": 0.18, "keys": {"HAIR_Short": 0.7}},
		"beard": {"color": "black", "full": 0.35, "grey": 0.15},
		"wear": {"tunic": "charcoal", "belt": "dark_leather", "IdentityApron": "dark_leather", "IdentityCap": "natural_brown"}, "hem": -0.3},
	"decimus": {"kind": "elder", "role": "Dorfverwalter", "look_age": 62, "height": 1.0,
		"face": {"ID_NoseBridge": 0.6, "ID_NoseLength": 0.5, "ID_FaceLength": 0.6, "ID_Lips": -0.6, "ID_Cheeks": -0.4, "ID_Ears": 0.5},
		"build": {"ID_Heavy": 0.2, "ID_Shoulders": -0.3},
		"skin": {"tone": "light", "sun": 0.3, "stubble": 0.3, "scalp": 0.45}, "hair": {"style": "short", "color": "ash", "grey": 0.85, "keys": {"HAIR_Recede": 0.9, "HAIR_Short": 0.6}},
		"wear": {"tunic": "bleached", "belt": "oxblood", "IdentityMantle": "deep_woad", "IdentityBrooch": "silver"}, "hem": 1.0},
	# --- village population (Layout.RESIDENTS) ---
	"livia": {"kind": "civilian_woman", "role": "Händlerin", "look_age": 41, "height": 0.95,
		"face": {"ID_Cheeks": 0.6, "ID_NoseBridge": 0.6, "ID_NoseLength": 0.3, "ID_JawWidth": 0.3, "ID_Lips": -0.3, "ID_FaceLength": -0.3},
		"build": {"ID_Heavy": 0.6, "ID_Shoulders": 0.0},
		"skin": {"tone": "fair", "sun": 0.3, "flush": 0.55}, "hair": {"style": "bound", "color": "chestnut", "grey": 0.12},
		"wear": {"tunic": "weld", "belt": "leather", "IdentityVeil": "walnut", "IdentityPouch": "leather"},
		"veil_long": 0.8},
	"cassian": {"kind": "civilian_man", "role": "Schreiber", "look_age": 44, "height": 0.99,
		"face": {"ID_FaceLength": 0.9, "ID_Cheeks": -0.8, "ID_JawWidth": -0.8, "ID_NoseLength": 0.2, "ID_Ears": 0.6, "ID_Lips": -0.5},
		"build": {"ID_Heavy": -0.8, "ID_Shoulders": -0.6},
		"skin": {"tone": "fair", "sun": 0.1, "stubble": 0.25, "scalp": 0.25}, "hair": {"style": "short", "color": "light_brown", "grey": 0.3, "keys": {"HAIR_Recede": 0.5}},
		"wear": {"tunic": "bleached", "belt": "dark_leather", "IdentityMantle": "natural_grey", "IdentityBrooch": "bronze"}, "hem": 0.9},
	"aulus": {"kind": "officer", "role": "Veteran", "look_age": 54,
		"skin": {"tone": "tan", "sun": 0.8, "stubble": 0.45, "flush": 0.3}, "hair": {"color": "ash", "grey": 0.7}},
	"titus": {"kind": "civilian_man", "role": "Wagenführer", "look_age": 41, "height": 1.0,
		"face": {"ID_NoseWidth": 0.7, "ID_Cheeks": 0.6, "ID_Brow": 0.4, "ID_Chin": -0.5, "ID_FaceLength": -0.6},
		"build": {"ID_Heavy": 0.8, "ID_Shoulders": 0.3},
		"skin": {"tone": "ruddy", "sun": 0.75, "flush": 0.65}, "hair": {"style": "short", "color": "brown", "grey": 0.15, "keys": {"HAIR_Volume": 0.4}},
		"beard": {"color": "brown", "full": 0.55, "grey": 0.2},
		"wear": {"tunic": "olive", "belt": "dark_leather", "IdentityMantle": "natural_brown", "IdentityCap": "dark_brown"}},
	"flavia": {"kind": "civilian_woman", "role": "Bäckerin", "look_age": 33, "height": 0.97,
		"face": {"ID_Cheeks": 0.7, "ID_NoseLength": -0.5, "ID_Lips": 0.4, "ID_FaceLength": -0.6, "ID_Chin": -0.4},
		"build": {"ID_Heavy": 0.35, "ID_Shoulders": -0.1},
		"skin": {"tone": "fair", "sun": 0.2, "flush": 0.65}, "hair": {"style": "bound", "color": "light_brown"},
		"wear": {"tunic": "undyed", "belt": "leather", "IdentityApron": "leather", "IdentityVeil": "bleached"},
		"veil_long": 0.0},
	"marius": {"kind": "civilian_man", "role": "Zimmermann", "look_age": 25, "height": 1.03,
		"face": {"ID_Chin": 0.6, "ID_Cheekbones": 0.4, "ID_NoseLength": -0.3, "ID_Lips": 0.3, "ID_Ears": -0.3},
		"build": {"ID_Heavy": -0.4, "ID_Shoulders": 0.6},
		"skin": {"tone": "olive", "sun": 0.55, "stubble": 0.45}, "hair": {"style": "short", "color": "chestnut", "keys": {"HAIR_Volume": 0.9, "HAIR_Nape": 0.4}},
		"wear": {"tunic": "oatmeal", "belt": "leather", "IdentityApron": "leather"}, "hem": -0.2},
	"sabina": {"kind": "civilian_woman", "role": "Tuchhändlerin", "eyes": "dark_brown", "look_age": 29, "height": 1.0,
		"face": {"ID_Cheekbones": 0.9, "ID_NoseLength": -0.2, "ID_NoseWidth": -0.5, "ID_Lips": 0.7, "ID_Brow": -0.9, "ID_JawWidth": -0.5},
		"build": {"ID_Heavy": -0.5, "ID_Shoulders": -0.5},
		"skin": {"tone": "fair", "sun": 0.1, "flush": 0.3}, "hair": {"style": "bound", "color": "black"},
		"wear": {"tunic": "deep_woad", "belt": "oxblood", "IdentityMantle": "madder", "IdentityBrooch": "silver", "IdentityEarrings": "silver"}},
	"gaius": {"kind": "civilian_man", "role": "Töpfer", "look_age": 48, "height": 0.98,
		"face": {"ID_NoseLength": 0.7, "ID_NoseWidth": 0.4, "ID_Cheeks": 0.5, "ID_Lips": 0.4, "ID_Chin": -0.3},
		"build": {"ID_Heavy": 0.7, "ID_Shoulders": 0.0},
		"skin": {"tone": "olive", "sun": 0.45, "stubble": 0.5, "scalp": 0.4}, "hair": {"style": "short", "color": "dark_brown", "grey": 0.35, "keys": {"HAIR_Recede": 1.0}},
		"wear": {"tunic": "natural_grey", "belt": "leather", "IdentityApron": "leather"}},
	"nerva": {"kind": "elder", "role": "Schmied", "look_age": 61, "height": 1.01,
		"face": {"ID_NoseBridge": -0.4, "ID_NoseWidth": 0.8, "ID_NoseLength": -0.2, "ID_JawWidth": 0.8, "ID_Brow": 1.0, "ID_Ears": 0.7, "ID_Lips": 0.3},
		"build": {"ID_Heavy": 0.85, "ID_Shoulders": 0.7},
		"skin": {"tone": "ruddy", "sun": 0.6, "flush": 0.7, "scalp": 0.55}, "hair": {"style": "short", "color": "ash", "grey": 0.75, "keys": {"HAIR_Recede": 1.0, "HAIR_Short": 1.0}},
		"beard": {"color": "ash", "full": 1.0, "grey": 0.75},
		"wear": {"tunic": "dark_brown", "belt": "oxblood", "IdentityApron": "oxblood"}},
	"priscilla": {"kind": "civilian_woman", "role": "Heilerin", "look_age": 47, "height": 1.02,
		"face": {"ID_Cheeks": -0.7, "ID_Cheekbones": 0.8, "ID_NoseLength": 0.5, "ID_NoseWidth": -0.4, "ID_Lips": -0.5, "ID_EyeDepth": 0.6, "ID_FaceLength": 0.3},
		"build": {"ID_Heavy": -0.7, "ID_Shoulders": -0.2},
		"skin": {"tone": "fair", "sun": 0.2, "flush": 0.15}, "hair": {"style": "bound", "color": "ash", "grey": 0.45},
		"wear": {"tunic": "green", "belt": "dark_leather", "IdentityMantle": "charcoal", "IdentityBrooch": "bronze", "IdentityPouch": "dark_leather"}},
	"octavia": {"kind": "civilian_woman", "role": "Weinbäuerin", "look_age": 52, "height": 0.96,
		"face": {"ID_Cheeks": 0.5, "ID_JawWidth": 0.6, "ID_NoseWidth": 0.6, "ID_Brow": 0.3, "ID_Lips": -0.2},
		"build": {"ID_Heavy": 0.5, "ID_Shoulders": 0.3},
		"skin": {"tone": "tan", "sun": 0.9, "flush": 0.4}, "hair": {"style": "bound", "color": "dark_brown", "grey": 0.5},
		"wear": {"tunic": "plum", "belt": "dark_leather", "IdentityVeil": "natural_grey", "IdentityApron": "leather"},
		"veil_long": 0.0},
	"publius": {"kind": "civilian_man", "role": "Bote", "look_age": 22, "height": 1.0,
		"face": {"ID_NoseLength": -0.6, "ID_Chin": -0.2, "ID_Cheeks": -0.4, "ID_Ears": 0.8, "ID_Lips": 0.4, "ID_FaceLength": 0.3},
		"build": {"ID_Heavy": -0.9, "ID_Shoulders": -0.4},
		"skin": {"tone": "olive", "sun": 0.6, "stubble": 0.15}, "hair": {"style": "short", "color": "black", "keys": {"HAIR_Volume": 1.0}},
		"wear": {"tunic": "faded_madder", "belt": "leather", "IdentityMantle": "olive", "IdentityPouch": "leather"}, "hem": -0.5},
	"lucius": {"kind": "legionary", "role": "Straßenwache", "look_age": 31,
		"skin": {"tone": "olive", "sun": 0.7, "stubble": 0.6}, "hair": {"color": "black"}},
	"sergius": {"kind": "legionary", "role": "Torwache", "look_age": 37,
		"skin": {"tone": "ruddy", "sun": 0.5, "stubble": 0.3, "flush": 0.5}, "hair": {"color": "auburn", "grey": 0.1}},
	"rufina": {"kind": "civilian_woman", "role": "Korbmacherin", "eyes": "green", "look_age": 43, "height": 0.99,
		"face": {"ID_NoseLength": 0.3, "ID_NoseBridge": -0.4, "ID_Chin": 0.4, "ID_Cheeks": 0.2, "ID_Ears": 0.5},
		"build": {"ID_Heavy": 0.2, "ID_Shoulders": 0.2},
		"skin": {"tone": "fair", "sun": 0.55, "flush": 0.5}, "hair": {"style": "bound", "color": "auburn", "grey": 0.12},
		"wear": {"tunic": "olive", "belt": "leather", "IdentityVeil": "faded_woad", "IdentityPouch": "leather"},
		"veil_long": 0.0},
	"marcellus": {"kind": "civilian_man", "role": "Lagerarbeiter", "look_age": 24, "height": 1.05,
		"face": {"ID_JawWidth": 0.4, "ID_Brow": 0.6, "ID_Cheeks": 0.3, "ID_NoseLength": -0.4, "ID_Lips": 0.6},
		"build": {"ID_Heavy": 0.2, "ID_Shoulders": 0.9},
		"skin": {"tone": "deep", "sun": 0.6, "stubble": 0.55}, "hair": {"style": "short", "color": "black", "keys": {"HAIR_Short": 1.0}},
		"wear": {"tunic": "natural_brown", "belt": "leather", "IdentityCap": "undyed"}, "hem": -0.4},
	"tullia": {"kind": "civilian_woman", "role": "Weberin", "look_age": 34, "height": 0.98,
		"face": {"ID_NoseBridge": 0.4, "ID_NoseWidth": -0.3, "ID_FaceLength": 0.5, "ID_Lips": 0.3, "ID_EyeDepth": 0.4, "ID_Brow": -0.5},
		"build": {"ID_Heavy": -0.3, "ID_Shoulders": -0.3},
		"skin": {"tone": "light", "sun": 0.2, "flush": 0.3}, "hair": {"style": "bound", "color": "brown"},
		"wear": {"tunic": "green", "belt": "oxblood", "IdentityMantle": "weld", "IdentityEarrings": "copper"}},
	"domitius": {"kind": "civilian_man", "role": "Feldarbeiter", "eyes": "grey_blue", "look_age": 26, "height": 0.97,
		"face": {"ID_Cheeks": 0.6, "ID_FaceLength": -0.5, "ID_NoseWidth": 0.3, "ID_Chin": 0.3, "ID_Ears": -0.5},
		"build": {"ID_Heavy": 0.1, "ID_Shoulders": 0.5},
		"skin": {"tone": "tan", "sun": 0.95, "flush": 0.35}, "hair": {"style": "short", "color": "dark_blond", "keys": {"HAIR_Volume": 0.7, "HAIR_Nape": 0.7}},
		"beard": {"color": "dark_blond", "full": 0.3},
		"wear": {"tunic": "oatmeal", "belt": "dark_leather"}, "hem": -0.5},
	"bassa": {"kind": "civilian_woman", "role": "Brotverkäuferin", "look_age": 42, "height": 0.96,
		"face": {"ID_Cheeks": 0.9, "ID_JawWidth": 0.4, "ID_Chin": -0.5, "ID_NoseLength": -0.2, "ID_Lips": 0.5},
		"build": {"ID_Heavy": 0.9, "ID_Shoulders": 0.2},
		"skin": {"tone": "olive", "sun": 0.35, "flush": 0.55}, "hair": {"style": "bound", "color": "black", "grey": 0.2},
		"wear": {"tunic": "ochre", "belt": "leather", "IdentityApron": "leather", "IdentityVeil": "undyed"},
		"veil_long": 0.0},
	"felix": {"kind": "civilian_man", "role": "Fassbinder", "look_age": 35, "height": 1.0,
		"face": {"ID_NoseBridge": 0.5, "ID_JawWidth": 0.3, "ID_Cheekbones": 0.6, "ID_Lips": 0.4, "ID_Brow": 0.3},
		"build": {"ID_Heavy": 0.3, "ID_Shoulders": 0.7},
		"skin": {"tone": "olive", "sun": 0.6, "flush": 0.3}, "hair": {"style": "short", "color": "dark_brown", "keys": {"HAIR_Volume": 0.3}},
		"beard": {"color": "dark_brown", "full": 0.6},
		"wear": {"tunic": "madder_brown", "belt": "dark_leather", "IdentityApron": "leather"}},
	"gaia": {"kind": "civilian_woman", "role": "Köchin", "look_age": 47, "height": 0.95,
		"face": {"ID_Cheeks": 1.0, "ID_NoseWidth": 0.7, "ID_FaceLength": -0.8, "ID_Chin": -0.6, "ID_Lips": 0.4},
		"build": {"ID_Heavy": 1.0, "ID_Shoulders": 0.4},
		"skin": {"tone": "ruddy", "sun": 0.3, "flush": 0.85}, "hair": {"style": "bound", "color": "brown", "grey": 0.3},
		"wear": {"tunic": "rust", "belt": "dark_leather", "IdentityApron": "dark_leather", "IdentityVeil": "oatmeal"},
		"veil_long": 0.0},
	"hilarus": {"kind": "civilian_man", "role": "Müller", "look_age": 39, "height": 1.01,
		"face": {"ID_Cheeks": 0.8, "ID_Chin": -0.6, "ID_NoseLength": -0.4, "ID_NoseWidth": 0.6, "ID_Brow": -0.4},
		"build": {"ID_Heavy": 0.9, "ID_Shoulders": 0.5},
		"skin": {"tone": "fair", "sun": 0.25, "flush": 0.75, "stubble": 0.4}, "hair": {"style": "short", "color": "light_brown", "keys": {"HAIR_Short": 0.8}},
		"wear": {"tunic": "bleached", "belt": "leather", "IdentityApron": "leather", "IdentityCap": "undyed"}},
	"irena": {"kind": "civilian_woman", "role": "Färberin", "look_age": 28, "height": 0.99,
		"face": {"ID_NoseLength": -0.3, "ID_Cheekbones": 0.5, "ID_Chin": 0.4, "ID_Lips": 0.5, "ID_Ears": -0.3, "ID_JawWidth": -0.6},
		"build": {"ID_Heavy": -0.4, "ID_Shoulders": 0.0},
		"skin": {"tone": "olive", "sun": 0.45, "flush": 0.3}, "hair": {"style": "bound", "color": "dark_brown"},
		"wear": {"tunic": "plum", "belt": "leather", "IdentityApron": "dark_leather", "IdentityEarrings": "copper"}},
	"leontius": {"kind": "elder", "role": "Hirte", "look_age": 57, "height": 0.99,
		"face": {"ID_Cheeks": -0.8, "ID_Cheekbones": 0.9, "ID_NoseLength": 0.6, "ID_EyeDepth": 0.9, "ID_FaceLength": 0.4},
		"build": {"ID_Heavy": -0.6, "ID_Shoulders": -0.2},
		"skin": {"tone": "deep", "sun": 1.0, "flush": 0.3}, "hair": {"style": "short", "color": "ash", "grey": 0.6, "keys": {"HAIR_Volume": 1.0, "HAIR_Nape": 1.0}},
		"beard": {"color": "ash", "full": 0.9, "grey": 0.6},
		"wear": {"tunic": "natural_brown", "belt": "dark_leather", "IdentityMantle": "natural_grey", "IdentityCap": "natural_brown", "IdentityPouch": "dark_leather"}},
	"mina": {"kind": "civilian_woman", "role": "Spinnerin", "eyes": "hazel", "look_age": 23, "height": 0.97,
		"face": {"ID_NoseLength": -0.6, "ID_Lips": 0.4, "ID_Cheeks": 0.3, "ID_Chin": -0.3, "ID_Brow": -0.7, "ID_FaceLength": -0.3},
		"build": {"ID_Heavy": -0.6, "ID_Shoulders": -0.6},
		"skin": {"tone": "fair", "sun": 0.2, "flush": 0.45}, "hair": {"style": "bound", "color": "dark_blond"},
		"wear": {"tunic": "undyed", "belt": "leather", "IdentityMantle": "faded_woad"}},
	"naso": {"kind": "civilian_man", "role": "Ölhändler", "look_age": 51, "height": 0.98,
		"face": {"ID_NoseLength": 1.0, "ID_NoseBridge": 1.0, "ID_NoseWidth": 0.6, "ID_Cheeks": 0.4, "ID_Chin": -0.4, "ID_Ears": 0.4},
		"build": {"ID_Heavy": 0.8, "ID_Shoulders": -0.2},
		"skin": {"tone": "olive", "sun": 0.4, "stubble": 0.35, "scalp": 0.5}, "hair": {"style": "short", "color": "dark_brown", "grey": 0.4, "keys": {"HAIR_Recede": 1.0, "HAIR_Short": 0.5}},
		"wear": {"tunic": "ochre", "belt": "oxblood", "IdentityMantle": "madder_brown", "IdentityBrooch": "bronze", "IdentityPouch": "oxblood"}},
}
## Imported Meshy units keep their own authored look (not handled here).
const EXTERNAL := {"severus": "unit_roman_signifer (Meshy derivative)"}


static func has_person(id: String) -> bool:
	return PEOPLE.has(id)


static func _rng(seed_text: String) -> RandomNumberGenerator:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash("imperathen-resident:" + seed_text)
	return rng


static func _colour(value: String, table: Dictionary) -> Color:
	return Color(str(table.get(value, value)))


## Complete, deterministic look for a named resident or a generic villager.
## Returns {} for routes this identity layer does not own.
static func look(resident_id: String, appearance: String, variation: int, years: int) -> Dictionary:
	if PEOPLE.has(resident_id):
		return _named(resident_id)
	if appearance in KINDS or appearance in ["legionary", "officer", "spearman", "archer"]:
		return _generic(appearance, variation, years)
	return {}


static func _face(seed_text: String, authored: Dictionary, fill: float) -> Dictionary:
	var rng := _rng(seed_text)
	var face := {}
	for key: String in FACE_KEYS:
		face[key] = clampf(float(authored.get(key, rng.randf_range(-1.0, 1.0) * fill)), -1.0, 1.0)
	return face


static func _finish(id: String, kind: String, entry: Dictionary) -> Dictionary:
	var years := int(entry.get("look_age", 35))
	var age_weight := clampf((float(years) - 28.0) / 34.0, 0.0, 1.0)
	var result := {"id": id, "kind": kind, "role": str(entry.get("role", "")), "look_age": years,
		"height": float(entry.get("height", 1.0)), "face": _face(id, entry.get("face", {}), 0.35)}
	result.face["ID_Age"] = clampf(float(entry.get("face_age", age_weight)), 0.0, 1.0)
	var build: Dictionary = entry.get("build", {})
	result["build"] = {"ID_Heavy": float(build.get("ID_Heavy", 0.0)), "ID_Shoulders": float(build.get("ID_Shoulders", 0.0))}
	var skin: Dictionary = entry.get("skin", {})
	var hair: Dictionary = entry.get("hair", {})
	var beard: Dictionary = entry.get("beard", {})
	var hair_colour := _colour(str(hair.get("color", "dark_brown")), HAIR)
	result["skin"] = {"tone": TONES.get(str(skin.get("tone", "light")), Color.WHITE), "sun": float(skin.get("sun", 0.4)),
		"flush": float(skin.get("flush", 0.3)), "age": clampf(float(skin.get("age", age_weight)), 0.0, 1.0), "stubble": float(skin.get("stubble", 0.0)),
		"scalp": float(skin.get("scalp", 0.0)), "brow": float(skin.get("brow", 0.55 if kind != "civilian_woman" else 0.4)),
		"brow_color": hair_colour.darkened(0.25), "stubble_color": hair_colour.darkened(0.35)}
	if not beard.is_empty():
		result.skin.stubble = maxf(float(result.skin.stubble), 0.55)
	var eye_name := str(entry.get("eyes", ""))
	if eye_name.is_empty():
		var roll := _rng(id + "/eyes").randf()
		for pair: Array in EYE_ODDS:
			if roll <= float(pair[1]):
				eye_name = str(pair[0])
				break
	result["eyes"] = _colour(eye_name, EYES)
	result["hair"] = {"style": str(hair.get("style", "short")), "color": hair_colour, "grey": float(hair.get("grey", 0.0)),
		"keys": hair.get("keys", {})}
	result["beard"] = {} if beard.is_empty() else {"color": _colour(str(beard.get("color", "dark_brown")), HAIR),
		"full": float(beard.get("full", 0.3)), "grey": float(beard.get("grey", float(result.hair.grey)))}
	var wear: Dictionary = entry.get("wear", {})
	var pieces := {}
	for key: String in wear:
		if key.begins_with("Identity"):
			pieces[key] = _colour(str(wear[key]), DYES)
	result["wear"] = {"tunic": _colour(str(wear.get("tunic", "undyed")), DYES), "belt": _colour(str(wear.get("belt", "leather")), DYES),
		"pieces": pieces, "hem": float(entry.get("hem", 0.0)), "veil_long": float(entry.get("veil_long", 0.0))}
	return result


static func _named(id: String) -> Dictionary:
	var entry: Dictionary = PEOPLE[id]
	var result := _finish(id, str(entry.kind), entry)
	if str(entry.kind) in ["legionary", "officer", "spearman", "archer"]:
		# Kit, tunic and helmet stay with the soldier model; skin and hair are personal.
		result["soldier"] = true
	return result


## Generic villagers: a stable, varied identity from (appearance, variation).
## Fill strength is higher than for named people, so 18 variants never repeat.
## City residents use their full persistent population key, not 18 recycled
## faces. Their profession/wealth alters clothing only, never saved economics.
static func city_look(uid: String, appearance: String, variation: int, years: int, job: String, wealth: int) -> Dictionary:
	if years < 18 or appearance not in KINDS:
		return {}
	var result := _generic(appearance,variation,years,"city:"+uid)
	var rng := _rng("city:"+uid+"/clothing")
	var palette := ["undyed","oatmeal","natural_grey","natural_brown","walnut"]
	if job in ["vendor","craft"]:
		palette = ["ochre","olive","faded_woad","faded_madder","natural_brown"]
	elif wealth >= 2:
		palette = ["woad","green","madder_brown","walnut","ochre"]
	elif job == "guard":
		palette = ["natural_grey","walnut","madder_brown"]
	result.wear.tunic = _colour(str(palette[rng.randi_range(0,palette.size()-1)]),DYES)
	result.role = job
	result["city"] = true
	result.height = rng.randf_range(0.95,1.05)
	if appearance == "civilian_woman" and years >= 55:
		result.hair.grey = clampf((float(years)-45.0)/43.0,0.08,0.7)
	return result


static func _generic(appearance: String, variation: int, years: int, stable_key: String = "") -> Dictionary:
	var key := stable_key if not stable_key.is_empty() else "%s/%d" % [appearance, posmod(variation, 18)]
	var rng := _rng(key)
	var woman := appearance == "civilian_woman"
	var elder := appearance == "elder"
	var tones := ["fair", "light", "olive", "tan", "deep", "ruddy"]
	var hair_names := ["black", "dark_brown", "brown", "chestnut", "auburn", "light_brown"]
	var tunics := ["undyed", "oatmeal", "natural_grey", "natural_brown", "walnut", "faded_madder", "ochre", "faded_woad", "olive", "rust", "green", "madder_brown"]
	var v := posmod(variation, 18)
	var entry := {"role": "Dorfbewohner", "look_age": clampi(years, 18, 80) if years > 0 else (64 if elder else 34),
		"height": [0.97, 1.03, 1.0, 0.95, 1.04, 0.99][v % 6],
		"face": {}, "build": {"ID_Heavy": rng.randf_range(-0.7, 0.8), "ID_Shoulders": rng.randf_range(-0.5, 0.8)},
		"skin": {"tone": tones[(v + rng.randi_range(0, 5)) % tones.size()], "sun": rng.randf_range(0.2, 0.9), "flush": rng.randf_range(0.1, 0.6),
			"stubble": 0.0 if woman else rng.randf_range(0.15, 0.7)},
		"hair": {"style": "bound" if woman else "short", "color": "ash" if elder else hair_names[(v * 7 + rng.randi_range(0, 2)) % hair_names.size()],
			"grey": rng.randf_range(0.5, 0.85) if elder else rng.randf_range(0.0, 0.15), "keys": {}},
		"wear": {"tunic": tunics[(v * 5) % tunics.size()], "belt": "leather" if v % 2 == 0 else "dark_leather"}}
	var keys: Dictionary = entry.hair.keys
	if not woman:
		if rng.randf() < (0.8 if elder else 0.3):
			keys["HAIR_Recede"] = rng.randf_range(0.4, 1.0)
			entry.skin["scalp"] = 0.4
		if rng.randf() < 0.4:
			keys["HAIR_Volume"] = rng.randf_range(0.3, 1.0)
		if rng.randf() < 0.35:
			keys["HAIR_Short"] = rng.randf_range(0.4, 1.0)
		if rng.randf() < (0.7 if elder else 0.35):
			entry["beard"] = {"color": entry.hair.color, "full": rng.randf_range(0.1, 0.9), "grey": entry.hair.grey}
	var wear: Dictionary = entry.wear
	var piece_roll := rng.randf()
	if woman:
		if v % 3 == 0:
			wear["IdentityVeil"] = tunics[(v * 3 + 2) % tunics.size()]
			entry["veil_long"] = 1.0 if v % 2 == 0 else 0.0
		if v % 4 == 1:
			wear["IdentityMantle"] = tunics[(v + 4) % tunics.size()]
		if v % 5 == 2:
			wear["IdentityEarrings"] = "bronze"
	else:
		if piece_roll < 0.25:
			wear["IdentityApron"] = "leather"
		elif piece_roll < 0.45:
			wear["IdentityMantle"] = tunics[(v + 3) % tunics.size()]
		if v % 4 == 3:
			wear["IdentityCap"] = "natural_brown"
		entry["hem"] = rng.randf_range(-0.4, 0.3) if not elder else rng.randf_range(0.2, 0.9)
	if appearance in ["legionary", "officer", "spearman", "archer"]:
		entry.erase("face")
		entry.erase("build")
		entry.erase("beard")
		entry.wear = {}
		entry.hair.erase("style")
		var soldier := _finish(key, appearance, entry)
		soldier["soldier"] = true
		return soldier
	var result := _finish(key, appearance, entry)
	# Generic faces use the full random range: they have no authored features.
	result.face = _face(key, {}, 0.85)
	result.face["ID_Age"] = clampf((float(result.look_age) - 28.0) / 34.0, 0.0, 1.0)
	result["generic"] = true
	return result


## Stable signatures for the uniqueness test and review reports.
static func face_vector(item: Dictionary) -> PackedFloat32Array:
	var values := PackedFloat32Array()
	for key: String in FACE_KEYS:
		values.append(float(item.get("face", {}).get(key, 0.0)))
	values.append(float(item.get("face", {}).get("ID_Age", 0.0)))
	for key: String in ["ID_Heavy", "ID_Shoulders"]:
		values.append(float(item.get("build", {}).get(key, 0.0)))
	var tone: Color = item.get("skin", {}).get("tone", Color.WHITE)
	values.append_array([tone.r * 2.0, tone.g * 2.0, tone.b * 2.0])
	var hair: Color = item.get("hair", {}).get("color", Color.BLACK)
	values.append_array([hair.r * 3.0, hair.g * 3.0, hair.b * 3.0, float(item.get("hair", {}).get("grey", 0.0))])
	return values


static func outfit_signature(item: Dictionary) -> String:
	var wear: Dictionary = item.get("wear", {})
	var parts: Array[String] = [str(item.get("kind", "")), (wear.get("tunic", Color.WHITE) as Color).to_html(false)]
	var pieces: Dictionary = wear.get("pieces", {})
	var names: Array = pieces.keys()
	names.sort()
	for name: String in names:
		parts.append("%s=%s" % [name, (pieces[name] as Color).to_html(false)])
	parts.append("hair=" + str(item.get("hair", {}).get("style", "")))
	parts.append("beard=" + ("yes" if not item.get("beard", {}).is_empty() else "no"))
	return "|".join(parts)
