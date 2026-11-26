extends RefCounted
## Original line glyphs for the Roman HUD (own SVG drawing on a 24-unit grid).
## They are rasterised on demand at the exact pixel size of the control, so
## they stay sharp from the 1280 x 720 desktop to the dense Fold7 displays.

const PATHS := {
	# Actions
	"interact": '<path d="M7 13V9.2a1.5 1.5 0 0 1 3 0V6a1.5 1.5 0 0 1 3 0v5-3.5a1.5 1.5 0 0 1 3 0V11-1.6a1.5 1.5 0 0 1 3 0V15c0 4.2-2.6 6.5-6 6.5h-1.6c-2.4 0-3.9-1.4-5.3-3.8L4.8 15c-.7-1.3.6-2.5 1.7-1.6L8 14.6"/>',
	"talk": '<path d="M4 5.5h16v10H11l-4.5 3.8V15.5H4Z"/><path d="M8 9.5h8M8 12.3h5"/>',
	"attack": '<path d="M7.5 12.5V9.4a1.6 1.6 0 0 1 3.2 0v1.2-2a1.6 1.6 0 0 1 3.2 0v2-1.3a1.6 1.6 0 0 1 3.2 0V14c0 3.6-2.3 5.8-5.6 5.8h-.9c-2.7 0-4.4-1.8-5-4.4l-.6-2.4c-.3-1.2 1.2-1.8 2-.9Z"/><path d="M3 6.5 5.4 8M5.5 3.5 6.6 6M9.5 2.8V5.6"/>',
	"gladius": '<path d="M12 2.5 14 6v9.5h-4V6Z"/><path d="M7.5 15.5h9M12 15.5v4"/><circle cx="12" cy="20.6" r="1.3"/>',
	"guard": '<path d="M12 3 19 6v5.5c0 4.6-3 7.8-7 9.5-4-1.7-7-4.9-7-9.5V6Z"/><path d="M12 7.5v9.5M8.2 11.5h7.6"/>',
	"dodge": '<path d="M5 17c0-6.5 4.4-11 11.5-11"/><path d="m13.5 3 3.4 3-3.2 3.4"/><path d="M8 20.5h9"/>',
	"techniques": '<path d="M5 5.5h14v14H5Z"/><path d="M8.5 9.5h7M8.5 12.5h7M8.5 15.5h4.5"/><path d="M5 5.5 3.5 4M19 5.5 20.5 4"/>',
	"pace": '<circle cx="12.5" cy="4.2" r="1.8"/><path d="m10 21 2-6.5-2.6-2.5.9-4.4 2.6 1.4 2.9 3.2"/><path d="m12.3 14.6 2.7 2.4.6 3.9M10.3 7.8 7 10.6"/>',
	"run": '<circle cx="14.5" cy="4" r="1.8"/><path d="m6 20.5 3.6-3.4 1.7-4.3-2.4-2.6 4.4-2.2 2.6 3.4 3.6.6"/><path d="m11.3 12.8 4.4 2.5-.8 5.2M8.9 10.5 5.3 9.6M2.5 6.5h4M3.5 14h3"/>',
	# Navigation and menu
	"chronicle": '<path d="M6.5 4.5h10.5a2 2 0 0 1 2 2V19h-11a2 2 0 0 1-2-2V4.5Z"/><path d="M4.5 6.5a2 2 0 0 1 2-2M6.5 19.2a2 2 0 0 1-2-2V6.5"/><path d="M9.5 9h6.5M9.5 12h6.5M9.5 15h4"/>',
	"pause": '<circle cx="12" cy="12" r="8.5"/><path d="M10 8.3v7.4M14 8.3v7.4"/>',
	"save": '<path d="M12 3.5v10M8 10l4 4 4-4"/><path d="M4.5 15.5v3.5h15v-3.5"/>',
	"person": '<circle cx="12" cy="7.5" r="3.6"/><path d="M4.8 20.5c.7-4.2 3.6-6.6 7.2-6.6s6.5 2.4 7.2 6.6"/>',
	"city": '<path d="M3.5 20.5h17M5 18v-7.5M9 18v-7.5M15 18v-7.5M19 18v-7.5M4 10.5h16L12 4Z"/><path d="M3.5 18h17"/>',
	"map": '<path d="m3.5 6 5.5-2.2 6 2.2 5.5-2.2V18l-5.5 2.2-6-2.2-5.5 2.2Z"/><path d="M9 3.8V18M15 6v14.2"/>',
	"village": '<path d="M3.5 20.5h17"/><path d="M5 20.5V11L10 7l5 4v9.5"/><path d="M13 9.5 16.5 6.8 20 9.6v10.9"/><path d="M8.5 20.5v-4.2h3v4.2"/>',
	"projects": '<path d="M4 7.5h16M4 12h16M4 16.5h10"/><circle cx="18.2" cy="16.5" r="1.6"/>',
	"globe": '<circle cx="12" cy="12" r="8.5"/><path d="M3.5 12h17M12 3.5c-3 3-3 14 0 17M12 3.5c3 3 3 14 0 17"/>',
	"close": '<path d="M6.5 6.5 17.5 17.5M17.5 6.5 6.5 17.5"/>',
	"lock": '<path d="M7 11h10v8.5H7Z"/><path d="M9 11V8.4a3 3 0 0 1 6 0V11"/>',
	"back": '<path d="M10 6 4 12l6 6"/><path d="M4.5 12h15"/>',
	# Resources and vitals
	"wood": '<path d="M4 15.5 16.5 7l3.3 4.8L7.3 20.3Z"/><ellipse cx="18.2" cy="9.4" rx="1.7" ry="2.9" transform="rotate(-34 18.2 9.4)"/><path d="M3 9.5 9.5 5"/>',
	"grain": '<path d="M12 21V8"/><path d="M12 8c-2.8-.4-3.8-2.6-3.8-4.6 2.6.3 3.8 2.3 3.8 4.6ZM12 8c2.8-.4 3.8-2.6 3.8-4.6-2.6.3-3.8 2.3-3.8 4.6Z"/><path d="M12 13c-2.8-.4-3.8-2.6-3.8-4.6 2.6.3 3.8 2.3 3.8 4.6ZM12 13c2.8-.4 3.8-2.6 3.8-4.6-2.6.3-3.8 2.3-3.8 4.6Z"/><path d="M12 18c-2.8-.4-3.8-2.6-3.8-4.6 2.6.3 3.8 2.3 3.8 4.6ZM12 18c2.8-.4 3.8-2.6 3.8-4.6-2.6.3-3.8 2.3-3.8 4.6Z"/>',
	"coin": '<circle cx="12" cy="12" r="8"/><circle cx="12" cy="12" r="5.4"/><path d="M10.4 9.6h3.2M12 9.6v4.8M10.4 14.4h3.2"/>',
	"vitality": '<path d="M12 20s-7-4.4-7-10a4 4 0 0 1 7-2.6A4 4 0 0 1 19 10c0 5.6-7 10-7 10Z"/>',
	"stamina": '<path d="M4 9.5h10.5a2.5 2.5 0 1 0-2.5-2.5M4 14.5h14a2.5 2.5 0 1 1-2.5 2.5M4 12h8"/>',
	"laurel": '<path d="M12 20.5c-4.8-1.3-7.5-5.5-7.5-11M12 20.5c4.8-1.3 7.5-5.5 7.5-11"/><path d="M5.4 13.5c1.6-.1 2.6.8 3 2.1M4.6 9.8c1.5.3 2.3 1.3 2.4 2.6M18.6 13.5c-1.6-.1-2.6.8-3 2.1M19.4 9.8c-1.5.3-2.3 1.3-2.4 2.6"/>',
	"family": '<circle cx="8" cy="7.5" r="2.6"/><circle cx="16" cy="7.5" r="2.6"/><circle cx="12" cy="13" r="2"/><path d="M3.5 19c.5-3.4 2.3-5.2 4.5-5.2 1.1 0 2 .3 2.7 1M20.5 19c-.5-3.4-2.3-5.2-4.5-5.2-1.1 0-2 .3-2.7 1M9 20.5c.4-2 1.5-3.2 3-3.2s2.6 1.2 3 3.2"/>',
	"ability": '<path d="M12 3.5 14.4 9l5.9.5-4.5 3.9 1.4 5.8L12 16.1l-5.2 3.1 1.4-5.8-4.5-3.9 5.9-.5Z"/>',
	"pouch": '<path d="M8.5 7.5h7l2.5 4.5c1.7 3.3.2 8.5-6 8.5s-7.7-5.2-6-8.5Z"/><path d="M8.5 7.5 7 4.5h10l-1.5 3M10 7.5c.7 1.2 3.3 1.2 4 0"/>',
	# Items
	"cup": '<path d="M6.5 6.5h11l-1.4 11a2.2 2.2 0 0 1-2.2 2h-3.8a2.2 2.2 0 0 1-2.2-2Z"/><path d="M6.8 9h10.4"/>',
	"jug": '<path d="M9 4h6M9.5 4v3L7 10.5c-1.6 2.4-1.2 6.6.7 8.5h8.6c1.9-1.9 2.3-6.1.7-8.5L14.5 7V4"/><path d="M17 10.5c2.4 0 3 3.4.4 4.6"/>',
	"food": '<path d="M3.5 12h17a8.5 8.5 0 0 1-17 0Z"/><path d="M9 9.5c.8-1.6 2.3-2.5 3-4.5M13.5 9.5c.6-1.2 1.6-1.8 2-3.2"/>',
	"lamp": '<path d="M4 15c0-2.5 3.6-4 8-4s8 1.5 8 4-3.6 3-8 3-8-.5-8-3Z"/><path d="M18.5 13.5 21 12M12 11c0-2 1.2-3.2 1.2-4.8S12 4 12 4"/>',
	"garment": '<path d="M8.5 4 4 7.5l2.2 3.4 2.3-1.3V20h7V9.6l2.3 1.3L20 7.5 15.5 4c-.6 1.4-1.8 2.2-3.5 2.2S9.1 5.4 8.5 4Z"/>',
	"belt": '<path d="M3.5 10h17v4h-17Z"/><path d="M10 9h4.4v6H10Z"/><circle cx="12.2" cy="12" r="0.8"/>',
	"brooch": '<circle cx="9" cy="12" r="4.5"/><path d="M13.5 12h7M18.5 10l2 2-2 2"/><circle cx="9" cy="12" r="1.6"/>',
	"shield": '<path d="M7 3.5h10l1.5 2v13l-1.5 2H7l-1.5-2v-13Z"/><circle cx="12" cy="12" r="2.4"/><path d="M12 5v4.6M12 14.4V19"/>',
	"helmet": '<path d="M5 15.5c0-5.4 3.1-9.5 7-9.5s7 4.1 7 9.5"/><path d="M4 15.5h16M8.5 15.5v4M15.5 15.5v4M12 6V3.5"/>',
	"item": '<path d="M5 8.5 12 4.5l7 4v8l-7 4-7-4Z"/><path d="m5 8.5 7 4 7-4M12 12.5v8"/>',
}

static var _cache: Dictionary = {}


## A white-on-transparent texture; tint it with modulate or draw colour.
static func texture(kind: String, pixels: int, stroke := 1.6) -> Texture2D:
	var size := clampi(pixels, 8, 512)
	var key := "%s:%d:%.2f" % [kind, size, stroke]
	if _cache.has(key):
		return _cache[key]
	var path: String = PATHS.get(kind, PATHS.item)
	var svg := '<svg xmlns="http://www.w3.org/2000/svg" width="24" height="24" viewBox="0 0 24 24"><g fill="none" stroke="#ffffff" stroke-width="%.2f" stroke-linecap="round" stroke-linejoin="round">%s</g></svg>' % [stroke, path]
	var image := Image.new()
	if image.load_svg_from_string(svg, float(size) / 24.0) != OK:
		return null
	var result := ImageTexture.create_from_image(image)
	_cache[key] = result
	return result


## Icon kind for a city-trade item id, a carried thing or an equipment slot.
static func item_kind(id: String, name := "") -> String:
	var text := (id + " " + name).to_lower()
	for pair: Array in [["gladius", "gladius"], ["scutum", "shield"], ["schild", "shield"], ["helm", "helmet"],
			["tunic", "garment"], ["tunika", "garment"], ["cloak", "garment"], ["mantel", "garment"], ["belt", "belt"], ["gürtel", "belt"],
			["brooch", "brooch"], ["fibel", "brooch"], ["lamp", "lamp"], ["lampe", "lamp"], ["cup", "cup"], ["becher", "cup"],
			["krug", "jug"], ["water", "jug"], ["wasser", "jug"], ["bread", "food"], ["brot", "food"], ["olive", "food"], ["cheese", "food"],
			["käse", "food"], ["fig", "food"], ["feige", "food"], ["stew", "food"], ["eintopf", "food"]]:
		if text.contains(pair[0]):
			return pair[1]
	return "item"
