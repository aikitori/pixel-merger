extends Node
## Sprache (Autoload "Loc"): Deutsch (Quelltexte) und Englisch. Alle Texte stehen deutsch im Code und
## laufen durch tr(); die englischen Übersetzungen liegen in scripts/i18n/. Die Wahl wird gespeichert.
## Namen von Einheiten stehen deutsch in den Datendateien: relocalize() setzt sie neu (siehe Registry).

signal language_changed(code: String)

const LANGUAGES := ["de", "en"]
const SETTINGS_PATH := "user://settings.cfg"

var language := "de"
## Speichern und Systemsprache nur mit Fenster: Tests (headless) bleiben immer deutsch.
var _interactive := DisplayServer.get_name() != "headless"


func _ready() -> void:
	var translation := Translation.new()
	translation.locale = "en"
	for german: String in UiEn.TEXTS:
		translation.add_message(german, UiEn.TEXTS[german])
	for german: String in NamesEn.NAMES:
		translation.add_message(german, NamesEn.NAMES[german])
	TranslationServer.add_translation(translation)
	if _interactive:
		var code := OS.get_locale_language()
		var file := ConfigFile.new()
		if file.load(SETTINGS_PATH) == OK:
			code = file.get_value("ui", "language", code)
		language = code if code in LANGUAGES else ("de" if code == "de" else "en")
	_apply()


func set_language(code: String) -> void:
	if code == language or not code in LANGUAGES:
		return
	language = code
	_apply()
	if _interactive:
		var file := ConfigFile.new()
		file.load(SETTINGS_PATH)  # andere Einstellungen (Ton) erhalten
		file.set_value("ui", "language", code)
		file.save(SETTINGS_PATH)
	language_changed.emit(code)


## Nächste Sprache der Liste.
func next_language() -> String:
	return LANGUAGES[(LANGUAGES.find(language) + 1) % LANGUAGES.size()]


func _apply() -> void:
	TranslationServer.set_locale(language)
	Registry.relocalize()
