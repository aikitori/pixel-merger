class_name EnemyData
extends Resource
## Werte eines Gegnertyps. Erzeugt von tools/generate_data.py (Tabelle ENEMIES und BOSSES) nach data/enemies/.
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
## Relative Spawn-Häufigkeit unter den möglichen Gegnern (0 = erscheint nie von selbst).
@export var weight: float = 1.0
## Bossgegner erscheinen nur in Bossrunden (Runde 5, 15, 25 ...), nie im normalen Spawn.
@export var is_boss := false
## Fähigkeit aus Abilities (aktive lösen von selbst aus) und ihre Stärke (1,0 = Stufe 1 einer Einheit).
@export var ability: StringName = &""
@export var ability_power := 1.0
## Verhalten aus Behaviors, Standard: geht auf den nächsten Gegner los.
@export var behavior: StringName = &"frontline"
## Bausteine aus Traits.KEYS. Bei Gegnern wirken Verteidigung, Auren und Tod, nicht die Wirkung von Treffern.
@export var fx: Dictionary = {}
## Gegner, den die Fähigkeit "Beschwörung" ruft (Id aus data/enemies).
@export var minion: StringName = &""
