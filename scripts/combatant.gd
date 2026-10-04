class_name Combatant
extends Node2D
## Einheit oder Gegner. Kämpft in der Kampfphase automatisch.
## Eigene Einheiten können einen Positionsbefehl bekommen: Sie laufen dorthin und
## halten die Stellung (greifen nur an, was in Reichweite kommt), bis der Befehl endet.

enum Team { PLAYER, ENEMY }

signal died(combatant: Combatant)

const GROUP_PLAYER := &"player"
const GROUP_ENEMY := &"enemy"
const ARRIVE_DISTANCE := 2.0
const SEPARATION_SPEED := 50.0
const RETARGET_INTERVAL := 0.4
const SWING_SECONDS := 0.25
const SWING_ARC := 1.3
## Richtungswechsel: Mindestabstand in x, Drehgeschwindigkeit (Sprite-Spiegelung pro Sekunde)
## und wie schnell die Laufrichtung der Zielrichtung folgt (mal Bewegungstempo pro Sekunde).
const FACE_DEADZONE := 5.0
const FLIP_SPEED := 9.0
const TURN_ACCELERATION := 8.0
const WALK_STEP_RATE := 0.35
const WALK_BOB := 2.0
const WALK_TILT := 0.08
## Intelligenz in Prozent = Chance, gezielt den schwächsten Gegner in der Nähe zu wählen.
const MAX_SMART_CHANCE := 90.0
const SMART_RADIUS := 60.0
## Heiler ohne Patient bleiben so nah bei ihren Verbündeten.
const HEALER_FOLLOW_DISTANCE := 40.0
## Schützen: Gegner in diesem Umkreis um den Schützling werden bekämpft, man entfernt sich nie weiter
## als die Leine von ihm, und ohne Gegner bleibt man in Folgeabstand.
const GUARD_ENGAGE := 70.0
const GUARD_LEASH := 90.0
const GUARD_FOLLOW_DISTANCE := 26.0
## Fähigkeiten: Reichweite der Auren, Prüfabstand der Auren und Tempo-Faktor beim Sprint.
const AURA_RADIUS := 60.0
const AURA_INTERVAL := 0.3
const SPRINT_FACTOR := 1.8
## Wuseln: Wer nichts zu tun hat, streift in der Nähe herum bzw. hüpft in der Bauphase vor Langeweile.
const WANDER_RADIUS := 34.0
const WANDER_SPEED_FACTOR := 0.45
const IDLE_HOP_SECONDS := 0.35
const IDLE_HOP_HEIGHT := 4.0
## Ab dieser Reichweite gilt eine Figur als Fernkämpfer (Modifikator Nebel).
const RANGED_MIN := 30.0

var team: Team = Team.PLAYER
var unit_data: UnitData
var display_name := ""
var sprite: Texture2D
var color := Color.WHITE
var level := 1
var body_size := 12.0
var max_health := 1.0
var health := 1.0
var attack := 1.0
var intelligence := 0.0
var attack_range := 12.0
var attack_cooldown := 1.0
var move_speed := 30.0
var gold_reward := 0
var is_boss := false
## Position vor der Kampfphase, wird danach wiederhergestellt.
var home_position := Vector2.ZERO
var has_order := false
var order_position := Vector2.ZERO
## Schützling: Die Einheit weicht ihm nicht von der Seite und greift an, was ihn bedroht.
var guard_target: Combatant
## Fähigkeit (siehe Abilities) und ihre Stärke; aktive lösen von selbst aus.
var ability: StringName = &""
var ability_power := 1.0
var ability_casts := 0
var _ability_cd := 0.0
var _aura_left := 0.0
## Wirkungen auf diese Einheit: Name -> [Restzeit, Wert]. Namen: shield, sprint, slow, buff.
var _effects: Dictionary = {}
var _forced_target: Combatant
var _forced_left := 0.0
var highlighted := false:
	set(value):
		highlighted = value
		queue_redraw()

var _target: Combatant
var _retarget_left := 0.0
var _cooldown_left := 0.0
var attack_style: StringName = &"melee"
var _swing_dir := Vector2.RIGHT
var _swing_left := 0.0
var _alive := true
## Die Sprites sind nach rechts gezeichnet. Gegner starten nach links blickend.
var _facing_left := false
## 1 = nach rechts, -1 = nach links, dazwischen dreht sich die Figur gerade.
var _flip := 1.0
var _velocity := Vector2.ZERO
var _walking := false
var _walk_phase := 0.0
## Jeder läuft ein wenig anders schnell, damit Gruppen nicht im Gleichschritt marschieren.
var _speed_jitter := randf_range(0.88, 1.15)
var _wander_point := Vector2.ZERO
var _wander_wait := 0.0
var _hop_t := -1.0
var _idle_left := randf_range(0.5, 4.0)


func setup_player(data: UnitData) -> void:
	team = Team.PLAYER
	unit_data = data
	display_name = data.display_name
	sprite = data.sprite
	color = data.color
	level = data.level
	body_size = _sprite_height(10.0 + 2.0 * data.level)
	max_health = data.max_health
	attack = data.attack
	intelligence = data.intelligence
	attack_range = data.attack_range
	attack_style = data.attack_style
	attack_cooldown = data.attack_cooldown
	move_speed = data.move_speed
	ability = data.ability
	ability_power = Abilities.power(data.level, data.category == "Kombination")
	_ability_cd = randf_range(2.0, 5.0)
	max_health *= Game.blessing(style_group(), "hp")
	attack *= Game.blessing(style_group(), "atk")
	health = max_health
	add_to_group(GROUP_PLAYER)


## Gruppe für Segen: Nahkämpfer, Fernkämpfer (Pfeil oder Magie) oder Heiler.
func style_group() -> StringName:
	match attack_style:
		&"melee": return &"melee"
		&"heal": return &"heal"
	return &"ranged"


## Segen neu anwenden (nach einem Ereignis), der Lebensanteil bleibt erhalten.
func refresh_blessings() -> void:
	if unit_data == null:
		return
	var share := health / maxf(max_health, 0.001)
	max_health = unit_data.max_health * Game.blessing(style_group(), "hp")
	attack = unit_data.attack * Game.blessing(style_group(), "atk")
	health = max_health * share
	queue_redraw()


func setup_enemy(data: EnemyData) -> void:
	team = Team.ENEMY
	display_name = data.display_name
	sprite = data.sprite
	color = data.color
	body_size = _sprite_height(data.body_size)
	max_health = data.max_health * Game.health_scale()
	attack = data.attack * Game.damage_scale()
	intelligence = data.intelligence
	attack_range = data.attack_range
	attack_style = data.attack_style
	attack_cooldown = data.attack_cooldown
	move_speed = data.move_speed
	gold_reward = roundi(data.gold_reward * Game.gold_scale() * Game.round_gold_mult())
	is_boss = data.is_boss
	if not is_boss:  # Sonderregel der Runde (Bosse bleiben, wie sie sind)
		max_health *= Modifiers.value("enemy_hp")
		attack *= Modifiers.value("enemy_damage")
		move_speed *= Modifiers.value("enemy_speed") * Modifiers.value("all_speed")
		gold_reward = maxi(1, roundi(gold_reward * Modifiers.value("gold")))
		if attack_range > RANGED_MIN:
			attack_range *= Modifiers.value("ranged_range")
		scale = Vector2.ONE * Modifiers.value("enemy_scale")
	health = max_health
	_facing_left = true
	_flip = -1.0
	add_to_group(GROUP_ENEMY)


func _sprite_height(fallback: float) -> float:
	return float(sprite.get_height()) if sprite != null else fallback


func _face(point_x: float) -> void:
	var left := point_x < position.x
	if absf(point_x - position.x) > FACE_DEADZONE and left != _facing_left:
		_facing_left = left


func center() -> Vector2:
	return position + Vector2(0, -body_size / 2.0)


func give_order(point: Vector2) -> void:
	has_order = true
	order_position = point
	guard_target = null


## Position halten: an Ort und Stelle bleiben, nur angreifen, was in Reichweite kommt.
func hold_position() -> void:
	give_order(position)


func guard(other: Combatant) -> void:
	has_order = false
	guard_target = other


func clear_order() -> void:
	has_order = false
	guard_target = null


func is_guarding() -> bool:
	return guard_target != null and is_instance_valid(guard_target) and guard_target._alive


## &"free" (Freikampf), &"hold" (Position halten) oder &"guard" (Schützen).
func order_mode() -> StringName:
	if is_guarding():
		return &"guard"
	return &"hold" if has_order else &"free"


func order_text() -> String:
	match order_mode():
		&"hold":
			return tr("  [Halten]")
		&"guard":
			return tr("  [Schützt %s]") % guard_target.display_name
	return ""


## Nach der Runde: volle Lebenspunkte und alle Kampf-Animationen zurücksetzen, sonst bliebe
## z.B. eine halbe Drehung (schmales Sprite) oder ein Schwertschwung stehen.
func reset_after_battle() -> void:
	_hop_t = -1.0
	_wander_point = Vector2.ZERO
	_wander_wait = 0.0
	health = max_health
	clear_order()
	_target = null
	_velocity = Vector2.ZERO
	_walking = false
	_walk_phase = 0.0
	_swing_left = 0.0
	_effects.clear()
	_forced_target = null
	_ability_cd = randf_range(2.0, 5.0)
	modulate = Color.WHITE
	_flip = -1.0 if _facing_left else 1.0
	if unit_data != null:  # Sonderregel der Runde zurücknehmen
		attack_range = unit_data.attack_range
		move_speed = unit_data.move_speed
	queue_redraw()


## Kampfbeginn: Sonderregel der Runde auf die eigene Einheit anwenden (reset_after_battle nimmt sie zurück).
func apply_round_modifier() -> void:
	if unit_data == null:
		return
	attack_range = unit_data.attack_range
	if attack_range > RANGED_MIN:
		attack_range *= Modifiers.value("ranged_range")
	move_speed = unit_data.move_speed * Modifiers.value("all_speed")


## Fläche, auf der die Figur angetippt werden kann (gezeichnetes Sprite plus Rand), in Elternkoordinaten.
func hit_rect(margin := 4.0) -> Rect2:
	var size := sprite.get_size() if sprite != null else Vector2(body_size, body_size)
	return Rect2(position + Vector2(-size.x / 2.0, -size.y), size).grow(margin)


func take_damage(amount: float, source: Combatant = null) -> void:
	if not _alive:
		return
	if ability == &"evasion" and randf() < minf(0.5, 0.08 * ability_power):
		return
	if ability == &"armor":
		amount *= 1.0 - minf(0.5, 0.1 * ability_power)
	if has_effect(&"shield"):
		amount *= effect_value(&"shield")
	if source != null and is_instance_valid(source) and source.ability == &"lifesteal":
		source.heal(amount * minf(0.6, 0.15 * source.ability_power))
	health -= amount
	queue_redraw()
	if amount > 0.0 and Effect.can_spawn_ambient():
		_spawn_effect(&"spark", center(), randf() * TAU, Color(1.0, 0.95, 0.7))
	if health <= 0.0 and _alive:
		if Effect.can_spawn_ambient():
			_spawn_effect(&"puff", position + Vector2(0, -body_size * 0.3), randf() * TAU, Color(0.8, 0.75, 0.7) if team == Team.ENEMY else Color(0.9, 0.85, 1.0))
		Sound.play(&"death")
		_alive = false
		_leave_group()
		died.emit(self)
		queue_free()


## Entfernt die Einheit sofort aus allen Zählungen (z.B. beim Verbinden).
func discard() -> void:
	_alive = false
	_leave_group()
	queue_free()


func _leave_group() -> void:
	remove_from_group(GROUP_PLAYER if team == Team.PLAYER else GROUP_ENEMY)


## Bauphase: Eigene Einheiten hüpfen ab und zu und schauen mal in die andere Richtung.
func _process(delta: float) -> void:
	if Game.phase != Game.Phase.BUILD or team != Team.PLAYER or highlighted:
		if _hop_t >= 0.0:
			_hop_t = -1.0
			queue_redraw()
		return
	if _hop_t >= 0.0:
		_hop_t += delta / IDLE_HOP_SECONDS
		if _hop_t >= 1.0:
			_hop_t = -1.0
		queue_redraw()
	else:
		_idle_left -= delta
		if _idle_left <= 0.0:
			_hop_t = 0.0
			_idle_left = randf_range(1.5, 5.0)
			if randf() < 0.35:
				_facing_left = not _facing_left
	var target := -1.0 if _facing_left else 1.0
	if not is_equal_approx(_flip, target):
		_flip = move_toward(_flip, target, FLIP_SPEED * delta)
		queue_redraw()


func _physics_process(frame_delta: float) -> void:
	if Game.phase != Game.Phase.BATTLE or not _alive:
		return
	var delta := Game.battle_delta(frame_delta)
	_cooldown_left -= delta
	_update_effects(delta)
	_update_ability(delta)
	if _swing_left > 0.0:
		_swing_left -= delta
		queue_redraw()
	_walking = false

	if guard_target != null and not is_guarding():
		guard_target = null  # Schützling ist gefallen: zurück in den Freikampf
	if has_order and position.distance_to(order_position) > ARRIVE_DISTANCE:
		_move_towards(order_position, delta)
	elif is_guarding():
		_guard(delta)
	else:
		_fight(delta)
	position = World.clamp_point(position + _separation() * delta)
	_animate(delta)


func _fight(delta: float) -> void:
	if is_instance_valid(_forced_target) and _forced_target._alive and _forced_left > 0.0:
		_target = _forced_target
		_retarget_left = RETARGET_INTERVAL
	if attack_style == &"heal":
		_heal_allies(delta)
		return
	_retarget_left -= delta
	if not is_instance_valid(_target) or not _target._alive or _retarget_left <= 0.0:
		_target = _find_target()
		_retarget_left = RETARGET_INTERVAL
	if _target == null:
		if team == Team.PLAYER and not has_order:
			_wander(delta)
		return
	var distance := position.distance_to(_target.position)
	_face(_target.position.x)
	if distance > attack_range:
		# Mit Befehl wird die Stellung gehalten, nur im Automatikmodus wird verfolgt.
		if not has_order:
			_move_towards(_target.position, delta)
	elif _cooldown_left <= 0.0:
		_cooldown_left = attack_cooldown
		_attack_target()


func _attack_target() -> void:
	if attack_style == &"melee":
		_swing_dir = (_target.center() - center()).normalized()
		_swing_left = SWING_SECONDS
		queue_redraw()
		_target.take_damage(attack * damage_mult(), self)
		Sound.play(&"swing")
		Sound.play(&"hit")
		return
	Sound.play(&"arrow" if attack_style == &"arrow" else &"fireball")
	var shot := Projectile.new()
	shot.setup(center(), _target, attack_style, color, attack * damage_mult(), self)
	get_parent().add_child(shot)


## Ohne Gegner in der Nähe der Heimatposition herumstreifen: kurz laufen, kurz verschnaufen.
func _wander(delta: float) -> void:
	if _wander_wait > 0.0:
		_wander_wait -= delta
		return
	if _wander_point == Vector2.ZERO or position.distance_to(_wander_point) < 3.0:
		_wander_point = World.clamp_point(home_position + Vector2(randf_range(-1.0, 1.0), randf_range(-1.0, 1.0)) * WANDER_RADIUS)
		_wander_wait = randf_range(0.2, 1.6)
		return
	_move_towards(_wander_point, delta, WANDER_SPEED_FACTOR)


## Schützen: Gegner in der Nähe des Schützlings bekämpfen, sonst an seiner Seite bleiben.
func _guard(delta: float) -> void:
	if attack_style == &"heal":
		_heal_allies(delta)
		return
	_retarget_left -= delta
	if not is_instance_valid(_target) or not _target._alive or _retarget_left <= 0.0:
		_target = _find_threat()
		_retarget_left = RETARGET_INTERVAL
	var anchor := guard_target.position
	if _target == null:
		if position.distance_to(anchor) > GUARD_FOLLOW_DISTANCE:
			_move_towards(anchor, delta)
		return
	_face(_target.position.x)
	if position.distance_to(_target.position) > attack_range:
		# Nicht weiter vom Schützling weglocken lassen, als die Leine reicht.
		_move_towards(anchor if position.distance_to(anchor) > GUARD_LEASH else _target.position, delta)
	elif _cooldown_left <= 0.0:
		_cooldown_left = attack_cooldown
		_attack_target()


## Der Gegner, der dem Schützling am nächsten ist (innerhalb von GUARD_ENGAGE).
func _find_threat() -> Combatant:
	var best: Combatant = null
	var best_dist := GUARD_ENGAGE * GUARD_ENGAGE
	for node in get_tree().get_nodes_in_group(GROUP_ENEMY if team == Team.PLAYER else GROUP_PLAYER):
		var dist := guard_target.position.distance_squared_to((node as Combatant).position)
		if dist <= best_dist:
			best_dist = dist
			best = node as Combatant
	return best


## Heiler: verletzten Verbündeten suchen, hinlaufen und heilen. Ohne Patient bei den Verbündeten bleiben.
func _heal_allies(delta: float) -> void:
	_retarget_left -= delta
	if not is_instance_valid(_target) or not _target._alive or _target.health >= _target.max_health \
			or _retarget_left <= 0.0:
		_target = _find_patient()
		_retarget_left = RETARGET_INTERVAL
	if _target == null:
		_follow_allies(delta)
		return
	_face(_target.position.x)
	if position.distance_to(_target.position) > attack_range:
		if not has_order:
			_move_towards(_target.position, delta)
	elif _cooldown_left <= 0.0:
		_cooldown_left = attack_cooldown
		Sound.play(&"heal")
		var spell := Projectile.new()
		spell.setup(center(), _target, &"heal", color, attack)
		get_parent().add_child(spell)


## Verletzter Verbündeter (auch man selbst): schlaue Heiler nehmen den mit dem kleinsten
## Lebensanteil, die anderen den nächsten.
func _find_patient() -> Combatant:
	if is_guarding() and guard_target.health < guard_target.max_health:
		return guard_target
	var group := GROUP_PLAYER if team == Team.PLAYER else GROUP_ENEMY
	var nearest: Combatant = null
	var nearest_dist := INF
	var neediest: Combatant = null
	var lowest := INF
	for node in get_tree().get_nodes_in_group(group):
		var other := node as Combatant
		if other.health >= other.max_health:
			continue
		var dist := position.distance_squared_to(other.position)
		if has_order and dist > attack_range * attack_range:
			continue
		if dist < nearest_dist:
			nearest_dist = dist
			nearest = other
		if other.health / other.max_health < lowest:
			lowest = other.health / other.max_health
			neediest = other
	if randf() * 100.0 < minf(intelligence, MAX_SMART_CHANCE):
		return neediest
	return nearest


func _follow_allies(delta: float) -> void:
	if has_order:
		return
	if is_guarding():
		if position.distance_to(guard_target.position) > GUARD_FOLLOW_DISTANCE:
			_move_towards(guard_target.position, delta)
		return
	var group := GROUP_PLAYER if team == Team.PLAYER else GROUP_ENEMY
	var nearest: Combatant = null
	var nearest_dist := INF
	for node in get_tree().get_nodes_in_group(group):
		var other := node as Combatant
		if other == self or other.attack_style == &"heal":
			continue
		var dist := position.distance_to(other.position)
		if dist < nearest_dist:
			nearest_dist = dist
			nearest = other
	if nearest != null and nearest_dist > HEALER_FOLLOW_DISTANCE:
		_move_towards(nearest.position, delta)


func heal(amount: float) -> void:
	health = minf(max_health, health + amount)
	queue_redraw()


## Boss wird wütend (Zeit abgelaufen): mehr Schaden und Tempo.
func enrage() -> void:
	attack *= 1.6
	move_speed *= 1.3
	attack_cooldown *= 0.8
	modulate = Color(1.0, 0.6, 0.55)


func is_alive() -> bool:
	return _alive


func _move_towards(point: Vector2, delta: float, speed_factor := 1.0) -> void:
	_face(point.x)
	# Die Laufrichtung folgt dem Ziel weich, damit ein neues Ziel keinen Ruck auslöst.
	var distance := position.distance_to(point)
	var speed := current_speed() * speed_factor
	var desired := (point - position).normalized() * minf(speed, distance / maxf(delta, 0.001))
	_velocity = _velocity.move_toward(desired, speed * TURN_ACCELERATION * delta)
	position = World.clamp_point(position + _velocity * delta)
	_walking = true


## Spiegelung und Laufwippen pro Physik-Schritt weiterführen.
func _animate(delta: float) -> void:
	if not _walking:
		_velocity = Vector2.ZERO
	var target := -1.0 if _facing_left else 1.0
	if not is_equal_approx(_flip, target):
		_flip = move_toward(_flip, target, FLIP_SPEED * delta)
		queue_redraw()
	if _walking:
		_walk_phase += delta * current_speed() * WALK_STEP_RATE
		queue_redraw()
	elif _walk_phase != 0.0:
		_walk_phase = 0.0
		queue_redraw()


# --- Fähigkeiten und Wirkungen -------------------------------------------------------

func has_effect(effect_name: StringName) -> bool:
	return _effects.has(effect_name)


func effect_value(effect_name: StringName) -> float:
	return _effects[effect_name][1] if _effects.has(effect_name) else 1.0


## Wirkung (re)starten. Länger gewinnt bei der Zeit, bei Verlangsamung der stärkere (kleinere) Wert,
## sonst der größere.
func apply_effect(effect_name: StringName, seconds: float, value := 1.0) -> void:
	if _effects.has(effect_name):
		var old: Array = _effects[effect_name]
		var better := minf(old[1], value) if effect_name in [&"slow", &"shield"] else maxf(old[1], value)
		_effects[effect_name] = [maxf(old[0], seconds), better]
	else:
		_effects[effect_name] = [seconds, value]
	queue_redraw()


## Gegner zwingen, kurz diese Einheit anzugreifen (Spott).
func force_target(unit: Combatant, seconds: float) -> void:
	_forced_target = unit
	_forced_left = seconds


func current_speed() -> float:
	return move_speed * _speed_jitter * effect_value(&"sprint") * effect_value(&"slow")


func damage_mult() -> float:
	return 1.0 + (effect_value(&"buff") - 1.0 if has_effect(&"buff") else 0.0)


func _update_effects(delta: float) -> void:
	var changed := false
	for effect_name: StringName in _effects.keys():
		_effects[effect_name][0] -= delta
		if _effects[effect_name][0] <= 0.0:
			_effects.erase(effect_name)
			changed = true
	if _forced_left > 0.0:
		_forced_left -= delta
	if ability == &"regen" and health < max_health:
		heal(max_health * 0.012 * ability_power * delta)
	if team == Team.PLAYER and health < max_health and Modifiers.value("regen") > 0.0:
		heal(max_health * Modifiers.value("regen") * delta)
	var tint := Color(1.0, 0.6, 0.55) if is_boss and Game.boss_enraged else Color.WHITE
	if has_effect(&"slow"):
		tint = Color(0.6, 0.8, 1.0)
	elif has_effect(&"buff"):
		tint = Color(1.0, 0.8, 0.7)
	if modulate != tint:
		modulate = tint
	if changed:
		queue_redraw()


func _opponents_near(point: Vector2, radius: float) -> Array[Combatant]:
	return _units_near(GROUP_ENEMY if team == Team.PLAYER else GROUP_PLAYER, point, radius)


## Verbündete im Umkreis, die Einheit selbst eingeschlossen.
func _allies_near(point: Vector2, radius: float) -> Array[Combatant]:
	return _units_near(GROUP_PLAYER if team == Team.PLAYER else GROUP_ENEMY, point, radius)


func _units_near(group: StringName, point: Vector2, radius: float) -> Array[Combatant]:
	var result: Array[Combatant] = []
	for node in get_tree().get_nodes_in_group(group):
		if (node as Combatant).position.distance_squared_to(point) <= radius * radius:
			result.append(node as Combatant)
	return result


func _update_ability(delta: float) -> void:
	if ability == &"":
		return
	if not Abilities.is_active(ability):
		_aura_left -= delta
		if _aura_left <= 0.0:
			_aura_left = AURA_INTERVAL
			_apply_aura()
		return
	_ability_cd -= delta
	if _ability_cd <= 0.0 and (Game.auto_abilities or team != Team.PLAYER):
		cast_now()


func ability_ready() -> bool:
	return Abilities.is_active(ability) and _ability_cd <= 0.0


## Sekunden bis die aktive Fähigkeit wieder bereit ist.
func ability_cooldown_left() -> float:
	return maxf(_ability_cd, 0.0)


## Aktive Fähigkeit jetzt auslösen (Automatik oder Knopf). false, wenn sie lädt oder ihre Bedingung
## (z.B. ein Gegner in der Nähe) nicht erfüllt ist.
func cast_now() -> bool:
	if not ability_ready() or not _cast_ability():
		return false
	_ability_cd = Abilities.cooldown(ability) * (Modifiers.value("ability_cd") if team == Team.PLAYER else 1.0)
	ability_casts += 1
	_spawn_effect(&"text", position + Vector2(0, -body_size - 10.0), 0.0, Color("#ffe27a"), Abilities.display_name(ability))
	return true


func _apply_aura() -> void:
	match ability:
		&"slow_aura":
			for foe in _opponents_near(position, AURA_RADIUS):
				foe.apply_effect(&"slow", AURA_INTERVAL + 0.3, 1.0 - minf(0.6, 0.25 + 0.07 * ability_power))
		&"war_aura":
			for ally in _allies_near(position, AURA_RADIUS):
				if ally != self:
					ally.apply_effect(&"buff", AURA_INTERVAL + 0.3, 1.0 + minf(0.6, 0.1 * ability_power))


## Aktive Fähigkeit auslösen, wenn ihre Bedingung erfüllt ist. Gibt zurück, ob sie ausgelöst wurde.
func _cast_ability() -> bool:
	var power := ability_power
	var enemy_target := _target if is_instance_valid(_target) and _target._alive and _target.team != team else null
	match ability:
		&"shield":
			if _opponents_near(position, 45.0).is_empty():
				return false
			apply_effect(&"shield", 2.0 + 0.4 * power, 0.2)
			_spawn_effect(&"ring", position + Vector2(0, -body_size / 2.0), body_size, Color("#8fe0ff"))
			Sound.play(&"hit")
		&"taunt":
			var foes := _opponents_near(position, 60.0)
			if foes.is_empty():
				return false
			for foe in foes:
				foe.force_target(self, 2.5 + 0.3 * power)
			_spawn_effect(&"ring", position, 60.0, Color("#ff9a3c"))
			Sound.play(&"swing")
		&"sprint":
			if enemy_target == null or position.distance_to(enemy_target.position) < maxf(attack_range * 1.5, 50.0):
				return false
			apply_effect(&"sprint", 2.0 + 0.3 * power, SPRINT_FACTOR)
			Sound.play(&"swing")
		&"war_cry":
			if _opponents_near(position, 110.0).is_empty():
				return false
			for ally in _allies_near(position, 80.0):
				ally.apply_effect(&"buff", 5.0, 1.0 + minf(0.8, 0.15 + 0.1 * power))
			_spawn_effect(&"ring", position, 80.0, Color("#ff5a4a"))
			Sound.play(&"swing")
		&"mass_heal":
			var hurt := false
			var allies := _allies_near(position, 90.0)
			for ally in allies:
				hurt = hurt or ally.health < ally.max_health * 0.85
			if not hurt:
				return false
			for ally in allies:
				ally.heal(attack * 1.8 * power + ally.max_health * 0.04)
			_spawn_effect(&"ring", position, 90.0, Color("#6dff8a"))
			Sound.play(&"heal")
		&"revive":
			var arena := get_tree().get_first_node_in_group(&"arena")
			if arena == null or not arena.has_method("revive_fallen") or not arena.revive_fallen(self):
				return false
			Sound.play(&"merge", 0.0)
		&"frost_nova":
			var foes := _opponents_near(position, 55.0)
			if foes.is_empty():
				return false
			for foe in foes:
				foe.take_damage(attack * 0.6 * power * damage_mult(), self)
				foe.apply_effect(&"slow", 3.0, 0.5)
			_spawn_effect(&"burst", position + Vector2(0, -body_size / 2.0), 55.0, Color("#8fe0ff"))
			Sound.play(&"fireball")
		&"arrow_rain", &"meteor":
			if enemy_target == null or position.distance_to(enemy_target.position) > maxf(attack_range, 60.0):
				return false
			var rain := ability == &"arrow_rain"
			var radius := 30.0 if rain else 34.0
			for foe in _opponents_near(enemy_target.position, radius):
				foe.take_damage(attack * (1.4 if rain else 2.2) * power * damage_mult(), self)
			_spawn_effect(&"rain" if rain else &"burst", enemy_target.position, radius,
					Color("#ffe27a") if rain else Color("#ff8a1f"))
			Sound.play(&"arrow" if rain else &"explode")
		_:
			return false
	return true


func _spawn_effect(kind: StringName, at: Vector2, radius: float, tint: Color, text := "") -> void:
	if get_parent() == null:
		return
	var effect := Effect.new()
	effect.setup(kind, at, radius, tint, text)
	get_parent().add_child(effect)


func _find_target() -> Combatant:
	var group := GROUP_ENEMY if team == Team.PLAYER else GROUP_PLAYER
	var candidates: Array[Combatant] = []
	var nearest: Combatant = null
	var nearest_dist := INF
	for node in get_tree().get_nodes_in_group(group):
		var other := node as Combatant
		var dist := position.distance_squared_to(other.position)
		if has_order and dist > attack_range * attack_range:
			continue
		candidates.append(other)
		if dist < nearest_dist:
			nearest_dist = dist
			nearest = other
	if nearest == null or randf() * 100.0 >= minf(intelligence, MAX_SMART_CHANCE):
		return nearest
	# Schlaue Einheiten: schwächster Gegner, der nicht viel weiter weg ist als der nächste.
	var limit := sqrt(nearest_dist) + SMART_RADIUS
	var weakest := nearest
	for other in candidates:
		if position.distance_to(other.position) <= limit and other.health < weakest.health:
			weakest = other
	return weakest


func _separation() -> Vector2:
	var push := Vector2.ZERO
	var group := GROUP_PLAYER if team == Team.PLAYER else GROUP_ENEMY
	var spacing := body_size * 0.5  # Abstand wie vor den größeren Sprites
	for node in get_tree().get_nodes_in_group(group):
		if node == self:
			continue
		var offset := position - (node as Combatant).position
		var dist := offset.length()
		if dist < spacing:
			push += offset / maxf(dist, 0.01) * (spacing - dist) / spacing * SEPARATION_SPEED
	return push


func _draw() -> void:
	var half := body_size / 2.0
	var rect := Rect2(-half, -body_size, body_size, body_size)
	var swing_t := 1.0 - _swing_left / SWING_SECONDS if _swing_left > 0.0 else 0.0
	var body_offset := Vector2.ZERO
	var tilt := 0.0
	if _swing_left > 0.0:  # kleiner Ausfallschritt zum Ziel
		body_offset = _swing_dir * sin(swing_t * PI) * 3.0
	if _hop_t >= 0.0:  # Leerlauf-Hüpfer in der Bauphase
		body_offset.y -= sin(_hop_t * PI) * IDLE_HOP_HEIGHT
	if _walk_phase != 0.0:  # Laufen: kleine Hüpfer und leichtes Wiegen
		body_offset.y -= absf(sin(_walk_phase)) * WALK_BOB
		tilt = sin(_walk_phase) * WALK_TILT
	# Spiegeln über die Skalierung: Eine negative Breite in draw_texture_rect würde zwar die
	# Textur umdrehen, aber die linke Kante behalten und das Sprite um seine Breite verschieben.
	draw_set_transform(body_offset, tilt, Vector2(_flip, 1.0))
	if sprite != null:
		var size := sprite.get_size()
		draw_texture_rect(sprite, Rect2(Vector2(-size.x / 2.0, -size.y), size), false)
	else:
		draw_rect(rect, color)
		var outline := Color(0.8, 0.15, 0.15) if team == Team.ENEMY else color.darkened(0.55)
		draw_rect(rect, outline, false, 1.0)
	draw_set_transform(Vector2.ZERO)
	if has_effect(&"shield"):
		draw_arc(Vector2(0, -body_size / 2.0), body_size * 0.62, 0.0, TAU, 20, Color(0.55, 0.9, 1.0, 0.85), 1.5)
	if has_effect(&"sprint"):
		for i in 3:
			draw_line(Vector2(-body_size * 0.5 * _flip - _flip * 2, -body_size * (0.3 + 0.2 * i)), Vector2(-body_size * 0.8 * _flip - _flip * 4, -body_size * (0.3 + 0.2 * i)), Color(1, 1, 1, 0.6), 1.0)
	if _swing_left > 0.0:
		_draw_sword_swing(swing_t)
	if highlighted:
		draw_rect(rect.grow(2.0), Color.WHITE, false, 1.0)
	if team == Team.PLAYER:
		for i in level:
			draw_rect(Rect2(-half + i * 3, -body_size - 4, 2, 2), Color.GOLD)
	if health < max_health:
		var width := maxf(body_size, 12.0)
		var top := -body_size - 8.0
		draw_rect(Rect2(-width / 2.0, top, width, 2), Color(0.2, 0.0, 0.0))
		draw_rect(Rect2(-width / 2.0, top, width * health / max_health, 2), Color(0.2, 0.9, 0.2))


## Schwert schwingt in einem Bogen vor der Einheit durch die Richtung zum Ziel.
func _draw_sword_swing(t: float) -> void:
	var pivot := Vector2(0, -body_size * 0.5) + _swing_dir * 4.0
	var base := _swing_dir.angle()
	var angle := base + lerpf(-SWING_ARC, SWING_ARC, t)
	var blade := 9.0 + body_size * 0.25
	draw_arc(pivot, blade, base - SWING_ARC, angle, 8, Color(1, 1, 1, 0.45 * (1.0 - t * 0.5)), 2.0)
	var dir := Vector2.from_angle(angle)
	draw_line(pivot, pivot + dir * blade, Color("#eef3ff"), 2.0)
	draw_line(pivot - dir * 1.5, pivot + dir * 2.0, Color("#ffd91f"), 2.0)
