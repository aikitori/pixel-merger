class_name Tutorial
extends PanelContainer
## Einstieg beim ersten Lauf: kurze Hinweise oben rechts (links steht die Einheitenkarte). Jeder
## verschwindet, sobald der Spieler den Schritt gemacht hat. Danach (oder mit "Ausblenden") merkt
## sich Progress, dass er gezeigt wurde.

## Schritte: Bedingung, die ihn erledigt (siehe _step_done), Text für Touch und für die Maus.
const STEPS := [
	["buy", "Willkommen! Tippe unten auf Dorf und kaufe in den Häusern ein paar Einheiten.",
		"Willkommen! Klicke unten auf Dorf (oder drücke D) und kaufe in den Häusern ein paar Einheiten."],
	["merge", "Zieh eine Einheit auf eine gleiche: Die beiden verbinden sich zu einer stärkeren.",
		"Zieh eine Einheit auf eine gleiche: Die beiden verbinden sich zu einer stärkeren."],
	["start", "Bereit? Tippe auf Kampf starten. Der Kampf läuft von selbst.",
		"Bereit? Klicke auf Kampf starten (Eingabe). Der Kampf läuft von selbst."],
	["battle", "Halte durch, bis die Zeit abläuft. Antippen wählt Einheiten, ein Tipp aufs Feld schickt sie los. Das Menü zeigt die Steuerung.",
		"Halte durch, bis die Zeit abläuft. Linksklick wählt Einheiten, Rechtsklick schickt sie los oder greift an. Esc zeigt alle Tasten."],
]

var step := 0
var _arena: Node
var _hud: Hud
var _text: Label
var _shown_touch := false


func setup(arena: Node, hud: Hud) -> void:
	_arena = arena
	_hud = hud


func _ready() -> void:
	position = Vector2(476, 28)
	custom_minimum_size = Vector2(158, 0)
	size = Vector2(158, 0)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var style := UiTheme.sign_style()
	style.content_margin_left = 6
	style.content_margin_right = 6
	style.content_margin_top = 4
	style.content_margin_bottom = 4
	add_theme_stylebox_override("panel", style)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 2)
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(box)
	_text = Label.new()
	_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_text.custom_minimum_size = Vector2(144, 0)
	_text.add_theme_font_size_override("font_size", 10)
	_text.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(_text)
	var skip := Button.new()
	skip.text = tr("Ausblenden")
	skip.add_theme_font_size_override("font_size", 9)
	skip.size_flags_horizontal = Control.SIZE_SHRINK_END
	skip.pressed.connect(finish)
	box.add_child(skip)
	_show_step()


func _process(_delta: float) -> void:
	if Game.phase == Game.Phase.GAME_OVER:
		finish()
		return
	while step < STEPS.size() and _step_done(STEPS[step][0]):
		step += 1
		if step >= STEPS.size():
			finish()
			return
		_show_step()
	if _shown_touch != PlayerInput.touch:
		_show_step()  # erst Maus, dann Finger (oder umgekehrt): passenden Text zeigen
	# Offene Fenster (Kaufliste, Rezeptbuch, Ereignis) nicht verdecken.
	visible = not _hud.panel_open()


func _step_done(id: String) -> bool:
	match id:
		"buy":
			return _arena.get_player_units().size() >= 2 or Game.phase != Game.Phase.BUILD
		"merge":
			return int(Game.stats.get("merges", 0)) > 0 or Game.phase != Game.Phase.BUILD
		"start":
			return Game.phase == Game.Phase.BATTLE or Game.round_number > 1
		"battle":
			return Game.round_number > 1
	return true


func _show_step() -> void:
	_shown_touch = PlayerInput.touch
	_text.text = tr(STEPS[step][1 if _shown_touch else 2])
	size = Vector2(158, 0)  # an die neue Textlänge anpassen


## Einstieg beenden und nicht wieder zeigen.
func finish() -> void:
	Progress.finish_tutorial()
	queue_free()
