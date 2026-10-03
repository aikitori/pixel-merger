class_name UnitData
extends Resource
## Werte einer Einheit. Wird von tools/generate_data.py aus tools/content.py erzeugt
## und liegt als .tres unter data/units/.

@export var id: StringName
@export var display_name: String
## Pixel-Sprite (siehe tools/generate_sprites.py).
@export var sprite: Texture2D
@export var color: Color = Color.WHITE
## Name der Entwicklungslinie bzw. "Kombination".
@export var line_name: String
## Stufe innerhalb der Entwicklungslinie (1 = Anfang, z.B. Bauer).
@export var level: int = 1
## Abschnitt im Shop (z.B. "Klassisch", "Fantasy", "Elemente").
@export var category: String
## > 0: Die Einheit ist im Shop kaufbar (Reihenfolge innerhalb des Shops).
@export var shop_order: int = 0
## Goldpreis im Shop.
@export var price: int = 0
## Ab dieser Runde darf diese Einheit durch Selbst-Merge entstehen.
@export var unlock_round: int = 1
## Nächste Stufe, wenn zwei dieser Einheiten verbunden werden. null = höchste Stufe.
@export var upgrade: UnitData
## Goldkosten für diese Selbst-Verbindung.
@export var upgrade_cost: int = 0
## Die vier Hauptwerte: Lebenspunkte (max_health), Stärke (attack), Beweglichkeit (move_speed)
## und Intelligenz (schlaue Einheiten wählen im Kampf gezielter ihre Ziele).
@export var max_health: float = 10.0
@export var attack: float = 1.0
@export var intelligence: float = 10.0
@export var attack_range: float = 12.0
## Kampfanimation: &"melee" (Schwert), &"arrow" (Pfeil) oder &"magic" (Feuerball).
@export var attack_style: StringName = &"melee"
## Fähigkeit (siehe Abilities), &"" = keine.
@export var ability: StringName = &""
@export var attack_cooldown: float = 1.0
@export var move_speed: float = 40.0


static func format_number(value: float) -> String:
	return "%d" % roundi(value) if is_equal_approx(value, roundf(value)) else "%.1f" % value


## Kurztext der vier Hauptwerte, z.B. "LP 40  Stä 5  Bew 40  Int 12".
func stats_text() -> String:
	return tr("LP %s  Stä %s  Bew %s  Int %s") % [
		format_number(max_health), format_number(attack),
		format_number(move_speed), format_number(intelligence)]
