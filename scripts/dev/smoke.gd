extends Node
## Entwickler-Test: spielt automatisch Runden durch und gibt den Verlauf aus.
## Start: godot --headless res://scenes/dev/smoke.tscn [-- --rounds=20]
## Mit mehr Runden dient er zum Abstimmen: je Runde Armee (Summe Leben x Stärke) und Gegnerfaktor.
## Prüft dabei Regeln, die unabhängig vom Zufall gelten (Gold nie negativ, Einheitenlimit, Auswertung),
## und endet mit "SMOKE-TEST OK" oder Zeilen mit "FAIL".

const DEFAULT_ROUNDS := 12
const TIME_SCALE := 10.0

var _arena: Node2D
## Wie ein Mensch: auf wenige Linien konzentrieren, damit Paare zum Mergen entstehen.
var _focus: Array[UnitData] = []
var _max_rounds := DEFAULT_ROUNDS
var _failed := false
var _min_gold := 0
var _rounds_played := 0


func _ready() -> void:
	Engine.time_scale = TIME_SCALE
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--rounds="):
			_max_rounds = int(arg.get_slice("=", 1))
	_arena = load("res://scenes/main.tscn").instantiate()
	add_child(_arena)
	await get_tree().process_frame
	Game.gold_changed.connect(func(gold: int) -> void: _min_gold = mini(_min_gold, gold))
	_check_recipe_book()
	await _play()
	await get_tree().process_frame  # _end_round läuft nach dem Phasenwechsel noch zu Ende (Rekord)
	_check_result()
	Engine.time_scale = 1.0
	print("SMOKE-TEST FAIL" if _failed else "SMOKE-TEST OK")
	get_tree().quit(1 if _failed else 0)


func _check(condition: bool, label: String) -> void:
	if not condition:
		_failed = true
		print("FAIL: " + label)


## Nach dem Lauf: Regeln, die bei jedem Verlauf gelten müssen.
func _check_result() -> void:
	_check(_rounds_played > 0, "Mindestens ein Kampf wurde gespielt")
	_check(_min_gold >= 0, "Gold war nie negativ (Minimum %d)" % _min_gold)
	_check(Game.phase == Game.Phase.GAME_OVER or Game.round_number > _max_rounds, "Lauf endet mit Niederlage oder nach allen Runden")
	_check(Game.round_number == _rounds_played + (0 if Game.phase == Game.Phase.GAME_OVER else 1),
			"Rundenzähler passt zu den gespielten Kämpfen")
	var stats := Game.stats
	_check(int(stats["kills"]) >= 0 and int(stats["gold"]) >= int(stats["kills"]), "Auswertung: Gold mindestens so groß wie die Zahl der Gegner")
	_check(Registry.units.has(StringName(stats["best_unit"])), "Auswertung kennt die stärkste Einheit (%s)" % stats["best_unit"])
	_check(Progress.best_round >= Game.round_number, "Rekord mindestens die erreichte Runde")


func _play() -> void:
	while Game.phase == Game.Phase.BUILD and Game.round_number <= _max_rounds:
		_merge_units()
		_buy_units()
		_merge_units()
		_upgrade_houses()
		var units: Array[Combatant] = _arena.get_player_units()
		var power := 0.0
		for unit in units:
			power += unit.max_health * unit.attack
		print("Runde %d: %d Einheiten, %d Gold übrig, Armee %d, Gegner x%.2f LP x%.2f Schaden, Häuser %s" % [
			Game.round_number, units.size(), Game.gold, roundi(power), Game.health_scale(), Game.damage_scale(), Game.house_levels])
		_check(units.size() <= Game.MAX_UNITS, "Höchstens %d Einheiten im Kampf" % Game.MAX_UNITS)
		if not _arena.start_battle():
			_check(false, "Kampf konnte nicht starten")
			return
		_rounds_played += 1
		await Game.phase_changed
		if Game.phase == Game.Phase.GAME_OVER:
			print("Verloren in Runde %d" % Game.round_number)
			return
	print("Ende bei Runde %d, Gold %d" % [Game.round_number, Game.gold])


func _buy_units() -> void:
	if _focus.is_empty():
		var shop: Array[UnitData] = []
		shop.assign(Registry.shop_units().filter(func(u: UnitData) -> bool: return Registry.buy_block_reason(u) == ""))
		shop.shuffle()
		_focus = shop.slice(0, 3)
		print("Fokus: ", ", ".join(_focus.map(func(u: UnitData) -> String: return u.display_name)))
	# Gold für einen Merge zurückhalten, wenn schon ein Paar steht. Mehr als das Kampflimit bringt nichts.
	while _arena.get_player_units().size() < Game.MAX_UNITS:
		var affordable := _focus.filter(func(u: UnitData) -> bool: return u.price <= Game.gold)
		if affordable.is_empty() or not _arena.buy_unit(affordable.pick_random()):
			return
		_merge_units()


func _merge_units() -> void:
	var merged := true
	while merged:
		merged = false
		var units: Array[Combatant] = _arena.get_player_units()
		for a in units:
			for b in units:
				if a == b:
					continue
				var recipe := Registry.find_recipe(a.unit_data, b.unit_data)
				if recipe != null and recipe.unlock_round <= Game.round_number and recipe.merge_cost <= Game.gold:
					_arena.try_merge(a, b)
					merged = true
					break
			if merged:
				break


## Übriges Gold in die Häuser der eigenen Linien, immer das billigste zuerst.
func _upgrade_houses() -> void:
	var categories: Array[String] = []
	for unit in _focus:
		if not categories.has(unit.category):
			categories.append(unit.category)
	while true:
		categories.sort_custom(func(a: String, b: String) -> bool: return Game.house_price(a) < Game.house_price(b))
		if not Game.upgrade_house(categories[0]):
			return


## Rezeptbuch öffnen, filtern und schließen (fängt Fehler beim Aufbau ab).
func _check_recipe_book() -> void:
	var book: RecipeBook = _arena.get("_hud")._book
	book.open_book()
	book.set_query("golem")
	print("Rezeptbuch: %d Rezepte, %d Linien, bei 'golem' %d Rezepte auf %d Seiten" % [
		book.entry_count(0), book.entry_count(1), book.match_count(0), book.page_count()])
	_check(book.entry_count(0) > 0 and book.entry_count(1) > 0 and book.match_count(0) > 0, "Rezeptbuch zeigt Rezepte und Linien")
	book.set_query("")
	book.close_book()
