extends SceneTree
const Model=preload("res://scripts/domain/world_model.gd")
const Combat=preload("res://scripts/domain/unarmed_combat.gd")
var checks:=0
var failures:=0

func _initialize() -> void:
	call_deferred("_run")

func expect(value: bool, message: String) -> void:
	checks+=1
	if not value:
		failures+=1
		printerr("UNARMED_FAIL: "+message)

func attack(model, id: String="jab_left", target: String="practice", facing:=Vector2(0,-1)) -> Dictionary:
	return model.execute("village_unarmed_attack",{"technique":id,"target_id":target,"facing_x":facing.x,"facing_z":facing.y})

func _run() -> void:
	var model=Model.new()
	model.new_game("italia",true,true)
	expect(model._validate_state(model.data).is_empty(),"fresh childhood state is valid")
	expect(Combat.enabled(model.data),"new chapter has unarmed authority")
	model.set_player_position(Vector3(0,1,-5.7))
	expect(attack(model).ok,"basic jab accepted at twelve")
	expect(model.data.village.unarmed.practice_hits==0,"accepting a button awards no hit")
	expect(not attack(model).ok,"cannot overlap recovery with another attack")
	model.advance(.20)
	expect(model.data.village.unarmed.practice_hits==0,"windup awards no hit")
	model.advance(.10)
	expect(model.data.village.unarmed.practice_hits==1,"hit resolves inside actual impact time")
	model.advance(.40)
	expect(model.data.village.unarmed.practice_hits==1,"one animation resolves once")
	expect(attack(model,"jab_left","practice",Vector2(0,1)).ok,"backwards swing may be attempted")
	model.advance(.7)
	expect(model.data.village.unarmed.practice_hits==1,"a backwards swing misses")
	model.set_player_position(Vector3(0,1,8))
	expect(attack(model).ok,"swing from far away is accepted")
	model.advance(.7)
	expect(model.data.village.unarmed.practice_hits==1,"far target gets no phantom hit")
	model.set_player_position(Vector3(0,1,-5.7))
	model.combat_sight_check=func(_from:Vector2,_to:Vector2): return false
	attack(model)
	model.advance(.7)
	expect(model.data.village.unarmed.practice_hits==1,"wall rejects hit at correct distance")
	model.combat_sight_check=Callable()
	expect(not attack(model,"high_kick").ok,"advanced motion requires practice")
	attack(model)
	model.advance(.10)
	var path:="user://unarmed_pending.json"
	expect(model.save_game(path).ok,"save during windup")
	var restored=Model.new()
	expect(restored.load_game(path).ok,"restore during windup")
	restored.advance(.60)
	expect(restored.data.village.unarmed.practice_hits==2,"restored windup resolves exactly once")
	restored.advance(.60)
	expect(restored.data.village.unarmed.practice_hits==2,"restored recovery cannot repeat a hit")
	var before:=JSON.stringify(restored.data)
	var bad=restored.execute("village_unarmed_attack",{"technique":"jab_left","target_id":"practice","facing_x":NAN,"facing_z":-1})
	expect(not bad.ok and JSON.stringify(restored.data)==before,"nonfinite direction rejected atomically")
	for i in 12:
		restored.advance(1.0)
		expect(attack(restored).ok,"controlled practice "+str(i))
		restored.advance(.7)
	expect(restored.data.village.unarmed.practice_hits==14,"distinct controlled repetitions unlock techniques")
	for id: String in Combat.TECHNIQUES:
		expect(Combat.available(restored.data,id),"unlocked "+id)
		restored.advance(2.0)
		var count: int=restored.data.village.unarmed.practice_hits
		expect(attack(restored,id,"air").ok,"execute "+id)
		restored.advance(1.4)
		expect(restored.data.village.unarmed.practice_hits==count,"air gives no practice for "+id)
	expect(restored.data.player.age==12,"learning techniques never ages the child")
	expect(not restored.execute("train",{}).ok,"old six-year transition is blocked")
	expect(restored.execute("village_unarmed_guard",{}).ok,"unarmed guard works without an active raid")
	expect(not attack(restored).ok,"guard and attack cannot overlap")
	restored.advance(.9)
	expect(restored.execute("village_unarmed_dodge",{}).ok,"dodge after guard recovery")
	var legacy=Model.new()
	legacy.new_game("italia",true)
	expect(not Combat.enabled(legacy.data),"older village creation keeps its previous schema")
	expect(not attack(legacy).ok,"legacy game does not accidentally mutate new combat state")
	print("UNARMED_COMBAT_PASS checks=%d failures=%d"%[checks,failures])
	quit(0 if failures==0 else 1)
