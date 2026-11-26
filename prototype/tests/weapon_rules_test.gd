extends SceneTree
const Rules = preload("res://scripts/domain/weapon_rules.gd")
var checks := 0

func check(condition: bool, message: String) -> void:
    checks += 1
    if not condition:
        push_error("FAIL: " + message)
        quit(1)

func _initialize() -> void:
    var weapons: Dictionary = Rules.load_catalog()
    check(weapons.size() == 7, "seven weapons load")
    var gladius: Dictionary = weapons.get("gladius", {})
    var scutum: Dictionary = weapons.get("scutum", {})
    var attacker := {"alive": true, "stamina": 20.0, "next_attack_s": 0.0}
    var defender := {"alive": true, "health": 50, "blocking": false}
    check(Rules.can_attack(gladius, attacker, 0.5, 1.0), "gladius attack allowed")
    check(not Rules.can_attack(gladius, attacker, 3.0, 1.0), "out of range")
    check(not Rules.can_attack(scutum, attacker, 0.0, 1.0), "shield not an attack")
    check(not Rules.can_attack(gladius, {"alive": false, "stamina": 20.0}, 0.5, 1.0), "dead attacker")
    check(not Rules.can_attack(gladius, {"alive": true, "stamina": 0.0}, 0.5, 1.0), "stamina required")
    check(not Rules.can_attack(gladius, {"alive": true, "stamina": 20.0, "next_attack_s": 2.0}, 0.5, 1.0), "cooldown")
    var hit: Dictionary = Rules.attack_preview(gladius, attacker, defender, 0.5, 1.0)
    check(bool(hit.get("accepted", false)), "attack preview accepted")
    check(int(hit.get("remaining_health", -1)) == 32, "damage")
    defender["blocking"] = true
    var block: Dictionary = Rules.attack_preview(gladius, attacker, defender, 0.5, 1.0)
    check(int(block.get("damage", -1)) < int(hit.get("damage", 0)), "blocking reduces damage")
    check(int(defender["health"]) == 50, "preview does not mutate defender")
    print("WEAPON_RULES_PASS checks=", checks)
    quit(0)
