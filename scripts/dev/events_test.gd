extends Node
## Entwickler-Test: Bossrunde (Runde 5), Bonusrunde (Runde 10) und Erfolge.
## Start: godot --headless res://scenes/dev/events_test.tscn

var _failed := false
var _arena: Node2D


func _ready() -> void:
	Engine.time_scale = 10.0
	get_tree().create_timer(120.0, true, false, true).timeout.connect(func() -> void:
		print("EVENTS-TEST ZEITÜBERSCHREITUNG")
		get_tree().quit(1))
	Achievements.reset()
	_arena = load("res://scenes/main.tscn").instantiate()
	add_child(_arena)
	await get_tree().process_frame

	_check(Game.round_kind(5) == Game.RoundKind.BOSS and Game.round_kind(15) == Game.RoundKind.BOSS, "Runde 5 und 15 sind Bossrunden")
	_check(Game.round_kind(10) == Game.RoundKind.BONUS and Game.round_kind(20) == Game.RoundKind.BONUS, "Runde 10 und 20 sind Bonusrunden")
	_check(Game.round_kind(4) == Game.RoundKind.NORMAL and Game.round_kind(11) == Game.RoundKind.NORMAL, "Andere Runden sind normal")
	_check(Registry.bosses.size() >= 4 and Registry.boss_for_round(5) != Registry.boss_for_round(15), "Bosse wechseln reihum")
	_check(not Registry.enemies.any(func(e: EnemyData) -> bool: return e.is_boss), "Bosse stehen nicht im normalen Spawn")

	# Schnellkauf (Rezeptbuch): alle Grundeinheiten eines Rezepts auf einmal, Verbinden bleibt manuell.
	var knight_bundle: Dictionary = Registry.base_units(Registry.units["knight"])
	_check(knight_bundle.size() == 1 and knight_bundle[Registry.units["peasant"]] == 4, "Ritter = 4 Bauern")
	var paladin: UnitData = Registry.units["paladin"]
	var bundle: Dictionary = Registry.base_units(paladin)
	var price: int = Registry.bundle_price(bundle)
	_check(Registry.bundle_size(bundle) == 6 and price == 4 * 5 + 2 * 8, "Paladin = 4 Bauern + 2 Lehrlinge (%dg)" % price)
	Game.gold = price - 1
	_check(not _arena.buy_bundle(bundle) and _arena.get_player_units().is_empty() and Game.gold == price - 1, "Schnellkauf ohne genug Gold kauft nichts")
	Game.gold = price
	_check(_arena.buy_bundle(bundle) and _arena.get_player_units().size() == 6 and Game.gold == 0, "Schnellkauf kauft alle Grundeinheiten")
	var types := {}
	for unit in _arena.get_player_units():
		types[unit.unit_data.id] = types.get(unit.unit_data.id, 0) + 1
	_check(types == {&"peasant": 4, &"apprentice": 2}, "Es wird nicht automatisch verbunden")
	Game.gold = 1000
	var big := {Registry.units["peasant"]: Game.BUILD_MAX_UNITS}
	_check(not _arena.buy_bundle(big) and _arena.get_player_units().size() == 6, "Schnellkauf lehnt ab, wenn die Arena voll würde")
	for unit in _arena.get_player_units():
		unit.discard()
	await get_tree().process_frame
	# Bauphase: mehr als das Kampflimit erlaubt, Kampfstart erst nach Zurückschicken (halber Preis).
	Game.gold = 1000
	var peasant: UnitData = Registry.units["peasant"]
	for i in Game.MAX_UNITS + 2:
		_arena.buy_unit(peasant)
	_check(_arena.get_player_units().size() == Game.MAX_UNITS + 2, "Bauphase erlaubt mehr Einheiten als das Kampflimit")
	_check(not _arena.start_battle() and Game.phase == Game.Phase.BUILD, "Kampf startet nicht mit zu vielen Einheiten")
	var before := Game.gold
	var extra: Array[Combatant] = [_arena.get_player_units()[0], _arena.get_player_units()[1]]
	_arena.call("_apply_selection", extra)
	_arena.return_selected()
	await get_tree().process_frame
	_check(_arena.get_player_units().size() == Game.MAX_UNITS and Game.gold == before + 2 * roundi(peasant.price * Game.REFUND_SHARE), "Zurückschicken erstattet 50 %% (%dg)" % (Game.gold - before))
	for unit in _arena.get_player_units():
		unit.discard()
	await get_tree().process_frame
	await _test_merge_all()
	_test_houses()
	await _test_house_lines_and_direct_buy()
	_test_late_scaling()
	await get_tree().process_frame

	# Version: Anzeige im Menü (project.godot) und APK-Version (export_presets.cfg) müssen übereinstimmen.
	var presets := FileAccess.get_file_as_string("res://export_presets.cfg")
	var match_name := RegEx.create_from_string('version/name="([^"]*)"').search(presets)
	var shown: String = ProjectSettings.get_setting("application/config/version", "")
	_check(match_name != null and match_name.get_string(1) == shown, "Versionsanzeige (%s) = APK-Version (%s)" % [shown, match_name.get_string(1) if match_name else "?"])

	# Sprache: Namen und Texte sind ins Englische übersetzbar, Deutsch bleibt der Standard.
	_check(Loc.language == "de" and Registry.units["knight"].display_name == "Ritter", "Tests laufen auf Deutsch")
	Loc.set_language("en")
	_check(Registry.units["knight"].display_name == "Knight" and Registry.units["knight"].line_name == "Melee", "Englisch: Einheit und Linie übersetzt")
	_check(Abilities.display_name(&"shield") == "Shield Up" and tr("Neustart") == "Restart", "Englisch: Fähigkeiten und Oberfläche übersetzt")
	var missing: Array[String] = []
	for unit: UnitData in Registry.units.values():
		if unit.display_name == Registry._german_names[unit][0] and not Registry._german_names[unit][0] in ["Paladin", "Anubis", "Chiron", "Hydra", "Ifrit", "Loki", "Medusa", "Pegasus", "Poltergeist", "Satyr", "Sleipnir", "Surtr", "Thor", "Titan", "Troll", "Veteran", "Wolf", "Ymir", "Zerberus", "Basilisk", "Banshee", "Ent", "Golem", "Kelpie", "Seraph", "Trickster", "Undine", "Faun", "Muspel", "Leviathan", "Achilles", "Asklepios", "Sprint", "Wyrmling", "Fee", "Apis", "Lamassu", "Lamia", "Naga", "Prior", "Sphinx", "Triton"]:
			missing.append(unit.display_name)
	_check(missing.is_empty(), "Alle Einheitennamen haben eine englische Übersetzung (unübersetzt: %s)" % [missing.slice(0, 5)])
	Loc.set_language("de")
	_check(Registry.units["knight"].display_name == "Ritter", "Zurück auf Deutsch")

	# Starke Armee, damit der Boss fällt: Stufe-5-Einheiten.
	for id in ["bodyguard", "bodyguard", "bodyguard", "bodyguard", "bodyguard", "bodyguard", "hawkeye", "hawkeye", "hawkeye", "world_weaver", "world_weaver", "world_weaver"]:
		_arena._spawn_player(Registry.units[id], World.random_center_point())
	_check(Achievements.is_unlocked(&"first_lvl5"), "Erfolg 'Meisterwerk': erste Stufe-5-Einheit")

	Game.round_number = 5
	Game.gold = 0
	_check(_arena.start_battle(), "Bossrunde startet")
	var bosses := get_tree().get_nodes_in_group(Combatant.GROUP_ENEMY).filter(func(e: Combatant) -> bool: return e.is_boss)
	_check(bosses.size() == 1, "Genau ein Boss ist erschienen")
	var boss_gold: int = bosses[0].gold_reward if not bosses.is_empty() else 0
	await _wait_battle_end()
	_check(Game.phase == Game.Phase.BUILD and Game.round_number == 6, "Bossrunde endet mit dem Tod des Bosses (Runde %d)" % Game.round_number)
	_check(Game.gold >= boss_gold, "Boss gibt Gold (%d >= %d)" % [Game.gold, boss_gold])
	_check(Achievements.is_unlocked(&"first_boss"), "Erfolg 'Bossbezwinger'")

	# Bonusrunde: Prämie und dreifaches Gold
	Game.round_number = 10
	Game.gold = 0
	var prize := Game.bonus_prize()
	_check(_arena.start_battle(), "Bonusrunde startet")
	var kinds := Game.round_gold_mult()
	_check(is_equal_approx(kinds, 3.0), "Bonusrunde: Gegner geben dreifaches Gold")
	await _wait_battle_end()
	_check(Game.phase == Game.Phase.BUILD and Game.round_number == 11, "Bonusrunde endet nach der Zeit (Phase %d, Runde %d)" % [Game.phase, Game.round_number])
	_check(Game.gold >= prize, "Bonusrunde: Prämie von %d Gold erhalten (Gold %d)" % [prize, Game.gold])
	_check(Achievements.is_unlocked(&"first_bonus"), "Erfolg 'Goldrausch'")
	_check(Achievements.is_unlocked(&"first_perfect") and Achievements.is_unlocked(&"round_10"), "Erfolge 'Makellos' und 'Durchhalter'")

	# Fortschritt und Zähler
	Achievements.reset()
	Achievements.report(&"kill", 99)
	_check(not Achievements.is_unlocked(&"kills_100") and Achievements.progress[&"kills_100"] == 99, "Zähler: 99 von 100")
	Achievements.report(&"kill")
	_check(Achievements.is_unlocked(&"kills_100"), "Zähler: 100 Gegner schalten den Erfolg frei")
	Achievements.report_max(&"gold", 150)
	Achievements.report_max(&"gold", 90)
	_check(Achievements.progress[&"rich"] == 150 and not Achievements.is_unlocked(&"rich"), "Höchstwert-Erfolge merken sich den größten Wert")

	# Rundenmodifikatoren: nur normale Runden, nie zweimal derselbe, Werte wirken auf Gegner und Einheiten
	var rolled := {}
	var special_ok := true
	for i in 300:
		var id := Modifiers.roll(4, &"fog")
		rolled[id] = true
		special_ok = special_ok and Modifiers.roll(5, &"") == &"" and Modifiers.roll(10, &"") == &"" and Modifiers.roll(1, &"") == &""
	_check(special_ok, "Boss-, Bonus- und erste Runde haben keinen Modifikator")
	_check(not rolled.has(&"fog") and rolled.size() >= Modifiers.INFO.size(), "Modifikatoren wechseln sich ab (%d Varianten)" % rolled.size())
	Game.set_modifier(&"giants")
	var giant := Combatant.new()
	giant.setup_enemy(Registry.enemies[0])
	var normal_hp := Registry.enemies[0].max_health * Game.health_scale()
	_check(giant.max_health > normal_hp * 3.0 and giant.scale.x > 1.3, "Riesenwuchs: Gegner mit mehr Leben und größer")
	giant.free()
	Game.set_modifier(&"fog")
	var archer: Combatant = _arena._spawn_player(Registry.units["archer"], World.CENTER)
	archer.apply_round_modifier()
	_check(is_equal_approx(archer.attack_range, Registry.units["archer"].attack_range * 0.6), "Nebel: Fernkämpfer haben 60 %% Reichweite (%.0f)" % archer.attack_range)
	archer.reset_after_battle()
	_check(is_equal_approx(archer.attack_range, Registry.units["archer"].attack_range), "Nach dem Kampf ist die Reichweite wieder normal")
	archer.discard()
	Game.set_modifier(&"calm")
	_check(is_equal_approx(Modifiers.value("ability_cd"), 0.5) and is_equal_approx(Modifiers.value("gold"), 1.0), "Windstille: nur die Abklingzeit ändert sich")
	Game.set_modifier(&"")
	_check(is_equal_approx(Modifiers.value("regen"), 0.0) and is_equal_approx(Modifiers.value("spawn"), 1.0), "Ohne Modifikator ist alles neutral")
	var hud: Hud = _arena.get("_hud")
	Game.set_modifier(&"blood_moon")
	_check(hud._modifier_sign.visible and hud._modifier_title.text.contains("Blutmond"), "Schild kündigt den Modifikator an")
	Game.set_modifier(&"")
	_check(not hud._modifier_sign.visible, "Ohne Modifikator kein Schild")

	# Ereignisse zwischen den Runden
	await _test_round_events()
	# Geheimrezepte
	await _test_secret_recipes()
	# Veteranen
	await _test_veterans()

	# Gelände: erst viele Hindernisse, nach jedem Boss weniger
	_check(World.stage_for_round(5) == 0 and World.stage_for_round(6) == 1 and World.stage_for_round(15) == 1 \
			and World.stage_for_round(16) == 2, "Gelände wechselt nach Bossrunde 5, 15, 25 ...")
	World.set_stage(0)
	_check(World.obstacles.size() == 18, "Stufe 0 startet mit 18 Hindernissen (%d)" % World.obstacles.size())
	var full: Array[Dictionary] = World.obstacles.duplicate()
	World.set_stage(1)
	_check(World.obstacles.size() == 15 and World.obstacles == full.slice(0, 15), "Nach dem ersten Boss sind es 15, die übrigen bleiben stehen")
	World.set_stage(6)
	_check(World.obstacles.is_empty(), "Nach sechs Bossen ist das Feld frei")
	World.set_stage(0)
	var clear := true
	for obstacle in World.obstacles:
		var spot: Vector2 = obstacle["pos"]
		clear = clear and World.clamp_point(spot) != spot
		clear = clear and not World.CENTER_SQUARE.has_point(spot)
		clear = clear and World.contains(World.clamp_point(spot))
	_check(clear, "Hindernisse schieben Figuren weg und liegen nicht auf dem Platz")
	_arena.call("_build_obstacles")
	await get_tree().process_frame
	_check(get_tree().get_nodes_in_group(&"obstacle").size() == 18, "Hindernisse erscheinen als Bilder im Spiel")
	World.set_stage(0)
	_test_arenas()
	await _test_tutorial()
	await _test_run_save()

	Engine.time_scale = 1.0
	print("EVENTS-TEST ", "FEHLGESCHLAGEN" if _failed else "OK")
	get_tree().quit(1 if _failed else 0)


## "Alles verbinden": nur gleiche Paare, niedrigste Stufe zuerst, Freischaltrunde und Gold zählen.
func _test_merge_all() -> void:
	var peasant: UnitData = Registry.units["peasant"]
	var second: UnitData = peasant.upgrade
	var apprentice: UnitData = Registry.units["apprentice"]
	Game.gold = 1000
	for i in 5:
		_arena.buy_unit(peasant)
	_arena.buy_unit(apprentice)
	Game.gold = 1000
	_check(_arena.merge_all_plan() == Vector2i(2, 2 * peasant.upgrade_cost),
		"Runde 1: zwei Paare Stufe 1, Stufe 3 noch gesperrt (%s)" % _arena.merge_all_plan())
	Game.round_number = 2
	var cost := 2 * peasant.upgrade_cost + second.upgrade_cost
	_check(_arena.merge_all_plan() == Vector2i(3, cost), "Runde 2: danach auch die beiden Stufe-2 (%s)" % _arena.merge_all_plan())
	Game.gold = 2 * peasant.upgrade_cost + 1
	_check(_arena.merge_all_plan() == Vector2i(2, 2 * peasant.upgrade_cost), "Plan hört auf, wenn das Gold nicht reicht")
	Game.gold = 1000
	_check(_arena.merge_all() == 3 and Game.gold == 1000 - cost, "Alles verbinden führt den Plan aus (%dg bezahlt)" % (1000 - Game.gold))
	await get_tree().process_frame
	var types := {}
	for unit in _arena.get_player_units():
		types[unit.unit_data] = types.get(unit.unit_data, 0) + 1
	_check(types == {second.upgrade: 1, peasant: 1, apprentice: 1}, "Ergebnis: eine Stufe 3, Einzelstücke bleiben (%s)" % [types.size()])
	_check(_arena.merge_all_plan() == Vector2i.ZERO and _arena.merge_all() == 0, "Danach gibt es nichts mehr zu verbinden")
	Game.round_number = 1
	for unit in _arena.get_player_units():
		unit.discard()
	await get_tree().process_frame


## Hausausbau: Preis steigt, Einheiten der Kategorie werden stärker, Kombinationen anteilig.
func _test_houses() -> void:
	var peasant: UnitData = Registry.units["peasant"]
	var unit: Combatant = _arena.call("_spawn_player", peasant, Vector2(320, 180))
	var health := unit.max_health
	Game.gold = Game.HOUSE_BASE_PRICE - 1
	_check(not Game.upgrade_house(peasant.category) and Game.house_level(peasant.category) == 0, "Ausbau ohne genug Gold geht nicht")
	Game.gold = 1000
	_check(Game.upgrade_house(peasant.category) and Game.gold == 1000 - Game.HOUSE_BASE_PRICE, "Ausbau Stufe 1 kostet %dg" % Game.HOUSE_BASE_PRICE)
	_check(Game.house_price(peasant.category) > Game.HOUSE_BASE_PRICE, "Nächste Stufe ist teurer (%dg)" % Game.house_price(peasant.category))
	_check(is_equal_approx(unit.max_health, health * (1.0 + Game.HOUSE_BONUS_PER_LEVEL)), "Vorhandene Einheit wird stärker (%.1f -> %.1f)" % [health, unit.max_health])
	# Kombination aus Kaserne und einem anderen Haus: zählt nach dem Anteil ihrer Grundeinheiten.
	var mixed: UnitData = null
	var share := 0.0
	for recipe in Registry.recipes:
		var bundle: Dictionary = Registry.base_units(recipe.result)
		var own := 0
		for base: UnitData in bundle:
			own += bundle[base] if base.category == peasant.category else 0
		if own > 0 and own < Registry.bundle_size(bundle):
			mixed = recipe.result
			share = float(own) / Registry.bundle_size(bundle)
			break
	_check(mixed != null and is_equal_approx(Game.house_factor(mixed), 1.0 + Game.HOUSE_BONUS_PER_LEVEL * share),
		"Kombination zählt anteilig (%s: %.3f)" % [mixed.id if mixed else "-", Game.house_factor(mixed)])
	var other: UnitData = Registry.shop_units().filter(func(u: UnitData) -> bool: return u.category != peasant.category)[0]
	_check(Game.house_factor(other) == 1.0, "Andere Häuser bleiben unverändert")
	unit.discard()
	Game.house_levels = {}
	Game.call("_reset_house_cache")


## Linien der Dorfhäuser erst ab Ausbaustufe, höhere Stufen ab Runde Game.DIRECT_BUY_ROUND direkt.
func _test_house_lines_and_direct_buy() -> void:
	var spearman: UnitData = Registry.units["spearman"]
	var house_lines := Registry.shop_units().filter(func(u: UnitData) -> bool: return u.house_level > 0)
	var categories := {}
	for unit: UnitData in house_lines:
		categories[unit.category] = true
	_check(categories.size() == Village.HOUSES.size(), "Jedes Haus hat eine Linie, die erst der Ausbau freischaltet (%d)" % categories.size())
	Game.gold = 1000
	_check(not _arena.buy_unit(spearman) and Game.gold == 1000, "Speerträger ohne Ausbau nicht kaufbar")
	for i in spearman.house_level:
		Game.upgrade_house(spearman.category)
	Game.gold = 1000
	_check(_arena.buy_unit(spearman) and Game.gold == 1000 - spearman.price, "Nach Ausbau Stufe %d kaufbar" % spearman.house_level)
	var peasant: UnitData = Registry.units["peasant"]
	var second: UnitData = peasant.upgrade
	var expected := roundi((2 * peasant.price + peasant.upgrade_cost) * Game.DIRECT_BUY_MARKUP)
	_check(Registry.shop_price(second) == expected, "Stufe 2 kostet Zutaten plus Aufschlag (%dg)" % Registry.shop_price(second))
	Game.round_number = Game.DIRECT_BUY_ROUND - 1
	_check(not _arena.buy_unit(second), "Stufe 2 vor Runde %d nicht direkt kaufbar" % Game.DIRECT_BUY_ROUND)
	Game.round_number = Game.DIRECT_BUY_ROUND
	Game.gold = 1000
	_check(_arena.buy_unit(second) and Game.gold == 1000 - expected, "Ab Runde %d: Stufe 2 direkt gekauft" % Game.DIRECT_BUY_ROUND)
	_check(_arena.buy_unit(second.upgrade), "Stufe 3 direkt kaufbar")
	_check(not _arena.buy_unit(second.upgrade.upgrade), "Stufe 4 nur durch Verbinden")
	_check(Registry.line_levels(peasant).size() == Game.DIRECT_BUY_MAX_LEVEL, "Dorf bietet %d Stufen je Linie an" % Game.DIRECT_BUY_MAX_LEVEL)
	Game.round_number = 1
	Game.house_levels = {}
	Game.call("_reset_house_cache")
	for unit in _arena.get_player_units():
		unit.discard()
	await get_tree().process_frame


## Gegner wachsen ab Runde 10 zusätzlich aufeinander aufbauend.
func _test_late_scaling() -> void:
	Game.round_number = 10
	var linear := 1.0 + Game.HEALTH_SCALE_PER_ROUND * 9
	_check(is_equal_approx(Game.health_scale(), linear), "Bis Runde 10 wächst das Leben linear")
	Game.round_number = 12
	_check(is_equal_approx(Game.health_scale(), (1.0 + Game.HEALTH_SCALE_PER_ROUND * 11) * pow(Game.LATE_HEALTH_GROWTH, 2)),
		"Ab Runde 11 kommt der späte Zuwachs dazu (%.2f)" % Game.health_scale())
	_check(Game.damage_scale() > 1.0 + Game.DAMAGE_SCALE_PER_ROUND * 11, "Auch der Schaden wächst später schneller")
	Game.round_number = 1


func _test_round_events() -> void:
	for unit: Combatant in _arena.get_player_units():
		unit.discard()
	await get_tree().process_frame
	Game.set_phase(Game.Phase.BUILD)
	Game.round_number = 6
	Game.set_modifier(&"")
	Game.blessings = {}
	_check(not RoundEvents.should_offer(2, 99), "Vor Runde 3 gibt es keine Ereignisse")
	_check(RoundEvents.should_offer(6, RoundEvents.PITY), "Nach %d Runden ohne Ereignis kommt sicher eins" % RoundEvents.PITY)
	var knight: Combatant = _arena._spawn_player(Registry.units["knight"], World.CENTER)
	var archer: Combatant = _arena._spawn_player(Registry.units["archer"], World.CENTER + Vector2(20, 0))
	var peasant: Combatant = _arena._spawn_player(Registry.units["peasant"], World.CENTER + Vector2(-20, 0))
	Game.gold = 500
	var all_ok := true
	for id: StringName in RoundEvents.WEIGHTS:
		var offer := RoundEvents.build(id, _arena)
		all_ok = all_ok and not offer.is_empty() and offer["title"] != "" and offer["text"] != ""
	_check(all_ok, "Alle %d Ereignisse lassen sich bauen" % RoundEvents.WEIGHTS.size())
	var offers := RoundEvents.offers(_arena)
	var ids := offers.map(func(o: Dictionary) -> StringName: return o["id"])
	_check(offers.size() == 3 and ids[0] != ids[1] and ids[1] != ids[2] and ids[0] != ids[2], "Drei verschiedene Angebote")

	var gold := Game.gold
	_check(RoundEvents.apply(RoundEvents.build(&"treasure", _arena), _arena) != "" and Game.gold == gold + 8 + 2 * 6, "Schatztruhe gibt Gold")
	var smith := RoundEvents.build(&"smith", _arena)
	smith["data"]["group"] = &"melee"
	var attack_before := knight.attack
	gold = Game.gold
	RoundEvents.apply(smith, _arena)
	_check(is_equal_approx(knight.attack, attack_before * 1.2) and Game.gold == gold - smith["cost"], "Schmied: Nahkämpfer +20 %% Stärke, kostet Gold")
	_check(is_equal_approx(archer.attack, Registry.units["archer"].attack), "Schmied wirkt nicht auf Fernkämpfer")
	var fresh: Combatant = _arena._spawn_player(Registry.units["knight"], World.CENTER + Vector2(0, 20))
	_check(is_equal_approx(fresh.attack, Registry.units["knight"].attack * 1.2), "Segen gilt auch für später gekaufte Einheiten")
	fresh.discard()
	var count: int = _arena.get_player_units().size()
	var witch := RoundEvents.build(&"witch", _arena)
	var victim: Combatant = witch["data"]["unit"]
	var lowest := INF
	for unit: Combatant in _arena.get_player_units():
		lowest = minf(lowest, unit.max_health)
	_check(is_equal_approx(victim.max_health, lowest), "Hexe wählt die Einheit mit den wenigsten Lebenspunkten")
	var hp_before := knight.max_health
	RoundEvents.apply(witch, _arena)
	await get_tree().process_frame
	_check(_arena.get_player_units().size() == count - 1 and not is_instance_valid(victim), "Hexe nimmt ihr Opfer")
	_check(is_equal_approx(knight.max_health, hp_before * 1.1), "Hexe: alle anderen +10 %% Leben")
	var trainer := RoundEvents.build(&"trainer", _arena)
	var trainee: Combatant = trainer["data"]["unit"]
	var target: UnitData = trainee.unit_data.upgrade
	RoundEvents.apply(trainer, _arena)
	await get_tree().process_frame
	_check(_arena.get_player_units().any(func(u: Combatant) -> bool: return u.unit_data == target), "Ausbilder: Einheit steigt eine Stufe auf")
	count = _arena.get_player_units().size()
	RoundEvents.apply(RoundEvents.build(&"recruit", _arena), _arena)
	_check(_arena.get_player_units().size() == count + 1, "Rekrut kommt dazu")
	RoundEvents.apply(RoundEvents.build(&"shrine", _arena), _arena)
	_check(Game.modifier == &"holy_ground", "Schrein: nächste Runde Heilige Erde")
	gold = Game.gold
	RoundEvents.apply(RoundEvents.build(&"pact", _arena), _arena)
	_check(Game.modifier == &"giants" and Game.gold > gold, "Dunkler Pakt: Gold, aber Riesenwuchs")
	Game.gold = 0
	var gamble := RoundEvents.build(&"gamble", _arena)
	_check(not gamble["enabled"] and RoundEvents.apply(gamble, _arena) == "", "Ohne Gold kein Glücksspiel")
	# Fenster: Start-Knopf ist gesperrt, solange es offen ist
	var hud: Hud = _arena.get("_hud")
	Game.gold = 500
	hud.show_event(RoundEvents.offers(_arena))
	_check(hud.event_open() and hud._start_button.disabled, "Ereignisfenster offen: Kampf starten gesperrt")
	hud._events.chosen.emit(RoundEvents.build(&"treasure", _arena))
	hud._events.close_panel()
	hud._refresh()
	_check(not hud._start_button.disabled, "Nach der Wahl ist der Start-Knopf wieder frei")
	Game.blessings = {}
	Game.set_modifier(&"")
	Game.round_number = 1
	for unit: Combatant in _arena.get_player_units():
		unit.discard()
	await get_tree().process_frame


func _test_secret_recipes() -> void:
	Progress.reset()
	var secrets := Registry.recipes.filter(func(r: RecipeData) -> bool: return r.secret)
	_check(secrets.size() == 6 and Progress.secret_count() == 6, "Es gibt 6 Geheimrezepte (%d)" % secrets.size())
	var arthur: RecipeData = Registry.find_recipe(Registry.units["knight"], Registry.units["unicorn"])
	_check(arthur != null and arthur.secret and Progress.is_hidden(arthur), "Ritter + Einhorn ist ein verborgenes Geheimrezept")
	var hud: Hud = _arena.get("_hud")
	var book: RecipeBook = hud._book
	book.open_book()
	book.set_query("artus")
	_check(book.match_count(0) == 0, "Im Buch verrät die Suche den Namen nicht")
	book.set_query("geheim")
	_check(book.match_count(0) == 6, "Das Buch zeigt 6 verborgene Geheimrezepte (%d)" % book.match_count(0))
	book.set_query("")
	book.close_book()
	# Hinweise beim Anfassen nennen das Geheimrezept nicht
	Game.set_phase(Game.Phase.BUILD)
	Game.round_number = 10
	Game.gold = 500
	var knight: Combatant = _arena._spawn_player(Registry.units["knight"], World.CENTER)
	var unicorn: Combatant = _arena._spawn_player(Registry.units["unicorn"], World.CENTER + Vector2(30, 0))
	_arena._show_recipe_hints(knight)
	var hinted := false
	for row: Dictionary in hud._hint_rows:
		hinted = hinted or (row["row"].visible and row["title"].text == arthur.result.display_name)
	_check(not hinted, "Rezeptliste beim Anfassen verrät das Geheimrezept nicht")
	hud.hide_recipe_hints()
	# Vorschau beim Ziehen: Ergebnis bleibt "???"
	knight.position = unicorn.position + Vector2(4, 0)
	_arena._dragging = knight
	var text: String = _arena._merge_preview(knight)
	_arena._dragging = null
	_check(text.begins_with("???") and hud._merge_cards[2]["title"].text == "???", "Vorschau zeigt nur ??? (%s)" % text)
	hud.hide_merge_preview()
	# Verbinden entdeckt das Rezept
	Achievements.reset()
	_check(_arena.try_merge(knight, unicorn), "Ritter + Einhorn lassen sich verbinden")
	_check(not Progress.is_hidden(arthur) and Achievements.is_unlocked(&"first_secret"), "Rezept ist entdeckt, Erfolg 'Entdecker'")
	_check(hud._banner.text.contains(arthur.result.display_name), "Meldung nennt das entdeckte Rezept")
	book.open_book()
	book.set_query("artus")
	_check(book.match_count(0) == 1, "Nach dem Entdecken steht König Artus im Buch")
	book.set_query("geheim")
	_check(book.match_count(0) == 5, "Noch 5 verborgene Geheimrezepte")
	book.set_query("")
	book.close_book()
	# Händler bietet nie Geheimrezepte an
	var secret_offered := false
	for i in 200:
		var offer := RoundEvents.build(&"merchant", _arena)
		if not offer.is_empty():
			secret_offered = secret_offered or Registry.recipes.any(func(r: RecipeData) -> bool: return r.secret and r.result == offer["data"]["unit"])
	_check(not secret_offered, "Wanderhändler bietet keine Geheimrezepte an")
	Progress.reset()
	Achievements.reset()
	Game.round_number = 1
	for unit: Combatant in _arena.get_player_units():
		unit.discard()
	await get_tree().process_frame


## Bossarenen: eigene Grundrisse, Platz in der Mitte und alle Tore begehbar, Hindernisse nicht im Weg.
func _test_arenas() -> void:
	_check(World.layout_for_round(4) == &"cross" and World.layout_for_round(6) == &"cross"
			and World.layout_for_round(10) == &"cross", "Normale Runden und Bonusrunden spielen im Kreuz")
	var bosses := [World.layout_for_round(5), World.layout_for_round(15), World.layout_for_round(25)]
	_check(not bosses.has(&"cross") and bosses[0] != bosses[1] and bosses[1] != bosses[2] and bosses[0] != bosses[2]
			and World.layout_for_round(35) == bosses[0], "Bossrunden wechseln reihum die Arena (%s)" % [bosses])
	for round_number in [1, 5, 6, 15, 16, 25, 26, 36, 46]:
		World.set_round(round_number)
		var name := World.layout_name
		var ok := World.terrain != null
		for corner in [World.CENTER_SQUARE.position, World.CENTER_SQUARE.end,
				Vector2(World.CENTER_SQUARE.position.x, World.CENTER_SQUARE.end.y), Vector2(World.CENTER_SQUARE.end.x, World.CENTER_SQUARE.position.y)]:
			ok = ok and World.contains(corner)
		_check(ok, "Arena %s (Runde %d): Bild da, Platz in der Mitte begehbar" % [name, round_number])
		var gates := true
		for arm in World.Arm.values():
			for i in 5:
				var spot := World.spawn_point(arm)
				gates = gates and World.contains(spot) and World.clamp_point(spot).distance_to(spot) < 0.01 \
						and spot.distance_to(World.CENTER) > 80.0
		_check(gates, "Arena %s: alle Tore liegen auf dem Boden, frei und weit genug von der Mitte" % name)
		var free := true
		for obstacle in World.obstacles:
			var spot: Vector2 = obstacle["pos"]
			free = free and World.contains(spot) and not World.CENTER_SQUARE.grow(16.0).has_point(spot)
		_check(free, "Arena %s: Hindernisse stehen auf dem Boden und nicht auf dem Platz" % name)
		# Von jedem Tor aus kommt man zur Mitte: Schritte entlang clamp_point bleiben nicht hängen.
		var reach := true
		for arm in World.Arm.values():
			var pos := World.spawn_point(arm)
			for step in 400:
				pos = World.clamp_point(pos + (World.CENTER - pos).limit_length(2.0))
			reach = reach and pos.distance_to(World.CENTER) < 40.0
		_check(reach, "Arena %s: Gegner finden von jedem Tor zur Mitte" % name)
	World.set_round(1)


func _test_veterans() -> void:
	Game.set_phase(Game.Phase.BUILD)
	Game.blessings = {}
	Game.round_number = 10
	Game.gold = 500
	Achievements.reset()
	var knight: Combatant = _arena._spawn_player(Registry.units["knight"], World.CENTER)
	var base_hp := knight.max_health
	_check(knight.veteran_level == 1 and knight.veteran_ability == &"", "Neue Einheiten sind Veteranenstufe 1 ohne Zusatzfähigkeit")
	knight.gain_xp(3)
	_check(knight.veteran_level == 2 and knight.max_health > base_hp, "3 Erfahrung: Stufe 2, mehr Leben")
	knight.gain_xp(15)
	_check(knight.veteran_level == 5 and knight.veteran_ability == &"war_cry", "Stufe 5: Veteranenfähigkeit (%s)" % knight.veteran_ability)
	_check(Achievements.is_unlocked(&"veteran_5"), "Erfolg 'Kampferprobt'")
	knight.gain_xp(1000)
	_check(knight.veteran_level == Combatant.VETERAN_MAX and knight.veteran_progress() == [0, 0], "Höchstens Stufe 10")
	_check(is_equal_approx(knight.max_health, base_hp * (1.0 + Combatant.VETERAN_BONUS * 9)), "Stufe 10: +36 %% Leben")
	var archer: Combatant = _arena._spawn_player(Registry.units["archer"], World.CENTER + Vector2(30, 0))
	archer.set_xp(18)
	_check(archer.veteran_ability == &"frost_nova", "Fernkämpfer mit Pfeilregen bekommen Frostnova (%s)" % archer.veteran_ability)
	# Erfahrung durch Besiegen
	var foe := Combatant.new()
	foe.setup_enemy(Registry.enemies[0])
	_arena.add_child(foe)
	var before := archer.xp
	foe.take_damage(99999.0, archer)
	_check(archer.xp == before + Combatant.XP_KILL, "Besiegter Gegner gibt dem Schützen Erfahrung")
	# Heiler bekommen Erfahrung für Heilung (aber nicht für Selbstheilung)
	var healer: Combatant = _arena._spawn_player(Registry.units["healer"], World.CENTER + Vector2(60, 0))
	var patient: Combatant = _arena._spawn_player(Registry.units["knight"], World.CENTER + Vector2(90, 0))
	var heal_before := healer.xp
	for i in 6:
		patient.health = 1.0
		patient.heal(patient.max_health, healer)
	_check(healer.xp > heal_before, "Heilen gibt dem Heiler Erfahrung (%d)" % (healer.xp - heal_before))
	var self_xp := healer.xp
	healer.health = 1.0
	healer.heal(healer.max_health, healer)
	_check(healer.xp == self_xp, "Selbstheilung gibt keine Erfahrung")
	# Verbinden: das Ergebnis behält die Erfahrung
	var a: Combatant = _arena._spawn_player(Registry.units["peasant"], World.CENTER + Vector2(0, 30))
	var b: Combatant = _arena._spawn_player(Registry.units["peasant"], World.CENTER + Vector2(10, 30))
	a.set_xp(12)
	b.set_xp(4)
	_arena.try_merge(a, b)
	await get_tree().process_frame
	var squires: Array = _arena.get_player_units().filter(func(u: Combatant) -> bool: return u.unit_data.id == &"squire")
	_check(squires.size() == 1 and squires[0].xp == 12 and squires[0].veteran_level == 4, "Verbundene Einheit behält die höhere Erfahrung")
	# Veteranenfähigkeit im Kampf
	Game.set_phase(Game.Phase.BATTLE)
	_arena._spawn_timer = 99999.0
	var dummy := Combatant.new()
	dummy.setup_enemy(Registry.enemies[0])
	dummy.position = knight.position + Vector2(20, 0)
	dummy.move_speed = 0.0
	dummy.attack = 0.0
	dummy.max_health = 99999.0
	dummy.health = 99999.0
	_arena.add_child(dummy)
	knight._veteran_cd = 0.0
	var casts := knight.ability_casts
	_check(knight.cast_veteran() and knight.ability_casts == casts + 1 and knight.has_effect(&"buff"), "Kriegsschrei als Veteranenfähigkeit wirkt")
	_check(not knight.veteran_ready(), "Danach lädt die Veteranenfähigkeit")
	var hud: Hud = _arena.get("_hud")
	hud.show_unit_card(knight)
	_check(hud._card.xp_text.text.contains("10") and hud._card.ability_label.text.contains("Veteran"), "Karte zeigt Veteranenstufe und Fähigkeit")
	_arena._clear_enemies()
	Game.set_phase(Game.Phase.BUILD)
	# Überleben einer Runde bringt Erfahrung
	var survivor: Combatant = _arena._spawn_player(Registry.units["mage"], World.CENTER)
	Game.set_phase(Game.Phase.BATTLE)
	_arena._end_round()
	_check(survivor.xp == Combatant.XP_SURVIVE, "Überlebte Runde: +%d Erfahrung" % Combatant.XP_SURVIVE)
	hud._events.close_panel()
	Achievements.reset()
	Game.round_number = 1
	for unit: Combatant in _arena.get_player_units():
		unit.discard()
	await get_tree().process_frame


func _wait_battle_end() -> void:
	while Game.phase == Game.Phase.BATTLE:
		await get_tree().physics_frame


func _check(ok: bool, text: String) -> void:
	print(("ok:   " if ok else "FAIL: ") + text)
	if not ok:
		_failed = true


## Spielstand: Lauf speichern, in eine Testdatei schreiben, zurücklesen und wieder herstellen; dazu der Rekord.
func _test_run_save() -> void:
	for unit in _arena.get_player_units():
		unit.discard()
	await get_tree().process_frame
	Game.round_number = 7
	Game.gold = 123
	Game.set_modifier(&"blood_moon")
	Game.blessings = {}
	Game.add_blessing(&"melee", "hp", 1.25)
	Game.house_levels = {"Klassisch": 2}
	Game.stats["kills"] = 42
	Game.auto_abilities = false
	_arena.set("_rounds_without_event", 2)
	var knight: Combatant = _arena.call("_spawn_player", Registry.units["knight"], Vector2(300, 180))
	knight.set_xp(20)
	_arena.call("_spawn_player", Registry.units["mage"], Vector2(320, 190))
	var group := knight.style_group()
	var offers: Array[Dictionary] = [RoundEvents.build(&"recruit", _arena, {"unit": Registry.units["peasant"]}),
			RoundEvents.build(&"smith", _arena, {"group": group}), RoundEvents.build(&"treasure", _arena)]
	_check(offers[0]["data"]["unit"] == Registry.units["peasant"] and offers[1]["data"]["group"] == group,
			"Ereignis-Angebote lassen sich mit fester Wahl bauen")
	var data := RunSave.capture(_arena, offers)
	var old_path := RunSave.path
	RunSave.path = "user://test_run.cfg"
	RunSave.enabled = true
	RunSave.write(data)
	var loaded := RunSave.read()
	_check(RunSave.exists() and loaded.get("round") == 7 and loaded.get("gold") == 123 and loaded.get("event_pending") == true,
			"Spielstand wird geschrieben und gelesen")
	Game.reset()
	RunSave.apply_game(loaded)
	_check(Game.round_number == 7 and Game.gold == 123 and Game.modifier == &"blood_moon" and not Game.auto_abilities,
			"Runde, Gold, Modifikator und Automatik kommen zurück")
	_check(is_equal_approx(Game.blessing(&"melee", "hp"), 1.25) and Game.house_level("Klassisch") == 2 and int(Game.stats["kills"]) == 42,
			"Segen, Hausausbau und Auswertung kommen zurück")
	var units := RunSave.units(loaded)
	_check(units.size() == 2 and units[0]["data"] == Registry.units["knight"] and units[0]["xp"] == 20 \
			and units[0]["position"] == Vector2(300, 180), "Einheiten mit Ort und Erfahrung kommen zurück")
	loaded["units"].append({"id": "gibt_es_nicht", "x": 0.0, "y": 0.0, "xp": 0})
	_check(RunSave.units(loaded).size() == 2, "Unbekannte Einheiten im Spielstand fallen weg")
	# Wie "Fortsetzen" im Menü: neue Arena lädt den Stand und stellt die Einheiten auf.
	_arena.queue_free()
	await get_tree().process_frame
	RunSave.write(data)
	Game.resume_requested = true
	_arena = load("res://scenes/main.tscn").instantiate()
	add_child(_arena)
	await get_tree().process_frame
	var resumed: Array[Combatant] = _arena.get_player_units()
	_check(not Game.resume_requested and Game.round_number == 7 and Game.gold == 123 and resumed.size() == 2 \
			and resumed.any(func(u: Combatant) -> bool: return u.unit_data.id == &"knight" and u.xp == 20),
			"Fortsetzen stellt Runde, Gold und Einheiten wieder her")
	var again: Array[Dictionary] = (_arena.get("_hud") as Hud).event_offers()
	_check(int(_arena.get("_rounds_without_event")) == 2 and again.size() == 3 and again[0]["id"] == &"recruit" \
			and again[0]["data"]["unit"] == Registry.units["peasant"] and again[1]["data"]["group"] == group \
			and again[2]["id"] == &"treasure", "Fortsetzen bietet dieselben Ereignis-Angebote wieder an")
	_arena.save_run()
	_check(RunSave.read().get("units", []).size() == 2, "Arena speichert den Lauf mit allen Einheiten")
	_arena.call("_game_over")
	_check(not RunSave.exists(), "Niederlage löscht den Spielstand")
	RunSave.write(data)
	loaded["format"] = RunSave.FORMAT + 1
	RunSave.write(loaded)
	_check(RunSave.read().is_empty(), "Spielstand in fremdem Format wird ignoriert")
	RunSave.clear()
	_check(not RunSave.exists(), "Spielstand lässt sich löschen")
	RunSave.path = old_path
	RunSave.enabled = false
	Game.auto_abilities = true
	Game.set_modifier(&"")

	var best := Progress.best_round
	_check(Progress.record_round(best + 1) and not Progress.record_round(best + 1) and Progress.best_round == best + 1,
			"Rekord steigt nur bei einer höheren Runde")
	Progress.best_round = best


## Einstieg: Hinweise folgen den Schritten Kaufen, Verbinden, Kampf starten, Runde überstehen.
func _test_tutorial() -> void:
	for unit in _arena.get_player_units():
		unit.discard()
	Game.reset()
	await get_tree().process_frame
	await get_tree().process_frame  # _process des Hinweises läuft nach process_frame
	Progress.tutorial_done = false
	var tutorial: Tutorial = _arena.start_tutorial()
	await get_tree().process_frame
	await get_tree().process_frame  # _process des Hinweises läuft nach process_frame
	_check(tutorial.step == 0 and tutorial.visible, "Einstieg beginnt mit dem Kaufen")
	var peasant: UnitData = Registry.units["peasant"]
	Game.gold = 100
	_arena.buy_unit(peasant)
	_arena.buy_unit(peasant)
	await get_tree().process_frame
	await get_tree().process_frame  # _process des Hinweises läuft nach process_frame
	_check(tutorial.step == 1, "Nach dem Kauf folgt das Verbinden (Schritt %d)" % tutorial.step)
	var units: Array[Combatant] = _arena.get_player_units()
	_arena.try_merge(units[0], units[1])
	await get_tree().process_frame
	await get_tree().process_frame  # _process des Hinweises läuft nach process_frame
	_check(tutorial.step == 2, "Nach dem Verbinden folgt der Kampfstart (Schritt %d)" % tutorial.step)
	(_arena.get("_hud") as Hud).set_paused(false)
	_arena.start_battle()
	await get_tree().process_frame
	await get_tree().process_frame  # _process des Hinweises läuft nach process_frame
	_check(tutorial.step == 3, "Im Kampf folgt der letzte Hinweis (Schritt %d)" % tutorial.step)
	var hud: Hud = _arena.get("_hud")
	hud.set_paused(true)
	await get_tree().process_frame
	await get_tree().process_frame
	_check(get_tree().paused and hud.is_paused() and not tutorial.visible, "Pause hält den Kampf an und verdeckt den Hinweis")
	hud.handle_back()
	_check(not get_tree().paused, "Zurück setzt den Kampf fort")
	_arena.events_enabled = false
	_arena.call("_end_round")
	await get_tree().process_frame
	await get_tree().process_frame  # _process des Hinweises läuft nach process_frame
	_check(not is_instance_valid(tutorial) and Progress.tutorial_done, "Nach der ersten Runde ist der Einstieg vorbei")
	hud.set_paused(true)
	_check(not get_tree().paused, "In der Bauphase gibt es keine Pause")
	_arena.events_enabled = true
