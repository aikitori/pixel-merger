"""Englische Namen aller Einheiten, Linien, Gegner und Kategorien (Schlüssel: der deutsche Name).

Wird von generate_data.py geprüft (jeder Name in content.py braucht einen Eintrag) und als
scripts/i18n/names_en.gd ausgegeben. Gleiche deutsche Namen haben immer dieselbe Übersetzung.
"""

EN = {
    # Nahkampf
    'Bauer': 'Peasant', 'Knappe': 'Squire', 'Ritter': 'Knight', 'Kreuzritter': 'Crusader', 'Leibwächter': 'Bodyguard',
    # Fernkampf
    'Schleuderer': 'Slinger', 'Bogenschütze': 'Archer', 'Jäger': 'Hunter', 'Scharfschütze': 'Sharpshooter',
    'Falkenauge': 'Hawkeye',
    # Magie
    'Lehrling': 'Apprentice', 'Magier': 'Mage', 'Erzmagier': 'Archmage', 'Großmeister': 'Grand Master',
    'Weltenweber': 'World Weaver',
    # Reittiere
    'Fohlen': 'Foal', 'Pferd': 'Horse', 'Streitross': 'Warhorse', 'Schlachtross': 'Destrier', 'Sturmross': 'Storm Steed',
    # Zwerge
    'Minenarbeiter': 'Miner', 'Zwergenkrieger': 'Dwarf Warrior', 'Axtmeister': 'Axe Master', 'Zwergenlord': 'Dwarf Lord',
    'Bergkönig': 'Mountain King',
    # Elfen
    'Elfenspäher': 'Elf Scout', 'Waldelf': 'Wood Elf', 'Hochelf': 'High Elf', 'Elfenfürst': 'Elf Lord',
    'Elfenkönig': 'Elf King',
    # Untote
    'Skelett': 'Skeleton', 'Ghul': 'Ghoul', 'Wiedergänger': 'Revenant', 'Todesritter': 'Death Knight',
    'Lichkönig': 'Lich King',
    # Drachen
    'Drachenei': 'Dragon Egg', 'Wyrmling': 'Wyrmling', 'Junger Drache': 'Young Dragon', 'Drache': 'Dragon',
    'Urdrache': 'Elder Dragon',
    # Hexen
    'Kräuterfrau': 'Herbalist', 'Hexe': 'Witch', 'Zauberhexe': 'Sorceress', 'Schwarze Hexe': 'Dark Witch',
    'Hexenkönigin': 'Witch Queen',
    # Wölfe
    'Wolfswelpe': 'Wolf Pup', 'Wolf': 'Wolf', 'Schattenwolf': 'Shadow Wolf', 'Werwolf': 'Werewolf',
    'Fenriswolf': 'Fenrir',
    # Riesen
    'Gnom': 'Gnome', 'Troll': 'Troll', 'Riese': 'Giant', 'Zyklop': 'Cyclops', 'Titan': 'Titan',
    # Waldwesen
    'Satyr': 'Satyr', 'Faun': 'Faun', 'Zentaur': 'Centaur', 'Kentaurenfürst': 'Centaur Lord', 'Chiron': 'Chiron',
    # Feuer
    'Funke': 'Spark', 'Flamme': 'Flame', 'Feuergeist': 'Fire Spirit', 'Feuerelementar': 'Fire Elemental', 'Ifrit': 'Ifrit',
    # Wasser
    'Tropfen': 'Droplet', 'Strudel': 'Whirlpool', 'Wassergeist': 'Water Spirit', 'Wasserelementar': 'Water Elemental',
    'Leviathan': 'Leviathan',
    # Erde
    'Felskäfer': 'Rock Beetle', 'Golem': 'Golem', 'Moorgeist': 'Bog Spirit', 'Erdelementar': 'Earth Elemental', 'Kristallkoloss': 'Crystal Colossus',
    # Wind
    'Windhauch': 'Breath of Wind', 'Brise': 'Breeze', 'Harpyie': 'Harpy', 'Luftelementar': 'Air Elemental',
    'Dschinn': 'Djinn',
    # Heiler
    'Kräuterkundiger': 'Herb Lore Healer', 'Heiler': 'Healer', 'Schamane': 'Shaman', 'Arzt': 'Doctor',
    'Lebensspender': 'Lifegiver',
    # handgemachte Kombinationen
    'Berittener Reiter': 'Mounted Knight', 'Schwerer Reiter': 'Heavy Rider', 'Reiter-Champion': 'Rider Champion',
    'Berittener Schütze': 'Mounted Archer', 'Reitender Bogner': 'Horse Archer', 'Steppenjäger': 'Steppe Hunter',
    'Paladin': 'Paladin', 'Hochpaladin': 'High Paladin', 'Lichtbringer': 'Lightbringer',
    'Heiliger Reiter': 'Holy Rider', 'Erzheiliger Reiter': 'Archholy Rider', 'Himmelsreiter': 'Sky Rider',
    'Legende': 'Legend', 'Mythos': 'Myth', 'Halbgott': 'Demigod',
    # Element-Kombinationen
    'Feuergolem': 'Fire Golem', 'Lavagolem': 'Lava Golem', 'Magmakoloss': 'Magma Colossus',
    'Wassergolem': 'Water Golem', 'Schlammgolem': 'Mud Golem', 'Flutkoloss': 'Flood Colossus',
    'Sandgolem': 'Sand Golem', 'Sturmgolem': 'Storm Golem', 'Wirbelkoloss': 'Whirl Colossus',
    'Flammenritter': 'Flame Knight', 'Glutritter': 'Ember Knight', 'Inferno-Paladin': 'Inferno Paladin',
    'Pyromant': 'Pyromancer', 'Feuermagier': 'Fire Mage', 'Flammenfürst': 'Flame Lord',
    'Hydromant': 'Hydromancer', 'Gezeitenmagier': 'Tide Mage', 'Meeresherr': 'Sea Lord',
    'Feuerwolf': 'Fire Wolf', 'Höllenhund': 'Hellhound', 'Zerberus': 'Cerberus',
    'Sturmschütze': 'Storm Archer', 'Blitzjäger': 'Lightning Hunter', 'Donnerfalke': 'Thunder Falcon',
    # Tabelle: Elemente
    'Frostgeist': 'Frost Spirit', 'Eisgeist': 'Ice Spirit', 'Winterkönig': 'Winter King',
    'Dampfgeist': 'Steam Spirit', 'Dampfwolke': 'Steam Cloud', 'Geysir': 'Geyser',
    'Blitz': 'Lightning', 'Gewitterwolke': 'Thundercloud', 'Donnergott': 'Thunder God',
    'Lavastein': 'Lava Stone', 'Lavaelementar': 'Lava Elemental', 'Vulkan': 'Volcano',
    'Sandsturm': 'Sandstorm', 'Wüstengeist': 'Desert Spirit', 'Sandkönig': 'Sand King',
    # Drachen und Mischwesen
    'Feuerwyrm': 'Fire Wyrm', 'Feuerdrache': 'Fire Dragon', 'Höllendrache': 'Hell Dragon',
    'Frostwyrm': 'Frost Wyrm', 'Eisdrache': 'Ice Dragon', 'Frostkönig': 'Frost King',
    'Drachenreiter': 'Dragon Rider', 'Drachenritter': 'Dragon Knight', 'Drachenfürst': 'Dragon Lord',
    'Drachenmagier': 'Dragon Mage', 'Drachenweiser': 'Dragon Sage', 'Drachenlord': 'Dragon Overlord',
    'Knochenwyrm': 'Bone Wyrm', 'Knochendrache': 'Bone Dragon', 'Todesdrache': 'Death Dragon',
    'Hydra': 'Hydra', 'Mehrkopf-Hydra': 'Many-Headed Hydra', 'Lernäische Hydra': 'Lernaean Hydra',
    'Basilisk': 'Basilisk', 'Königsbasilisk': 'King Basilisk', 'Versteinerer': 'Petrifier',
    'Chimäre': 'Chimera', 'Große Chimäre': 'Great Chimera', 'Urchimäre': 'Primal Chimera',
    'Phönix': 'Phoenix', 'Feuerphönix': 'Fire Phoenix', 'Sonnenvogel': 'Sun Bird',
    'Donnervogel': 'Thunderbird', 'Blitzvogel': 'Lightning Bird', 'Sturmvogel': 'Storm Bird',
    # Untote
    'Nekromant': 'Necromancer', 'Totenbeschwörer': 'Death Summoner', 'Todesmagier': 'Death Mage',
    'Skelettritter': 'Skeleton Knight', 'Knochenritter': 'Bone Knight', 'Grabritter': 'Grave Knight',
    'Vampir': 'Vampire', 'Blutgraf': 'Blood Count', 'Vampirfürst': 'Vampire Lord',
    'Zombieriese': 'Zombie Giant', 'Fäulnisriese': 'Rot Giant', 'Seuchenfürst': 'Plague Lord',
    'Mumie': 'Mummy', 'Pharao': 'Pharaoh', 'Wüstenkönig': 'Desert King',
    'Geist': 'Ghost', 'Poltergeist': 'Poltergeist', 'Banshee': 'Banshee',
    'Schakalwächter': 'Jackal Guard', 'Anubis': 'Anubis', 'Totenrichter': 'Judge of the Dead',
    # Zwerge
    'Runenmeister': 'Rune Master', 'Runenschmied': 'Runesmith', 'Runenkönig': 'Rune King',
    'Steinwächter': 'Stone Guardian', 'Bergwächter': 'Mountain Guardian', 'Titanenwächter': 'Titan Guardian',
    'Feuerzwerg': 'Fire Dwarf', 'Schmiedemeister': 'Forge Master', 'Essenkönig': 'Forge King',
    'Zwergenritter': 'Dwarf Knight', 'Eisenwächter': 'Iron Guard', 'Schildträger': 'Shield Bearer',
    'Zwergenschütze': 'Dwarf Gunner', 'Armbrustmeister': 'Crossbow Master', 'Meisterschütze': 'Master Marksman',
    'Thor': 'Thor', 'Donnerer': 'Thunderer',
    # Elfen
    'Feuerelf': 'Fire Elf', 'Glutelf': 'Ember Elf', 'Sonnenelf': 'Sun Elf',
    'Baumhüter': 'Tree Keeper', 'Ent': 'Ent', 'Uralter Ent': 'Ancient Ent',
    'Dunkelelf': 'Dark Elf', 'Schattenelf': 'Shadow Elf', 'Nachtelf': 'Night Elf',
    'Elfenmagier': 'Elf Mage', 'Sternenmagier': 'Star Mage', 'Erzdruide': 'Arch Druid',
    'Tierflüsterer': 'Beast Whisperer', 'Wildhüter': 'Wild Warden', 'Herr der Wälder': 'Lord of the Forests',
    # Hexen und Märchen
    'Rotkäppchen': 'Red Riding Hood', 'Wolfsbändigerin': 'Wolf Tamer', 'Waldhexe': 'Forest Witch',
    'Besenreiterin': 'Broom Rider', 'Sturmhexe': 'Storm Witch', 'Wetterhexe': 'Weather Witch',
    'Eishexe': 'Ice Witch', 'Schneekönigin': 'Snow Queen', 'Winterhexe': 'Winter Witch',
    'Medusa': 'Medusa', 'Gorgone': 'Gorgon', 'Gorgonenkönigin': 'Gorgon Queen',
    'Sirene': 'Siren', 'Meeressirene': 'Sea Siren', 'Sirenenkönigin': 'Siren Queen',
    'Loki': 'Loki', 'Trickster': 'Trickster', 'Feuerlist': 'Fire Cunning',
    'Koboldreiter': 'Goblin Rider', 'Wolfsgnom': 'Wolf Gnome', 'Gnomenhäuptling': 'Gnome Chieftain',
    # Riesen
    'Feuerriese': 'Fire Giant', 'Muspel': 'Muspel', 'Surtr': 'Surtr',
    'Frostriese': 'Frost Giant', 'Eisriese': 'Ice Giant', 'Ymir': 'Ymir',
    'Steinriese': 'Stone Giant', 'Felsriese': 'Rock Giant', 'Bergriese': 'Mountain Giant',
    'Minotaurus': 'Minotaur', 'Labyrinthwächter': 'Labyrinth Guardian', 'Stierkrieger': 'Bull Warrior',
    'Herkules': 'Hercules', 'Halbgott-Held': 'Demigod Hero', 'Olymp-Held': 'Hero of Olympus',
    'Achilles': 'Achilles', 'Held von Troja': 'Hero of Troy', 'Unverwundbarer': 'The Invulnerable',
    # Pferde und Reittiere
    'Pegasus': 'Pegasus', 'Sturmpegasus': 'Storm Pegasus', 'Himmelspegasus': 'Sky Pegasus',
    'Einhorn': 'Unicorn', 'Sonnenhorn': 'Sun Horn', 'Lichteinhorn': 'Light Unicorn',
    'Nachtmahr': 'Nightmare', 'Höllenross': 'Hell Steed', 'Höllenhengst': 'Hell Stallion',
    'Sleipnir': 'Sleipnir', 'Sturm-Sleipnir': 'Storm Sleipnir', 'Wotans Ross': "Odin's Steed",
    'Kelpie': 'Kelpie', 'Nöck': 'Nix', 'Meeresross': 'Sea Steed',
    'Walküre': 'Valkyrie', 'Schildmaid': 'Shieldmaiden', 'Walküren-Fürstin': 'Valkyrie Princess',
    'Wolfsritter': 'Wolf Knight', 'Wolfskrieger': 'Wolf Warrior', 'Alpha-Ritter': 'Alpha Knight',
    # Grundlinien untereinander
    'Söldner': 'Mercenary', 'Veteran': 'Veteran', 'Kriegsherr': 'Warlord',
    'Arkanschütze': 'Arcane Archer', 'Arkanjäger': 'Arcane Hunter', 'Arkanmeister': 'Arcane Master',
    'Tierjäger': 'Beast Hunter', 'Wildjäger': 'Wild Hunter', 'Herr der Meute': 'Lord of the Pack',
    'Magierreiter': 'Mage Rider', 'Arkanreiter': 'Arcane Rider', 'Zauberreiter': 'Spell Rider',
    # Heil-Kombinationen
    'Feldarzt': 'Field Medic', 'Lazarettarzt': 'Hospital Doctor', 'Generalarzt': 'Surgeon General',
    'Fee': 'Fairy', 'Lichtfee': 'Light Fairy', 'Feenkönigin': 'Fairy Queen',
    'Priester': 'Priest', 'Hohepriester': 'High Priest', 'Erzbischof': 'Archbishop',
    'Druide': 'Druid', 'Hochdruide': 'High Druid', 'Waldweiser': 'Forest Sage',
    'Quellnymphe': 'Spring Nymph', 'Undine': 'Undine', 'Meeresnymphe': 'Sea Nymph',
    'Dryade': 'Dryad', 'Baumnymphe': 'Tree Nymph', 'Waldmutter': 'Forest Mother',
    'Pestdoktor': 'Plague Doctor', 'Seuchenarzt': 'Pestilence Doctor', 'Herr der Pest': 'Lord of the Plague',
    'Medizinmann': 'Medicine Man', 'Voodoo-Priester': 'Voodoo Priest', 'Stammesältester': 'Tribal Elder',
    'Silbereinhorn': 'Silver Unicorn', 'Heilendes Einhorn': 'Healing Unicorn', 'Lebenseinhorn': 'Life Unicorn',
    'Engel': 'Angel', 'Erzengel': 'Archangel', 'Seraph': 'Seraph',
    'Asklepios': 'Asclepius', 'Heilgott': 'God of Healing', 'Gott der Heilkunst': 'God of Medicine',
    # Linien
    'Nahkampf': 'Melee', 'Fernkampf': 'Ranged', 'Magie': 'Magic', 'Reittiere': 'Mounts', 'Zwerge': 'Dwarves',
    'Elfen': 'Elves', 'Untote': 'Undead', 'Drachen': 'Dragons', 'Hexen': 'Witches', 'Wölfe': 'Wolves',
    'Riesen': 'Giants', 'Waldwesen': 'Forest Creatures', 'Feuer': 'Fire', 'Wasser': 'Water', 'Erde': 'Earth',
    'Wind': 'Wind',
    # Kategorien und Dorfhäuser
    'Klassisch': 'Classic', 'Fantasy': 'Fantasy', 'Märchen': 'Fairy Tale', 'Mythologie': 'Mythology',
    'Elemente': 'Elements', 'Heilkunst': 'Healing', 'Kombination': 'Combination',
    'Kaserne': 'Barracks', 'Gildenhaus': 'Guild Hall', 'Märchenhütte': 'Fairy Cottage', 'Tempel': 'Temple',
    'Elementarturm': 'Elemental Tower', 'Lazarett': 'Infirmary',
    # Gegner und Bosse
    'Goblin': 'Goblin', 'Oger': 'Ogre', 'Ork': 'Orc', 'Schleim': 'Slime', 'Skelett-Bogenschütze': 'Skeleton Archer',
    'Ogerkönig': 'Ogre King', 'Knochenkönig': 'Bone King', 'Steingigant': 'Stone Giant',
    # Geheimrezepte
    'König Artus': 'King Arthur', 'Hochkönig Artus': 'High King Arthur', 'Ewiger König': 'Eternal King',
    'Merlin': 'Merlin the Mage', 'Merlin der Weise': 'Merlin the Wise', 'Merlin der Ewige': 'Merlin the Eternal',
    'Baba Jaga': 'Baba Yaga', 'Knochenhexe': 'Bone Witch', 'Hexe der Hühnerhütte': 'Witch of the Chicken Hut',
    'Krake': 'Octopus', 'Riesenkrake': 'Giant Octopus', 'Kraken': 'The Kraken',
    'Robin Hood': 'Robin of Locksley', 'König der Diebe': 'Prince of Thieves', 'Held von Sherwood': 'Hero of Sherwood',
}
