extends SceneTree
## The saved practice-staff flag uses the existing hand-skinned prop at every LOD.

const Person = preload("res://scripts/visuals/village_person.gd")
var checks := 0
var failures: Array[String] = []


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var hero := Person.new()
	root.add_child(hero)
	hero.configure("player","italia",12)
	hero.sample_pose("march",.37)
	hero.speed = 1.35
	_check(not _blade(hero).visible,"none: the child starts with no visible practice equipment")
	var previous_clip := hero.clip
	var previous_phase := hero.phase
	var previous_speed := hero.speed
	var previous_body_id := hero.body.get_instance_id()
	hero.set_practice_staff_equipped(true)
	_check(_blade(hero).visible,"loaned: the existing staff becomes visible immediately")
	_check(hero.clip==previous_clip and is_equal_approx(hero.phase,previous_phase) and is_equal_approx(hero.speed,previous_speed),"Equipping preserves the current animation, phase and movement speed")
	_check(hero.body.get_instance_id()==previous_body_id,"Equipping does not replace the character model")
	for level in 4:
		hero._reload(level)
		var blade := _blade(hero)
		_check(blade!=null and blade.visible and blade.skin!=null,"loaned: the same hand-skinned prop is visible at LOD %d"%level)
		_check(hero.body.find_children("PracticeBlade","MeshInstance3D",true,false).size()==1,"There is exactly one carried prop at LOD %d"%level)
		_check(hero.clip=="march" and is_equal_approx(hero.phase,.37),"Carrying preserves the walking frame across LOD %d"%level)
	# Buying the already borrowed item keeps the same visible prop. The caller's
	# state transition does not create a second object or a second inventory item.
	previous_body_id = hero.body.get_instance_id()
	hero.set_practice_staff_equipped(true)
	_check(_blade(hero).visible and hero.body.get_instance_id()==previous_body_id,"owned: buying the loan keeps the same visible prop")
	for action in ["idle","talk","march","run","train","block"]:
		hero.sample_pose(action,.41)
		_check(_blade(hero).visible,"The explicitly carried item persists during "+action)
	hero.set_practice_staff_equipped(false)
	_check(not _blade(hero).visible,"returned: the child immediately gives up the visible prop")
	for level in 4:
		hero._reload(level)
		_check(not _blade(hero).visible,"returned: LOD %d cannot restore the given-back item"%level)
	# A fresh projection of a loaded loan accepts the flag before loading its rig.
	var restored := Person.new()
	root.add_child(restored)
	restored.set_practice_staff_equipped(true)
	restored.configure("player","italia",12)
	_check(_blade(restored).visible,"A restored loan is visible after the first model load")
	restored.set_practice_staff_equipped(false)
	restored.reset_motion()
	_check(not _blade(restored).visible,"Restoring none clears the item and resetting motion does not restore it")
	# The original adult rule remains unchanged when no explicit childhood item
	# is supplied; no attack, damage, clip or timing implementation is modified.
	hero.configure("player","italia",18)
	for action in ["attack","train","block"]:
		hero.sample_pose(action,.4)
		_check(_blade(hero).visible,"Legacy adult equipment still appears for "+action)
	for action in ["idle","march","talk"]:
		hero.sample_pose(action,.4)
		_check(not _blade(hero).visible,"Legacy adult equipment remains stowed for "+action)
	var companion := Person.new()
	root.add_child(companion)
	companion.configure("companion","italia",12)
	companion.set_practice_staff_equipped(true)
	_check(not _blade(companion).visible,"The player's equipment cannot equip a separate companion")
	companion.free()
	restored.free()
	hero.free()
	await process_frame
	print("CHILDHOOD_EQUIPMENT_VISUAL_RESULT checks=%d failures=%d"%[checks,failures.size()])
	for message: String in failures: printerr("FAIL: "+message)
	quit(0 if failures.is_empty() else 1)


func _blade(person: Person) -> MeshInstance3D:
	return person.body.find_child("PracticeBlade",true,false) as MeshInstance3D


func _check(value: bool,message: String) -> void:
	checks += 1
	if not value:
		failures.append(message)
		push_error(message)
