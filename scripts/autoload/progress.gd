extends Node
## Spielübergreifender Fortschritt (Autoload "Progress"): entdeckte Geheimrezepte.
## Gespeichert in user://progress.cfg, nur mit Fenster (Tests ohne Fenster ändern keinen echten Spielstand).

signal secret_discovered(result: UnitData)

const SAVE_PATH := "user://progress.cfg"

## Ergebnis-Ids der entdeckten Geheimrezepte.
var discovered: Dictionary = {}
var persist := DisplayServer.get_name() != "headless"


func _ready() -> void:
	if not persist:
		return
	var file := ConfigFile.new()
	if file.load(SAVE_PATH) == OK:
		for id: String in file.get_value("secrets", "discovered", PackedStringArray()):
			discovered[StringName(id)] = true


## Geheimrezept, das noch nicht entdeckt wurde: Name und Zutaten bleiben verborgen.
func is_hidden(recipe: RecipeData) -> bool:
	return recipe != null and recipe.secret and not discovered.has(recipe.result.id)


## Gibt true zurück, wenn das Rezept gerade zum ersten Mal entdeckt wurde.
func discover(recipe: RecipeData) -> bool:
	if not is_hidden(recipe):
		return false
	discovered[recipe.result.id] = true
	_save()
	secret_discovered.emit(recipe.result)
	return true


func secret_count() -> int:
	var total := 0
	for recipe in Registry.recipes:
		if recipe.secret:
			total += 1
	return total


func reset() -> void:
	discovered.clear()
	_save()


func _save() -> void:
	if not persist:
		return
	var file := ConfigFile.new()
	file.load(SAVE_PATH)
	var ids := PackedStringArray()
	for id: StringName in discovered:
		ids.append(String(id))
	file.set_value("secrets", "discovered", ids)
	file.save(SAVE_PATH)
