extends SceneTree
const Entry = preload("res://main.tscn")
const Observer = preload("res://scripts/ui/android_village_diagnostics.gd")
var game
func _initialize() -> void:
    run.call_deferred()
func frames(count: int) -> void:
    for frame in count:
        await physics_frame
        game._physics_process(1.0/60.0)
        game.world._physics_process(1.0/60.0)
        game._process(1.0/60.0)
func run() -> void:
    root.content_scale_size = Vector2i.ZERO
    root.size = Vector2i(1280,720)
    game = Entry.instantiate()
    root.add_child(game)
    await process_frame
    game.set_process(false)
    game.set_physics_process(false)
    game.world.set_physics_process(false)
    game.ui._touch_enabled = true
    game.ui._finish_intro()
    game.ui.action_requested.emit("new_game",{})
    game._opening_skip()
    game._opening_next()
    game._opening_skip()
    game._opening_next()
    await frames(90)
    var observer = Observer.new()
    observer.session = game
    root.add_child(observer)
    observer.set_process(false)
    var data_before := var_to_bytes(game.model.data)
    var fresh: Dictionary = observer.snapshot()
    var readonly_fresh := var_to_bytes(game.model.data) == data_before
    game._pause()
    var result: Dictionary = game._save(false)
    if not result.ok:
        printerr(result)
        quit(1)
        return
    data_before = var_to_bytes(game.model.data)
    var file_before := FileAccess.get_sha256(game.SAVE_PATH)
    var before: Dictionary = observer.snapshot()
    var readonly_saved := var_to_bytes(game.model.data) == data_before and FileAccess.get_sha256(game.SAVE_PATH) == file_before
    game._show_menu()
    game._continue_game()
    await frames(90)
    data_before = var_to_bytes(game.model.data)
    var after: Dictionary = observer.snapshot()
    var readonly_restored := var_to_bytes(game.model.data) == data_before and FileAccess.get_sha256(game.SAVE_PATH) == file_before
    var output := {"engine":Engine.get_version_info().string, "actual_android_process_restart":false, "new_childhood_start":fresh, "saved":before, "reloaded":after, "observer_preserves_model_and_save":readonly_fresh and readonly_saved and readonly_restored,
        "maximum_transport_chunks":maxi(ceili(float(Marshalls.utf8_to_base64(JSON.stringify(before)).length())/512.0),ceili(float(Marshalls.utf8_to_base64(JSON.stringify(after)).length())/512.0))}
    var file := FileAccess.open(OS.get_environment("IMPERATHEN_OBSERVER_REPORT"),FileAccess.WRITE)
    file.store_string(JSON.stringify(output,"  ")+"\n")
    file.close()
    print("OBSERVER_PROBE_PASS read_only=", output.observer_preserves_model_and_save, " observed=",fresh.behavior_runtime.observed_count," chunks=",output.maximum_transport_chunks)
    game.queue_free()
    observer.queue_free()
    await process_frame
    quit(0 if output.observer_preserves_model_and_save else 1)
