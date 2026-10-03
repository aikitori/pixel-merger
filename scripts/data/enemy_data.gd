class_name EnemyData
extends Resource
## Werte eines Gegnertyps. Als .tres-Datei unter data/enemies/ ablegen.
## Lebenspunkte, Angriff und Gold werden zusätzlich mit der Runde skaliert (siehe Game).

@export var id: StringName
@export var display_name: String
@export var sprite: Texture2D
@export var color: Color = Color.WHITE
@export var body_size: float = 12.0
@export var max_health: float = 10.0
@export var attack: float = 1.0
@export var intelligence: float = 10.0
@export var attack_range: float = 10.0
## Kampfanimation: &"melee" (Schwert), &"arrow" (Pfeil) oder &"magic" (Feuerball).
@export var attack_style: StringName = &"melee"
@export var attack_cooldown: float = 1.0
@export var move_speed: float = 30.0
@export var gold_reward: int = 1
## Ab dieser Runde kann der Gegner spawnen.
@export var min_round: int = 1
## Relative Spawn-Häufigkeit unter den möglichen Gegnern.
@export var weight: float = 1.0
## Bossgegner erscheinen nur in Bossrunden (Runde 5, 15, 25 ...), nie im normalen Spawn.
@export var is_boss := false
