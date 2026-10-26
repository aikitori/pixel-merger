class_name PlayerInput
extends RefCounted
## Steuerung nach Art von Strategiespielen: Tastenkürzel, Maus oder Touch und die Übersicht im Menü.
## Maus: links wählen, rechts befehlen. Touch: Tippen wählt und befiehlt, langes Drücken ersetzt den
## Rechtsklick. Die Belegung steht nur hier, das Menü (PausePanel) liest dieselbe Liste.

## Zuletzt per Finger bedient (aus Touch erzeugte Mausereignisse haben das Gerät DEVICE_ID_EMULATION).
## Bestimmt Trefferradius, Ziehschwelle, Rechtsklick-Ersatz und welche Hilfe das Menü zeigt.
static var touch := DisplayServer.is_touchscreen_available()

## Tastenkürzel (Buchstaben nach Tastenbeschriftung, damit H auch auf QWERTZ H ist).
const KEYS := {
	KEY_ENTER: &"start", KEY_KP_ENTER: &"start",
	KEY_SPACE: &"pause", KEY_P: &"pause", KEY_PAUSE: &"pause",
	KEY_D: &"village", KEY_R: &"book", KEY_V: &"merge_all", KEY_DELETE: &"return",
	KEY_H: &"hold", KEY_S: &"stop", KEY_G: &"guard", KEY_Q: &"ability", KEY_TAB: &"next",
	KEY_PLUS: &"faster", KEY_EQUAL: &"faster", KEY_KP_ADD: &"faster",
	KEY_MINUS: &"slower", KEY_KP_SUBTRACT: &"slower",
	KEY_F11: &"fullscreen",
}

const HELP_MOUSE := [
	["Linksklick", "Einheit wählen, auf freiem Boden abwählen"],
	["Ziehen", "Einheit verschieben, auf eine andere: verbinden; auf freiem Boden: Auswahlrahmen"],
	["Rechtsklick", "Gewählte laufen hin, greifen den Gegner an oder schützen den Verbündeten"],
	["Umschalt+Klick", "Einheit zur Auswahl hinzu oder heraus"],
	["Strg+Klick, Doppelklick", "Alle gleichen Einheiten wählen"],
	["Strg+1-9, 1-9", "Gruppe speichern, Gruppe wählen; Strg+A alle"],
	["H, S, G, Q", "Halten, Frei, Schützen, Fähigkeit; Tab nächste Einheit"],
	["Leertaste, +/-", "Pause, Kampftempo"],
	["Eingabe, D, R, V, Entf", "Kampf starten, Dorf, Rezepte, alles verbinden, zurückschicken"],
	["Esc", "Fenster schließen, Auswahl aufheben, Menü"],
]

const HELP_TOUCH := [
	["Tippen", "Einheit wählen, nochmal tippen: abwählen"],
	["Ziehen", "Einheit verschieben, auf eine andere: verbinden; auf freiem Boden: Auswahlrahmen"],
	["Doppeltipp", "Alle gleichen Einheiten wählen"],
	["Kampf: aufs Feld tippen", "Gewählte laufen hin, auf einen Gegner: angreifen"],
	["Lange drücken", "Auf einen Verbündeten: schützen (wie Rechtsklick)"],
	["Knöpfe unten", "Alle, Mehrfach, Befehl, Fähigkeit, Tempo"],
	["Zurück", "Fenster schließen, Auswahl aufheben, Menü"],
]


static func action_for(event: InputEventKey) -> StringName:
	return KEYS.get(event.keycode, &"")


## Gruppennummer 1-9 einer Zifferntaste (auch Ziffernblock), sonst 0.
static func group_for(event: InputEventKey) -> int:
	if event.keycode >= KEY_1 and event.keycode <= KEY_9:
		return event.keycode - KEY_0
	if event.keycode >= KEY_KP_1 and event.keycode <= KEY_KP_9:
		return event.keycode - KEY_KP_0
	return 0


## Merkt sich, ob Finger oder Maus die letzte Eingabe gemacht hat.
static func note(event: InputEvent) -> void:
	if event is InputEventScreenTouch or event is InputEventScreenDrag:
		touch = true
	elif event is InputEventMouse:
		touch = event.device == InputEvent.DEVICE_ID_EMULATION
	elif event is InputEventKey:
		touch = false


static func is_touch(event: InputEvent) -> bool:
	return event is InputEventMouse and event.device == InputEvent.DEVICE_ID_EMULATION


## Übersicht für das Menü: Zeilen [Eingabe, Wirkung], übersetzt.
static func help() -> Array:
	var lines := []
	for line: Array in (HELP_TOUCH if touch else HELP_MOUSE):
		lines.append([TranslationServer.translate(line[0]), TranslationServer.translate(line[1])])
	return lines
