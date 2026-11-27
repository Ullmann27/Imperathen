extends RefCounted
## Cinematic feedback is a view of a verified result, never a source of harm.
## No time-scale change or forced execution; the player can take control back.
const DURATION := .85
static func eligible(event: Dictionary, player_age: int, enabled: bool) -> bool:
	var point: Variant = event.get("target_position")
	return enabled and player_age>=18 and bool(event.get("hit",false)) and bool(event.get("armed",false)) and not bool(event.get("practice",false)) and int(event.get("before_health",0))>0 and int(event.get("after_health",-1))==0 and point is Vector2 and point.is_finite() and not str(event.get("target_id","")) in ["","air","practice"]

static func weight(remaining: float) -> float:
	if not is_finite(remaining) or remaining<=0 or remaining>=DURATION:
		return 0.0
	return sin(PI*clampf(remaining/DURATION,0,1))*.68
