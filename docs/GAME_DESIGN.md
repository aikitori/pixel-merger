# Pixel Merger – Spielidee

Pixel-2D-Handyspiel inspiriert von der Warcraft-3-Custom-Map "Binders".

## Ablauf

Mehrere Runden, jede Runde besteht aus zwei Phasen:

1. **Bauphase (BUILD):** Einheiten mit Gold kaufen und miteinander kombinieren,
   z.B. Ritter + Pferd = Berittener Reiter.
2. **Kampfphase (BATTLE):** Läuft **automatisch** ab (keine Steuerung durch den Spieler)
   und hat ein **festes Zeitfenster**. Je mehr Gegner in dieser Zeit besiegt werden,
   desto mehr Gold gibt es für die nächste Bauphase.

## Regeln

- Kombinationen können **weiter kombiniert** werden (mehrstufig): Das Ergebnis eines Rezepts
  darf selbst Zutat eines anderen Rezepts sein.
- Jedes Rezept hat **genau zwei Zutaten**.
- Die Reihenfolge der Zutaten ist egal: A + B = B + A.
- **Gegner:** KI-Wellen, die mit der Runde stärker werden.
- **Kampfphase:** Während des Zeitfensters (x Sekunden bis Minuten) spawnen laufend neue Monster.
- **Kampfanimationen:** Nahkämpfer (Reichweite bis 30) schwingen das Schwert, Fernkämpfer schießen Pfeile (Linien Fernkampf, Elfen, Waldwesen und Schützen-Kombinationen), alle anderen Fernkämpfer werfen Feuerbälle. Der Stil steht pro Einheit in `attack_style` (erzeugt von `tools/generate_data.py`). Der Schaden wird beim Einschlag verteilt. Beim Laufen wippen die Figuren, bei Zielwechsel drehen sie sich weich (Spiegelung läuft über die Zeit, die Laufrichtung folgt dem Ziel mit Beschleunigung).
  Überleben bis zum Ende des Zeitfensters = Runde überstanden. Noch lebende Gegner bleiben
  folgenlos, es gibt keine Strafe.
- **Steuerung:** Einheiten kaufen und platzieren sich frei in der Arena (Bauphase: ziehen,
  auf eine andere Einheit ziehen = verbinden). Im Kampf handeln sie automatisch, können aber
  taktisch befehligt werden: Einheit antippen, dann Befehl wählen (Knopf "Befehl" unten):
  **Frei** (Freikampf, Standard: Gegner suchen und verfolgen), **Halten** (bleibt stehen, greift nur
  an, was in Reichweite kommt; ein Tipp aufs Feld schickt sie dorthin und sie hält dort) und
  **Schützen** (danach die andere Einheit antippen: bleibt an ihrer Seite und bekämpft Gegner in
  ihrer Nähe, ohne sich weit locken zu lassen; Heiler heilen den Schützling zuerst). Fällt der
  Schützling, wird die Einheit wieder frei. Erneutes Antippen der Einheit hebt den Befehl auf.
- **Fähigkeiten:** Jede Einheit hat genau eine Fähigkeit (`ability`, Namen/Wirkung in
  `scripts/abilities.gd`, Zuordnung in `tools/content.py`: pro Linie, Kombinationen erben die der
  Zutat, die nicht fürs Aussehen steht, z.B. Feuergolem = Golem + Feuer: Feuersturm). Die Stärke
  wächst mit der Stufe (Kombinationen starten höher). **Aktiv** (lösen im Kampf von selbst aus,
  wenn die Bedingung erfüllt und die Abklingzeit vorbei ist): Schild hoch, Pfeilregen, Feuersturm,
  Frostnova, Sprint, Massenheilung, Wiederbeleben (stellt den zuletzt Gefallenen mit halbem Leben auf),
  Spott, Kriegsruf. **Passiv:** Panzerung, Regeneration, Ausweichen, Lebensraub, Fluch-Aura
  (Gegner langsamer), Anführer-Aura (Verbündete mehr Schaden). Angezeigt im Info-Feld, Shop und Rezeptbuch.
  **Manuell auslösen:** Einheit im Kampf antippen, dann den Fähigkeitsknopf rechts unten (zeigt
  "Name!" wenn bereit, sonst die Restzeit). Der Knopf prüft dieselbe Bedingung wie die Automatik.
  Oben schaltet "Auto-Fähigk." die Automatik aus: Dann löst nur noch der Spieler aus.
- **Spezialrunden:** Jede fünfte Runde ist besonders. **Bossrunden** (5, 15, 25, ...): Ein Boss mit
  Krone und eigener Lebensleiste erscheint (reihum Ogerkönig, Feuerdrache, Knochenkönig,
  Steingigant, Werte in `BOSSES` in `tools/generate_data.py`), die Runde endet erst mit seinem Tod.
  Läuft die Kampfzeit ab, wird er wütend (mehr Schaden und Tempo). **Bonusrunden** (10, 20, 30, ...):
  Gegner geben dreifaches Gold und kommen schneller, am Ende gibt es eine Prämie (`Game.bonus_prize`).
  Die Bau-Leiste kündigt die Spezialrunde schon an.
- **Gelände:** Das Feld startet voller Hindernisse (18: Fels, Baum, Kristall, Ruinensäule). Nach jedem Boss (ab Runde 6, 16, 26, ...) verschwinden drei, nach sechs Bossen ist es frei. Die Platzierung ist fest. Figuren rutschen seitlich daran vorbei (`World.push_out_of_obstacles`); Platz in der Mitte und Armenden bleiben frei.
- **Erfolge:** Autoload `Achievements` (Liste in `scripts/autoload/achievements.gd`, Speicherung in
  `user://achievements.cfg`), Knopf "Erfolge" oben. Beispiele: erster Boss, erste Stufe-5-Einheit,
  Runde ohne Verluste, Bonusrunde, 100 Gegner, volle Arena, Wiederbeleben. Neue Erfolge werden
  oben eingeblendet.
- **Gewusel:** Gegner kommen in Rudeln (ab Runde 4 bis zu 2, ab Runde 8 bis zu 3), jeder läuft etwas
  anders schnell, eigene Einheiten ohne Gegner streifen um ihre Position, in der Bauphase hüpfen
  sie und schauen sich um. Treffer und Tode erzeugen kleine Funken- und Staubeffekte.
- **Menü und Sprache:** Das Spiel startet im Hauptmenü (`scenes/menu.tscn`): Starten, Erfolge, Sprache
  (Deutsch/Englisch), Ton, Beenden und die Version unten links (`application/config/version` in
  `project.godot`, muss mit `version/name` in `export_presets.cfg` übereinstimmen, ein Test prüft das).
  Alle Texte stehen deutsch im Code und laufen durch `tr()`; Englisch steht in `scripts/i18n/ui_en.gd`
  (Oberfläche) und `scripts/i18n/names_en.gd` (Namen, erzeugt aus `tools/i18n_names.py`). Neue Texte
  brauchen dort einen Eintrag, sonst bleiben sie deutsch. Die Wahl wird gespeichert, die Standardsprache
  richtet sich nach dem Gerät.
- **Niederlage:** Sind in der Kampfphase alle eigenen Einheiten tot, ist das Spiel verloren.
- **Einheitenlimit:** Im Kampf treten höchstens 20 Einheiten an (`Game.MAX_UNITS`). In der Bauphase dürfen bis zu 40
  stehen (`Game.BUILD_MAX_UNITS`), weil man für Rezepte viele Grundeinheiten braucht. Der Kampf startet erst, wenn
  höchstens 20 übrig sind. Überzählige schickt man per Knopf "Zurückschicken" zurück und bekommt 50 % des
  Kaufpreises der Grundeinheiten (`Game.REFUND_SHARE`, Verbinden wird nicht erstattet).
- **Gold:** kommt aus besiegten Gegnern der Kampfphase. Der Betrag hängt vom Gegnertyp
  und von der Runde ab, bis Runde 10 +10 % je Runde, danach nur noch +5 % je Runde.
- **Merge-Kosten:** Verbinden kostet Gold. Je größer und komplexer das Ergebnis, desto teurer
  (aktuell 12g für Stufe 2 bis 150g für die Legende, pro Rezept in `merge_cost`).
- **Werte:** Jede Einheit und Kombination hat Lebenspunkte (LP), Stärke (Schaden pro Treffer),
  Beweglichkeit (Lauftempo) und Intelligenz. Intelligenz = Chance (in Prozent, max. 90), im Kampf
  gezielt den schwächsten Gegner in der Nähe anzugreifen statt blind den nächsten.
  Dazu kommen Reichweite und Angriffstempo.
- **Rezeptbuch:** Button "Rezepte" in der Bauphase. Zeigt alle Kombinationen (Zutaten, Kosten,
  Freischaltrunde, Werte, Stufenfolge) und alle Linien mit Suchfeld. Noch gesperrte Rezepte
  sind abgedunkelt.
- **Fortschritt:** Je weiter man kommt, desto stärkere Merges werden verfügbar
  (Rezepte und Einheiten sind in Stufen/Tiers organisiert, die nach Runde freigeschaltet werden).
- **Spielwelt:** Ein Kreuz aus zwei Armen (West-Ost und Nord-Süd), außerhalb ist Abgrund mit
  Klippenkante. Die eigenen Einheiten stehen in der Mitte, die Gegner kommen aus allen vier
  Richtungen (reihum, jede Richtung gleich oft) und laufen zur Mitte. Figuren können das Kreuz
  nie verlassen (`scripts/world.gd`: Form, Spawnpunkte, Begrenzung).
- **Kampftempo:** Im Kampf ersetzt ein Tempo-Knopf (1x/2x/3x) Shop und Rezeptbuch.
- **Zurück-Taste (Android) / Esc:** schließt zuerst Rezeptbuch, dann die Kaufliste, dann das Dorf, erst danach die App.
- **Abstellen:** Eine Einheit, die neben eine nicht verbindbare gezogen wird, bleibt einfach dort
  stehen. Zurückspringen gibt es nur, wenn ein Rezept existiert, aber gesperrt ist oder Gold fehlt.
- **Format:** Querformat, 640x360.

- **Veteranen:** Neben der Stufe aus dem Verbinden (1-5) hat jede eigene Einheit eine Veteranenstufe
  1-10 aus Erfahrung: +1 pro besiegtem Gegner, +6 für einen Boss, +2 pro überlebter Runde
  (Schwellen in `Combatant.VETERAN_XP`). Jede Veteranenstufe gibt +4 % Leben und Stärke. Ab Stufe 5
  kommt eine zweite, aktive Fähigkeit dazu, passend zum Kampfstil (Nahkampf: Kriegsschrei, Fernkampf:
  Pfeilregen oder Frostnova, Heiler: Massenheilung oder Wiederbeleben). Beim Verbinden behält das
  Ergebnis die Erfahrung der erfahreneren Zutat. Abzeichen an der Figur: Bronze, Silber ab 5, Gold bei 10.
- **Rundenmodifikatoren:** Ab Runde 2 haben etwa 70 % der normalen Runden eine Sonderregel (`scripts/modifiers.gd`),
  angekündigt in der Bauphase und als Wetter sichtbar.
- **Ereignisse zwischen den Runden:** Ab Runde 3 manchmal drei Angebote zur Wahl (`scripts/round_events.gd`),
  spätestens nach drei Runden ohne Ereignis. Segen von Schmied, Rüstmeister und Hexe gelten für den ganzen Lauf.
- **Geheimrezepte:** Fünf Kombinationen (`SECRET_TABLE` in `tools/content.py`) stehen erst nach dem
  Entdecken im Rezeptbuch, gespeichert in `user://progress.cfg` (Autoload `Progress`).

## Offene Fragen

- Balancing: Stand nach Audit (Oktober 2026): Ein Test-Bot, der sich wie ein Mensch auf drei
  Linien konzentriert und Paare mergt, erreicht Runde 5 bis 10. Nahkampf-lastige Aufstellungen
  sind etwas schwächer als Fernkampf in der Mitte. Feintuning per Spieltest.
- Ende: aktuell endlos bis zur Niederlage (kein Boss/Sieg).

## Ideen (noch nicht umgesetzt)

### Merge-Zone statt Verbinden durch Ziehen

Stand: Idee vom 4. Oktober 2026, bewusst zurückgestellt.

- **Ablauf:** Verbunden wird nicht mehr, indem man eine Einheit auf eine andere zieht. Stattdessen gibt
  es eine markierte Merge-Zone auf dem Feld (Vorschlag: im Südarm direkt unter dem Steinplatz, dort
  dürfen dann keine Hindernisse liegen). Die Zutaten werden in die Zone gezogen, das Ergebnis
  erscheint außerhalb der Zone.
- **Auslöser (entschieden):** ein Knopf "Verbinden (Xg)". Die Vorschau rechts zeigt Zutaten und
  Ergebnis, der Knopf verbindet. Kein automatisches Verbinden, weil bei Rezepten mit drei Zutaten
  oft schon zwei davon ein eigenes Rezept ergeben (z.B. Ritter + Pferd).
- **Zone:** höchstens 3 Einheiten. Passt der Inhalt zu keinem Rezept, sagt die Vorschau das. Stufen-
  aufstieg (zwei gleiche Einheiten) läuft ebenfalls über die Zone.
- **Rezepte mit drei Zutaten (entschieden: etwa 8 zum Start).** Entwurf:
  - Templer: Ritter + Magier + Heiler
  - Zerberus: Wolf + Ghul + Flamme
  - Elementarfürst: Flamme + Welle + Kiesel
  - Waldläufer: Bogenschütze + Wolf + Waldelf
  - Streitwagen: Streitross + Ritter + Bogenschütze
  - Kopfloser Reiter: Skelett + Pferd + Flamme
  - Weltenbaum: Waldelf + Kiesel + Tropfen
  - Golddrache: Drachenjunges + Funke + Zwergenkrieger
- **Technik:** `RecipeData` braucht eine dritte Zutat (`ingredient_c`), `Registry` eine Suche nach
  einer Menge von Zutaten. Anzupassen: Rezeptbuch (drei Symbole), Rezeptliste beim Anfassen
  (zwei Partner), Schnellkauf (`base_units`), `tools/content.py` und die Generatoren, Test-Bot
  und Eingabetests (die heute per Ziehen verbinden).

## Shop, Entwicklungslinien und Kombinationen (umgesetzt)

- **Dorf (Shop):** Der Knopf "Dorf" unten links wechselt in eine eigene Ansicht, ein Dorf mit
  sechs Häusern. Jedes Haus gehört einer Kategorie von Grundeinheiten: Kaserne (Klassisch),
  Gildenhaus (Fantasy), Märchenhütte (Märchen), Tempel (Mythologie), Elementarturm (Elemente), Lazarett (Heilkunst).
  Ein Tipp auf ein Haus öffnet dessen Kaufliste, ein Tipp auf eine Einheit kauft sie (Preis je
  Linie, `price` in `tools/content.py`). Die Einheit erscheint zufällig in der Mitte der Arena,
  der Knopf "Arena" kehrt zurück. Die Arena bleibt das Kreuz mit Kampf. Das Dorf gibt es nur in
  der Bauphase.
- **Platzieren und Verbinden** geht auf dem **gesamten Kreuz**: Einheiten lassen sich überall hin
  ziehen, ziehen auf eine andere Einheit = verbinden.
- **Linien (je ein Shop-Eintrag der Stufe 1, 5 Stufen mit eigenen Namen):** Nahkampf (Bauer -> Leibwächter),
  Fernkampf, Magie, Reittiere; Fantasy: Zwerge, Elfen, Untote, Drachen; Märchen: Hexen, Wölfe,
  Riesen; Mythologie: Waldwesen (Satyr -> Chiron); Elemente: Feuer, Wasser, Erde, Wind;
  Heilkunst: Heiler (Kräuterkundiger -> Heiler -> Schamane -> Arzt -> Lebensspender).
  **Heiler** (`attack_style = heal`) greifen nie an: Sie laufen zum verletzten Verbündeten und heilen ihn
  mit einem Zauber (Stärke = `attack`, Intelligenz = Chance, den mit dem kleinsten Lebensanteil zu
  wählen). Ohne Patient bleiben sie bei den Verbündeten, mit Positionsbefehl halten sie die Stellung.
  **Heil-Kombinationen** (alles mit einem Heiler als Zutat heilt selbst): Feldarzt (Ritter + Heiler), Fee,
  Priester, Druide, Quellnymphe, Dryade, Pestdoktor, Medizinmann, Silbereinhorn, Engel, Asklepios.
- **Selbst-Merge:** Zwei gleiche Einheiten ergeben die nächste Stufe der Linie. Kosten und
  Werte steigen pro Stufe, höhere Stufen werden erst mit der Runde freigeschaltet.
- **Kombinationen:** Zwei verschiedene Einheiten ergeben eine Kombination, z.B. Ritter + Pferd =
  Berittener Reiter, Golem + Feuer (Flamme) = Feuergolem, Magier + Flamme = Pyromant.
  Jede Kombination hat selbst 3 Selbst-Merge-Stufen mit eigenen Namen.
- Die **Stufenzahl** (aktuell 5 pro Linie, 3 pro Kombination) ist ein Platzhalter und steht
  allein in `tools/content.py`.

Offen:

- Weitere Kombinationen (neue Zeile in `COMBO_TABLE` genügt, Werte, Kosten, Freischaltung und
  Farbe werden berechnet). Bisher gibt es 70 Kombinationen (Drachenreiter, Phönix, Nekromant, Sleipnir, Medusa, Thor, Herkules, Schneekönigin ...), definiert in der Tabelle `COMBO_TABLE` in `tools/content.py`.
- Im Shop sind nur die Stufe-1-Einheiten kaufbar; höhere Stufen und Kombinationen entstehen
  durch Merges.

## Technik

- Godot 4.4, Renderer "Mobile", GDScript.
- Pixel-Art: Basisauflösung 640x360, Integer-Skalierung, Nearest-Filter, Pixel-Snapping.
- Einheiten, Gegner und Rezepte sind Resources (`UnitData`, `RecipeData`) unter `data/`.

## Sound und Musik (umgesetzt)

- Alle Klänge sind selbst synthetisiert (`tools/generate_audio.py`, nur Standardbibliothek):
  14 Effekte (Schwert, Pfeil, Feuerball, Treffer, Explosion, Tod, Gold, Kauf, Verbinden, Klick,
  Fehler, Kampfbeginn, Runde geschafft, Game Over) und zwei Musikstücke als nahtlose Schleifen
  (ruhig für die Bauphase, treibend für den Kampf), Überblendung beim Phasenwechsel.
- Autoload `Sound`: Mindestabstand pro Effekt, damit viele Angriffe nicht zu Lärm werden; jeder
  Knopf klickt automatisch. Oben rechts schaltet "Ton an/aus" alles stumm (wird gespeichert).
  Im Hintergrund (Android/iOS) ist die App still.

- **Mehrfachauswahl (Kampfphase):** Auswahlrahmen (auf freiem Boden ziehen), Umschalt-/Strg-Klick, Knopf "Mehrfach" (Antippen fügt hinzu oder nimmt heraus) Knopf "Alle" und Doppeltipp auf eine Einheit (wählt alle gleichen). Ziel-Tipp, Befehlsknopf (Halten, Schützen, Frei) und Fähigkeitsknopf gelten für alle gewählten Einheiten; beim Losschicken bleiben die Abstände der Gruppe erhalten. Die Karte links zeigt die Hauptauswahl und "+N".
