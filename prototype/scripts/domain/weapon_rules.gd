extends RefCounted
## Isolated combat rules; integration into existing WorldModel requires separate review.
## No direct writes to saves, scenes or existing combat logic.

const CATALOG_PATH := "res://data/weapons/weapon_catalog.v1.json"

static func load_catalog() -> Dictionary:
    if not FileAccess.file_exists(CATALOG_PATH):
        return {}
    var file := FileAccess.open(CATALOG_PATH, FileAccess.READ)
    if file == null:
        return {}
    var parsed: Variant = JSON.parse_string(file.get_as_text())
    if not (parsed is Dictionary):
        return {}
    var result: Dictionary = {}
    for weapon in parsed.get("weapons", []):
        if not (weapon is Dictionary):
            return {}
        var id: String = str(weapon.get("id", ""))
        if id.is_empty() or result.has(id):
            return {}
        result[id] = weapon
    return result

static func can_attack(weapon: Dictionary, attacker: Dictionary, distance_m: float, now_s: float) -> bool:
    if weapon.is_empty() or attacker.is_empty():
        return false
    if str(weapon.get("category", "")) == "shield":
        return false
    if not bool(attacker.get("alive", true)):
        return false
    if float(attacker.get("stamina", 0.0)) < float(weapon.get("stamina_cost", 0.0)):
        return false
    if now_s < float(attacker.get("next_attack_s", 0.0)):
        return false
    return distance_m >= 0.0 and distance_m <= float(weapon.get("reach_m", 0.0))

static func attack_preview(weapon: Dictionary, attacker: Dictionary, defender: Dictionary, distance_m: float, now_s: float) -> Dictionary:
    ## Pure preview only. Authoritative WorldModel must validate and commit atomically.
    if not can_attack(weapon, attacker, distance_m, now_s):
        return {"accepted": false, "reason": "attack_not_allowed"}
    if not bool(defender.get("alive", true)):
        return {"accepted": false, "reason": "target_not_alive"}
    var damage: int = maxi(0, int(weapon.get("damage", 0)))
    if bool(defender.get("blocking", false)):
        damage = int(ceil(float(damage) * 0.35))
    var remaining: int = maxi(0, int(defender.get("health", 0)) - damage)
    return {
        "accepted": true,
        "damage": damage,
        "remaining_health": remaining,
        "target_alive": remaining > 0,
        "attacker_stamina": maxf(0.0, float(attacker.get("stamina", 0.0)) - float(weapon.get("stamina_cost", 0.0))),
        "next_attack_s": now_s + float(weapon.get("cooldown_s", 0.0))
    }
