class_name RecipeData
extends Resource
## Kombinationsrezept mit genau zwei Zutaten, z.B. Ritter + Pferd -> Berittener Reiter.
## Die Reihenfolge ist egal. Als .tres-Datei unter data/recipes/ ablegen.

@export var ingredient_a: UnitData
@export var ingredient_b: UnitData
@export var result: UnitData
## Ab dieser Runde darf das Rezept benutzt werden.
@export var unlock_round: int = 1
## Goldkosten des Verbindens. Größere/komplexere Ergebnisse kosten mehr.
@export var merge_cost: int = 0


func matches(a: UnitData, b: UnitData) -> bool:
	return (a == ingredient_a and b == ingredient_b) or (a == ingredient_b and b == ingredient_a)
