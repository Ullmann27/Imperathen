extends Node3D
const ROOT = "res://assets/roman_material_lab/"
const IDS = ["iron_worn", "iron_service", "iron_veteran", "iron_honor", "leather_oiled", "oak_worked", "lime_plaster"]

func _ready() -> void:
	for i in range(IDS.size()):
		var id: String = IDS[i]
		var material := StandardMaterial3D.new()
		material.albedo_texture = load(ROOT + id + "_basecolor.png") as Texture2D
		material.normal_enabled = true
		material.normal_texture = load(ROOT + id + "_normal.png") as Texture2D
		var packed := load(ROOT + id + "_orm.png") as Texture2D
		material.roughness = 1.0
		material.roughness_texture = packed
		material.roughness_texture_channel = BaseMaterial3D.TEXTURE_CHANNEL_GREEN
		material.metallic = 1.0
		material.metallic_texture = packed
		material.metallic_texture_channel = BaseMaterial3D.TEXTURE_CHANNEL_BLUE
		material.ao_enabled = true
		material.ao_texture = packed
		material.ao_texture_channel = BaseMaterial3D.TEXTURE_CHANNEL_RED
		material.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
		var x := float(i % 4) * 2.2 - 3.3
		var z := floorf(float(i) / 4.0) * 2.8
		var specimen := MeshInstance3D.new()
		var sphere := SphereMesh.new()
		sphere.radius = 0.70
		sphere.height = 1.40
		sphere.radial_segments = 48
		sphere.rings = 24
		specimen.mesh = sphere
		specimen.material_override = material
		add_child(specimen)
		specimen.position = Vector3(x, 1.0, z)
		var label := Label3D.new()
		label.text = id
		label.font_size = 48
		label.pixel_size = 0.008
		label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		add_child(label)
		label.position = Vector3(x, 0.2, z)
