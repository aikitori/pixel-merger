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
- **Gegner:** KI-Wellen, die mit der Runde stärker werden: Leben +15 %, Schaden +8 % je Runde (linear).
  Ab Runde 11 kommt ein aufeinander aufbauender Zuwachs dazu (Leben x1,08, Schaden x1,05 je Runde,
  `Game.LATE_*`), weil Stufen, Veteranen und Hausausbau die eigene Armee schneller als linear stärken.
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
  **Aus Mythologie, Rollenspiel und Echtzeitstrategie** (vor allem für Kombinationen, `COMBO_ABILITY_OVERRIDE`):
  Kettenblitz (Thor, Donnervogel, Runenmeister), Versteinern (Medusa, Basilisk), Betörender Gesang (Sirene,
  Kelpie), Wirbelwind (Minotaurus, Skelettritter), Sturmangriff (Nachtmahr, Sleipnir, Drachenreiter: Ansturm,
  erster Treffer doppelt und betäubt), Beschwörung (Nekromant ruft Skelette, Tierflüsterer und Tierjäger Wölfe,
  zählen nicht als Einheiten und verschwinden nach etwa 10 s), Schattenschritt (Loki, Dunkelelf, Geist),
  Giftwolke (Hydra, Zombieriese), Erdbeben (Steinriese, Baumhüter), Heiliges Licht (Priester, Engel),
  Feueratem (Feuerdrache, Chimäre), Verhexen (Baba Yaga, Besenreiterin: halber Schaden), Flutwelle (Kraken,
  Hydromant: stößt zurück), Göttlicher Schutz (Paladin, Achilles: unverwundbar), Berserkerwut (Wolfsritter,
  Feuerriese). Passiv: Dornen (Dryade, Zwergenritter), Kritischer Treffer (Zwergenschütze, Arkanschütze),
  Richtspruch (Anubis: fast besiegte Gegner fallen sofort). Betäubungen wirken bei Bossen nur 40 % so lang.
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
  Mit jeder Geländestufe wechselt auch der Mauerstil des Kreuzes: grauer Stein, Backstein, bewachsene Mauern,
  Marmor, dunkle Reliefs (danach von vorn).
- **Bossarenen:** Bossrunden spielen nicht im Kreuz, sondern reihum in einer eigenen Arena
  (`World.layout_for_round`): **Thronsaal** (Runde 5, 35, ...: große Halle mit Säulenreihen, rotem Teppich,
  Tor in der Rückwand, Seitengängen und Treppe), **Abgrund** (15, 45, ...: Brücke über die Tiefe, Plattform in
  der Mitte, Gegner kommen auch aus zwei Portalen) und **Rundarena** (25, 55, ...: achteckiger Sandplatz mit vier
  Toren). Die Hindernisse dort sind fest. Beim Wechsel rücken Figuren außerhalb des neuen Bodens auf den
  nächsten freien Platz, ein Hinweis kündigt die Arena an. Grundrisse: `LAYOUTS` in `tools/arena_dcss.py`,
  daraus erzeugt `scripts/arena_layouts.gd` (begehbare Rechtecke, Tore, Hindernisse).
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
- **Niederlage:** Sind in der Kampfphase alle eigenen Einheiten tot, ist das Spiel verloren. Der Bildschirm zeigt
  eine Auswertung des Laufs (besiegte Gegner, erbeutetes Gold, Verbindungen, stärkste Einheit nach dem Preis ihrer
  Grundeinheiten, `Game.stats`) und den Rekord.
- **Spielstand:** Der laufende Lauf wird gespeichert (`scripts/run_save.gd`, `user://run.cfg`): zu Beginn jeder Bauphase,
  nach einem Ereignis, beim Kampfstart (Stand vor dem Kampf), beim Verlassen und wenn die App in den Hintergrund geht.
  Gespeichert werden Runde, Gold, Modifikator, Segen, Hausausbau, Auswertung, Einheiten mit Ort und Erfahrung und die
  Angebote eines offenen Ereignisses (`RoundEvents.to_save`, beim Fortsetzen stehen dieselben wieder zur Wahl). Im Menü steht dann "Fortsetzen (Runde X)" und "Neues Spiel"
  (verwirft den Lauf erst beim zweiten Tipp). Nach einer Niederlage wird der Stand gelöscht. Wer im Kampf
  aufhört, macht beim Kampfbeginn weiter.
- **Rekord:** Die höchste erreichte Runde aller Läufe (`Progress.best_round`, in `user://progress.cfg`) steht im Menü
  unten rechts und auf dem Verloren-Bildschirm ("Neuer Rekord!", wenn der Lauf ihn verbessert hat).
- **Einheitenlimit:** Im Kampf treten höchstens 20 Einheiten an (`Game.MAX_UNITS`). In der Bauphase dürfen bis zu 40
  stehen (`Game.BUILD_MAX_UNITS`), weil man für Rezepte viele Grundeinheiten braucht. Der Kampf startet erst, wenn
  höchstens 20 übrig sind. Überzählige schickt man per Knopf "Zurückschicken" zurück und bekommt 50 % des
  Kaufpreises der Grundeinheiten (`Game.REFUND_SHARE`, Verbinden wird nicht erstattet).
- **Gold:** kommt aus besiegten Gegnern der Kampfphase. Der Betrag hängt vom Gegnertyp
  und von der Runde ab, bis Runde 10 +10 % je Runde, danach nur noch +5 % je Runde.
- **Merge-Kosten:** Verbinden kostet Gold. Je größer und komplexer das Ergebnis, desto teurer
  (aktuell 12g für Stufe 2 bis 150g für die Legende, pro Rezept in `merge_cost`).
- **Alles verbinden:** In der Bauphase erscheint über "Kampf starten" der Knopf "Verbinden Nx: Gg",
  sobald zwei gleiche Einheiten verbunden werden können. Er verbindet alle gleichen Paare zur nächsten
  Stufe, niedrigste Stufe zuerst, solange Gold und Freischaltrunde reichen (auch in Folge: vier Bauern
  ergeben einen Ritter). Kombinationen aus verschiedenen Einheiten bleiben Handarbeit, damit keine
  geplante Zutat verloren geht. Die erfahrenste Einheit wird mit der unerfahrensten verbunden.
- **Hausausbau:** In der Kaufliste jedes Dorfhauses lässt sich das Haus ausbauen. Jede Stufe gibt allen
  Einheiten dieser Kategorie +8 % Leben und Stärke, Kombinationen anteilig nach ihren Grundeinheiten
  (Paladin aus 4 Bauern und 2 Lehrlingen zählt ganz zur Kaserne). Preis 30g, je Stufe x1,8 (30, 54, 97,
  175, ...): eine Goldsenke ohne Obergrenze für späte Runden. Gilt für den laufenden Lauf, das Schild
  am Haus zeigt die Stufe.
- **Linien der Dorfhäuser:** Ab Ausbaustufe 2 (`HOUSE_LINE_LEVEL` in `tools/content.py`) bietet jedes Haus
  eine eigene Linie an, vorher steht sie gesperrt in der Kaufliste ("ab Ausbau 2"):
  Kaserne Garde (Speerträger bis Feldmarschall, Wirbelwind), Gildenhaus Nagas (Naga bis Nagakönigin, Giftwolke),
  Märchenhütte Frösche (Laubfrosch bis Froschkönig, Bezaubern), Tempel Greifen (Hippogreif bis Himmelsgreif,
  Sturmangriff), Elementarturm Eis (Schneeflocke bis Frostfürst, Frostnova), Lazarett Kloster (Novize bis
  Heiliger, heilen mit Heiligem Licht). Dazu 13 Kombinationen: Lanzenreiter (Pikenier + Pferd), Triton
  (Speerträger + Tropfen), Lamia (Naga + Hexe), Blitznatter (Naga + Funke), Froschprinz (Frosch + Ritter),
  Molch (Laubfrosch + Tropfen), Greifenreiter (Greif + Ritter), Apis (Hippogreif + Pferd), Frostgreif
  (Greif + Frostwicht), Frostritter (Schneeflocke + Ritter), Eismagier (Schneeflocke + Magier), Templer
  (Mönch + Ritter, heilt), Exorzist (Mönch + Skelett, heilt). Geheimrezept: Sankt Georg (Gardist + Wyrmling).
- **Höhere Stufen direkt kaufen:** Ab Runde 8 (`Game.DIRECT_BUY_ROUND`) stehen in der Kaufliste neben jeder
  Grundeinheit Knöpfe für Stufe 2 und 3. Preis: Grundeinheiten und Verbindungskosten mal 1,25
  (`Registry.shop_price`), z.B. Knappe 20g statt 2 x 5g + 6g. Stufe 4 und 5 entstehen weiter nur durch
  Verbinden. Ob etwas kaufbar ist, entscheidet `Registry.buy_block_reason` (Hausausbau, Runde).
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
- **Pause:** Im Kampf hält der Knopf "Pause" oben das Spiel an (`PausePanel`, der Szenenbaum pausiert, die Oberfläche
  läuft weiter), "Weiter" oder die Zurück-Taste setzt fort. Geht die App im Kampf in den Hintergrund, pausiert sie
  von selbst.
- **Ton:** Der Ton-Knopf (Menü und Spiel) schaltet reihum: alles an, nur Effekte (Musik auf eigenem Bus stumm),
  alles aus. Die Wahl steht in `user://settings.cfg`.
- **Einstieg:** Beim ersten Lauf zeigt `Tutorial` oben rechts kurze Hinweise: im Dorf kaufen, zwei gleiche Einheiten
  verbinden, Kampf starten, durchhalten. Jeder Hinweis verschwindet, sobald der Schritt gemacht ist, und versteckt
  sich, solange ein Fenster offen ist. Danach oder mit "Ausblenden" merkt sich `Progress`, dass er gezeigt wurde.
- **Leistung:** Figuren holen die Mitglieder ihrer Gruppe aus einer gemeinsamen Liste, die nur bei Änderungen neu
  gebaut wird, das Abstandhalten prüft nur nahe Figuren (Raster), und `World` hält die Hindernisse kompakt für das
  Herausschieben. Mit 20 eigenen Einheiten und 80 Gegnern rund ein Drittel weniger Rechenzeit je Schritt.
- **Zurück-Taste (Android) / Esc:** schließt zuerst Rezeptbuch, dann die Kaufliste, dann das Dorf, erst danach die App.
- **Abstellen:** Eine Einheit, die neben eine nicht verbindbare gezogen wird, bleibt einfach dort
  stehen. Zurückspringen gibt es nur, wenn ein Rezept existiert, aber gesperrt ist oder Gold fehlt.
- **Format:** Querformat, 640x360.

- **Veteranen:** Neben der Stufe aus dem Verbinden (1-5) hat jede eigene Einheit eine Veteranenstufe
  1-10 aus Erfahrung: +1 pro besiegtem Gegner, +6 für einen Boss, +2 pro überlebter Runde, Heiler zusätzlich +1 je Heilung im Umfang der Lebenspunkte ihrer Patienten (nicht für Selbstheilung)
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
  - Elementarfürst: Flamme + Strudel + Felskäfer
  - Waldläufer: Bogenschütze + Wolf + Waldelf
  - Streitwagen: Streitross + Ritter + Bogenschütze
  - Kopfloser Reiter: Skelett + Pferd + Flamme
  - Weltenbaum: Waldelf + Felskäfer + Tropfen
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

## Bildstil "Kerker" mit Dungeon-Crawl-Kacheln (umgesetzt)

- Alle Figuren, Gegner, Arena, Dorf und Oberflächenteile kommen aus den 32x32-Kacheln von Dungeon Crawl
  Stone Soup (CC0, `tools/dcss/`). Perspektive wie dort: Boden und Mauern von oben, Figuren schräg von vorn.
- Einheiten: passende Monsterkachel oder eine Figur aus Puppenteilen (Körper, Rüstung, Helm, Waffe, Schild,
  Umhang). Was fehlt, ist im selben Stil selbst gezeichnet: Pferd (mit Fellfarben, Schabracke, Stirnpanzer,
  Horn, Flügeln) und Drachenei. Reiter sitzen mit dem Oberkörper auf dem Pferd oder Wolf.
- Kombinationen haben je Stufe eine eigene Kachel oder werden mit Stufe 2 und 3 in ihrer Farbe umrandet.
- Namen folgen dem Bild: Felskäfer, Strudel, Moorgeist, Harpyie, Kristallkoloss, Armbrustmeister.
- Animation wie bei 0x72: je 4 Bilder Stehen (Atmen) und Laufen (Wippen, schwingende Beine), aus jeder Kachel
  abgeleitet (`assets/sprites/anim/`). Auch im Dorf und im Menü bewegen sich die Figuren so.
- Arena schräg von oben: Mauern zeigen oben ihre Vorderseite (mit Zinnen, Fackeln, Bannern), unten nur
  niedrige Zinnen, damit niemand verdeckt wird. Tore an den Stellen, an denen Gegner erscheinen (Torbogen mit
  Fallgitter, dunkler Gang, Treppe, Portal). Der Steinplatz mit Runenkreis liegt eine Stufe erhöht. Hindernisse
  sind Baum, Eisblock, Säulenstumpf, Säule und Fels. Dorf: Häuser aus Mauerkacheln mit Tür und Schmuck, Wege, Brunnen.
- Oberfläche: dunkler Granit mit Stahl- oder Goldrand wie die Reiter in Dungeon Crawl, Goldhaufen als Münze.
  Nachbearbeitung "Kerker": leicht warmes Fackellicht, dunklere Bildränder.
- Der Clonk-Stil (`generate_sprites.py --figures clonk`) und der Holz-Stil (`--classic`) sind erhalten, aber nicht
  im Spiel wählbar.
- Einheiten, Gegner und Rezepte sind Resources (`UnitData`, `RecipeData`) unter `data/`.

## Sound und Musik (umgesetzt)

- 16 Effekte (Schwert, Pfeil, Feuerball, Heilen, Blättern, Treffer, Explosion, Tod, Gold, Kauf,
  Verbinden, Klick, Fehler, Kampfbeginn, Runde geschafft, Game Over). 15 davon sind CC0-Aufnahmen von
  Kenney und Juhani Junkala (per Hörprobe ausgesucht, `CC0_SFX` in `tools/generate_audio.py`), der
  Kampfbeginn ist synthetisiert. Die zwei Musikstücke sind selbst erzeugt, nahtlose Schleifen
  (ruhig für die Bauphase, treibend für den Kampf), Überblendung beim Phasenwechsel.
- Autoload `Sound`: Mindestabstand pro Effekt, damit viele Angriffe nicht zu Lärm werden; jeder
  Knopf klickt automatisch. Oben rechts schaltet "Ton an/aus" alles stumm (wird gespeichert).
  Im Hintergrund (Android/iOS) ist die App still.

- **Mehrfachauswahl (Kampfphase):** Auswahlrahmen (auf freiem Boden ziehen), Umschalt-/Strg-Klick, Knopf "Mehrfach" (Antippen fügt hinzu oder nimmt heraus), Knopf "Alle" und Doppeltipp auf eine Einheit (wählt alle gleichen). **Abwählen:** Mit Auswahl heißt der Knopf "Keine" und hebt sie auf; ebenso Zurück/Esc, Rechtsklick und ein Tipp auf die einzige gewählte Einheit (ein Tipp auf ein Gruppenmitglied wählt nur dieses). Ein Tipp, der abwählt, zählt nicht als Beginn eines Doppeltipps. Ziel-Tipp, Befehlsknopf (Halten, Schützen, Frei) und Fähigkeitsknopf gelten für alle gewählten Einheiten; beim Losschicken bleiben die Abstände der Gruppe erhalten. Die Karte links zeigt die Hauptauswahl und "+N".
