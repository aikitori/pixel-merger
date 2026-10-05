class_name ArtStyle
extends RefCounted
## Bildstile: eine Nachbearbeitung über das ganze Bild (shaders/art_style.gdshader) plus eigene Farben und
## Materialien für die Oberfläche (UiTheme liest sie über ui()) und optional ein Titel-Logo.
## DEFAULT ist der Stil des Spiels (passend zu den erzeugten Sprites), &"" der frühere Holz-Stil.
## Die Nachbearbeitung hängt Game ein (Game.refresh_art_style). Screenshots: SHOT_STYLE=<id> (scenes/dev/shot.tscn).

const STYLES := {
	&"handheld": {"name": "Taschenkonsole", "shader": 1, "ui": {
		"btn_top": Color("#9bbc0f"), "btn_bottom": Color("#8bac0f"), "edge": Color("#306230"),
		"outline": Color("#0f380f"), "panel_top": Color("#306230"), "panel_bottom": Color("#306230"),
		"btn_hover_top": Color("#c4e04a"), "btn_pressed_top": Color("#306230"), "btn_pressed_bottom": Color("#306230"),
		"text": Color("#0f380f"), "text_shadow": Color(0, 0, 0, 0),
		"label_text": Color("#9bbc0f"), "label_shadow": Color("#0f380f"),
		"plank_a": Color("#306230"), "plank_b": Color("#306230"), "plank_seam": Color("#0f380f"),
	}},
	&"ink": {"name": "Tusche & Pergament", "shader": 2, "ui": {
		"btn_top": Color("#f6ead0"), "btn_bottom": Color("#e2cfa4"), "edge": Color("#8a6a40"),
		"outline": Color("#2a1d14"), "panel_top": Color("#4a3322"), "panel_bottom": Color("#3a2618"),
		"btn_hover_top": Color("#fff6e0"), "btn_pressed_top": Color("#cdb88a"), "btn_pressed_bottom": Color("#bfa877"),
		"text": Color("#2a1d14"), "text_shadow": Color(0, 0, 0, 0),
		"label_text": Color("#f6ead0"), "label_shadow": Color("#2a1d14"),
		"plank_a": Color("#4a3322"), "plank_b": Color("#432e1f"), "plank_seam": Color("#2a1d14"),
	}},
	&"neon": {"name": "Neon-Nacht", "shader": 3, "ui": {
		"btn_top": Color("#140a2a"), "btn_bottom": Color("#0a0418"), "edge": Color("#29f0ff"),
		"outline": Color("#ff3df0"), "panel_top": Color("#0e0620"), "panel_bottom": Color("#06020f"),
		"btn_hover_top": Color("#24104a"), "btn_pressed_top": Color("#3a0a4a"), "btn_pressed_bottom": Color("#24062e"),
		"text": Color("#d8fbff"), "text_shadow": Color(1.0, 0.24, 0.94, 0.7),
		"plank_a": Color("#0a0418"), "plank_b": Color("#0c0620"), "plank_seam": Color("#ff3df0"),
	}},
	&"pastel": {"name": "Zuckerwatte", "shader": 4, "ui": {
		"btn_top": Color("#ffc6dd"), "btn_bottom": Color("#f5a3c4"), "edge": Color("#ffffff"),
		"outline": Color("#7a5a8e"), "panel_top": Color("#b49ad6"), "panel_bottom": Color("#9e84c4"),
		"btn_hover_top": Color("#ffdcea"), "btn_pressed_top": Color("#e98fb5"), "btn_pressed_bottom": Color("#dd7ea6"),
		"text": Color("#6a4a7a"), "text_shadow": Color(1, 1, 1, 0.8),
		"label_text": Color("#ffffff"), "label_shadow": Color("#7a5a8e"),
		"plank_a": Color("#b49ad6"), "plank_b": Color("#ab90cf"), "plank_seam": Color("#8a6aac"),
	}},
	&"gothic": {"name": "Düsterwald", "shader": 5, "ui": {
		"btn_top": Color("#3a3a40"), "btn_bottom": Color("#25252b"), "edge": Color("#7a1010"),
		"outline": Color("#08080a"), "panel_top": Color("#202024"), "panel_bottom": Color("#141417"),
		"btn_hover_top": Color("#4a4a52"), "btn_pressed_top": Color("#1a1a1e"), "btn_pressed_bottom": Color("#121215"),
		"text": Color("#d6cfc4"), "text_shadow": Color(0, 0, 0, 0.9),
		"plank_a": Color("#2a2a30"), "plank_b": Color("#26262b"), "plank_seam": Color("#0c0c0e"),
	}},
	&"doom": {"name": "Höllenshooter", "shader": 6, "logo": "res://assets/logo/logo_doom.png", "ui": {
		"btn_top": Color("#6b6b6b"), "btn_bottom": Color("#4a4a4a"), "edge": Color("#9a9a9a"),
		"outline": Color("#1a1a1a"), "panel_top": Color("#4f4f4f"), "panel_bottom": Color("#3a3a3a"),
		"btn_hover_top": Color("#7d7d7d"), "btn_pressed_top": Color("#3a3a3a"), "btn_pressed_bottom": Color("#2c2c2c"),
		"text": Color("#d81e1e"), "text_shadow": Color(0, 0, 0, 1),
		"label_text": Color("#e8c060"), "label_shadow": Color("#1a0a04"),
		"plank_a": Color("#555555"), "plank_b": Color("#4c4c4c"), "plank_seam": Color("#262626"),
	}},
}

const DEFAULT := &"doom"

static var current: StringName = DEFAULT


static func set_style(id: StringName) -> void:
	current = id if STYLES.has(id) else &""
	UiTheme.clear_cache()


static func display_name(id: StringName) -> String:
	return STYLES[id]["name"] if STYLES.has(id) else "Klassisch"


## Oberflächenfarbe des aktiven Stils, sonst `fallback` (der bisherige Holz-Stil).
static func ui(key: String, fallback: Color) -> Color:
	if not STYLES.has(current):
		return fallback
	return STYLES[current]["ui"].get(key, fallback)


## Eigenes Titel-Logo des aktiven Stils (tools/generate_logo.py), sonst null.
static func logo() -> Texture2D:
	if not STYLES.has(current) or not STYLES[current].has("logo"):
		return null
	return load(STYLES[current]["logo"])


## Nachbearbeitung als oberste Ebene, null beim bisherigen Stil.
static func make_overlay() -> CanvasLayer:
	if not STYLES.has(current):
		return null
	var layer := CanvasLayer.new()
	layer.layer = 128
	var rect := ColorRect.new()
	rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var material := ShaderMaterial.new()
	material.shader = load("res://shaders/art_style.gdshader")
	material.set_shader_parameter("style", STYLES[current]["shader"])
	rect.material = material
	layer.add_child(rect)
	return layer
