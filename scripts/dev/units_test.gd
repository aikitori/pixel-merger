extends Node
## Entwickler-Test: Eigenart der Einheiten. Daten (Verhalten, Angriffsform, Merkmale, einzigartige Linien und
## Signaturen), Animationsstreifen, die Zusatzwirkung jeder Angriffsform, die Bausteine der Merkmale und
## die Verhaltensweisen im kleinen Kampf. Alles mit festen Positionen, nichts hängt vom Zufall ab.
## Start: godot --headless res://scenes/dev/units_test.tscn

const CENTER := Vector2(320, 176)

var _failed := false
var _arena: Node2D


func _ready() -> void:
	get_tree().create_timer(240.0, true, false, true).timeout.connect(func() -> void:
		print("UNITS-TEST ZEITÜBERSCHREITUNG")
		get_tree().quit(1))
	World.set_round(1)
	_arena = Node2D.new()  # eigene Fläche ohne Rundenlogik
	add_child(_arena)
	_check_data()
	_check_strips()
	await _check_attack_kinds()
	await _check_traits()
	await _check_behaviors()
	_check_enemy_data()
	await _check_enemies()
	Game.phase = Game.Phase.BUILD
	print("UNITS-TEST ", "FEHLER" if _failed else "OK")
	get_tree().quit(1 if _failed else 0)


func _check(ok: bool, label: String) -> void:
	print("%s %s" % ["ok:  " if ok else "FAIL:", label])
	_failed = _failed or not ok


# --- Daten -----------------------------------------------------------------------

func _check_data() -> void:
	var bad: Array[String] = []
	var signatures := {}
	var lines := {}
	for id: StringName in Registry.units:
		var unit: UnitData = Registry.units[id]
		if not Behaviors.INFO.has(unit.behavior) or not AttackKinds.INFO.has(unit.attack_kind):
			bad.append(String(id))
		for trait_id in unit.traits:
			if not Traits.INFO.has(trait_id):
				bad.append("%s:%s" % [id, trait_id])
		if unit.category == "Kombination":
			if unit.traits.size() != 1:
				bad.append("%s ohne Signatur" % id)
			elif unit.level == 1:
				signatures[unit.traits[0]] = signatures.get(unit.traits[0], 0) + 1
		else:
			var expected := (1 if unit.level >= 3 else 0) + (1 if unit.level >= 5 else 0)
			if unit.traits.size() != expected:
				bad.append("%s hat %d Merkmale statt %d" % [id, unit.traits.size(), expected])
			if unit.level == 1:
				var key := "%s|%s|%s" % [unit.behavior, unit.attack_kind, unit.ability]
				lines[key] = lines.get(key, []) + [String(id)]
	_check(bad.is_empty(), "Alle Einheiten haben gültiges Verhalten, Angriffsform und Merkmale %s" % [bad.slice(0, 5)])
	var shared := signatures.keys().filter(func(k: StringName) -> bool: return signatures[k] > 1)
	var combos := Registry.recipes.filter(func(r: RecipeData) -> bool: return r.ingredient_a != r.ingredient_b).size()
	_check(shared.is_empty() and signatures.size() == combos, "Jede Kombination hat ihre eigene Signatur (%d von %d)" % [signatures.size(), combos])
	var same := lines.values().filter(func(ids: Array) -> bool: return ids.size() > 1)
	_check(same.is_empty(), "Keine zwei Linien teilen Verhalten, Angriffsform und Fähigkeit %s" % [same])
	var typos: Array[String] = []
	for id: StringName in Traits.INFO:
		for key: String in Traits.INFO[id]["fx"]:
			if not key in Traits.KEYS:
				typos.append("%s.%s" % [id, key])
	_check(typos.is_empty(), "Alle Merkmale nutzen bekannte Bausteine %s" % [typos])


func _check_strips() -> void:
	var bad: Array[String] = []
	for id: StringName in Registry.units:
		var unit: UnitData = Registry.units[id]
		var strip := Combatant._load_anim(unit.sprite)
		if strip == null or strip.get_width() % Combatant.ANIM_FRAMES != 0 \
				or strip.get_width() / Combatant.ANIM_FRAMES < unit.sprite.get_width():
			bad.append(String(id))
	_check(bad.is_empty(), "Jede Einheit hat einen Streifen mit %d Bildern %s" % [Combatant.ANIM_FRAMES, bad.slice(0, 5)])


# --- Hilfen ----------------------------------------------------------------------

func _player(id: String, at: Vector2) -> Combatant:
	var unit := Combatant.new()
	unit.setup_player(Registry.units[id])
	unit.position = at
	_arena.add_child(unit)
	return unit


func _dummy(at: Vector2, hp := 1000.0) -> Combatant:
	var dummy := Combatant.new()
	dummy.setup_enemy(Registry.pick_enemy(1))
	dummy.max_health = hp
	dummy.health = hp
	dummy.attack = 0.0
	dummy.move_speed = 0.0
	dummy.attack_range = 0.0
	dummy.position = at
	_arena.add_child(dummy)
	return dummy


func _clear() -> void:
	for child in _arena.get_children():
		if child is Combatant:
			(child as Combatant).discard()
		else:
			child.queue_free()
	await get_tree().process_frame


func _frames(count: int) -> void:
	for i in count:
		await get_tree().physics_frame


# --- Angriffsformen --------------------------------------------------------------

## Jede Form einmal direkt: Angreifer links, Ziel rechts daneben, ein zweiter Gegner neben bzw. hinter dem Ziel.
func _check_attack_kinds() -> void:
	Game.phase = Game.Phase.BATTLE
	var results: Array[String] = []
	for kind: StringName in AttackKinds.INFO:
		if AttackKinds.INFO[kind]["family"] == "heal":
			continue
		var source := _player("knight", CENTER - Vector2(30, 0))
		source.fx = {}
		var target := _dummy(CENTER)
		var other := _dummy(CENTER + Vector2(10, 0))
		var start := target.position
		AttackKinds.after_hit(kind, source, target, 10.0)
		var ok := false
		match kind:
			&"slash", &"axe", &"stomp", &"thrust", &"javelin", &"arcane", &"fireball":
				ok = other.health < other.max_health
			&"club":
				ok = target.position.x > start.x and target.has_effect(&"stun")
			&"kick", &"water_jet":
				ok = target.position.x > start.x
			&"tongue":
				ok = target.position.x < start.x
			&"claw":
				ok = target.health < target.max_health
			&"bite", &"ember", &"spit":
				ok = target.has_effect(&"poison")
			&"grasp", &"ice_shard":
				ok = target.has_effect(&"slow")
			&"curse":
				ok = target.has_effect(&"weak")
			&"lightning", &"arrow":
				ok = true  # keine Zusatzwirkung (Blitz trifft sofort, Pfeil ist nur schnell)
		if not ok:
			results.append(String(kind))
		await _clear()
	_check(results.is_empty(), "Jede Angriffsform wirkt wie beschrieben %s" % [results])
	# Sofortige Formen schießen kein Geschoss, die anderen schon (im echten Kampf).
	var shooter := _player("breath", CENTER - Vector2(25, 0))  # Luft: Blitzschlag
	var victim := _dummy(CENTER + Vector2(5, 0))
	var saw_projectile := false
	for i in 240:
		await get_tree().physics_frame
		for child in _arena.get_children():
			saw_projectile = saw_projectile or child is Projectile
	_check(victim.health < victim.max_health and not saw_projectile, "Blitzschlag trifft sofort ohne Geschoss")
	await _clear()
	Game.phase = Game.Phase.BUILD


# --- Merkmale --------------------------------------------------------------------

func _with_fx(id: String, at: Vector2, effects: Dictionary) -> Combatant:
	var unit := _player(id, at)
	unit.fx = effects
	return unit


func _check_traits() -> void:
	Game.phase = Game.Phase.BATTLE
	var melee := _player("knight", CENTER - Vector2(20, 0))
	melee.fx = {}
	var dodger := _with_fx("archer", CENTER, {"dodge": 1.0})
	dodger.take_damage(10.0, melee)
	_check(dodger.health == dodger.max_health, "Ausweichen: kein Schaden")
	var blocker := _with_fx("archer", CENTER, {"block": 1.0})
	blocker.take_damage(10.0, melee)
	_check(blocker.health == blocker.max_health, "Parade: Nahkampftreffer abgewehrt")
	var tough := _with_fx("archer", CENTER, {"reduce": 0.5})
	tough.max_health = 100.0
	tough.health = 100.0
	tough.take_damage(10.0, null)
	_check(is_equal_approx(tough.health, 95.0), "Schadensminderung halbiert (%.1f)" % tough.health)
	var thorny := _with_fx("archer", CENTER, {"thorns": 0.5})
	var before := melee.health
	thorny.take_damage(4.0, melee)
	_check(melee.health < before, "Dornen verletzen den Nahkämpfer")
	var phoenix := _with_fx("archer", CENTER, {"revive": 0.5})
	phoenix.take_damage(phoenix.max_health * 2.0, null)
	var first_alive := phoenix.is_alive() and is_equal_approx(phoenix.health, phoenix.max_health * 0.5)
	phoenix.take_damage(phoenix.max_health * 2.0, null)
	_check(first_alive and not phoenix.is_alive(), "Wiederaufstehen genau einmal je Kampf")
	await _clear()

	var hunter := _with_fx("knight", CENTER - Vector2(20, 0), {"opener": 2.0, "kill_gold": 3})
	var target := _dummy(CENTER, 100.0)
	Combatant.land_hit(hunter, target, 10.0, &"lightning")
	var opened := is_equal_approx(target.health, 80.0)
	Combatant.land_hit(hunter, target, 10.0, &"lightning")
	_check(opened and is_equal_approx(target.health, 70.0), "Eröffnungsschlag nur beim ersten Treffer (%.1f)" % target.health)
	var gold := Game.gold
	Combatant.land_hit(hunter, target, 500.0, &"lightning")
	_check(Game.gold == gold + 3, "Gold für den Sieg (%+d)" % (Game.gold - gold))
	var judge := _with_fx("knight", CENTER - Vector2(20, 0), {"execute": 0.2})
	var weak := _dummy(CENTER, 100.0)
	weak.health = 25.0
	Combatant.land_hit(judge, weak, 10.0, &"lightning")
	_check(not weak.is_alive(), "Richten: fast Besiegte fallen sofort")
	var marker := _with_fx("knight", CENTER - Vector2(20, 0), {"mark": [0.5, 3.0], "burn": [0.5, 3.0]})
	var marked := _dummy(CENTER, 1000.0)
	Combatant.land_hit(marker, marked, 10.0, &"lightning")
	var after_first := marked.health
	marked.take_damage(10.0, null)
	_check(marked.has_effect(&"poison") and is_equal_approx(after_first - marked.health, 15.0),
			"Markierung erhöht den Schaden, Brand wirkt (%.1f)" % (after_first - marked.health))
	await _clear()

	var bomb := _with_fx("archer", CENTER, {"death_blast": [5.0, 40.0]})
	var near := _dummy(CENTER + Vector2(20, 0))
	bomb.take_damage(bomb.max_health * 2.0, null)
	_check(near.health < near.max_health, "Explosion beim Tod trifft Gegner ringsum")
	await _clear()

	var healer := _with_fx("knight", CENTER, {"aura_heal": 0.1, "aura_burn": 1.0})
	var hurt := _player("archer", CENTER + Vector2(15, 0))
	hurt.health = hurt.max_health * 0.5
	var foe := _dummy(CENTER + Vector2(-15, 0))
	await _frames(90)  # gut eine Sekunde
	_check(hurt.health > hurt.max_health * 0.5 and foe.health < foe.max_health, "Auren heilen Verbündete und versengen Gegner")
	await _clear()
	Game.phase = Game.Phase.BUILD


# --- Verhalten -------------------------------------------------------------------

func _check_behaviors() -> void:
	Game.phase = Game.Phase.BATTLE
	# Plänkler weicht zurück
	var elf := _player("elf_scout", CENTER)
	var close := _dummy(CENTER + Vector2(15, 0))
	await _frames(60)
	_check(elf.position.distance_to(close.position) > 25.0, "Plänkler hält Abstand (%.0f)" % elf.position.distance_to(close.position))
	await _clear()
	# Meuchler nimmt den schwächsten
	var wolf := _player("wolf_pup", CENTER)
	_dummy(CENTER + Vector2(20, 0))
	var wounded := _dummy(CENTER + Vector2(-60, 0))
	wounded.health = 50.0
	await _frames(3)
	_check(wolf._target == wounded, "Meuchler jagt den schwächsten Gegner")
	await _clear()
	# Flankierer jagt Fernkämpfer
	var skeleton := _player("skeleton", CENTER)
	_dummy(CENTER + Vector2(20, 0))
	var archer := _dummy(CENTER + Vector2(-70, 0))
	archer.attack_style = &"arrow"
	await _frames(3)
	_check(skeleton._target == archer, "Flankierer jagt Fernkämpfer")
	await _clear()
	# Artillerie zielt auf Gruppen
	var slinger := _player("slinger", CENTER)
	_dummy(CENTER + Vector2(40, 0))
	var group: Array[Combatant] = [_dummy(CENTER + Vector2(-55, 0)), _dummy(CENTER + Vector2(-60, 6)), _dummy(CENTER + Vector2(-60, -6))]
	await _frames(3)
	_check(group.has(slinger._target), "Artillerie zielt auf die Gegnergruppe")
	await _clear()
	# Wächter fängt Angreifer des Schützlings ab
	var gnome := _player("gnome", CENTER)
	var ward := _player("archer", CENTER + Vector2(-60, 0))
	ward.move_speed = 0.0
	ward.attack = 0.0
	_dummy(CENTER + Vector2(25, 0))
	var attacker := _dummy(CENTER + Vector2(-80, 0))
	await _frames(3)
	_check(gnome._target == attacker and gnome.ward == ward, "Wächter fängt den Angreifer des Schützlings ab")
	await _clear()
	# Stürmer zieht sich nach dem Treffer zurück
	var foal := _player("foal", CENTER)
	var punching_bag := _dummy(CENTER + Vector2(8, 0))
	var retreated := false
	for i in 120:
		await get_tree().physics_frame
		retreated = retreated or (foal.behavior_left > 0.0 and punching_bag.health < punching_bag.max_health)
	_check(retreated, "Stürmer zieht sich nach dem Angriff zurück")
	await _clear()
	# Hüpfer springen
	var frog := _player("tree_frog", CENTER)
	_dummy(CENTER + Vector2(-120, 0))
	var jumped := false
	for i in 90:
		await get_tree().physics_frame
		jumped = jumped or Behaviors.hop_height(frog) > 1.0
	_check(jumped, "Hüpfer springt beim Laufen")
	await _clear()
	# Schweber gleiten über Hindernisse
	var spark := _player("spark", CENTER)
	var rock: Vector2 = World.obstacles[0]["pos"] if not World.obstacles.is_empty() else CENTER
	_check(spark._clamp(rock) == World.clamp_to_floor(rock) and World.clamp_point(rock) != rock,
			"Schweber ignoriert Hindernisse, andere werden herausgeschoben")
	await _clear()
	Game.phase = Game.Phase.BUILD


# --- Gegner ----------------------------------------------------------------------

func _enemy(id: String, at: Vector2) -> Combatant:
	var enemy := Combatant.new()
	enemy.setup_enemy(Registry.enemy_by_id(StringName(id)))
	enemy.position = at
	_arena.add_child(enemy)
	return enemy


func _check_enemy_data() -> void:
	var bad: Array[String] = []
	for enemy: EnemyData in Registry.enemies + Registry.bosses:
		var strip := Combatant._load_anim(enemy.sprite)
		if strip == null or strip.get_width() % Combatant.ANIM_FRAMES != 0:
			bad.append("%s ohne Streifen" % enemy.id)
		if enemy.ability != &"" and not Abilities.INFO.has(enemy.ability) or enemy.ability == &"revive":
			bad.append("%s Fähigkeit %s" % [enemy.id, enemy.ability])
		if not Behaviors.INFO.has(enemy.behavior):
			bad.append("%s Verhalten" % enemy.id)
		for key: String in enemy.fx:
			if not key in Traits.KEYS:
				bad.append("%s.%s" % [enemy.id, key])
		if (enemy.ability == &"summon") != (enemy.minion != &""):
			bad.append("%s Helfer" % enemy.id)
		elif enemy.minion != &"" and Registry.enemy_by_id(enemy.minion) == null:
			bad.append("%s: Helfer %s fehlt" % [enemy.id, enemy.minion])
	_check(bad.is_empty(), "Alle Gegner haben Streifen, gültige Fähigkeit, Verhalten und Bausteine %s" % [bad])
	var early_ok := true
	var minion_seen := false
	for i in 400:
		early_ok = early_ok and Registry.pick_enemy(1).min_round <= 1
		minion_seen = minion_seen or Registry.pick_enemy(99).id == &"skeleton"
	_check(early_ok and not minion_seen, "Spawn: Runde 1 nur frühe Gegner, Helfer erscheinen nie von selbst")
	var kinds := {}
	for i in 600:
		kinds[Registry.pick_enemy(20).id] = true
	var plain := Registry.enemies.filter(func(e: EnemyData) -> bool: return e.weight > 0.0 and e.min_round <= 20)
	_check(kinds.size() == plain.size(), "Runde 20: alle %d Gegnertypen kommen vor (%d)" % [plain.size(), kinds.size()])


func _check_enemies() -> void:
	Game.phase = Game.Phase.BATTLE
	var knight := func(at: Vector2) -> Combatant:
		var unit := _player("knight", at)
		unit.fx = {}
		return unit
	# Stachelfrosch: Dornen
	var frog := _enemy("spiny_frog", CENTER)
	var hitter: Combatant = knight.call(CENTER + Vector2(-12, 0))
	frog.take_damage(10.0, hitter)
	_check(hitter.health < hitter.max_health, "Stachelfrosch verletzt Nahkämpfer mit Dornen")
	await _clear()
	# Gnoll-Schamane heilt Verbündete
	var shaman := _enemy("gnoll_shaman", CENTER)
	var hurt := _enemy("goblin", CENTER + Vector2(30, 0))
	hurt.health = hurt.max_health * 0.3
	var before := hurt.health
	shaman._ability_cd = 0.0
	_check(shaman.cast_now() and hurt.health > before, "Gnoll-Schamane heilt verletzte Gegner")
	await _clear()
	# Gnoll-Hauptmann: Kriegsruf stärkt Verbündete
	var sergeant := _enemy("gnoll_sergeant", CENTER)
	var ally := _enemy("goblin", CENTER + Vector2(25, 0))
	knight.call(CENTER + Vector2(70, 0))
	sergeant._ability_cd = 0.0
	_check(sergeant.cast_now() and ally.has_effect(&"buff"), "Gnoll-Hauptmann stärkt Gegner im Umkreis")
	await _clear()
	# Warg: Sturmangriff aus der Ferne
	var warg := _enemy("warg", CENTER)
	warg._target = knight.call(CENTER + Vector2(100, 0))
	warg._ability_cd = 0.0
	_check(warg.cast_now() and warg.has_effect(&"charge"), "Warg stürmt auf ein fernes Ziel los")
	await _clear()
	# Totenbeschwörer ruft Skelette ohne Beute
	var necromancer := _enemy("necromancer", CENTER)
	knight.call(CENTER + Vector2(100, 0))
	necromancer._ability_cd = 0.0
	var count := get_tree().get_nodes_in_group(Combatant.GROUP_ENEMY).size()
	var cast_ok := necromancer.cast_now()
	var minions := get_tree().get_nodes_in_group(Combatant.GROUP_ENEMY).filter(func(c: Combatant) -> bool: return c.summoned)
	_check(cast_ok and get_tree().get_nodes_in_group(Combatant.GROUP_ENEMY).size() > count and not minions.is_empty()
			and minions[0].gold_reward == 0, "Totenbeschwörer beschwört Helfer ohne Beute")
	await _clear()
	# Sprengpilz explodiert beim Tod
	var mushroom := _enemy("mushroom", CENTER)
	var victim: Combatant = knight.call(CENTER + Vector2(20, 0))
	mushroom.take_damage(1.0e9, null)
	_check(victim.health < victim.max_health, "Sprengpilz verletzt Nachbarn beim Tod")
	await _clear()
	# Dunkelmagier: Feuersturm auf das Ziel
	var mage := _enemy("dark_mage", CENTER)
	var target: Combatant = knight.call(CENTER + Vector2(60, 0))
	mage._target = target
	mage._ability_cd = 0.0
	_check(mage.cast_now() and target.health < target.max_health, "Dunkelmagier schlägt einen Feuersturm ein")
	await _clear()
	# Vampir: Lebensraub
	var vampire := _enemy("vampire", CENTER)
	vampire.health = vampire.max_health * 0.5
	before = vampire.health
	var prey: Combatant = knight.call(CENTER + Vector2(12, 0))
	prey.take_damage(20.0, vampire)
	_check(vampire.health > before, "Vampir heilt sich mit Lebensraub")
	await _clear()
	# Troll regeneriert
	var troll := _enemy("troll", CENTER)
	troll.health = troll.max_health * 0.5
	before = troll.health
	await _frames(40)
	_check(troll.health > before, "Troll regeneriert Leben")
	await _clear()
	# Geist und Wasserspeier: Verteidigung aus den Bausteinen
	var ghost := _enemy("ghost", CENTER)
	var gargoyle := _enemy("gargoyle", CENTER)
	_check(ghost.fx.get("dodge", 0.0) > 0.0 and gargoyle.fx.get("reduce", 0.0) > 0.0 and ghost._floats, "Geist weicht aus, Wasserspeier mindert Schaden, beide schweben")
	await _clear()
	# Schakal (Flankierer) jagt den Fernkämpfer, Vampir (Meuchler) den schwächsten
	var jackal := _enemy("jackal", CENTER)
	knight.call(CENTER + Vector2(25, 0))
	var archer := _player("archer", CENTER + Vector2(-70, 0))
	await _frames(3)
	_check(jackal._target == archer, "Schakal jagt den Fernkämpfer")
	await _clear()
	var stalker := _enemy("vampire", CENTER)
	knight.call(CENTER + Vector2(20, 0))
	var weak: Combatant = knight.call(CENTER + Vector2(-60, 0))
	weak.health = 10.0
	await _frames(3)
	_check(stalker._target == weak, "Vampir jagt den schwächsten Gegner")
	await _clear()
	# Elite-Gegner: stärker, größer, mehr Beute; Bosse und Helfer nie
	var plain := _enemy("orc", CENTER)
	var elite := _enemy("orc", CENTER + Vector2(40, 0))
	elite.make_elite()
	_check(elite.elite and is_equal_approx(elite.max_health, plain.max_health * Combatant.ELITE_HEALTH)
			and elite.gold_reward == plain.gold_reward * Combatant.ELITE_GOLD and elite.scale.x > plain.scale.x
			and elite.display_name.begins_with("Elite"), "Elite-Gegner haben mehr Leben, Beute und Größe")
	var boss := _enemy("boss_ogre", CENTER + Vector2(80, 0))
	boss.make_elite()
	_check(not boss.elite, "Bosse werden nie Elite")
	var chance_round := Game.round_number
	Game.round_number = Game.ELITE_ROUND - 1
	var early := Game.elite_chance()
	Game.round_number = 100
	var late := Game.elite_chance()
	Game.round_number = chance_round
	_check(early == 0.0 and late == Game.ELITE_MAX_CHANCE, "Elite erst ab Runde %d, Anteil gedeckelt" % Game.ELITE_ROUND)
	await _clear()
	# Bosse wirken ihre Fähigkeit
	var dragon := _enemy("boss_dragon", CENTER)
	var burned: Combatant = knight.call(CENTER + Vector2(50, 0))
	dragon._target = burned
	dragon._ability_cd = 0.0
	_check(dragon.cast_now() and burned.health < burned.max_health, "Feuerdrache speit Feuer")
	await _clear()
	var golem := _enemy("boss_golem", CENTER)
	var stomped: Combatant = knight.call(CENTER + Vector2(30, 0))
	golem._ability_cd = 0.0
	_check(golem.cast_now() and stomped.has_effect(&"stun"), "Steingigant löst ein Erdbeben aus")
	await _clear()
	var king := _enemy("boss_bones", CENTER)
	knight.call(CENTER + Vector2(90, 0))
	king._ability_cd = 0.0
	_check(king.cast_now() and get_tree().get_nodes_in_group(Combatant.GROUP_ENEMY).size() >= 3, "Knochenkönig beschwört Skelette")
	await _clear()
	Game.phase = Game.Phase.BUILD
