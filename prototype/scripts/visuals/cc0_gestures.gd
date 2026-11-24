extends RefCounted
## CC0 Quaternius/KinemIQ v1.0, retargeted by cc0_retarget_review.gd.
## Only relative Spine/Head rotation is allowed into idle and speech.
## Full library remains available for review; never drives world movement.

const PATH := "res://assets/animations/hero_cc0_library.tres"
const CLIPS := {"idle":"idlerelaxedidlerelaxed","talk":"idletalkingidletalking"}
const MAX_ANGLE := 0.0872664625997165
static var _library: AnimationLibrary
static var _attempted := false

static func library() -> AnimationLibrary:
	if not _attempted:
		_attempted = true
		if ResourceLoader.exists(PATH,"AnimationLibrary"):
			_library = load(PATH) as AnimationLibrary
	return _library

static func delta(action: String, bone: String, normalized: float) -> Quaternion:
	if not CLIPS.has(action) or bone not in ["Spine","Head"] or not is_finite(normalized):
		return Quaternion.IDENTITY
	var source := library()
	if source == null or not source.has_animation(CLIPS[action]):
		return Quaternion.IDENTITY
	var animation := source.get_animation(CLIPS[action])
	var track := animation.find_track(NodePath("HeroRig/Skeleton3D:"+bone),Animation.TYPE_ROTATION_3D)
	if track < 0 or animation.length <= 0.0:
		return Quaternion.IDENTITY
	var phase := fposmod(normalized,1.0)
	var start := animation.rotation_track_interpolate(track,0.0).normalized()
	var current := animation.rotation_track_interpolate(track,phase*animation.length).normalized()
	if not start.is_finite() or not current.is_finite():
		return Quaternion.IDENTITY
	var rotation := (start.inverse()*current).normalized()
	if rotation.w < 0.0:
		rotation = -rotation
	var angle := Quaternion.IDENTITY.angle_to(rotation)
	if angle <= 0.00001:
		return Quaternion.IDENTITY
	# Blend a small fraction of the real motion, with a continuous loop seam.
	var weight := minf(0.35,MAX_ANGLE/angle)*sin(phase*PI)
	return Quaternion.IDENTITY.slerp(rotation,weight).normalized()
