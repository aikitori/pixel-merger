class_name Fullscreen
extends RefCounted
## Vollbild ein/aus (Browser und Desktop). Auf Android läuft das Spiel ohnehin im Vollbild.
## Im Browser muss der Aufruf aus einem Klick kommen, sonst erlaubt der Browser ihn nicht.


static func available() -> bool:
	return DisplayServer.get_name() != "headless" and not OS.has_feature("android") and not OS.has_feature("ios")


static func is_on() -> bool:
	var mode := DisplayServer.window_get_mode()
	return mode == DisplayServer.WINDOW_MODE_FULLSCREEN or mode == DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN


static func toggle() -> void:
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED if is_on() else DisplayServer.WINDOW_MODE_FULLSCREEN)


## Beschriftung des Knopfs: nennt die Aktion, die er auslöst.
static func label() -> String:
	return TranslationServer.translate("Fenster") if is_on() else TranslationServer.translate("Vollbild")
