class_name AbilityCasts
extends RefCounted
## Wirkung der aktiven Fähigkeiten (Namen, Texte und Abklingzeiten in Abilities). Combatant ruft cast()
## aus cast_now() und cast_veteran() auf, die Abklingzeit setzt der Combatant selbst.


## Aktive Fähigkeit `id` auslösen, wenn ihre Bedingung erfüllt ist. Gibt zurück, ob sie ausgelöst wurde.
static func cast(caster: Combatant, id: StringName) -> bool:
	var power := caster.ability_power
	var enemy_target := caster._target if is_instance_valid(caster._target) and caster._target._alive and caster._target.team != caster.team else null
	match id:
		&"shield":
			if caster._opponents_near(caster.position, 45.0).is_empty():
				return false
			caster.apply_effect(&"shield", 2.0 + 0.4 * power, 0.2)
			caster._spawn_effect(&"ring", caster.position + Vector2(0, -caster.body_size / 2.0), caster.body_size, Color("#8fe0ff"))
			Sound.play(&"hit")
		&"taunt":
			var foes := caster._opponents_near(caster.position, 60.0)
			if foes.is_empty():
				return false
			for foe in foes:
				foe.force_target(caster, 2.5 + 0.3 * power)
			caster._spawn_effect(&"ring", caster.position, 60.0, Color("#ff9a3c"))
			Sound.play(&"swing")
		&"sprint":
			if enemy_target == null or caster.position.distance_to(enemy_target.position) < maxf(caster.attack_range * 1.5, 50.0):
				return false
			caster.apply_effect(&"sprint", 2.0 + 0.3 * power, Combatant.SPRINT_FACTOR)
			Sound.play(&"swing")
		&"war_cry":
			if caster._opponents_near(caster.position, 110.0).is_empty():
				return false
			for ally in caster._allies_near(caster.position, 80.0):
				ally.apply_effect(&"buff", 5.0, 1.0 + minf(0.8, 0.15 + 0.1 * power))
			caster._spawn_effect(&"ring", caster.position, 80.0, Color("#ff5a4a"))
			Sound.play(&"swing")
		&"mass_heal":
			var hurt := false
			var allies := caster._allies_near(caster.position, 90.0)
			for ally in allies:
				hurt = hurt or ally.health < ally.max_health * 0.85
			if not hurt:
				return false
			for ally in allies:
				ally.heal(caster.attack * 1.8 * power + ally.max_health * 0.04, caster)
			caster._spawn_effect(&"ring", caster.position, 90.0, Color("#6dff8a"))
			Sound.play(&"heal")
		&"revive":
			var arena := caster.get_tree().get_first_node_in_group(&"arena")
			if arena == null or not arena.has_method("revive_fallen") or not arena.revive_fallen(caster):
				return false
			Sound.play(&"merge", 0.0)
		&"frost_nova":
			var foes := caster._opponents_near(caster.position, 55.0)
			if foes.is_empty():
				return false
			for foe in foes:
				foe.take_damage(caster.attack * 0.6 * power * caster.damage_mult(), caster)
				foe.apply_effect(&"slow", 3.0, 0.5)
			caster._spawn_effect(&"burst", caster.position + Vector2(0, -caster.body_size / 2.0), 55.0, Color("#8fe0ff"))
			Sound.play(&"fireball")
		&"arrow_rain", &"meteor":
			if enemy_target == null or caster.position.distance_to(enemy_target.position) > maxf(caster.attack_range, 60.0):
				return false
			var rain := id == &"arrow_rain"
			var radius := 30.0 if rain else 34.0
			for foe in caster._opponents_near(enemy_target.position, radius):
				foe.take_damage(caster.attack * (1.4 if rain else 2.2) * power * caster.damage_mult(), caster)
			caster._spawn_effect(&"rain" if rain else &"burst", enemy_target.position, radius,
					Color("#ffe27a") if rain else Color("#ff8a1f"))
			Sound.play(&"arrow" if rain else &"explode")
		&"chain_lightning":
			if enemy_target == null or caster.position.distance_to(enemy_target.position) > maxf(caster.attack_range, 60.0):
				return false
			var hit: Array[Combatant] = []
			var current := enemy_target
			var from := caster.center()
			var damage := caster.attack * 1.3 * power * caster.damage_mult()
			for jump in 3 + roundi(power):
				hit.append(current)
				caster._spawn_bolt(from, current.center())
				from = current.center()
				var next: Combatant = null
				var best := 60.0 * 60.0
				for foe in caster._opponents_near(current.position, 60.0):
					var dist := foe.position.distance_squared_to(current.position)
					if not hit.has(foe) and dist < best:
						best = dist
						next = foe
				current.take_damage(damage, caster)
				damage *= 0.8
				if next == null:
					break
				current = next
			Sound.play(&"fireball")
		&"petrify", &"charm":
			var stone := id == &"petrify"
			var foes := caster._opponents_near(caster.position, 70.0)
			if foes.is_empty():
				return false
			foes.sort_custom(func(a: Combatant, b: Combatant) -> bool:
				return a.position.distance_squared_to(caster.position) < b.position.distance_squared_to(caster.position))
			for foe in foes.slice(0, 2 + roundi(power) if stone else 6):
				# Wert 1 = versteinert (grau), 2 = betört (rosa), siehe _update_effects
				foe.apply_effect(&"stun", (1.4 if stone else 1.8) + 0.25 * power, 1.0 if stone else 2.0)
			caster._spawn_effect(&"ring", caster.position, 70.0, Color("#b8b8b0") if stone else Color("#ff8ad8"))
			Sound.play(&"hit" if stone else &"heal")
		&"whirlwind":
			var foes := caster._opponents_near(caster.position, 34.0)
			if foes.size() < 2:
				return false
			for foe in foes:
				foe.take_damage(caster.attack * 1.1 * power * caster.damage_mult(), caster)
			caster._swing_dir = Vector2.RIGHT
			caster._swing_left = Combatant.SWING_SECONDS
			caster._spawn_effect(&"ring", caster.position + Vector2(0, -caster.body_size / 2.0), 34.0, Color("#eef3ff"))
			Sound.play(&"swing")
		&"charge":
			if enemy_target == null:
				return false
			var dist := caster.position.distance_to(enemy_target.position)
			if dist < maxf(caster.attack_range + 25.0, 45.0) or dist > 170.0:
				return false
			caster.apply_effect(&"charge", 3.0, 3.0)
			caster._spawn_effect(&"puff", caster.position, randf() * TAU, Color(0.85, 0.75, 0.6))
			Sound.play(&"swing")
		&"summon":
			if caster._opponents_near(caster.position, 160.0).is_empty() or caster.get_parent() == null:
				return false
			for i in 1 + int(power >= 2.0):
				summon(caster)
			caster._spawn_effect(&"burst", caster.position, 30.0, Color("#b07aff"))
			Sound.play(&"merge", 0.0)
		&"blink":
			var threats := caster._opponents_near(caster.position, 28.0)
			var spot := Vector2.ZERO
			if caster.attack_style == &"melee":
				if enemy_target == null or caster.position.distance_to(enemy_target.position) < 45.0:
					return false
				var side := (enemy_target.position - caster.position).normalized()
				spot = enemy_target.position + side * 12.0
			else:
				if threats.is_empty():
					return false
				var away := (caster.position - threats[0].position).normalized()
				spot = caster.position + (away if away != Vector2.ZERO else Vector2.LEFT) * 70.0
			caster._spawn_effect(&"puff", caster.position + Vector2(0, -caster.body_size * 0.3), 0.0, Color("#4a2a6a"))
			caster.position = World.clamp_point(spot)
			caster._velocity = Vector2.ZERO
			caster._spawn_effect(&"puff", caster.position + Vector2(0, -caster.body_size * 0.3), 1.0, Color("#4a2a6a"))
			Sound.play(&"swing")
		&"poison_cloud":
			if enemy_target == null or caster.position.distance_to(enemy_target.position) > maxf(caster.attack_range, 60.0):
				return false
			for foe in caster._opponents_near(enemy_target.position, 36.0):
				foe.poison(caster.attack * 0.35 * power, 4.0, caster)
			caster._spawn_effect(&"burst", enemy_target.position, 36.0, Color("#7adf3a"))
			Sound.play(&"fireball")
		&"earthquake":
			var foes := caster._opponents_near(caster.position, 65.0)
			if foes.is_empty():
				return false
			for foe in foes:
				foe.take_damage(caster.attack * 0.8 * power * caster.damage_mult(), caster)
				foe.apply_effect(&"stun", 0.8 + 0.15 * power, 1.0)
			caster._spawn_effect(&"burst", caster.position, 65.0, Color("#a8743a"))
			Sound.play(&"explode")
		&"holy_light":
			var allies := caster._allies_near(caster.position, 75.0)
			var foes := caster._opponents_near(caster.position, 75.0)
			var hurt := false
			for ally in allies:
				hurt = hurt or ally.health < ally.max_health * 0.85
			if not hurt and foes.is_empty():
				return false
			for ally in allies:
				ally.heal(caster.attack * 1.2 * power + ally.max_health * 0.03, caster)
			for foe in foes:
				foe.take_damage(caster.attack * 1.0 * power, caster)
			caster._spawn_effect(&"burst", caster.position, 75.0, Color("#fff3a0"))
			Sound.play(&"heal")
		&"fire_breath":
			if enemy_target == null or caster.position.distance_to(enemy_target.position) > maxf(caster.attack_range, 70.0):
				return false
			var aim := (enemy_target.position - caster.position).normalized()
			for foe in caster._opponents_near(caster.position, 80.0):
				var offset := foe.position - caster.position
				if offset.length() < 6.0 or aim.angle_to(offset) < 0.6 and aim.angle_to(offset) > -0.6:
					foe.take_damage(caster.attack * 1.3 * power * caster.damage_mult(), caster)
					foe.poison(caster.attack * 0.2 * power, 3.0, caster)
			caster._spawn_effect(&"cone", caster.position + Vector2(0, -caster.body_size / 2.0), 80.0, Color("#ff7a1f"), "", aim)
			Sound.play(&"explode")
		&"hex":
			var strongest: Combatant = null
			for foe in caster._opponents_near(caster.position, maxf(caster.attack_range, 80.0)):
				if not foe.has_effect(&"weak") and (strongest == null or foe.attack > strongest.attack):
					strongest = foe
			if strongest == null:
				return false
			strongest.apply_effect(&"weak", 4.0 + 0.5 * power, 0.5)
			strongest.apply_effect(&"slow", 4.0 + 0.5 * power, 0.6)
			caster._spawn_effect(&"ring", strongest.position + Vector2(0, -strongest.body_size / 2.0), 16.0, Color("#b07aff"))
			Sound.play(&"heal")
		&"tidal_wave":
			var foes := caster._opponents_near(caster.position, 60.0)
			if foes.is_empty():
				return false
			for foe in foes:
				foe.take_damage(caster.attack * 0.8 * power * caster.damage_mult(), caster)
				var push := (foe.position - caster.position).normalized()
				foe.position = World.clamp_point(foe.position + (push if push != Vector2.ZERO else Vector2.RIGHT) * 40.0)
			caster._spawn_effect(&"ring", caster.position, 60.0, Color("#4fa8ff"))
			caster._spawn_effect(&"burst", caster.position, 45.0, Color("#4fa8ff"))
			Sound.play(&"fireball")
		&"divine_shield":
			var ward: Combatant = null
			for ally in caster._allies_near(caster.position, 85.0):
				if ally.health < ally.max_health * 0.35 and (ward == null or ally.health < ward.health):
					ward = ally
			if ward == null:
				return false
			ward.apply_effect(&"shield", 2.0 + 0.3 * power, 0.0)
			caster._spawn_effect(&"ring", ward.position + Vector2(0, -ward.body_size / 2.0), ward.body_size, Color("#ffd91f"))
			Sound.play(&"heal")
		&"berserk":
			if caster.health > caster.max_health * 0.5 or caster._opponents_near(caster.position, maxf(caster.attack_range + 20.0, 50.0)).is_empty():
				return false
			caster.apply_effect(&"buff", 5.0, 1.0 + minf(0.9, 0.3 + 0.1 * power))
			caster.apply_effect(&"haste", 5.0, 1.6)
			caster._spawn_effect(&"ring", caster.position + Vector2(0, -caster.body_size / 2.0), caster.body_size, Color("#ff3a2a"))
			Sound.play(&"swing")
		_:
			return false
	return true


## Beschworener Helfer neben der Einheit, verschwindet nach SUMMON_SECONDS.
static func summon(caster: Combatant) -> Combatant:
	var unit_id := Combatant.SUMMON_DEFAULT
	for prefix: String in Combatant.SUMMON_UNITS:
		if caster.unit_data != null and String(caster.unit_data.id).begins_with(prefix):
			unit_id = Combatant.SUMMON_UNITS[prefix]
	var minion := Combatant.new()
	minion.setup_player(Registry.units[unit_id])
	minion.summoned = true
	minion.summoner = caster
	minion._summon_left = Combatant.SUMMON_SECONDS + caster.ability_power
	minion.max_health *= 0.6 + 0.2 * caster.ability_power
	minion.health = minion.max_health
	minion.attack *= 0.6 + 0.2 * caster.ability_power
	minion.modulate = Color(0.85, 0.75, 1.0)
	minion.position = World.clamp_point(caster.position + Vector2(randf_range(-16, 16), randf_range(6, 14)))
	minion.home_position = minion.position
	caster.get_parent().add_child(minion)
	return minion
