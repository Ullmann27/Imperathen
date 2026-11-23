extends RefCounted
## Retain the earlier village campaign as a real saved-game compatibility case.
## Fresh lives use the separately tested authored childhood entry point.

static func load_into(game: Node) -> bool:
	game._show_menu()
	game.model.new_game("italia", true)
	var saved: Dictionary = game.model.save_game(game.SAVE_PATH)
	if not saved.get("ok", false):
		return false
	game._continue_game()
	return game.screen == "playing" and not game.model.get_childhood_view().get("enabled", true)
