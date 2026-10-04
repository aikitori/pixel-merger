class_name Abilities
extends RefCounted
## Fähigkeiten der Einheiten: Name, Kurzbeschreibung, aktiv/passiv und Abklingzeit.
## Die Wirkung steckt in Combatant. Welche Einheit welche Fähigkeit hat, steht in tools/content.py.
## Aktive Fähigkeiten lösen im Kampf von selbst aus (Bedingung erfüllt, Abklingzeit vorbei),
## passive wirken dauerhaft. Die Stärke wächst mit der Stufe der Einheit (siehe power).

const INFO := {
	&"shield": {"name": "Schild hoch", "active": true, "cooldown": 10.0,
		"text": "Hebt bei nahen Gegnern kurz das Schild: nur ein Fünftel Schaden."},
	&"arrow_rain": {"name": "Pfeilregen", "active": true, "cooldown": 9.0,
		"text": "Lässt Pfeile auf das Ziel regnen und trifft alle Gegner im Umkreis."},
	&"meteor": {"name": "Feuersturm", "active": true, "cooldown": 12.0,
		"text": "Schlägt eine Explosion beim Ziel ein, die große Fläche verletzt."},
	&"frost_nova": {"name": "Frostnova", "active": true, "cooldown": 10.0,
		"text": "Frostwelle um die Einheit: verletzt und verlangsamt nahe Gegner."},
	&"sprint": {"name": "Sprint", "active": true, "cooldown": 8.0,
		"text": "Rennt kurz viel schneller, wenn das Ziel weit weg ist."},
	&"mass_heal": {"name": "Massenheilung", "active": true, "cooldown": 11.0,
		"text": "Heilt alle verletzten Verbündeten in der Nähe."},
	&"revive": {"name": "Wiederbeleben", "active": true, "cooldown": 22.0,
		"text": "Erweckt den zuletzt gefallenen Verbündeten mit halbem Leben."},
	&"taunt": {"name": "Spott", "active": true, "cooldown": 12.0,
		"text": "Zwingt nahe Gegner kurz, diese Einheit anzugreifen."},
	&"war_cry": {"name": "Kriegsruf", "active": true, "cooldown": 14.0,
		"text": "Verbündete in der Nähe machen kurz mehr Schaden."},
	&"chain_lightning": {"name": "Kettenblitz", "active": true, "cooldown": 9.0,
		"text": "Ein Blitz springt vom Ziel zu weiteren Gegnern in der Nähe."},
	&"petrify": {"name": "Versteinern", "active": true, "cooldown": 14.0,
		"text": "Ein Blick wie Medusa: nahe Gegner erstarren kurz zu Stein."},
	&"charm": {"name": "Betörender Gesang", "active": true, "cooldown": 13.0,
		"text": "Nahe Gegner lauschen wie gebannt und greifen kurz nicht an."},
	&"whirlwind": {"name": "Wirbelwind", "active": true, "cooldown": 8.0,
		"text": "Dreht sich mit der Waffe und trifft alle Gegner rundherum."},
	&"charge": {"name": "Sturmangriff", "active": true, "cooldown": 10.0,
		"text": "Stürmt auf ein fernes Ziel los, der erste Treffer macht doppelten Schaden und betäubt."},
	&"summon": {"name": "Beschwörung", "active": true, "cooldown": 18.0,
		"text": "Ruft für kurze Zeit Helfer in den Kampf."},
	&"blink": {"name": "Schattenschritt", "active": true, "cooldown": 9.0,
		"text": "Springt durch die Schatten: hinter das Ziel oder weg von Angreifern."},
	&"poison_cloud": {"name": "Giftwolke", "active": true, "cooldown": 11.0,
		"text": "Giftwolke beim Ziel: Gegner darin verlieren eine Weile Leben."},
	&"earthquake": {"name": "Erdbeben", "active": true, "cooldown": 14.0,
		"text": "Stampft auf: nahe Gegner werden verletzt und kurz betäubt."},
	&"holy_light": {"name": "Heiliges Licht", "active": true, "cooldown": 11.0,
		"text": "Licht heilt Verbündete in der Nähe und verbrennt nahe Gegner."},
	&"fire_breath": {"name": "Feueratem", "active": true, "cooldown": 10.0,
		"text": "Speit Feuer in Richtung Ziel: trifft alle Gegner im Kegel und lässt sie brennen."},
	&"hex": {"name": "Verhexen", "active": true, "cooldown": 12.0,
		"text": "Verflucht den stärksten nahen Gegner: halber Schaden und langsamer."},
	&"tidal_wave": {"name": "Flutwelle", "active": true, "cooldown": 12.0,
		"text": "Eine Welle verletzt nahe Gegner und spült sie zurück."},
	&"divine_shield": {"name": "Göttlicher Schutz", "active": true, "cooldown": 18.0,
		"text": "Ein schwer verletzter Verbündeter in der Nähe wird kurz unverwundbar."},
	&"berserk": {"name": "Berserkerwut", "active": true, "cooldown": 15.0,
		"text": "Schwer verletzt in Raserei: mehr Schaden und schnellere Angriffe."},
	&"thorns": {"name": "Dornen", "active": false, "cooldown": 0.0,
		"text": "Nahkämpfer, die angreifen, verletzen sich selbst."},
	&"crit": {"name": "Kritischer Treffer", "active": false, "cooldown": 0.0,
		"text": "Manche Treffer machen doppelten Schaden."},
	&"execute": {"name": "Richtspruch", "active": false, "cooldown": 0.0,
		"text": "Fast besiegte Gegner (keine Bosse) fallen beim nächsten Treffer sofort."},
	&"armor": {"name": "Panzerung", "active": false, "cooldown": 0.0,
		"text": "Nimmt dauerhaft weniger Schaden."},
	&"regen": {"name": "Regeneration", "active": false, "cooldown": 0.0,
		"text": "Heilt sich laufend selbst."},
	&"evasion": {"name": "Ausweichen", "active": false, "cooldown": 0.0,
		"text": "Weicht manchen Treffern ganz aus."},
	&"lifesteal": {"name": "Lebensraub", "active": false, "cooldown": 0.0,
		"text": "Heilt sich um einen Teil des verursachten Schadens."},
	&"slow_aura": {"name": "Fluch-Aura", "active": false, "cooldown": 0.0,
		"text": "Gegner in der Nähe bewegen sich langsamer."},
	&"war_aura": {"name": "Anführer-Aura", "active": false, "cooldown": 0.0,
		"text": "Verbündete in der Nähe machen dauerhaft mehr Schaden."},
}


static func display_name(id: StringName) -> String:
	return TranslationServer.translate(INFO[id]["name"]) if INFO.has(id) else ""


static func description(id: StringName) -> String:
	return TranslationServer.translate(INFO[id]["text"]) if INFO.has(id) else ""


static func is_active(id: StringName) -> bool:
	return INFO.has(id) and INFO[id]["active"]


static func cooldown(id: StringName) -> float:
	return INFO[id]["cooldown"] if INFO.has(id) else 0.0


## "Schild hoch (aktiv)" bzw. "(passiv)"
static func label(id: StringName) -> String:
	if not INFO.has(id):
		return ""
	return "%s (%s)" % [display_name(id), TranslationServer.translate("aktiv" if INFO[id]["active"] else "passiv")]


## Stärkefaktor: Stufe 1 = 1,0, jede weitere Stufe +0,4. Kombinationen starten höher.
static func power(level: int, combo: bool) -> float:
	return (1.0 + 0.4 * (level - 1)) * (1.6 if combo else 1.0)
