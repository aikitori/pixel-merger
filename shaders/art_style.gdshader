shader_type canvas_item;
// Bildstil als Nachbearbeitung über das ganze Bild (siehe ArtStyle). Das Spiel rendert in 640x360,
// ein Bildschirmpixel ist also ein Spielpixel.
//   1 Taschenkonsole: vier Grüntöne mit geordnetem Dithering
//   2 Tusche & Pergament: Papier, Tuschekonturen, Schraffur in Schatten, aquarellierte Farbe
//   3 Neon-Nacht: dunkles Bild, leuchtende Kanten in der Farbe des Objekts, Bildzeilen
//   4 Zuckerwatte: Pastell, aufgehellte Schatten, weiche lila Konturen statt Schwarz
//   5 Düsterwald: entsättigt, kalte Schatten, nur Rot bleibt kräftig, Vignette und Korn
//   6 Höllenshooter: warm-schmutzige Erdtöne, harter Kontrast, wenige Farbstufen, Körnung
//   7 Kerker: Fackellicht für die Dungeon-Crawl-Kacheln, warm in der Mitte, dunklere Ränder, sonst unverändert

uniform sampler2D screen_tex : hint_screen_texture, filter_nearest;
uniform int style = 0;

float luma(vec3 c) {
	return dot(c, vec3(0.299, 0.587, 0.114));
}

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(12.9898, 78.233))) * 43758.5453);
}

float smooth_noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1.0, 0.0)), f.x),
			mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), f.x), f.y);
}

float bayer4(vec2 p) {
	int x = int(mod(p.x, 4.0));
	int y = int(mod(p.y, 4.0));
	int m[16] = int[16](0, 8, 2, 10, 12, 4, 14, 6, 3, 11, 1, 9, 15, 7, 13, 5);
	return (float(m[y * 4 + x]) + 0.5) / 16.0;
}

vec3 rgb2hsv(vec3 c) {
	vec4 K = vec4(0.0, -1.0 / 3.0, 2.0 / 3.0, -1.0);
	vec4 p = mix(vec4(c.bg, K.wz), vec4(c.gb, K.xy), step(c.b, c.g));
	vec4 q = mix(vec4(p.xyw, c.r), vec4(c.r, p.yzx), step(p.x, c.r));
	float d = q.x - min(q.w, q.y);
	float e = 1.0e-10;
	return vec3(abs(q.z + (q.w - q.y) / (6.0 * d + e)), d / (q.x + e), q.x);
}

vec3 hsv2rgb(vec3 c) {
	vec4 K = vec4(1.0, 2.0 / 3.0, 1.0 / 3.0, 3.0);
	vec3 p = abs(fract(c.xxx + K.xyz) * 6.0 - K.www);
	return c.z * mix(K.xxx, clamp(p - K.xxx, 0.0, 1.0), c.y);
}

vec3 tap(vec2 uv, vec2 px, vec2 o) {
	return texture(screen_tex, uv + o * px).rgb;
}

// Kantenstärke (Sobel) auf Helligkeit und Farbe.
float edge_at(vec2 uv, vec2 px) {
	vec3 tl = tap(uv, px, vec2(-1, -1)), t = tap(uv, px, vec2(0, -1)), tr = tap(uv, px, vec2(1, -1));
	vec3 l = tap(uv, px, vec2(-1, 0)), r = tap(uv, px, vec2(1, 0));
	vec3 bl = tap(uv, px, vec2(-1, 1)), b = tap(uv, px, vec2(0, 1)), br = tap(uv, px, vec2(1, 1));
	vec3 gx = -tl - 2.0 * l - bl + tr + 2.0 * r + br;
	vec3 gy = -tl - 2.0 * t - tr + bl + 2.0 * b + br;
	return length(vec2(length(gx), length(gy))) * 0.35;
}

// Liegt das Pixel auf der dunkleren Seite einer Kante? Dann wird die Kontur nur einen Pixel breit.
bool darker_side(vec2 uv, vec2 px, float l) {
	float nb = luma(tap(uv, px, vec2(1, 0))) + luma(tap(uv, px, vec2(-1, 0)))
			+ luma(tap(uv, px, vec2(0, 1))) + luma(tap(uv, px, vec2(0, -1)));
	return l < nb * 0.25 - 0.02;
}

void fragment() {
	vec2 px = SCREEN_PIXEL_SIZE;
	vec2 uv = SCREEN_UV;
	vec2 pix = floor(uv / px);
	vec3 c = texture(screen_tex, uv).rgb;
	float l = luma(c);
	vec3 o = c;
	vec2 centered = uv - 0.5;
	float vig = dot(centered, centered);

	if (style == 1) {
		vec3 pal[4] = vec3[4](vec3(0.06, 0.22, 0.06), vec3(0.19, 0.38, 0.19), vec3(0.55, 0.67, 0.06), vec3(0.61, 0.74, 0.06));
		float lv = clamp((l - 0.08) * 1.25, 0.0, 1.0);
		float q = clamp(floor(lv * 3.0 + (bayer4(pix) - 0.5) * 0.12 + 0.5), 0.0, 3.0);
		if (edge_at(uv, px) > 0.6 && darker_side(uv, px, l)) {
			q = 0.0;
		}
		o = pal[int(q)];
		// LCD-Raster: jede zweite Zeile minimal dunkler
		o *= mod(pix.y, 2.0) < 1.0 ? 1.0 : 0.94;
	} else if (style == 2) {
		float grain = smooth_noise(pix * 0.08) * 0.6 + smooth_noise(pix * 0.6) * 0.4;
		vec3 paper = vec3(0.95, 0.89, 0.74) * (0.92 + 0.08 * grain);
		float lq = floor(l * 4.0 + 0.5) / 4.0;
		vec3 wash = mix(vec3(lq), c, 0.3);
		o = paper * (0.42 + 0.68 * wash);
		vec3 ink = vec3(0.17, 0.11, 0.08);
		if (l < 0.33 && mod(pix.x + pix.y, 4.0) < 1.0) {
			o = mix(o, ink, 0.75);
		}
		if (l < 0.18 && mod(pix.x - pix.y, 4.0) < 1.0) {
			o = mix(o, ink, 0.85);
		}
		if (edge_at(uv, px) > 0.35 && darker_side(uv, px, l)) {
			o = ink;
		}
		o *= 1.0 - vig * 0.55;
	} else if (style == 3) {
		vec3 hsv = rgb2hsv(c);
		vec3 neon = hsv2rgb(vec3(hsv.x, max(hsv.y, 0.75), 1.0));
		float e = edge_at(uv, px);
		// Leuchten: Kanten der Nachbarschaft mit abnehmendem Gewicht
		float glow = 0.0;
		glow += edge_at(uv + vec2(2.0, 0.0) * px, px) + edge_at(uv - vec2(2.0, 0.0) * px, px);
		glow += edge_at(uv + vec2(0.0, 2.0) * px, px) + edge_at(uv - vec2(0.0, 2.0) * px, px);
		glow *= 0.12;
		o = c * c * 0.12 + vec3(0.02, 0.0, 0.06);
		o += neon * clamp(e * 1.6, 0.0, 1.2);
		o += neon * glow * 0.8;
		if (l > 0.82) {
			o = mix(o, vec3(0.85, 1.0, 1.0), 0.8);
		}
		o *= mod(pix.y, 2.0) < 1.0 ? 1.0 : 0.72;
		// leichte Farbverschiebung an den Rändern
		o.r += texture(screen_tex, uv + vec2(1.0, 0.0) * px).r * 0.06;
		o.b += texture(screen_tex, uv - vec2(1.0, 0.0) * px).b * 0.08;
	} else if (style == 4) {
		vec3 hsv = rgb2hsv(c);
		hsv.y *= 0.6;
		if (hsv.x > 0.2 && hsv.x < 0.45) {
			hsv.x += 0.07;  // Gras und Blätter Richtung Mint
		}
		hsv.z = 0.45 + 0.55 * hsv.z;
		o = hsv2rgb(hsv);
		o = mix(o, vec3(1.0, 0.93, 0.97), 0.12);
		if (l < 0.28) {
			o = vec3(0.38, 0.25, 0.46);
		}
		o = mix(o, vec3(1.0, 0.86, 0.93), vig * 0.5);
	} else if (style == 5) {
		vec3 hsv = rgb2hsv(c);
		vec3 grey = vec3(l);
		o = mix(grey, c, 0.12) * vec3(0.82, 0.92, 1.06);
		bool red = (hsv.x < 0.035 || hsv.x > 0.94) && hsv.y > 0.45 && hsv.z > 0.3;
		if (red) {
			o = mix(o, vec3(0.78, 0.08, 0.06) * (0.5 + hsv.z * 0.6), 0.85);
		}
		o = pow(o, vec3(1.6)) * 1.18;
		float shadow = 1.0 - smoothstep(0.0, 0.45, l);
		o += vec3(0.0, 0.04, 0.06) * shadow;
		o += vec3(0.05, 0.03, 0.0) * smoothstep(0.6, 1.0, l);
		o *= 1.0 - vig * 1.5;
		o += (hash(pix) - 0.5) * 0.06;
	} else if (style == 6) {
		vec3 hsv = rgb2hsv(c);
		hsv.y *= 0.82;
		if (hsv.x > 0.17 && hsv.x < 0.45) {
			hsv.x = mix(hsv.x, 0.13, 0.2);  // Gras Richtung Oliv und Erde
		}
		o = hsv2rgb(hsv) * vec3(1.05, 0.97, 0.86);
		o = pow(o, vec3(1.25)) * 1.1;
		o += (hash(pix) - 0.5) * 0.07;
		o = floor(o * 14.0 + bayer4(pix) * 0.8) / 14.0;
		// zum oberen und unteren Rand dunkler, wie schwaches Deckenlicht
		o *= 1.0 - pow(abs(uv.y - 0.5) * 2.0, 3.0) * 0.35;
	} else if (style == 7) {
		o = pow(c, vec3(1.08)) * 1.06;
		o *= mix(vec3(1.05, 0.98, 0.88), vec3(1.0), smoothstep(0.0, 0.25, vig));
		o *= 1.0 - vig * 0.9;
	}
	COLOR = vec4(clamp(o, 0.0, 1.0), 1.0);
}
