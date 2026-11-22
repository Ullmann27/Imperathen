class_name FrontierQuality
extends RefCounted
## Visual controls only: this class has no reference to gameplay/save state.

const PROFILE_PATH := "res://quality_profiles.json"
var profiles: Dictionary = {}
var active_id := "balanced"

func _init() -> void:
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(PROFILE_PATH))
	if parsed is Dictionary and parsed.get("profiles") is Dictionary:
		profiles = parsed["profiles"]

func resolution_scale(pixel_size: Vector2i, profile_id: String) -> float:
	var pixels := maxf(float(pixel_size.x) * float(pixel_size.y), 1.0)
	var budget: float = float(profiles[profile_id]["max_3d_pixels"])
	return clampf(sqrt(budget / pixels), 0.25, 1.0)

func apply(profile_id: String, viewport: Viewport, sun: DirectionalLight3D,
		environment: Environment, decoration: MultiMeshInstance3D) -> Dictionary:
	if not profiles.has(profile_id):
		return {"error": "Unknown graphics profile: " + profile_id}
	active_id = profile_id
	var profile: Dictionary = profiles[profile_id]
	# canvas_items exposes logical UI coordinates through get_visible_rect().
	# Render budgets must instead use the physical output size.
	var output_size: Vector2i = viewport.size if viewport is Window else viewport.get_texture().get_size()
	viewport.scaling_3d_mode = Viewport.SCALING_3D_MODE_BILINEAR
	viewport.scaling_3d_scale = resolution_scale(output_size, profile_id)
	var aa: int = int(profile["msaa_samples"])
	viewport.msaa_3d = Viewport.MSAA_4X if aa == 4 else (Viewport.MSAA_2X if aa == 2 else Viewport.MSAA_DISABLED)
	viewport.mesh_lod_threshold = float(profile["mesh_lod_threshold"])
	RenderingServer.directional_shadow_atlas_set_size(int(profile["shadow_atlas_size"]), true)
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = float(profile["shadow_distance_metres"])
	# Glow is optional on the compatibility fallback; essential light/materials remain.
	environment.glow_enabled = bool(profile["glow"]) and RenderingServer.get_current_rendering_method() != "gl_compatibility"
	decoration.multimesh.visible_instance_count = int(round(decoration.multimesh.instance_count * float(profile["decoration_fraction"])))
	return {"profile": profile_id, "label": profile["label"], "output_size": [output_size.x, output_size.y],
		"render_scale": viewport.scaling_3d_scale, "visible_decorations": decoration.multimesh.visible_instance_count,
		"shadow_distance_metres": sun.directional_shadow_max_distance, "msaa_samples": aa,
		"renderer": RenderingServer.get_current_rendering_method()}
