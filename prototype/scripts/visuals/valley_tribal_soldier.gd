extends "res://scripts/visuals/soldier_visual.gd"
## Original highland-warrior families from the project's own Blender sources.
const FAMILIES := {
	"germanic_retainer": "forest_swordsman",
	"germanic_levy": "forest_spear",
	"germanic_skirmisher": "forest_skirmisher",
}
var family := ""


func _body_scene() -> PackedScene:
	return load("res://assets/germanic_warriors/%s_%d.glb" % [family, detail]) as PackedScene


func _apply_tint(_instance: MeshInstance3D) -> void:
	# Individual garments, skin, wood and metals keep their authored materials.
	pass


static func silhouette(family_id: String) -> Mesh:
	var packed := load("res://assets/germanic_warriors/%s_far.glb" % family_id) as PackedScene
	var figure := packed.instantiate() as Node3D
	var instance := figure.find_children("*", "MeshInstance3D", true, false)[0] as MeshInstance3D
	var mesh := instance.mesh
	figure.free()
	return mesh
