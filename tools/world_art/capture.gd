extends SceneTree

const Preview = preload("res://scripts/world_expansion/preview.gd")
var workshop: Node3D
var output_path := ""
var frames: Array[Dictionary] = []

func _initialize() -> void:
    call_deferred("_run")

func _run() -> void:
    if DisplayServer.get_name() == "headless":
        push_error("Graphical evidence requires an actual renderer.")
        quit(2)
        return
    var args := OS.get_cmdline_user_args()
    if args.is_empty():
        push_error("Capture destination missing")
        quit(2)
        return
    output_path = args[0]
    root.size = Vector2i(1280, 720)
    workshop = Preview.new()
    root.add_child(workshop)
    await process_frame
    if not _require(workshop.load_error.is_empty(), "Workshop assets failed to load: " + workshop.load_error):
        return
    workshop.set_controls_visible(false)
    workshop.set_quality("high")
    workshop.controller.motion_paused = true
    workshop.controller.set_wind_time(0.0)
    workshop.controller.set_wind(0.55)
    workshop.controller.set_time_of_day(13.0)
    if not _require(workshop.select_settlement("village"), "Village selection failed"):
        return
    workshop.set_view_mode(0)
    await _capture("01_village_midday")
    workshop.controller.set_time_of_day(18.0)
    await _capture("02_village_sunset")
    workshop.controller.set_time_of_day(0.0)
    await _capture("03_village_night")
    workshop.controller.set_time_of_day(13.0)
    workshop.set_view_mode(2)
    if not _require(workshop.focus_on_asset("field_elm"), "Elm focus failed"):
        return
    workshop.controller.set_wind_time(0.0)
    await _capture("04_vegetation_wind_t0")
    workshop.controller.set_wind_time(2.0)
    await _capture("05_vegetation_wind_t2")
    workshop.controller.set_wind(0.0)
    workshop.controller.set_wind_time(0.0)
    await _capture("06_vegetation_calm_t0")
    workshop.controller.set_wind_time(2.0)
    await _capture("07_vegetation_calm_t2")
    if not _require(workshop.select_settlement("capital"), "Capital selection failed"):
        return
    workshop.set_view_mode(1)
    var capital: Dictionary = workshop.diagnostics().settlement
    if not _require(int(capital.placed_buildings) == 4000 and int(capital.distance_enabled_buildings) == 4000, "Capital overview does not contain 4000 active placements"):
        return
    await _capture("08_capital_4000")
    workshop.set_view_mode(3)
    workshop.set_controls_visible(true)
    await _capture("09_regional_routes")
    workshop.set_view_mode(0)
    workshop.set_controls_visible(false)
    if not _require(workshop.focus_on_asset("basilica"), "Basilica material review focus failed"):
        return
    await _capture("10_basilica_normalmap")
    var file := FileAccess.open(output_path.path_join("capture.json"), FileAccess.WRITE)
    file.store_string(JSON.stringify({
        "renderer": RenderingServer.get_video_adapter_name(),
        "rendering_method": ProjectSettings.get_setting("rendering/renderer/rendering_method"),
        "display_driver": DisplayServer.get_name(),
        "size": [1280,720],
        "scope": "Actual desktop software/hardware rendering; not an Android performance result",
        "frames": frames
    }, "\t"))
    file.close()
    workshop.queue_free()
    await process_frame
    await RenderingServer.frame_post_draw
    quit(0)

func _capture(label: String) -> void:
    for index in range(3):
        await process_frame
    await RenderingServer.frame_post_draw
    var picture := root.get_texture().get_image()
    if picture == null or picture.is_empty():
        push_error("Empty viewport: " + label)
        quit(1)
        return
    var destination := output_path.path_join(label + ".png")
    var error := picture.save_png(destination)
    if error != OK:
        push_error("PNG write failed: " + label)
        quit(1)
        return
    var hasher := HashingContext.new()
    hasher.start(HashingContext.HASH_SHA256)
    hasher.update(picture.get_data())
    frames.append({"label":label,"file":label+".png","pixel_sha256":hasher.finish().hex_encode(),"diagnostics":workshop.diagnostics()})
    print("WORLD_CAPTURE " + label)

func _require(condition: bool, message: String) -> bool:
    if not condition:
        push_error(message)
        quit(1)
    return condition
