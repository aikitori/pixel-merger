class_name ArenaLayouts
## Grundrisse der Arenen. Erzeugt von tools/arena_dcss.py, nicht von Hand ändern.
## walk: begehbare Rechtecke (Fußpunkte). spawn: je Arm (WEST, NORTH, EAST, SOUTH) eine Strecke [von, bis].
## obstacles: feste Hindernisse (nur Bossarenen), sonst verteilt World sie zufällig.

const CROSS_TEXTURES: Array[String] = [
	"res://assets/sprites/tiles/arena.png",
	"res://assets/sprites/tiles/arena_cross_1.png",
	"res://assets/sprites/tiles/arena_cross_2.png",
	"res://assets/sprites/tiles/arena_cross_3.png",
	"res://assets/sprites/tiles/arena_cross_4.png",
]

const BOSS_LAYOUTS: Array[StringName] = [&"hall", &"chasm", &"ring"]

const LAYOUTS := {
	&"cross": {
		"walk": [Rect2(0, 110, 640, 132), Rect2(256, 38, 128, 282)],
		"spawn": [[Vector2(2, 110), Vector2(2, 242)], [Vector2(256, 40), Vector2(384, 40)], [Vector2(638, 110), Vector2(638, 242)], [Vector2(256, 318), Vector2(384, 318)]],
		"obstacles": [],
		"texture": "res://assets/sprites/tiles/arena.png",
	},
	&"hall": {
		"walk": [Rect2(30, 66, 580, 254), Rect2(0, 154, 38, 44), Rect2(602, 154, 38, 44)],
		"spawn": [[Vector2(2, 154), Vector2(2, 198)], [Vector2(296, 68), Vector2(344, 68)], [Vector2(638, 154), Vector2(638, 198)], [Vector2(260, 318), Vector2(380, 318)]],
		"obstacles": [{"pos": Vector2(96, 106), "kind": "pillar"}, {"pos": Vector2(190, 106), "kind": "pillar"}, {"pos": Vector2(450, 106), "kind": "pillar"}, {"pos": Vector2(544, 106), "kind": "pillar"}, {"pos": Vector2(96, 284), "kind": "pillar"}, {"pos": Vector2(190, 284), "kind": "pillar"}, {"pos": Vector2(450, 284), "kind": "pillar"}, {"pos": Vector2(544, 284), "kind": "pillar"}],
		"texture": "res://assets/sprites/tiles/arena_hall.png",
	},
	&"chasm": {
		"walk": [Rect2(0, 148, 640, 56), Rect2(198, 54, 244, 246)],
		"spawn": [[Vector2(2, 148), Vector2(2, 204)], [Vector2(296, 62), Vector2(344, 62)], [Vector2(638, 148), Vector2(638, 204)], [Vector2(296, 294), Vector2(344, 294)]],
		"obstacles": [{"pos": Vector2(216, 84), "kind": "ruin"}, {"pos": Vector2(424, 84), "kind": "ruin"}, {"pos": Vector2(216, 284), "kind": "ruin"}, {"pos": Vector2(424, 284), "kind": "ruin"}],
		"texture": "res://assets/sprites/tiles/arena_chasm.png",
	},
	&"ring": {
		"walk": [Rect2(46, 120, 548, 112), Rect2(102, 72, 436, 208), Rect2(182, 38, 276, 282), Rect2(0, 154, 58, 44), Rect2(582, 154, 58, 44)],
		"spawn": [[Vector2(2, 154), Vector2(2, 198)], [Vector2(256, 40), Vector2(384, 40)], [Vector2(638, 154), Vector2(638, 198)], [Vector2(256, 318), Vector2(384, 318)]],
		"obstacles": [{"pos": Vector2(140, 90), "kind": "pillar"}, {"pos": Vector2(500, 90), "kind": "pillar"}, {"pos": Vector2(140, 258), "kind": "pillar"}, {"pos": Vector2(500, 258), "kind": "pillar"}],
		"texture": "res://assets/sprites/tiles/arena_ring.png",
	},
}
