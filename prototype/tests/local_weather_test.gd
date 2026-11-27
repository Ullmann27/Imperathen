extends SceneTree
const Weather := preload("res://scripts/domain/local_weather.gd")
const Calendar := preload("res://scripts/domain/world_calendar.gd")
const Look := preload("res://scripts/rendering/village_look.gd")
const Fires := preload("res://scripts/rendering/route_fire_lights.gd")
var failures:=0
var checks:=0
func _initialize()->void:
	_run.call_deferred()
func check(ok:bool,why:String)->void:
	checks+=1
	if not ok:
		failures+=1
		push_error(why)
func _run()->void:
	var start:=Calendar.date_to_jdn(Calendar.CAMPAIGN_START)
	check(Weather.sample(Calendar.new_clock(start,6*3600),"italia").rain==0.0,"Authored first morning is dry")
	var seen:Dictionary={}
	for day in range(start,start+366):
		for hour in [3,9,15,21]:
			var clock:=Calendar.new_clock(day,hour*3600)
			var a:=Weather.sample(clock,"italia")
			check(a==Weather.sample(clock.duplicate(),"italia"),"Same saved time gives same weather")
			check(float(a.rain)>=0.0 and float(a.rain)<=1.0 and float(a.wetness)>=0.0 and float(a.wetness)<=1.0,"Finite bounded weather")
			seen[a.kind]=true
		for seconds in [0,21600,43200,64800]:
			var now:=Calendar.new_clock(day,seconds)
			var last:=Calendar.advance_clock(now,-1)
			var a:=Weather.sample(last,"italia")
			var b:=Weather.sample(now,"italia")
			check(absf(float(a.rain)-float(b.rain))<0.001 and absf(float(a.wind)-float(b.wind))<0.001,"Weather transition continuous at block boundary")
	check(seen.size()==5,"All five fictional weather regimes occur")
	check(Weather.sample(null,"italia",2).kind=="rain","Clockless legacy autumn preserved")
	var fire:=Fires.new()
	root.add_child(fire)
	fire.set_route_context(Vector3.ZERO,PackedVector2Array([Vector2.ZERO,Vector2(0,-6),Vector2(10,-6)]))
	check(fire._route_samples.size()==3,"Lookahead follows path distance")
	check(fire._route_samples[0].is_equal_approx(Vector2(0,-4)) and fire._route_samples[1].is_equal_approx(Vector2(2,-6)),"Forward route samples follow bend")
	fire.free()
	print("LOCAL_WEATHER_PASS" if failures==0 else "LOCAL_WEATHER_FAIL"," checks=",checks," failures=",failures)
	quit(0 if failures==0 else 1)
