class_name Traits
extends RefCounted
## Merkmale: Stufen-Merkmal (ab Stufe 3) und Meisterzug (Stufe 5) jeder Linie, Signatur jeder Kombination.
## Welche Einheit welche hat, steht in tools/content.py (LINE_PROFILE, COMBO_SIGNATURE).
## Jedes Merkmal setzt sich aus Bausteinen zusammen (Schlüssel in "fx"), die Combatant an festen Stellen
## abfragt:
##   Werte:     hp, atk, speed, range, cooldown (Faktoren)
##   Treffer:   burn [Anteil Stärke je s, s], slow [Faktor, s], stun [Chance, s], knock (Pixel),
##              weaken [Faktor, s], mark [Mehrschaden, s], leech (Anteil), splash [Anteil, Radius],
##              chain [Anteil, Sprünge], execute (Lebensanteil), crit [Chance, Faktor], double (Chance),
##              opener (Faktor für den ersten Treffer im Kampf), boss (Faktor gegen Bosse)
##   Getroffen: block (Chance gegen Nahkampf), reduce (Anteil), thorns (Anteil), dodge (Chance),
##              last_stand (Anteil weniger Schaden unter einem Drittel Leben)
##   Sieg:      kill_heal (Anteil Leben), kill_haste (s), kill_gold (Gold), kill_rally [Mehrschaden, s]
##   Aura:      jede Sekunde im Umkreis AURA_RADIUS: aura_heal (Anteil Leben der Verbündeten),
##              aura_burn (Anteil Stärke als Schaden), aura_guard (Schadensfaktor der Verbündeten),
##              aura_chill (Tempo der Gegner), aura_haste (Angriffstempo der Verbündeten)
##   Tod:       death_blast [Anteil Stärke, Radius], revive (Lebensanteil, einmal je Kampf)
##   Kampfbeginn: start_shield [Schadensfaktor, s]

## Alle Bausteine, die Combatant kennt (ein Tippfehler in "fx" würde sonst still nichts tun).
const KEYS := ["hp", "atk", "speed", "range", "cooldown", "burn", "slow", "stun", "knock", "weaken", "mark",
		"leech", "splash", "chain", "execute", "crit", "double", "opener", "boss", "block", "reduce", "thorns",
		"dodge", "last_stand", "kill_heal", "kill_haste", "kill_gold", "kill_rally", "aura_heal", "aura_burn",
		"aura_guard", "aura_chill", "aura_haste", "death_blast", "revive", "start_shield"]
const AURA_RADIUS := 55.0
const AURA_INTERVAL := 1.0

const INFO := {
	# --- Linien: Merkmal ab Stufe 3, Meisterzug auf Stufe 5 ---
	&"parry": {"name": "Parade", "text": "Wehrt jeden vierten Nahkampftreffer ab.", "fx": {"block": 0.25}},
	&"last_stand": {"name": "Letztes Gefecht", "text": "Unter einem Drittel Leben nur halber Schaden.", "fx": {"last_stand": 0.5}},
	&"keen_eye": {"name": "Adlerauge", "text": "Jeder fünfte Schuss trifft doppelt.", "fx": {"crit": [0.2, 2.0]}},
	&"headshot": {"name": "Kopfschuss", "text": "Gegner unter 15 % Leben fallen sofort (keine Bosse).", "fx": {"execute": 0.15}},
	&"mana_flow": {"name": "Manafluss", "text": "Zaubert ein Fünftel schneller.", "fx": {"cooldown": 0.8}},
	&"arcane_burst": {"name": "Arkane Entladung", "text": "Treffer verletzen auch Gegner im Umkreis.", "fx": {"splash": [0.5, 26.0]}},
	&"trample": {"name": "Niedertrampeln", "text": "Betäubt Getroffene manchmal kurz.", "fx": {"stun": [0.2, 0.6]}},
	&"thunder_charge": {"name": "Donnernder Ansturm", "text": "Schneller, der erste Treffer im Kampf dreifach.", "fx": {"opener": 3.0, "speed": 1.2}},
	&"stubborn": {"name": "Dickschädel", "text": "Nimmt 15 % weniger Schaden.", "fx": {"reduce": 0.15}},
	&"ancestors": {"name": "Ahnenruf", "text": "Steht einmal je Kampf mit 40 % Leben wieder auf.", "fx": {"revive": 0.4}},
	&"ranger": {"name": "Waldläufer", "text": "Größere Reichweite und flinker.", "fx": {"range": 1.15, "speed": 1.1}},
	&"moon_arrow": {"name": "Mondpfeil", "text": "Getroffene nehmen kurz 25 % mehr Schaden.", "fx": {"mark": [0.25, 3.0]}},
	&"plague": {"name": "Seuchengriff", "text": "Vergiftet Getroffene.", "fx": {"burn": [0.25, 3.0]}},
	&"soul_hunger": {"name": "Seelenhunger", "text": "Heilt sich bei jedem Sieg um ein Viertel.", "fx": {"kill_heal": 0.25}},
	&"hoard": {"name": "Drachenhort", "text": "Jeder Sieg bringt 1 Gold extra.", "fx": {"kill_gold": 1}},
	&"ember_heart": {"name": "Glutherz", "text": "Versengt Gegner in der Nähe jede Sekunde.", "fx": {"aura_burn": 0.35}},
	&"evil_eye": {"name": "Böser Blick", "text": "Getroffene machen kurz weniger Schaden.", "fx": {"weaken": [0.7, 2.5]}},
	&"coven": {"name": "Hexensabbat", "text": "Ein Sieg stärkt Verbündete in der Nähe.", "fx": {"kill_rally": [0.25, 4.0]}},
	&"hunt": {"name": "Hetzjagd", "text": "Getroffene werden langsamer.", "fx": {"slow": [0.7, 1.5]}},
	&"blood_frenzy": {"name": "Blutrausch", "text": "Nach jedem Sieg kurz rasend schnell.", "fx": {"kill_haste": 4.0}},
	&"thick_hide": {"name": "Dickes Fell", "text": "Ein Drittel mehr Leben.", "fx": {"hp": 1.33}},
	&"primal_force": {"name": "Urgewalt", "text": "Schleudert Getroffene weit weg und betäubt oft.", "fx": {"knock": 16.0, "stun": [0.3, 0.8]}},
	&"double_throw": {"name": "Doppelwurf", "text": "Wirft oft zweimal.", "fx": {"double": 0.3}},
	&"chiron_teaching": {"name": "Chirons Lehre", "text": "Verbündete in der Nähe greifen schneller an.", "fx": {"aura_haste": 1.25}},
	&"embers": {"name": "Glut", "text": "Setzt Getroffene in Brand.", "fx": {"burn": [0.3, 3.0]}},
	&"conflagration": {"name": "Feuersbrunst", "text": "Explodiert beim Tod und verbrennt Gegner ringsum.", "fx": {"death_blast": [2.5, 40.0]}},
	&"current": {"name": "Strömung", "text": "Getroffene werden weggespült und langsamer.", "fx": {"slow": [0.75, 1.0], "knock": 6.0}},
	&"wellspring": {"name": "Quell des Lebens", "text": "Heilt Verbündete in der Nähe jede Sekunde.", "fx": {"aura_heal": 0.02}},
	&"stone_skin": {"name": "Steinhaut", "text": "Nahkämpfer verletzen sich an ihr.", "fx": {"thorns": 0.25}},
	&"bedrock": {"name": "Grundfels", "text": "Nimmt 30 % weniger Schaden, aber langsamer.", "fx": {"reduce": 0.3, "speed": 0.85}},
	&"gust": {"name": "Böe", "text": "Weicht jedem fünften Treffer aus.", "fx": {"dodge": 0.2}},
	&"tempest": {"name": "Sturmgewalt", "text": "Treffer springen auf drei weitere Gegner über.", "fx": {"chain": [0.5, 3]}},
	&"apothecary": {"name": "Feldapotheke", "text": "Mehr Leben, heilt schneller.", "fx": {"hp": 1.2, "cooldown": 0.85}},
	&"blessing_ward": {"name": "Schutzsegen", "text": "Verbündete in der Nähe nehmen weniger Schaden.", "fx": {"aura_guard": 0.85}},
	&"long_reach": {"name": "Lange Lanze", "text": "Ein Drittel mehr Reichweite.", "fx": {"range": 1.33}},
	&"spear_wall": {"name": "Speerwall", "text": "Wehrt Nahkampf oft ab und sticht zurück.", "fx": {"block": 0.3, "thorns": 0.15}},
	&"scale_mail": {"name": "Schuppenkleid", "text": "Weicht manchmal aus, nimmt weniger Schaden.", "fx": {"dodge": 0.12, "reduce": 0.1}},
	&"basilisk_gaze": {"name": "Basiliskenblick", "text": "Getroffene erstarren manchmal.", "fx": {"stun": [0.15, 1.2]}},
	&"leap": {"name": "Sprungkraft", "text": "Ein Viertel schneller.", "fx": {"speed": 1.25}},
	&"royal_kiss": {"name": "Königskuss", "text": "Raubt Leben und heilt sich bei jedem Sieg.", "fx": {"leech": 0.1, "kill_heal": 0.15}},
	&"dive": {"name": "Sturzflug", "text": "Der erste Treffer im Kampf doppelt.", "fx": {"opener": 2.0}},
	&"sky_lord": {"name": "Herr der Lüfte", "text": "Schlägt oft doppelt zu und stößt weg.", "fx": {"double": 0.35, "knock": 8.0}},
	&"freeze": {"name": "Gefrieren", "text": "Getroffene frieren manchmal ein.", "fx": {"stun": [0.12, 1.0]}},
	&"eternal_winter": {"name": "Ewiger Winter", "text": "Gegner in der Nähe werden langsamer.", "fx": {"aura_chill": 0.65}},
	&"inner_calm": {"name": "Innere Ruhe", "text": "Nimmt weniger Schaden und heilt Nachbarn leicht.", "fx": {"reduce": 0.15, "aura_heal": 0.01}},
	&"holy_wrath": {"name": "Heiliger Zorn", "text": "Versengt Gegner ringsum, besonders Bosse.", "fx": {"aura_burn": 0.25, "boss": 1.3}},

	# --- Signaturen der Kombinationen ---
	&"lance_charge": {"name": "Lanzenangriff", "text": "Erster Treffer dreifach und wirft den Gegner um.", "fx": {"opener": 3.0, "stun": [0.25, 0.8]}},
	&"parthian_shot": {"name": "Partherschuss", "text": "Schießt schneller und trifft oft doppelt.", "fx": {"cooldown": 0.85, "double": 0.25}},
	&"aura_of_light": {"name": "Aura des Lichts", "text": "Verbündete ringsum nehmen weniger Schaden.", "fx": {"aura_guard": 0.8}},
	&"heavenly_charge": {"name": "Himmelssturm", "text": "Erster Treffer doppelt, heilt Verbündete ringsum.", "fx": {"opener": 2.0, "aura_heal": 0.015}},
	&"legendary_presence": {"name": "Legendäre Gestalt", "text": "Mehr Leben und Stärke, Verbündete greifen schneller an.", "fx": {"hp": 1.15, "atk": 1.15, "aura_haste": 1.2}},
	&"magma_core": {"name": "Magmakern", "text": "Versengt Nachbarn, Nahkämpfer verbrennen sich.", "fx": {"aura_burn": 0.3, "thorns": 0.2}},
	&"tidal_body": {"name": "Flutkörper", "text": "Heilt sich bei Siegen, spült Gegner weg.", "fx": {"kill_heal": 0.2, "knock": 10.0}},
	&"sand_veil": {"name": "Sandschleier", "text": "Weicht oft aus.", "fx": {"dodge": 0.3}},
	&"flame_blade": {"name": "Flammenklinge", "text": "Treffer brennen lange nach.", "fx": {"burn": [0.35, 4.0]}},
	&"pyroclasm": {"name": "Pyroklasmus", "text": "Große Explosion um jedes Ziel.", "fx": {"splash": [0.6, 32.0]}},
	&"undertow": {"name": "Sog", "text": "Getroffene werden stark gebremst.", "fx": {"slow": [0.45, 2.0]}},
	&"hellfire_bite": {"name": "Höllenbiss", "text": "Brennt und raubt Leben.", "fx": {"burn": [0.25, 2.0], "leech": 0.15}},
	&"storm_arrows": {"name": "Sturmpfeile", "text": "Pfeile springen auf zwei weitere Gegner.", "fx": {"chain": [0.5, 2]}},
	&"frost_touch": {"name": "Frosthauch", "text": "Lässt Gegner ringsum frieren, weicht aus.", "fx": {"aura_chill": 0.7, "dodge": 0.1}},
	&"scalding_steam": {"name": "Brühheißer Dampf", "text": "Verbrüht Gegner ringsum jede Sekunde.", "fx": {"aura_burn": 0.4}},
	&"static_charge": {"name": "Statische Ladung", "text": "Betäubt oft kurz.", "fx": {"stun": [0.3, 0.4]}},
	&"lava_flow": {"name": "Lavastrom", "text": "Brennt lange, explodiert beim Tod.", "fx": {"burn": [0.2, 5.0], "death_blast": [1.5, 34.0]}},
	&"blinding_sand": {"name": "Blendsand", "text": "Getroffene treffen schlechter.", "fx": {"weaken": [0.6, 2.0]}},
	&"dragonfire": {"name": "Drachenfeuer", "text": "Brand und Flächenschaden.", "fx": {"burn": [0.3, 3.0], "splash": [0.35, 22.0]}},
	&"frost_breath": {"name": "Frostatem", "text": "Gefriert Getroffene oft.", "fx": {"stun": [0.25, 0.9]}},
	&"dragon_lance": {"name": "Drachenlanze", "text": "Erster Treffer doppelt, durchbohrt Gegner dahinter.", "fx": {"opener": 2.0, "splash": [0.5, 18.0]}},
	&"draconic_lore": {"name": "Drachenweisheit", "text": "Schnellere Zauber, mehr Schaden gegen Bosse.", "fx": {"cooldown": 0.8, "boss": 1.5}},
	&"bone_armor": {"name": "Knochenpanzer", "text": "Nimmt viel weniger Schaden.", "fx": {"reduce": 0.3}},
	&"regrowth": {"name": "Nachwachsen", "text": "Steht einmal je Kampf mit vollem Leben wieder auf.", "fx": {"revive": 1.0, "hp": 0.85}},
	&"stone_gaze": {"name": "Steinerner Blick", "text": "Versteinert Getroffene oft.", "fx": {"stun": [0.2, 1.5]}},
	&"three_heads": {"name": "Drei Köpfe", "text": "Schlägt oft doppelt zu, brennt und vergiftet.", "fx": {"double": 0.3, "burn": [0.2, 2.0]}},
	&"rebirth": {"name": "Wiedergeburt", "text": "Steht aus der Asche auf und explodiert dabei.", "fx": {"revive": 0.6, "death_blast": [1.5, 36.0]}},
	&"thunderclap": {"name": "Donnerschlag", "text": "Blitze springen weit, betäuben kurz.", "fx": {"chain": [0.4, 4], "stun": [0.1, 0.3]}},
	&"soul_harvest": {"name": "Seelenernte", "text": "Jeder Sieg stärkt Verbündete und heilt ihn.", "fx": {"kill_rally": [0.2, 3.0], "kill_heal": 0.1}},
	&"grave_guard": {"name": "Grabwächter", "text": "Wehrt oft ab, steht einmal wieder auf.", "fx": {"block": 0.25, "revive": 0.3}},
	&"blood_thirst": {"name": "Blutdurst", "text": "Raubt viel Leben.", "fx": {"leech": 0.3}},
	&"rotting_stench": {"name": "Fäulnisgestank", "text": "Schwächt Gegner ringsum mit Gift.", "fx": {"aura_burn": 0.2, "aura_chill": 0.8}},
	&"ancient_curse": {"name": "Uralter Fluch", "text": "Getroffene nehmen mehr Schaden und treffen schlechter.", "fx": {"mark": [0.2, 3.0], "weaken": [0.8, 3.0]}},
	&"ethereal": {"name": "Körperlos", "text": "Weicht vielen Treffern aus.", "fx": {"dodge": 0.35, "hp": 0.85}},
	&"weighing_hearts": {"name": "Herzwägung", "text": "Richtet fast Besiegte, Gold für jeden Sieg.", "fx": {"execute": 0.2, "kill_gold": 1}},
	&"runic_ward": {"name": "Runenschutz", "text": "Schützt sich zu Kampfbeginn, Treffer springen über.", "fx": {"start_shield": [0.3, 5.0], "chain": [0.4, 1]}},
	&"unbreakable": {"name": "Unzerbrechlich", "text": "Nimmt weniger Schaden, besonders mit wenig Leben.", "fx": {"reduce": 0.2, "last_stand": 0.4}},
	&"forge_heat": {"name": "Essenglut", "text": "Brennende Axthiebe, Nachbarn werden heiß.", "fx": {"burn": [0.25, 2.0], "aura_burn": 0.15}},
	&"iron_bulwark": {"name": "Eisenwall", "text": "Wehrt viel ab, Verbündete ringsum geschützt.", "fx": {"block": 0.35, "aura_guard": 0.9}},
	&"black_powder": {"name": "Schwarzpulver", "text": "Schüsse explodieren, oft kritisch.", "fx": {"splash": [0.4, 20.0], "crit": [0.15, 2.0]}},
	&"mjolnir": {"name": "Mjölnir", "text": "Blitz springt über und betäubt, mehr Schaden an Bossen.", "fx": {"chain": [0.6, 2], "stun": [0.15, 0.6], "boss": 1.25}},
	&"sunfire": {"name": "Sonnenfeuer", "text": "Brennende Pfeile mit großer Reichweite.", "fx": {"burn": [0.25, 3.0], "range": 1.1}},
	&"deep_roots": {"name": "Tiefe Wurzeln", "text": "Heilt Verbündete ringsum, nimmt weniger Schaden.", "fx": {"aura_heal": 0.015, "reduce": 0.15}},
	&"shadow_blade": {"name": "Schattenklinge", "text": "Erster Treffer dreifach, oft kritisch.", "fx": {"opener": 3.0, "crit": [0.2, 2.0]}},
	&"starlight": {"name": "Sternenlicht", "text": "Getroffene leuchten auf und nehmen mehr Schaden.", "fx": {"mark": [0.3, 2.5]}},
	&"pack_leader": {"name": "Leitwolf", "text": "Verbündete ringsum greifen schneller an.", "fx": {"aura_haste": 1.3}},
	&"basket_of_tricks": {"name": "Korb voller Tricks", "text": "Schwächt Getroffene und bremst sie.", "fx": {"weaken": [0.75, 2.0], "slow": [0.75, 2.0]}},
	&"storm_ride": {"name": "Sturmritt", "text": "Sehr schnell, weicht oft aus.", "fx": {"speed": 1.3, "dodge": 0.15}},
	&"frozen_heart": {"name": "Eisherz", "text": "Gefriert Getroffene, Gegner ringsum frieren.", "fx": {"stun": [0.15, 1.0], "aura_chill": 0.75}},
	&"serpent_hair": {"name": "Schlangenhaar", "text": "Vergiftet und versteinert manchmal.", "fx": {"burn": [0.2, 3.0], "stun": [0.1, 1.2]}},
	&"lure": {"name": "Lockruf", "text": "Getroffene werden herangezogen und geschwächt.", "fx": {"knock": -10.0, "weaken": [0.8, 2.0]}},
	&"trickery": {"name": "Täuschung", "text": "Weicht oft aus, erster Treffer doppelt.", "fx": {"dodge": 0.25, "opener": 2.0}},
	&"wolf_mount": {"name": "Wolfsreittier", "text": "Schnell, beißt doppelt.", "fx": {"speed": 1.25, "double": 0.25}},
	&"muspel_fire": {"name": "Muspelfeuer", "text": "Riesige Brandwunden, Feuer beim Tod.", "fx": {"burn": [0.4, 3.0], "death_blast": [2.0, 44.0]}},
	&"glacier": {"name": "Gletscher", "text": "Langsam, aber kaum zu verletzen, bremst Gegner.", "fx": {"reduce": 0.35, "speed": 0.8, "slow": [0.6, 1.5]}},
	&"mountain": {"name": "Berg", "text": "Riesig viel Leben, Nahkämpfer prallen ab.", "fx": {"hp": 1.4, "thorns": 0.15}},
	&"bull_rush": {"name": "Stieransturm", "text": "Erster Treffer doppelt, schleudert weg.", "fx": {"opener": 2.0, "knock": 14.0}},
	&"twelve_labors": {"name": "Zwölf Aufgaben", "text": "Stärker gegen Bosse, wird mit jedem Sieg kurz wütend.", "fx": {"boss": 1.6, "kill_haste": 2.0}},
	&"heel": {"name": "Ferse", "text": "Weicht fast allem aus, aber weniger Leben.", "fx": {"dodge": 0.5, "hp": 0.7}},
	&"winged_hooves": {"name": "Geflügelte Hufe", "text": "Sehr schnell, erster Treffer doppelt.", "fx": {"speed": 1.3, "opener": 2.0}},
	&"pure_horn": {"name": "Reines Horn", "text": "Heilt Verbündete ringsum, durchbohrt Gegner.", "fx": {"aura_heal": 0.015, "splash": [0.3, 16.0]}},
	&"nightmare_hooves": {"name": "Albtraumhufe", "text": "Brennende Tritte, die Angst machen.", "fx": {"burn": [0.25, 2.0], "weaken": [0.8, 2.0]}},
	&"eight_legs": {"name": "Acht Beine", "text": "Das schnellste Ross, tritt doppelt.", "fx": {"speed": 1.4, "double": 0.2}},
	&"drowning": {"name": "Ertränken", "text": "Zieht Getroffene heran und bremst sie stark.", "fx": {"knock": -8.0, "slow": [0.5, 2.0]}},
	&"chooser_of_slain": {"name": "Wählerin der Gefallenen", "text": "Ein Sieg stärkt Verbündete, steht einmal wieder auf.", "fx": {"kill_rally": [0.2, 3.0], "revive": 0.3}},
	&"alpha": {"name": "Alphatier", "text": "Verbündete ringsum greifen schneller an, Sieg macht rasend.", "fx": {"aura_haste": 1.15, "kill_haste": 3.0}},
	&"paid_in_gold": {"name": "Für Gold", "text": "Jeder Sieg bringt 2 Gold extra.", "fx": {"kill_gold": 2}},
	&"arcane_arrows": {"name": "Arkane Pfeile", "text": "Pfeile durchschlagen Rüstung: kritisch und markierend.", "fx": {"crit": [0.15, 2.0], "mark": [0.15, 2.0]}},
	&"tracker": {"name": "Fährtenleser", "text": "Größere Reichweite, mehr Schaden gegen Bosse.", "fx": {"range": 1.2, "boss": 1.3}},
	&"battle_magic": {"name": "Kampfmagie", "text": "Schnelle Zauber im Ritt, Flächenschaden.", "fx": {"speed": 1.15, "splash": [0.35, 22.0]}},
	&"triage": {"name": "Triage", "text": "Mehr Leben, schützt Verbündete ringsum.", "fx": {"hp": 1.2, "aura_guard": 0.9}},
	&"fairy_dust": {"name": "Feenstaub", "text": "Heilt ringsum und weicht aus.", "fx": {"aura_heal": 0.012, "dodge": 0.2}},
	&"sanctuary": {"name": "Heiligtum", "text": "Verbündete ringsum nehmen deutlich weniger Schaden.", "fx": {"aura_guard": 0.8}},
	&"natures_gift": {"name": "Gabe der Natur", "text": "Heilt Verbündete ringsum kräftig.", "fx": {"aura_heal": 0.025}},
	&"healing_spring": {"name": "Heilquelle", "text": "Heilt ringsum, wird selbst schneller.", "fx": {"aura_heal": 0.015, "cooldown": 0.85}},
	&"bark_shield": {"name": "Rindenschild", "text": "Schützt sich zu Kampfbeginn, Dornen.", "fx": {"start_shield": [0.4, 6.0], "thorns": 0.2}},
	&"quarantine": {"name": "Quarantäne", "text": "Vergiftet Gegner ringsum, heilt Verbündete.", "fx": {"aura_burn": 0.2, "aura_heal": 0.008}},
	&"voodoo": {"name": "Voodoo", "text": "Schwächt Gegner ringsum, steht einmal wieder auf.", "fx": {"aura_chill": 0.8, "revive": 0.35}},
	&"silver_light": {"name": "Silberlicht", "text": "Heilt ringsum und schützt.", "fx": {"aura_heal": 0.012, "aura_guard": 0.9}},
	&"guardian_angel": {"name": "Schutzengel", "text": "Verbündete ringsum geschützt, steht wieder auf.", "fx": {"aura_guard": 0.85, "revive": 0.5}},
	&"rod_of_asclepius": {"name": "Äskulapstab", "text": "Die stärkste Heilaura.", "fx": {"aura_heal": 0.03}},
	&"impale": {"name": "Aufspießen", "text": "Lange Lanze, erster Treffer dreifach.", "fx": {"range": 1.25, "opener": 3.0}},
	&"trident": {"name": "Dreizack", "text": "Trifft das Ziel und zwei Nachbarn.", "fx": {"chain": [0.6, 2]}},
	&"venom_kiss": {"name": "Giftkuss", "text": "Starkes Gift, raubt Leben.", "fx": {"burn": [0.35, 3.0], "leech": 0.1}},
	&"shock_coil": {"name": "Schockwindung", "text": "Betäubt oft, Blitze springen über.", "fx": {"stun": [0.2, 0.5], "chain": [0.4, 1]}},
	&"enchanted_prince": {"name": "Verwunschener Prinz", "text": "Steht einmal als Prinz wieder auf, stärker.", "fx": {"revive": 0.5, "atk": 1.1}},
	&"regenerate": {"name": "Molchblut", "text": "Heilt sich bei jedem Sieg kräftig.", "fx": {"kill_heal": 0.35}},
	&"sky_charge": {"name": "Himmelsangriff", "text": "Erster Treffer doppelt und betäubt, schnell.", "fx": {"opener": 2.0, "stun": [0.2, 0.7], "speed": 1.1}},
	&"sacred_bull": {"name": "Heiliger Stier", "text": "Mehr Leben, schleudert Gegner weg.", "fx": {"hp": 1.25, "knock": 12.0}},
	&"frost_wings": {"name": "Frostschwingen", "text": "Getroffene frieren und werden langsam.", "fx": {"slow": [0.55, 2.0], "stun": [0.1, 0.8]}},
	&"frost_armor": {"name": "Frostpanzer", "text": "Nimmt weniger Schaden, Angreifer werden langsamer.", "fx": {"reduce": 0.2, "aura_chill": 0.8}},
	&"shatter": {"name": "Zersplittern", "text": "Eisschüsse zersplittern um das Ziel.", "fx": {"splash": [0.45, 24.0], "slow": [0.7, 1.5]}},
	&"crusade": {"name": "Kreuzzug", "text": "Verbündete ringsum geschützt und schneller.", "fx": {"aura_guard": 0.9, "aura_haste": 1.15}},
	&"banish": {"name": "Bannfluch", "text": "Versengt Gegner ringsum, besonders Bosse.", "fx": {"aura_burn": 0.3, "boss": 1.4}},
	&"excalibur": {"name": "Excalibur", "text": "Mehr Stärke, Verbündete ringsum geschützt.", "fx": {"atk": 1.25, "aura_guard": 0.85}},
	&"archwizard": {"name": "Erzzauberer", "text": "Riesige Explosionen, schnellere Zauber.", "fx": {"splash": [0.6, 30.0], "cooldown": 0.85}},
	&"chicken_hut": {"name": "Hühnerbeinhütte", "text": "Schwächt Getroffene stark, steht einmal wieder auf.", "fx": {"weaken": [0.6, 3.0], "revive": 0.3}},
	&"tentacles": {"name": "Fangarme", "text": "Trifft viele Gegner zugleich und hält sie fest.", "fx": {"chain": [0.5, 3], "slow": [0.6, 1.5]}},
	&"rob_the_rich": {"name": "Den Reichen nehmen", "text": "Jeder Sieg bringt Gold, Schüsse oft doppelt.", "fx": {"kill_gold": 1, "double": 0.2}},
	&"dragonslayer": {"name": "Drachentöter", "text": "Doppelter Schaden gegen Bosse.", "fx": {"boss": 2.0}},
}


static func display_name(id: StringName) -> String:
	return TranslationServer.translate(INFO[id]["name"]) if INFO.has(id) else ""


static func description(id: StringName) -> String:
	return TranslationServer.translate(INFO[id]["text"]) if INFO.has(id) else ""


## Alle Bausteine der Merkmale `ids` zusammengefasst: Faktoren werden multipliziert, Anteile und
## Chancen addiert, Listen ([Wert, Sekunden]) nimmt das stärkere Merkmal.
static func combine(ids: Array) -> Dictionary:
	var fx := {}
	for id: StringName in ids:
		if not INFO.has(id):
			push_error("Unbekanntes Merkmal: %s" % id)
			continue
		var parts: Dictionary = INFO[id]["fx"]
		for key: String in parts:
			if not key in KEYS:
				push_error("Merkmal %s: unbekannter Baustein %s" % [id, key])
			var value = parts[key]
			if not fx.has(key):
				fx[key] = value
			elif key in ["hp", "atk", "speed", "range", "cooldown", "opener", "boss", "aura_guard", "aura_chill", "aura_haste"]:
				fx[key] = float(fx[key]) * float(value)
			elif value is Array:
				fx[key] = value if float(value[0]) > float(fx[key][0]) else fx[key]
			else:
				fx[key] = fx[key] + value
	return fx
