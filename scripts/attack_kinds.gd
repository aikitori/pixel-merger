class_name AttackKinds
extends RefCounted
## Angriffsformen: wie eine Einheit zuschlägt oder schießt und was ein Treffer zusätzlich bewirkt.
## Welche Einheit welche Form hat, steht in tools/content.py (LINE_PROFILE, COMBO_ATTACK).
## Nahkampf wirkt sofort, Fernkampf über ein Geschoss (Projectile), "lightning" und "blessing" sofort mit
## sichtbarem Strahl. Gegner ohne eigene Form nutzen den Standard ihres Kampfstils (siehe for_style).

const INFO := {
	# Nahkampf
	&"slash": {"name": "Schwerthieb", "text": "Trifft auch einen Gegner daneben.", "family": "melee", "sound": &"swing"},
	&"axe": {"name": "Axthieb", "text": "Trifft alle Gegner rund um das Ziel ein wenig.", "family": "melee", "sound": &"swing"},
	&"club": {"name": "Keulenschlag", "text": "Schleudert das Ziel weg und betäubt kurz.", "family": "melee", "sound": &"hit"},
	&"stomp": {"name": "Stampfer", "text": "Erschüttert den Boden rund um das Ziel.", "family": "melee", "sound": &"explode"},
	&"kick": {"name": "Huftritt", "text": "Stößt das Ziel zurück.", "family": "melee", "sound": &"hit"},
	&"claw": {"name": "Krallen", "text": "Zwei schnelle Hiebe.", "family": "melee", "sound": &"swing"},
	&"bite": {"name": "Biss", "text": "Das Ziel blutet nach.", "family": "melee", "sound": &"hit"},
	&"grasp": {"name": "Totengriff", "text": "Das Ziel wird langsamer.", "family": "melee", "sound": &"hit"},
	&"tongue": {"name": "Zungenschlag", "text": "Zieht das Ziel heran.", "family": "melee", "sound": &"swing"},
	&"thrust": {"name": "Speerstich", "text": "Durchbohrt auch einen Gegner dahinter.", "family": "melee", "sound": &"swing"},
	# Fernkampf
	&"arrow": {"name": "Pfeil", "text": "Schneller Schuss.", "family": "ranged", "sound": &"arrow",
		"speed": 260.0, "look": "arrow", "color": Color("#c97a2e")},
	&"javelin": {"name": "Wurfspeer", "text": "Durchschlägt das Ziel und trifft einen dahinter.", "family": "ranged",
		"sound": &"arrow", "speed": 200.0, "look": "javelin", "color": Color("#d8c8a0")},
	&"arcane": {"name": "Arkankugel", "text": "Springt vom Ziel auf einen zweiten Gegner.", "family": "ranged",
		"sound": &"fireball", "speed": 170.0, "look": "orb", "color": Color("#b07aff")},
	&"ember": {"name": "Glutspucke", "text": "Setzt das Ziel in Brand.", "family": "ranged", "sound": &"fireball",
		"speed": 160.0, "look": "orb", "color": Color("#ff7a1f")},
	&"curse": {"name": "Fluchbann", "text": "Das Ziel macht kurz weniger Schaden.", "family": "ranged", "sound": &"heal",
		"speed": 140.0, "look": "skull", "color": Color("#8a3aff")},
	&"fireball": {"name": "Feuerball", "text": "Explodiert und trifft Gegner ringsum.", "family": "ranged",
		"sound": &"fireball", "speed": 150.0, "look": "fireball", "color": Color("#ff8a1f")},
	&"water_jet": {"name": "Wasserstrahl", "text": "Spült das Ziel zurück.", "family": "ranged", "sound": &"heal",
		"speed": 210.0, "look": "drop", "color": Color("#4fa8ff")},
	&"lightning": {"name": "Blitzschlag", "text": "Trifft sofort.", "family": "ranged", "sound": &"fireball",
		"speed": 0.0, "look": "bolt", "color": Color("#bfe6ff")},
	&"spit": {"name": "Giftspucke", "text": "Vergiftet das Ziel.", "family": "ranged", "sound": &"heal",
		"speed": 150.0, "look": "drop", "color": Color("#7adf3a")},
	&"ice_shard": {"name": "Eissplitter", "text": "Verlangsamt das Ziel.", "family": "ranged", "sound": &"arrow",
		"speed": 220.0, "look": "shard", "color": Color("#8fe0ff")},
	# Heilen
	&"heal": {"name": "Heilzauber", "text": "Heilt einen Verbündeten.", "family": "heal", "sound": &"heal",
		"speed": 120.0, "look": "heal", "color": Color("#4fe07a")},
	&"blessing": {"name": "Segensstrahl", "text": "Heilt sofort.", "family": "heal", "sound": &"heal",
		"speed": 0.0, "look": "beam", "color": Color("#fff3a0")},
}


static func display_name(id: StringName) -> String:
	return TranslationServer.translate(INFO[id]["name"]) if INFO.has(id) else ""


static func description(id: StringName) -> String:
	return TranslationServer.translate(INFO[id]["text"]) if INFO.has(id) else ""


## Standardform eines Kampfstils (Gegner und Bosse haben keine eigene).
static func for_style(style: StringName) -> StringName:
	match style:
		&"arrow": return &"arrow"
		&"magic": return &"fireball"
		&"heal": return &"heal"
	return &"slash"


static func is_melee(id: StringName) -> bool:
	return INFO.has(id) and INFO[id]["family"] == "melee"


## Sofortige Wirkung ohne Flugzeit (Blitz, Segensstrahl).
static func is_instant(id: StringName) -> bool:
	return INFO.has(id) and INFO[id]["family"] != "melee" and float(INFO[id].get("speed", 1.0)) <= 0.0


static func sound(id: StringName) -> StringName:
	return INFO[id]["sound"] if INFO.has(id) else &"hit"


## Zusatzwirkung eines Treffers mit Schaden `damage` auf `target`. `source` kann schon gefallen sein
## (Geschoss im Flug), dann zählt der Zusatzschaden ohne Urheber.
static func after_hit(id: StringName, source: Combatant, target: Combatant, damage: float) -> void:
	var by: Combatant = source if is_instance_valid(source) else null
	var at := target.position
	match id:
		&"slash":
			var next := _nearest_other(target, at, 16.0)
			if next != null:
				next.take_damage(damage * 0.3, by)
		&"axe":
			for other in _others_near(target, at, 18.0):
				other.take_damage(damage * 0.2, by)
		&"club":
			_push(target, by, 14.0)
			target.apply_effect(&"stun", 0.25, 1.0)
		&"stomp":
			for other in _others_near(target, at, 20.0):
				other.take_damage(damage * 0.35, by)
			_spawn(target, &"ring", at, 20.0, Color("#a8743a"))
		&"kick":
			_push(target, by, 10.0)
		&"claw":
			if target.is_alive():
				target.take_damage(damage * 0.4, by)  # zweiter Hieb
		&"bite":
			target.poison(damage * 0.25, 3.0, by)
		&"grasp":
			target.apply_effect(&"slow", 1.2, 0.65)
		&"tongue":
			_push(target, by, -8.0)
		&"thrust", &"javelin":
			var behind := _behind(target, by, 24.0)
			if behind != null:
				behind.take_damage(damage * (0.45 if id == &"thrust" else 0.35), by)
		&"arcane":
			var next := _nearest_other(target, at, 45.0)
			if next != null:
				next.take_damage(damage * 0.35, by)
				_spawn(target, &"bolt", target.center(), 0.0, Color("#b07aff"), next.center() - target.center())
		&"ember":
			target.poison(damage * 0.2, 2.0, by)
		&"curse":
			target.apply_effect(&"weak", 2.0, 0.75)
		&"fireball":
			for other in _others_near(target, at, 18.0):
				other.take_damage(damage * 0.3, by)
		&"water_jet":
			_push(target, by, 10.0)
		&"spit":
			target.poison(damage * 0.3, 3.0, by)
		&"ice_shard":
			target.apply_effect(&"slow", 1.5, 0.6)


static func _others_near(target: Combatant, point: Vector2, radius: float) -> Array[Combatant]:
	var result: Array[Combatant] = []
	for other in target._allies_near(point, radius):
		if other != target and other.is_alive():
			result.append(other)
	return result


static func _nearest_other(target: Combatant, point: Vector2, radius: float) -> Combatant:
	var best: Combatant = null
	var best_dist := radius * radius
	for other in _others_near(target, point, radius):
		var dist := other.position.distance_squared_to(point)
		if dist <= best_dist:
			best_dist = dist
			best = other
	return best


## Gegner hinter dem Ziel (vom Angreifer aus gesehen).
static func _behind(target: Combatant, source: Combatant, reach: float) -> Combatant:
	if source == null:
		return null
	var dir := (target.position - source.position).normalized()
	for other in _others_near(target, target.position + dir * reach * 0.6, reach * 0.6):
		if (other.position - target.position).dot(dir) > 0.0:
			return other
	return null


## Ziel vom Angreifer wegstoßen (negativ: heranziehen). Bosse bewegen sich kaum.
static func _push(target: Combatant, source: Combatant, distance: float) -> void:
	if source == null or not target.is_alive():
		return
	var dir := (target.position - source.position).normalized()
	if dir == Vector2.ZERO:
		return
	target.position = World.clamp_point(target.position + dir * distance * (0.25 if target.is_boss else 1.0))


static func _spawn(near: Combatant, kind: StringName, at: Vector2, radius: float, tint: Color, direction := Vector2.ZERO) -> void:
	if Effect.can_spawn_ambient():
		near._spawn_effect(kind, at, radius, tint, "", direction)
