extends Node
## Entwickler-Test: spielt automatisch Runden durch und gibt den Verlauf aus.
## Start: godot --headless res://scenes/dev/smoke.tscn [-- --rounds=20]
## Mit mehr Runden dient er zum Abstimmen: je Runde Armee (Summe Leben x Stärke) und Gegnerfaktor.

const DEFAULT_ROUNDS := 12
const TIME_SCALE := 10.0

var _arena: Node2D
## Wie ein Mensch: auf wenige Linien konzentrieren, damit Paare zum Mergen entstehen.
var _focus: Array[UnitData] = []
var _max_rounds := DEFAULT_ROUNDS


func _ready() -> void:
	Engine.time_scale = TIME_SCALE
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--rounds="):
			_max_rounds = int(arg.get_slice("=", 1))
	_arena = load("res://scenes/main.tscn").instantiate()
	add_child(_arena)
	await get_tree().process_frame
	_check_recipe_book()
	await _play()
	Engine.time_scale = 1.0
	get_tree().quit()


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
		if not _arena.start_battle():
			print("Kampf konnte nicht starten")
			return
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
	book.set_query("")
	book.close_book()
