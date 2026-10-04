extends Node
## Entwickler-Test: Kampfanimationen (Schwert, Pfeil, Feuerball) werden ausgelöst und treffen.
## Start: godot --headless res://scenes/dev/anim_test.tscn

var _failed := false


func _ready() -> void:
	var arena := Node2D.new()  # eigene Fläche, damit die Rundenlogik der Hauptszene nicht eingreift
	add_child(arena)
	await _check(arena, "knight", &"melee")
	await _check(arena, "archer", &"arrow")
	await _check(arena, "mage", &"magic")
	await _check_walk_and_turn(arena)
	await _check_healer(arena)
	await _check_guard(arena)
	await _check_abilities(arena)
	_check_audio()
	print("ANIM-TEST ", "FEHLER" if _failed else "OK")
	get_tree().quit(1 if _failed else 0)


func _check(arena: Node2D, unit_id: String, style: StringName) -> void:
	var attacker := Combatant.new()
	attacker.setup_player(Registry.units[unit_id])
	attacker.position = Vector2(300, 170)
	arena.add_child(attacker)
	var dummy := Combatant.new()
	dummy.setup_enemy(Registry.pick_enemy(1))
	dummy.max_health = 1000.0
	dummy.health = 1000.0
	dummy.attack = 0.0
	dummy.move_speed = 0.0
	dummy.position = Vector2(300 + minf(attacker.attack_range, 40.0), 170)
	arena.add_child(dummy)
	Game.phase = Game.Phase.BATTLE
	var saw_animation := false
	for i in 240:
		await get_tree().physics_frame
		if style == &"melee":
			saw_animation = saw_animation or attacker._swing_left > 0.0
		else:
			for child in arena.get_children():
				if child is Projectile:
					saw_animation = true
	var ok := attacker.attack_style == style and saw_animation and dummy.health < 1000.0
	print("%s %s: Stil=%s, Animation=%s, Schaden=%.1f" % [
		"ok:  " if ok else "FAIL:", unit_id, attacker.attack_style, saw_animation, 1000.0 - dummy.health])
	_failed = _failed or not ok
	attacker.discard()
	dummy.discard()
	Game.phase = Game.Phase.BUILD


func _player(arena: Node2D, id: String, at: Vector2) -> Combatant:
	var unit := Combatant.new()
	unit.setup_player(Registry.units[id])
	unit.position = at
	arena.add_child(unit)
	return unit


## Spielt `frames` Physik-Schritte und meldet, ob `seen` irgendwann wahr war.
func _watch(frames: int, seen: Callable) -> bool:
	var result := false
	for i in frames:
		await get_tree().physics_frame
		result = result or seen.call()
	return result


func _ability_result(id: StringName, ok: bool, unit: Combatant) -> void:
	print("%s Fähigkeit %s (%s): ausgelöst/wirksam=%s, Auslösungen=%d" % [
		"ok:  " if ok else "FAIL:", id, unit.display_name, ok, unit.ability_casts])
	_failed = _failed or not ok


## Jede Fähigkeit wird mit einer kleinen Szene geprüft, in der ihre Bedingung erfüllt ist.
func _check_abilities(arena: Node2D) -> void:
	Game.phase = Game.Phase.BATTLE
	var spots: Array[Combatant] = []

	var knight := _player(arena, "knight", Vector2(300, 170))
	var foe := _dummy(Vector2(325, 170))
	arena.add_child(foe)
	var ok: bool = await _watch(700, func() -> bool: return knight.ability_casts > 0 and knight.ability == &"shield")
	_ability_result(&"shield", ok, knight)
	knight.discard()
	foe.discard()

	var archer := _player(arena, "archer", Vector2(300, 170))
	var foe_a := _dummy(Vector2(350, 170))
	var foe_b := _dummy(Vector2(362, 175))
	arena.add_child(foe_a)
	arena.add_child(foe_b)
	ok = await _watch(700, func() -> bool: return archer.ability_casts > 0)
	ok = ok and foe_a.health < foe_a.max_health and foe_b.health < foe_b.max_health
	_ability_result(&"arrow_rain", ok, archer)
	for u in [archer, foe_a, foe_b]:
		u.discard()

	var flame := _player(arena, "flame", Vector2(300, 170))
	var foe_m := _dummy(Vector2(335, 170))
	arena.add_child(foe_m)
	ok = await _watch(900, func() -> bool: return flame.ability_casts > 0)
	_ability_result(&"meteor", ok, flame)
	flame.discard()
	foe_m.discard()

	var mage := _player(arena, "mage", Vector2(300, 170))
	var foe_f := _dummy(Vector2(330, 170))
	arena.add_child(foe_f)
	ok = await _watch(700, func() -> bool: return foe_f.has_effect(&"slow"))
	_ability_result(&"frost_nova", ok, mage)
	mage.discard()
	foe_f.discard()

	var horse := _player(arena, "horse", Vector2(30, 170))
	var foe_s := _dummy(Vector2(610, 170))
	arena.add_child(foe_s)
	ok = await _watch(700, func() -> bool: return horse.has_effect(&"sprint"))
	_ability_result(&"sprint", ok, horse)
	horse.discard()
	foe_s.discard()

	var healer := _player(arena, "healer", Vector2(300, 170))
	var hurt_a := _player(arena, "knight", Vector2(320, 170))
	var hurt_b := _player(arena, "knight", Vector2(330, 180))
	for u in [hurt_a, hurt_b]:
		u.health = 5.0
		u.attack = 0.0
		u.move_speed = 0.0
	ok = await _watch(700, func() -> bool: return healer.ability_casts > 0)
	_ability_result(&"mass_heal", ok, healer)
	for u in [healer, hurt_a, hurt_b]:
		u.discard()

	var troll := _player(arena, "troll", Vector2(300, 170))
	var foe_t := _dummy(Vector2(340, 170))
	arena.add_child(foe_t)
	ok = await _watch(700, func() -> bool: return foe_t._forced_target == troll)
	_ability_result(&"taunt", ok, troll)
	troll.discard()
	foe_t.discard()

	var wolf := _player(arena, "wolf", Vector2(300, 170))
	var friend := _player(arena, "knight", Vector2(320, 175))
	var foe_w := _dummy(Vector2(380, 170))
	arena.add_child(foe_w)
	ok = await _watch(700, func() -> bool: return friend.has_effect(&"buff"))
	_ability_result(&"war_cry", ok, wolf)
	for u in [wolf, friend, foe_w]:
		u.discard()

	var witch := _player(arena, "witch", Vector2(300, 170))
	var foe_c := _dummy(Vector2(340, 170))
	arena.add_child(foe_c)
	ok = await _watch(60, func() -> bool: return foe_c.has_effect(&"slow"))
	_ability_result(&"slow_aura", ok, witch)
	witch.discard()
	foe_c.discard()

	var satyr := _player(arena, "satyr", Vector2(300, 170))
	var friend_b := _player(arena, "knight", Vector2(330, 170))
	friend_b.move_speed = 0.0
	ok = await _watch(60, func() -> bool: return friend_b.has_effect(&"buff"))
	_ability_result(&"war_aura", ok, satyr)
	satyr.discard()
	friend_b.discard()

	# Passive ohne Gegner: Panzerung, Ausweichen, Lebensraub, Regeneration
	var dwarf := _player(arena, "dwarf_warrior", Vector2(300, 170))
	var before := dwarf.health
	dwarf.take_damage(10.0)
	ok = before - dwarf.health < 10.0 and before - dwarf.health > 0.0
	_ability_result(&"armor", ok, dwarf)
	dwarf.discard()

	var elf := _player(arena, "elf_scout", Vector2(300, 170))
	elf.max_health = 1000.0
	elf.health = 1000.0
	for i in 200:
		elf.take_damage(1.0)
	ok = elf.health < 1000.0 and elf.health > 800.0
	_ability_result(&"evasion", ok, elf)
	elf.discard()

	var skeleton := _player(arena, "skeleton", Vector2(300, 170))
	skeleton.health = 3.0
	var victim := _dummy(Vector2(310, 170))
	arena.add_child(victim)
	victim.take_damage(10.0, skeleton)
	ok = skeleton.health > 3.0
	_ability_result(&"lifesteal", ok, skeleton)
	skeleton.discard()
	victim.discard()

	var drop := _player(arena, "droplet", Vector2(300, 170))
	drop.health = drop.max_health * 0.3
	var start_health := drop.health
	ok = await _watch(180, func() -> bool: return drop.health > start_health + 0.5)
	_ability_result(&"regen", ok, drop)
	drop.discard()
	await _check_new_abilities(arena)
	Game.phase = Game.Phase.BUILD
	spots.clear()


## Schützen: Die Einheit greift Gegner beim Schützling an, ignoriert ferne Gegner und folgt dem Schützling.
func _check_guard(arena: Node2D) -> void:
	var ward := Combatant.new()
	ward.setup_player(Registry.units["peasant"])
	ward.position = Vector2(300, 170)
	ward.attack = 0.0
	ward.move_speed = 0.0
	arena.add_child(ward)
	var guard := Combatant.new()
	guard.setup_player(Registry.units["knight"])
	guard.position = Vector2(240, 170)
	arena.add_child(guard)
	var near := _dummy(Vector2(335, 170))
	arena.add_child(near)
	var far := _dummy(Vector2(240, 300))  # weit weg vom Schützling
	arena.add_child(far)
	guard.guard(ward)
	Game.phase = Game.Phase.BATTLE
	for i in 360:
		await get_tree().physics_frame
	var engaged := near.health < near.max_health
	var ignored_far := far.health >= far.max_health
	near.discard()
	ward.position = Vector2(480, 170)
	for i in 600:
		await get_tree().physics_frame
	var followed := guard.position.distance_to(ward.position) < 40.0
	ward.discard()
	for i in 5:
		await get_tree().physics_frame
	var released := guard.order_mode() == &"free"
	var ok := engaged and ignored_far and followed and released
	print("%s Schützen: Gegner beim Schützling bekämpft=%s, ferner ignoriert=%s, folgt=%s, frei nach Tod=%s" % [
		"ok:  " if ok else "FAIL:", engaged, ignored_far, followed, released])
	_failed = _failed or not ok
	guard.discard()
	far.discard()
	Game.phase = Game.Phase.BUILD


## Heiler läuft zum verletzten Verbündeten, heilt ihn bis zum Maximum und greift keinen Gegner an.
func _check_healer(arena: Node2D) -> void:
	var healer := Combatant.new()
	healer.setup_player(Registry.units["shaman"])
	healer.position = Vector2(200, 170)
	arena.add_child(healer)
	var patient := Combatant.new()
	patient.setup_player(Registry.units["knight"])
	patient.position = Vector2(330, 170)
	patient.health = 1.0
	patient.attack = 0.0
	patient.move_speed = 0.0
	arena.add_child(patient)
	var enemy := _dummy(Vector2(420, 170))
	arena.add_child(enemy)
	Game.phase = Game.Phase.BATTLE
	var saw_spell := false
	for i in 600:
		await get_tree().physics_frame
		for child in arena.get_children():
			if child is Projectile:
				saw_spell = true
	var ok := healer.attack_style == &"heal" and saw_spell and patient.health >= patient.max_health \
			and enemy.health >= enemy.max_health
	print("%s Heiler: Stil=%s, Zauber=%s, Patient LP=%.1f/%.1f, Gegner unberührt=%s" % [
		"ok:  " if ok else "FAIL:", healer.attack_style, saw_spell, patient.health, patient.max_health,
		enemy.health >= enemy.max_health])
	_failed = _failed or not ok
	for unit in [healer, patient, enemy]:
		unit.discard()
	Game.phase = Game.Phase.BUILD


## Laufwippen beim Gehen und weiche Drehung, wenn das Ziel die Seite wechselt.
func _check_walk_and_turn(arena: Node2D) -> void:
	var runner := Combatant.new()
	runner.setup_player(Registry.units["knight"])
	runner.position = Vector2(320, 172)
	arena.add_child(runner)
	var east := _dummy(Vector2(520, 172))
	arena.add_child(east)
	Game.phase = Game.Phase.BATTLE
	var walked := false
	for i in 30:
		await get_tree().physics_frame
		walked = walked or runner._walk_phase != 0.0
	var speed_before := runner._velocity.x
	east.discard()
	var west := _dummy(Vector2(100, 172))
	arena.add_child(west)
	var min_speed := speed_before
	var saw_mid_flip := false
	for i in 40:
		await get_tree().physics_frame
		min_speed = minf(min_speed, runner._velocity.x)
		saw_mid_flip = saw_mid_flip or absf(runner._flip) < 0.9
	# Die Geschwindigkeit darf nicht in einem Schritt umspringen (weicher Richtungswechsel).
	var ok := walked and saw_mid_flip and runner._flip < 0.0 and speed_before > 0.0 and min_speed < 0.0
	print("%s Laufen/Drehen: gewippt=%s, Zwischenstellung beim Drehen=%s" % ["ok:  " if ok else "FAIL:", walked, saw_mid_flip])
	_failed = _failed or not ok
	runner.discard()
	west.discard()
	Game.phase = Game.Phase.BUILD


## Einheit `id` bekommt Fähigkeit `ability` (Bedingung wird jeweils im Test hergestellt).
func _with(arena: Node2D, id: String, ability: StringName, at: Vector2) -> Combatant:
	var unit := _player(arena, id, at)
	unit.ability = ability
	unit.move_speed = 0.0
	return unit


func _clear(arena: Node2D) -> void:
	for child in arena.get_children():
		if child is Combatant:
			(child as Combatant).discard()
		else:
			child.queue_free()
	await get_tree().physics_frame


func _check_new_abilities(arena: Node2D) -> void:
	Game.phase = Game.Phase.BATTLE
	var center := Vector2(300, 170)

	var mage := _with(arena, "mage", &"chain_lightning", center)
	var chain: Array[Combatant] = [_dummy(center + Vector2(40, 0)), _dummy(center + Vector2(70, 10)), _dummy(center + Vector2(100, 0))]
	for foe in chain:
		arena.add_child(foe)
	var ok: bool = await _watch(700, func() -> bool: return mage.ability_casts > 0 and chain[2].health < chain[2].max_health)
	_ability_result(&"chain_lightning", ok, mage)
	await _clear(arena)

	for id: StringName in [&"petrify", &"charm"]:
		var caster := _with(arena, "witch", id, center)
		var foe := _dummy(center + Vector2(40, 0))
		arena.add_child(foe)
		ok = await _watch(900, func() -> bool: return foe.has_effect(&"stun"))
		_ability_result(id, ok, caster)
		await _clear(arena)

	var spinner := _with(arena, "knight", &"whirlwind", center)
	var left := _dummy(center + Vector2(-14, 0))
	var right := _dummy(center + Vector2(14, 0))
	arena.add_child(left)
	arena.add_child(right)
	ok = await _watch(700, func() -> bool: return spinner.ability_casts > 0)
	ok = ok and left.health < left.max_health and right.health < right.max_health
	_ability_result(&"whirlwind", ok, spinner)
	await _clear(arena)

	var rider := _with(arena, "knight", &"charge", Vector2(150, 170))
	rider.move_speed = 25.0
	rider._ability_cd = 0.1  # sofort, solange das Ziel noch weit weg ist
	var far := _dummy(Vector2(280, 170))
	arena.add_child(far)
	ok = await _watch(900, func() -> bool: return far.has_effect(&"stun"))
	_ability_result(&"charge", ok, rider)
	await _clear(arena)

	var caller := _with(arena, "mage", &"summon", center)
	var target := _dummy(center + Vector2(60, 0))
	arena.add_child(target)
	ok = await _watch(700, func() -> bool:
		for child in arena.get_children():
			if child is Combatant and (child as Combatant).summoned:
				return true
		return false)
	_ability_result(&"summon", ok, caller)
	await _clear(arena)

	var shade := _with(arena, "knight", &"blink", center)
	var distant := _dummy(center + Vector2(100, 0))
	arena.add_child(distant)
	ok = await _watch(700, func() -> bool: return shade.position.distance_to(distant.position) < 30.0)
	_ability_result(&"blink", ok, shade)
	await _clear(arena)

	var plague := _with(arena, "mage", &"poison_cloud", center)
	var sick := _dummy(center + Vector2(40, 0))
	arena.add_child(sick)
	ok = await _watch(700, func() -> bool: return sick.has_effect(&"poison"))
	_ability_result(&"poison_cloud", ok, plague)
	await _clear(arena)

	var titan := _with(arena, "knight", &"earthquake", center)
	var shaken := _dummy(center + Vector2(40, 0))
	arena.add_child(shaken)
	ok = await _watch(700, func() -> bool: return shaken.has_effect(&"stun"))
	_ability_result(&"earthquake", ok, titan)
	await _clear(arena)

	var saint := _with(arena, "healer", &"holy_light", center)
	var evil := _dummy(center + Vector2(50, 0))
	arena.add_child(evil)
	ok = await _watch(700, func() -> bool: return saint.ability_casts > 0 and evil.health < evil.max_health)
	_ability_result(&"holy_light", ok, saint)
	await _clear(arena)

	var dragon := _with(arena, "mage", &"fire_breath", center)
	var burnt := _dummy(center + Vector2(40, 0))
	arena.add_child(burnt)
	ok = await _watch(700, func() -> bool: return dragon.ability_casts > 0 and burnt.has_effect(&"poison"))
	_ability_result(&"fire_breath", ok, dragon)
	await _clear(arena)

	var crone := _with(arena, "witch", &"hex", center)
	var cursed := _dummy(center + Vector2(40, 0))
	arena.add_child(cursed)
	ok = await _watch(700, func() -> bool: return cursed.has_effect(&"weak") and cursed.damage_mult() < 1.0)
	_ability_result(&"hex", ok, crone)
	await _clear(arena)

	var sea := _with(arena, "knight", &"tidal_wave", center)
	var washed := _dummy(center + Vector2(30, 0))
	arena.add_child(washed)
	ok = await _watch(700, func() -> bool: return washed.position.x > center.x + 50.0)
	_ability_result(&"tidal_wave", ok, sea)
	await _clear(arena)

	var paladin := _with(arena, "knight", &"divine_shield", center)
	var weak_ally := _player(arena, "peasant", center + Vector2(20, 0))
	weak_ally.health = weak_ally.max_health * 0.2
	weak_ally.move_speed = 0.0
	ok = await _watch(700, func() -> bool: return weak_ally.has_effect(&"shield") and weak_ally.effect_value(&"shield") == 0.0)
	_ability_result(&"divine_shield", ok, paladin)
	await _clear(arena)

	var berserker := _with(arena, "knight", &"berserk", center)
	berserker.health = berserker.max_health * 0.3
	var rival := _dummy(center + Vector2(14, 0))
	arena.add_child(rival)
	ok = await _watch(700, func() -> bool: return berserker.has_effect(&"haste"))
	_ability_result(&"berserk", ok, berserker)
	await _clear(arena)

	# Passive Fähigkeiten
	var thorny := _with(arena, "knight", &"thorns", center)
	thorny.attack = 0.0
	var brute := _dummy(center + Vector2(12, 0))
	brute.attack = 5.0
	brute.attack_style = &"melee"
	brute.attack_range = 20.0
	arena.add_child(brute)
	ok = await _watch(300, func() -> bool: return brute.health < brute.max_health)
	_ability_result(&"thorns", ok, thorny)
	await _clear(arena)

	var sniper := _with(arena, "knight", &"crit", center)
	sniper.ability_power = 10.0  # Höchstchance 40 %
	var board := _dummy(center + Vector2(12, 0))
	arena.add_child(board)
	var biggest := 0.0
	var last := board.health
	for i in 600:
		await get_tree().physics_frame
		biggest = maxf(biggest, last - board.health)
		last = board.health
	ok = biggest >= sniper.attack * 1.9
	_ability_result(&"crit", ok, sniper)
	await _clear(arena)

	var judge := _with(arena, "knight", &"execute", center)
	var doomed := _dummy(center + Vector2(12, 0))
	doomed.health = doomed.max_health * 0.1
	var fallen := [false]
	doomed.died.connect(func(_unit: Combatant) -> void: fallen[0] = true)
	arena.add_child(doomed)
	ok = await _watch(300, func() -> bool: return fallen[0])
	_ability_result(&"execute", ok, judge)
	await _clear(arena)
	Game.phase = Game.Phase.BUILD


func _dummy(at: Vector2) -> Combatant:
	var dummy := Combatant.new()
	dummy.setup_enemy(Registry.pick_enemy(1))
	dummy.max_health = 1000.0
	dummy.health = 1000.0
	dummy.attack = 0.0
	dummy.move_speed = 0.0
	dummy.position = at
	return dummy


## Alle Effekte und beide Musikstücke sind geladen, die Musik läuft als Schleife.
func _check_audio() -> void:
	var missing: Array[String] = []
	for id in Sound.SFX_SETTINGS:
		if not Sound.has_sound(id):
			missing.append(String(id))
	for id in [&"build", &"battle"]:
		if not Sound.has_music(id):
			missing.append(String(id))
	var ok := missing.is_empty()
	print("%s Audio: %d Effekte, fehlend: %s" % ["ok:  " if ok else "FAIL:", Sound.SFX_SETTINGS.size(), missing])
	_failed = _failed or not ok
