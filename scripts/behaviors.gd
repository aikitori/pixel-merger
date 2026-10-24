class_name Behaviors
extends RefCounted
## Verhalten im Kampf: welches Ziel eine Einheit wählt und wie sie sich dazu bewegt.
## Welche Einheit welches hat, steht in tools/content.py (LINE_PROFILE, COMBO_BEHAVIOR). Combatant fragt
## pick_target bei der Zielwahl, steer vor dem normalen Heranlaufen und after_attack nach jedem Angriff.
## Befehle des Spielers (Halten, Schützen, Laufen) gehen immer vor.

const INFO := {
	&"frontline": {"name": "Frontkämpfer", "text": "Geht auf den nächsten Gegner los."},
	&"guardian": {"name": "Wächter", "text": "Bleibt bei Fernkämpfern und Heilern und fängt ihre Angreifer ab."},
	&"skirmisher": {"name": "Plänkler", "text": "Hält Abstand und weicht zurück, wenn Gegner zu nah kommen."},
	&"flanker": {"name": "Flankierer", "text": "Läuft außen herum und jagt Fernkämpfer und Heiler."},
	&"charger": {"name": "Stürmer", "text": "Greift an, zieht sich kurz zurück und stürmt erneut."},
	&"assassin": {"name": "Meuchler", "text": "Jagt den schwächsten Gegner in Reichweite."},
	&"artillery": {"name": "Artillerie", "text": "Zielt auf Gegnergruppen und bleibt auf Abstand."},
	&"hopper": {"name": "Hüpfer", "text": "Bewegt sich in weiten Sprüngen."},
	&"floater": {"name": "Schweber", "text": "Schwebt über Hindernisse hinweg."},
	&"support": {"name": "Unterstützer", "text": "Bleibt bei Verbündeten und heilt sie."},
}

const GUARD_RANGE := 120.0
const GUARD_LEASH := 55.0
const FLANK_RANGE := 160.0
const ASSASSIN_RANGE := 150.0
const KITE_SHARE := 0.45
const CHARGER_RETREAT := 0.6
const CLUSTER_RADIUS := 22.0
const CLUSTER_CANDIDATES := 8
const HOP_CYCLE := 0.7
const HOP_SHARE := 0.5


static func display_name(id: StringName) -> String:
	return TranslationServer.translate(INFO[id]["name"]) if INFO.has(id) else ""


static func description(id: StringName) -> String:
	return TranslationServer.translate(INFO[id]["text"]) if INFO.has(id) else ""


## Ziel nach Verhalten, null = Standard (nächster oder schwächster Gegner, Combatant._find_target).
static func pick_target(unit: Combatant) -> Combatant:
	if unit.has_order:
		return null
	match unit.behavior:
		&"guardian":
			unit.ward = _ward(unit)
			if unit.ward != null:
				return _nearest_foe(unit, unit.ward.position, GUARD_RANGE * 0.75)
		&"flanker":
			var best: Combatant = null
			var best_dist := FLANK_RANGE * FLANK_RANGE
			for foe in unit.foes():
				if foe.attack_style == &"melee":
					continue
				var dist := unit.position.distance_squared_to(foe.position)
				if dist < best_dist:
					best_dist = dist
					best = foe
			return best
		&"assassin":
			var weakest: Combatant = null
			for foe in unit.foes():
				if unit.position.distance_squared_to(foe.position) <= ASSASSIN_RANGE * ASSASSIN_RANGE \
						and (weakest == null or foe.health < weakest.health):
					weakest = foe
			return weakest
		&"artillery":
			return _cluster_target(unit)
	return null


## Bewegung nach Verhalten. true: Die Einheit ist schon versorgt (nicht normal heranlaufen).
## `distance`: Abstand zum Ziel.
static func steer(unit: Combatant, delta: float, target: Combatant, distance: float) -> bool:
	if unit.has_order:
		return false
	match unit.behavior:
		&"charger":
			if unit.behavior_left > 0.0:
				unit.behavior_left -= delta
				unit.move_towards(unit.position + (unit.position - target.position).normalized() * 30.0, delta, 1.2)
				return true
		&"skirmisher", &"artillery":
			var keep := unit.attack_range * (KITE_SHARE if unit.behavior == &"skirmisher" else 0.6)
			if distance < keep and unit.attack_range > Combatant.RANGED_MIN:
				var away := (unit.position - target.position).normalized()
				if away == Vector2.ZERO:
					away = Vector2.LEFT
				unit.move_towards(unit.position + away * 30.0, delta, 0.9 if unit.behavior == &"skirmisher" else 0.5)
				unit.try_attack(target, distance)
				return true
		&"guardian":
			if is_instance_valid(unit.ward) and unit.ward.is_alive() and distance > unit.attack_range * 1.5 \
					and unit.position.distance_to(unit.ward.position) > GUARD_LEASH:
				unit.move_towards(unit.ward.position, delta)
				return true
		&"flanker":
			if distance > unit.attack_range + 20.0:
				# Bogen statt gerader Linie: seitlich versetzter Zielpunkt
				var dir := (target.position - unit.position).normalized()
				var side := dir.orthogonal() * (1.0 if unit.get_instance_id() % 2 == 0 else -1.0)
				unit.move_towards(target.position + side * minf(30.0, distance * 0.4), delta)
				return true
	return false


static func after_attack(unit: Combatant) -> void:
	if unit.behavior == &"charger" and unit.attack_range <= Combatant.RANGED_MIN:
		unit.behavior_left = CHARGER_RETREAT


## Tempofaktor für das Laufen: Hüpfer springen (schnell) und landen (Pause).
static func speed_factor(unit: Combatant) -> float:
	if unit.behavior != &"hopper":
		return 1.0
	return 2.2 if fmod(unit.hop_clock, HOP_CYCLE) < HOP_CYCLE * HOP_SHARE else 0.0


## Höhe des Sprungs (für die Darstellung), 0 = am Boden.
static func hop_height(unit: Combatant) -> float:
	if unit.behavior != &"hopper" or not unit.is_walking():
		return 0.0
	var t := fmod(unit.hop_clock, HOP_CYCLE) / (HOP_CYCLE * HOP_SHARE)
	return sin(t * PI) * 6.0 if t < 1.0 else 0.0


## Schweber gleiten über Hindernisse: nur der Boden begrenzt sie.
static func ignores_obstacles(unit: Combatant) -> bool:
	return unit.behavior == &"floater"


## Verbündeter Fernkämpfer oder Heiler in der Nähe, den ein Wächter beschützt.
static func _ward(unit: Combatant) -> Combatant:
	var best: Combatant = null
	var best_dist := GUARD_RANGE * GUARD_RANGE
	for ally in unit.allies():
		if ally == unit or ally.attack_style == &"melee" or ally.summoned:
			continue
		var dist := unit.position.distance_squared_to(ally.position)
		if dist < best_dist:
			best_dist = dist
			best = ally
	return best


static func _nearest_foe(unit: Combatant, point: Vector2, radius: float) -> Combatant:
	var best: Combatant = null
	var best_dist := radius * radius
	for foe in unit.foes():
		var dist := point.distance_squared_to(foe.position)
		if dist < best_dist:
			best_dist = dist
			best = foe
	return best


## Unter den nächsten Gegnern in Reichweite der mit den meisten Nachbarn (lohnt Flächenschaden).
static func _cluster_target(unit: Combatant) -> Combatant:
	var reach := unit.attack_range + 30.0
	var near: Array[Combatant] = []
	for foe in unit.foes():
		if unit.position.distance_squared_to(foe.position) <= reach * reach:
			near.append(foe)
	if near.size() <= 1:
		return near[0] if near.size() == 1 else null
	near.sort_custom(func(a: Combatant, b: Combatant) -> bool:
		return unit.position.distance_squared_to(a.position) < unit.position.distance_squared_to(b.position))
	near = near.slice(0, CLUSTER_CANDIDATES)
	var best: Combatant = near[0]
	var best_count := -1
	for foe in near:
		var count := 0
		for other in near:
			if other != foe and foe.position.distance_squared_to(other.position) <= CLUSTER_RADIUS * CLUSTER_RADIUS:
				count += 1
		if count > best_count:
			best_count = count
			best = foe
	return best
