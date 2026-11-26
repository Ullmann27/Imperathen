extends RefCounted
## Shared material library for the monument and street-furniture kits.
## The kit GLBs carry only material names, UVs and vertex-colour wear; the
## textures live once in res://assets/monuments/textures.
const TEXTURES := "res://assets/monuments/textures/"
const SPEC := {
	"travertine": {"rough": 0.86}, "travertine_paving": {"rough": 0.78}, "tuff": {"rough": 0.95},
	"brick": {"rough": 0.9}, "brick_floor": {"rough": 0.85}, "marble": {"rough": 0.42}, "marble_statue": {"rough": 0.38},
	"plaster": {"rough": 0.92}, "wood": {"rough": 0.8}, "wood_dark": {"rough": 0.78}, "sand": {"rough": 1.0},
	"bronze": {"rough": 0.45, "metal": 0.85}, "bronze_gilt": {"rough": 0.3, "metal": 1.0}, "iron": {"rough": 0.6, "metal": 0.8},
	"roof_tile": {"rough": 0.88}, "canvas": {"rough": 0.95, "two_sided": true},
	"canvas_purple": {"rough": 0.95, "two_sided": true, "texture": "canvas", "tint": Color(0.42, 0.10, 0.28)},
	"canvas_red": {"rough": 0.95, "two_sided": true, "texture": "canvas", "tint": Color(0.62, 0.16, 0.12)},
	"canvas_ochre": {"rough": 0.95, "two_sided": true, "texture": "canvas", "tint": Color(0.80, 0.58, 0.22)},
	"numeral_red": {"rough": 0.9, "flat": Color(0.55, 0.10, 0.07)},
	"paint_red": {"rough": 0.9, "texture": "plaster", "tint": Color(0.62, 0.17, 0.12)},
	"paint_black": {"rough": 0.9, "flat": Color(0.07, 0.06, 0.06)},
	"paint_ochre": {"rough": 0.9, "texture": "plaster", "tint": Color(0.85, 0.62, 0.25)},
	"arch_shadow": {"rough": 1.0, "flat": Color(0.045, 0.04, 0.035), "unshaded": true},
	"basalt": {"rough": 0.7, "texture": "travertine_paving", "tint": Color(0.30, 0.30, 0.33)},
	"terracotta": {"rough": 0.85, "texture": "plaster", "tint": Color(0.72, 0.38, 0.24)},
	"water": {"rough": 0.08, "flat": Color(0.16, 0.30, 0.33, 0.82), "alpha": true},
	"foliage": {"rough": 0.8, "flat": Color(0.20, 0.34, 0.14), "two_sided": true},
	"foliage_dark": {"rough": 0.8, "flat": Color(0.10, 0.22, 0.12), "two_sided": true},
	"bark": {"rough": 0.95, "texture": "wood_dark", "tint": Color(0.75, 0.68, 0.6)},
	"flame": {"flat": Color(1.0, 0.62, 0.2), "unshaded": true, "emission": 2.5},
}
static var _cache: Dictionary = {}


static func material(material_name: String, profile: String = "balanced") -> Material:
	var key := material_name + "|" + profile
	if _cache.has(key):
		return _cache[key]
	var spec: Dictionary = SPEC.get(material_name, {})
	var result := StandardMaterial3D.new()
	result.resource_name = material_name
	result.vertex_color_use_as_albedo = true
	result.roughness = float(spec.get("rough", 0.85))
	result.metallic = float(spec.get("metal", 0.0))
	if spec.has("flat"):
		result.albedo_color = spec.flat
	else:
		var source := str(spec.get("texture", material_name))
		var albedo := TEXTURES + source + "_albedo.jpg"
		if ResourceLoader.exists(albedo):
			result.albedo_texture = load(albedo)
		result.albedo_color = spec.get("tint", Color.WHITE)
		var normal := TEXTURES + source + "_normal.jpg"
		if profile != "low" and ResourceLoader.exists(normal):
			result.normal_enabled = true
			result.normal_texture = load(normal)
			result.normal_scale = 1.0
		result.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC if profile in ["high", "very_high"] else BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	if spec.get("two_sided", false):
		result.cull_mode = BaseMaterial3D.CULL_DISABLED
	if spec.get("unshaded", false):
		result.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	if spec.get("alpha", false):
		result.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	if spec.has("emission"):
		result.emission_enabled = true
		result.emission = result.albedo_color
		result.emission_energy_multiplier = float(spec.emission)
	_cache[key] = result
	return result


## Replaces every surface material of the meshes below `root` by library materials of the same name.
static func apply(root: Node, profile: String) -> void:
	for node: Node in root.find_children("*", "MeshInstance3D", true, false):
		assign(node.mesh, profile)


static func assign(mesh: Mesh, profile: String) -> void:
	if mesh == null:
		return
	for surface in mesh.get_surface_count():
		var current := mesh.surface_get_material(surface)
		if current != null and SPEC.has(current.resource_name):
			mesh.surface_set_material(surface, material(current.resource_name, profile))
