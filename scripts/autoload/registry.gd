extends Node
## Lädt alle Einheiten, Rezepte und Gegner aus data/ (Autoload "Registry").

var units: Dictionary = {}
var recipes: Array[RecipeData] = []
var enemies: Array[EnemyData] = []
var bosses: Array[EnemyData] = []
## Vorstufe jeder Einheit (zwei davon ergeben sie durch Selbst-Merge).
var _previous: Dictionary = {}
## Deutsche Originalnamen (Datei-Inhalt): Resource -> [display_name, line_name]. Siehe relocalize().
var _german_names: Dictionary = {}


func _ready() -> void:
	for res in _load_all("res://data/units"):
		if res is UnitData:
			units[res.id] = res
	for res in _load_all("res://data/recipes"):
		if res is RecipeData:
			recipes.append(res as RecipeData)
	# Selbst-Merge: zwei gleiche Einheiten ergeben die nächste Stufe.
	for unit in units.values():
		if unit.upgrade != null:
			_previous[unit.upgrade] = unit
			var recipe := RecipeData.new()
			recipe.ingredient_a = unit
			recipe.ingredient_b = unit
			recipe.result = unit.upgrade
			recipe.merge_cost = unit.upgrade_cost
			recipe.unlock_round = unit.upgrade.unlock_round
			recipes.append(recipe)
	for res in _load_all("res://data/enemies"):
		if res is EnemyData:
			(bosses if (res as EnemyData).is_boss else enemies).append(res as EnemyData)
	bosses.sort_custom(func(a: EnemyData, b: EnemyData) -> bool: return a.min_round < b.min_round)
	for res in units.values() + enemies + bosses:
		_german_names[res] = [res.display_name, res.get("line_name") if res is UnitData else ""]
	if units.is_empty() or enemies.is_empty() or shop_units().is_empty():
		push_error("Registry: Spieldaten fehlen (%d Einheiten, %d Gegner) - Export prüfen" % [units.size(), enemies.size()])
	print_verbose("Registry: %d Einheiten, %d Rezepte, %d Gegner, %d im Shop" % [
		units.size(), recipes.size(), enemies.size(), shop_units().size()])


## Im Shop kaufbare Einheiten (Stufe 1 jeder Linie), nach Shop-Reihenfolge sortiert.
func shop_units() -> Array[UnitData]:
	var result: Array[UnitData] = []
	for unit in units.values():
		if unit.shop_order > 0:
			result.append(unit)
	result.sort_custom(func(a: UnitData, b: UnitData) -> bool: return a.shop_order < b.shop_order)
	return result


## Einheiten-, Linien- und Gegnernamen in die aktuelle Sprache setzen (Loc ruft das bei jedem Wechsel auf).
func relocalize() -> void:
	for res: Resource in _german_names:
		res.display_name = tr(_german_names[res][0])
		if res is UnitData:
			res.line_name = tr(_german_names[res][1])


## Boss der Bossrunde: reihum durch alle Bosse (Runde 5, 15, 25, ...).
func boss_for_round(round_number: int) -> EnemyData:
	return bosses[((round_number - 5) / 10) % bosses.size()]


## Alle Grundeinheiten (im Shop kaufbar), aus denen sich `unit` durch Verbinden aufbauen lässt:
## {Grundeinheit: Anzahl}. Beispiel: Ritter = 4 Bauern, Paladin = Ritter + Magier.
func base_units(unit: UnitData) -> Dictionary:
	if unit.shop_order > 0:
		return {unit: 1}
	if _previous.has(unit):
		var half := base_units(_previous[unit])
		for key in half:
			half[key] *= 2
		return half
	for recipe in recipes:
		if recipe.result == unit and recipe.ingredient_a != recipe.ingredient_b:
			return merge_counts(base_units(recipe.ingredient_a), base_units(recipe.ingredient_b))
	return {}


func merge_counts(a: Dictionary, b: Dictionary) -> Dictionary:
	var result := a.duplicate()
	for key in b:
		result[key] = result.get(key, 0) + b[key]
	return result


func bundle_price(bundle: Dictionary) -> int:
	var total := 0
	for unit: UnitData in bundle:
		total += unit.price * bundle[unit]
	return total


func bundle_size(bundle: Dictionary) -> int:
	var total := 0
	for unit: UnitData in bundle:
		total += bundle[unit]
	return total


func find_recipe(a: UnitData, b: UnitData) -> RecipeData:
	for recipe in recipes:
		if recipe.matches(a, b):
			return recipe
	return null


func pick_enemy(round_number: int) -> EnemyData:
	var pool: Array[EnemyData] = []
	var total := 0.0
	for enemy in enemies:
		if enemy.min_round <= round_number:
			pool.append(enemy)
			total += enemy.weight
	var roll := randf() * total
	for enemy in pool:
		roll -= enemy.weight
		if roll <= 0.0:
			return enemy
	return pool.back()


func _load_all(dir: String) -> Array[Resource]:
	var result: Array[Resource] = []
	var files := Array(DirAccess.get_files_at(dir))
	files.sort()
	for file: String in files:
		# Exportierte Builds benennen Ressourcen teils in "*.tres.remap" um.
		var name := file.trim_suffix(".remap")
		if name.ends_with(".tres"):
			result.append(load(dir.path_join(name)))
	return result
