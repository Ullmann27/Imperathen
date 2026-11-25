extends SceneTree
## Deterministic policy and real RuntimeDisplay lifecycle regression. No fake
## Fold7 thermals, FPS benchmark or new gameplay success is inferred here.
const Policy := preload("res://scripts/rendering/fold7_quality_policy.gd")
var checks := 0
var failures: Array[String] = []


func _initialize() -> void:
	if OS.get_environment("IMPERATHEN_ISOLATED_TEST") != "1":
		push_error("Graphics policy regression needs an isolated test account")
		quit(2)
		return
	_run.call_deferred()


func _check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures.append(message)
		push_error(message)


func _run() -> void:
	_check(Policy.recommended_profile(true,"Qualcomm Adreno 830")=="high",
		"Adreno 830 Android tier recommends High on a fresh install")
	_check(Policy.recommended_profile(true,"Qualcomm Adreno (TM) 830")=="high",
		"The driver-reported trademark suffix does not hide high-tier hardware")
	_check(Policy.recommended_profile(false,"Adreno 830")=="balanced",
		"A desktop does not inherit a Fold7 heuristic")
	_check(Policy.recommended_profile(true,"Mali-G76")=="balanced",
		"Unknown Android tier retains the safe balanced preference")
	var high: Dictionary = Policy.initial("high")
	_check(is_equal_approx(float(high.ratio),1.0),"High initially uses the entire selected pixel budget")
	for i in 2:
		high = Policy.step("high",high,28.0,-1.0,80,true)
	_check(is_equal_approx(float(high.ratio),1.0),"Short pressure does not thrash resolution")
	high = Policy.step("high",high,28.0,-1.0,80,true)
	_check(is_equal_approx(float(high.ratio),0.94),"Three sustained high-P95 windows reduce only 3D resolution")
	_check(str(high.reason)=="sustained_frame_pressure","Reduction has measured reason")
	var holding: Dictionary = Policy.step("high",high,16.5,-1.0,80,true)
	for i in 30:
		holding = Policy.step("high",holding,16.5,-1.0,80,true)
	_check(is_equal_approx(float(holding.ratio),0.94),
		"Missing GPU measurement never fabricates spare GPU headroom")
	for i in 18:
		holding = Policy.step("high",holding,16.5,5.0,80,true)
	_check(float(holding.ratio)>0.94,"Confirmed GPU render headroom permits cautious recovery")
	_check(float(holding.ratio)<=1.0,"Recovery never supersamples beyond the chosen preset")
	var worst: Dictionary = Policy.initial("very_high")
	for i in 150:
		worst = Policy.step("very_high",worst,65.0,51.0,90,true)
	_check(float(worst.ratio)>=0.68 and float(worst.ratio)<0.72,
		"Very High hits a strict minimum quality floor under prolonged pressure")
	var frozen: Dictionary = worst.duplicate(true)
	for bad in [NAN,INF,-1.0,0.0]:
		worst = Policy.step("very_high",worst,float(bad),22.0,90,true)
	_check(worst==frozen,"Invalid or missing measurements never change the policy")
	worst = Policy.step("very_high",worst,60.0,51.0,10,true)
	_check(worst==frozen,"Too few samples never drive resolution decisions")
	worst = Policy.step("very_high",worst,60.0,51.0,90,false)
	_check(worst==frozen,"Pause or background does not count as a gameplay sample")
	var balance: Dictionary = Policy.initial("balanced")
	balance = Policy.step("balanced",balance,200.0,200.0,180,true)
	_check(is_equal_approx(float(balance.ratio),1.0),"Balanced is unchanged by an opt-in high-tier governor")
	var selected := {"ratio":0.75}
	_check(is_equal_approx(Policy.effective_render_scale(0.80,selected),0.60),
		"Actual 3D buffer scale combines the native-pixel cap and dynamic ratio")
	_check(is_equal_approx(Policy.effective_render_scale(1.0,selected),0.75),
		"UI pixel resolution does not enter the 3D scale policy")
	var display := root.get_node_or_null("RuntimeDisplay")
	_check(is_instance_valid(display),"Actual global runtime display is available")
	if is_instance_valid(display):
		display._notification(Node.NOTIFICATION_APPLICATION_RESUMED)
		display._notification(Node.NOTIFICATION_APPLICATION_FOCUS_IN)
		display.set_diagnostics(false)
		display.apply_quality("high")
		display.set_sustained_scene(true)
		_check(display.is_processing() and not display._panel.visible,
			"Sustained city measures invisible diagnostics without showing a debug HUD")
		_check(Engine.max_fps==60 and display.quality_report().selected=="high",
			"High preserves the selected 60 FPS limit and public quality report")
		display._governor.ratio = 0.76
		root.size = Vector2i(2160,2160)
		display._on_size_changed()
		var cap: float = sqrt(float(display._profiles.high.max_3d_pixels) / float(root.size.x*root.size.y))
		_check(is_equal_approx(root.scaling_3d_scale,cap*0.76),
			"Square unfolded viewport preserves aspect and scales only the 3D buffer")
		display.set_sustained_paused(true)
		_check(not display.is_processing() and is_equal_approx(float(display._governor.ratio),0.76),
			"Paused game stops hidden monitoring without resetting selected image detail")
		display.set_sustained_paused(false)
		_check(display.is_processing(),"Resume restarts sampling only in the foreground")
		display.set_sustained_scene(false)
		_check(not display.is_processing() and display.quality_report().dynamic_3d_ratio==1.0,
			"Leaving the city resets the transient render reduction without changing High preference")
		root.size = Vector2i(1280,720)
		display.apply_quality("balanced")
		display.set_diagnostics(false)
	if failures.is_empty():
		print("FOLD7_GRAPHICS_POLICY_PASS checks=%d; deterministic 3D policy, not a device benchmark" % checks)
	else:
		print("FOLD7_GRAPHICS_POLICY_FAIL checks=%d failures=%d" % [checks,failures.size()])
	quit(0 if failures.is_empty() else 1)
