#!/usr/bin/env python3
"""Génère scripts/rooms_hautfer.gd : les 24 salles des Galeries de Hautfer (Z1).

Le plan vient de la carte détaillée de Hautfer et de la Lande. Une case du plan vaut un écran,
soit 40 × 22 cases de 32 pixels. Chaque salle est construite ici avec quelques outils
(murs, corniches, éboulis, passages), puis écrite en caractères comme les autres salles.

Usage : python3 tools/gen_hautfer.py   (réécrit scripts/rooms_hautfer.gd)
On peut ensuite retoucher les salles à la main dans le .gd ; relancer ce script écrase ces retouches.
"""
from pathlib import Path

CW, CH = 40, 22   # une case du plan, en cases de 32 px


class R:
    def __init__(self, rid, name, w, h):
        self.id, self.name = rid, name
        self.W, self.H = CW * w, CH * h
        self.g = [["#"] * self.W for _ in range(self.H)]
        self.doors = {}
        self.hints = []
        self.extra = {}
        # intérieur : 2 cases de roche sur les côtés et en haut, 3 en bas
        self.fill(2, 2, self.W - 3, self.H - 4, " ")

    def fill(self, x0, y0, x1, y1, ch):
        for y in range(max(0, y0), min(self.H, y1 + 1)):
            for x in range(max(0, x0), min(self.W, x1 + 1)):
                self.g[y][x] = ch
        return self

    def put(self, x, y, s):
        for i, ch in enumerate(s):
            if 0 <= x + i < self.W:
                self.g[y][x + i] = ch
        return self

    def plat(self, x, y, n, ch="#"):
        return self.fill(x, y, x + n - 1, y, ch)

    def hint(self, x, y, text):
        self.hints.append([x, y, text])
        return self

    # --- passages -------------------------------------------------------------------------
    def side(self, side, seg, digit, dest, ledge=8):
        """Passage sur le côté gauche (W) ou droit (E), au niveau du sol de la rangée seg."""
        y0 = CH * seg + 16
        x_edge, x_in = (0, 1) if side == "W" else (self.W - 1, self.W - 2)
        for y in range(y0, y0 + 3):
            self.g[y][x_edge] = digit
            self.g[y][x_in] = " "
        # un sol sous le passage, vers l'intérieur
        if side == "W":
            self.fill(0, y0 + 3, ledge - 1, y0 + 3, "#")
        else:
            self.fill(self.W - ledge, y0 + 3, self.W - 1, y0 + 3, "#")
        self.doors[digit] = dest
        return self

    def top(self, x, digit, dest):
        """Passage vers le haut : un trou de 4 cases dans le plafond (colonnes x à x+3)."""
        self.fill(x, 0, x + 3, 0, digit)
        self.fill(x, 1, x + 3, 1, " ")
        self.doors[digit] = dest
        return self

    def bottom(self, x, digit, dest, grate=False):
        """Passage vers le bas : un trou dans le sol. grate : couvert d'une grille fissurée."""
        H = self.H
        self.fill(x, H - 3, x + 3, H - 2, " ")
        if grate:
            self.fill(x, H - 3, x + 3, H - 3, "X")
        self.fill(x, H - 1, x + 3, H - 1, digit)
        self.doors[digit] = dest
        return self

    def _jit(self, *k):
        """Petit bruit déterministe (0, 1 ou 2) pour casser les formes trop régulières."""
        h = 0
        for v in (self.id,) + k:
            for ch in str(v):
                h = (h * 131 + ord(ch)) % 1000003
        return h % 3

    def wl(self, top, end, depth=3):
        """Corniche de roche accrochée au mur gauche (jusqu'à la colonne end) ;
        le dessous s'épaissit vers le mur, de façon irrégulière."""
        self.fill(2, top, end, top, "#")
        for k in range(1, depth + 1):
            self.fill(2, top + k, end - 2 * k - self._jit(top, k), top + k, "#")
        return self

    def wr(self, top, start, depth=3):
        """Corniche de roche accrochée au mur droit (à partir de la colonne start)."""
        self.fill(start, top, self.W - 3, top, "#")
        for k in range(1, depth + 1):
            self.fill(start + 2 * k + self._jit(top, k), top + k, self.W - 3, top + k, "#")
        return self

    def rough(self, y0, y1, depth=2):
        """Parois irrégulières : des bosses de roche le long des deux murs, entre y0 et y1."""
        for y in range(y0, y1 + 1):
            for side in (0, 1):
                d = min(depth, (self._jit(y // 2, side) + self._jit(y // 3, side, 1)) // 2 + self._jit(y // 5, side, 2) // 2)
                for i in range(d):
                    x = 2 + i if side == 0 else self.W - 3 - i
                    if self.g[y][x] == " " and all(not self.g[yy][0 if side == 0 else self.W - 1].isdigit()
                                                    for yy in range(max(0, y - 1), min(self.H, y + 5))):
                        self.g[y][x] = "#"
        return self

    def mound(self, steps, floor=None):
        """Un tas (éboulis, gradins, piles) : [(x0, x1, haut), ...], plein jusqu'au sol."""
        floor = self.H - 4 if floor is None else floor
        for x0, x1, y in steps:
            self.fill(x0, y, x1, floor, "#")
        return self

    def spot(self, x, y, s):
        """Pose un objet ou un ennemi sur une case vide (vérifié)."""
        for i in range(len(s)):
            assert self.g[y][x + i] == " ", (self.id, x + i, y, self.g[y][x + i])
        return self.put(x, y, s)

    def rows(self):
        return ["".join(r) for r in self.g]


def build():
    rooms = []

    def mk(*a):
        r = R(*a)
        rooms.append(r)
        return r

    # ======================================================================== la surface
    r = mk("h22_belvedere", "Le belvédère", 1, 1)
    r.side("E", 0, "1", ["h14_maison", "1"])
    r.fill(2, 2, 37, 3, "#")                     # le ciel bas, la falaise au-dessus
    r.plat(2, 7, 9).put(5, 6, "f").put(7, 6, "f")
    r.plat(14, 16, 6, "=").plat(8, 13, 6, "=").plat(14, 10, 6, "=")
    r.put(26, 18, "G")
    r.hint(18, 12, "La nuit, la brume se fige.")
    r.hint(18, 13, "On voit toute la Lande, et Albion au loin.")

    r = mk("h14_maison", "La maison de Gerold", 1, 2)
    r.side("W", 0, "1", ["h22_belvedere", "1"], ledge=26)
    r.side("E", 1, "2", ["h15_place", "1"])
    r.fill(0, 19, 25, 19, "#")                   # le plancher de la chambre
    # l'escalier de la maison, en lacets, dont il manque des marches
    r.plat(22, 38, 4).plat(29, 35, 4).plat(23, 32, 4).plat(30, 29, 4)
    r.plat(24, 26, 4).plat(31, 25, 7).plat(26, 22, 3)
    r.fill(8, 38, 12, 40, "#").spot(10, 37, "f")  # l'établi de l'atelier
    r.spot(8, 18, "l").spot(14, 18, "c")
    r.hint(4, 12, "La chambre d'Ilse.")
    r.hint(4, 33, "L'atelier de Gerold.")

    r = mk("h15_place", "La place du Puits", 3, 1)
    r.side("W", 0, "1", ["h14_maison", "2"])
    r.side("E", 0, "2", ["h12_rue", "1"])
    r.bottom(58, "3", ["h18_fond_puits", "2"])
    r.fill(56, 18, 57, 18, "w").fill(62, 18, 63, 18, "w")
    r.plat(61, 15, 8, "-")                       # le treuil du puits
    for x in (14, 24, 80, 92):                   # les tables du dernier repas
        r.plat(x, 17, 6)
    r.put(17, 16, "c").put(27, 16, "c").put(84, 16, "c").put(40, 18, "cc").put(100, 18, "c")
    r.put(36, 18, "E").put(98, 18, "E").put(70, 8, "G").put(20, 6, "G")
    r.plat(104, 16, 4).plat(96, 13, 6).put(98, 12, "f")
    r.hint(46, 12, "Le puits du bourg.")
    r.hint(10, 12, "Les tables du dernier repas sont encore dressées.")

    r = mk("h18_fond_puits", "Le fond du puits", 1, 1)
    r.bottom(18, "1", ["h06_roulage", "2"])
    r.top(18, "2", ["h15_place", "3"])
    # la voûte de la cave, percée par le cylindre du puits (colonnes 17 à 23)
    r.fill(2, 2, 16, 7, "#").fill(24, 2, 37, 7, "#").fill(2, 8, 9, 8, "#").fill(31, 8, 37, 9, "#")
    r.plat(17, 7, 2).plat(21, 4, 3)              # les pierres déchaussées du cuvelage
    r.plat(21, 10, 6, "-")                       # la poutre du treuil, coincée en travers
    r.mound([(22, 27, 16), (28, 36, 13)])        # l'éboulis de maçonnerie tombée du puits
    r.spot(6, 18, "c").spot(33, 12, "R")
    r.hint(4, 12, "Une corde pend encore.")

    r = mk("h12_rue", "La rue de la Forge", 3, 1)
    r.side("W", 0, "1", ["h15_place", "2"])
    r.side("E", 0, "2", ["h13_forge", "1"])
    r.bottom(58, "3", ["h17_maison_commune", "1"])
    r.plat(61, 15, 8, "-")
    r.fill(30, 16, 37, 18, "#").fill(40, 18, 44, 18, "^")   # la rue s'est effondrée
    r.plat(71, 16, 4).fill(76, 13, 90, 13, "#").put(84, 12, "f")
    r.fill(96, 16, 99, 18, "#")
    r.put(20, 18, "E").put(72, 18, "E").put(106, 18, "E").put(50, 7, "G").put(100, 6, "G")
    r.put(10, 18, "cc").put(66, 18, "c")
    r.hint(58, 10, "La maison commune s'est enfoncée dans la mine.")

    r = mk("h17_maison_commune", "La maison commune", 2, 1)
    r.top(58, "1", ["h12_rue", "3"])
    # le toit enfoncé : le puits de jour (colonnes 57 à 63) et les débris de l'étage
    r.fill(46, 2, 56, 7, "#").fill(64, 2, 73, 7, "#")
    r.plat(57, 7, 2).plat(61, 4, 3)
    r.plat(61, 10, 6, "-")                       # la poutre maîtresse, tombée en biais
    r.mound([(62, 68, 16), (69, 77, 13)])        # l'étage effondré, bancs et tables empilés
    for x in (6, 9, 12, 16, 22, 25, 30, 34, 40, 44, 50):
        r.spot(x, 18, "c")
    r.spot(18, 18, "R").spot(46, 18, "R").spot(20, 8, "G").spot(44, 6, "G").spot(72, 11, "G")
    r.plat(14, 16, 5).plat(4, 13, 8).spot(6, 12, "f")
    r.hint(10, 6, "Les murs sont couverts de visages.")
    r.hint(10, 7, "La nuit, les morts parlent ici.")

    r = mk("h13_forge", "La forge de Gerold", 1, 1)
    r.side("W", 0, "1", ["h12_rue", "2"])
    r.side("E", 0, "2", ["h21_carreau", "1"])
    r.fill(17, 17, 21, 18, "#").put(19, 16, "m")  # l'enclume et le marteau
    r.put(9, 18, "F")
    r.fill(28, 8, 37, 18, "#").fill(28, 16, 37, 18, " ")   # la hotte de la forge
    r.hint(4, 10, "La forge de Gerold.")

    r = mk("h21_carreau", "Le carreau de la mine", 3, 1)
    r.side("W", 0, "1", ["h13_forge", "2"])
    r.side("E", 0, "2", ["h16_clocher", "1"])
    r.top(58, "3", ["h08_monte_charge", "1"])
    r.bottom(98, "4", ["h23_grand_puits", "1"], grate=True)
    r.fill(96, 18, 97, 18, "w").fill(102, 18, 103, 18, "w")
    r.plat(101, 15, 8, "-")                      # le chevalement du Grand Puits
    r.fill(20, 13, 34, 13, "#").fill(26, 10, 27, 12, "#")   # le chevalement effondré
    # le terril : les déblais montent jusqu'au monte-charge, sur un boisage où passent les berlines
    r.mound([(35, 42, 10), (43, 50, 7), (51, 58, 6)], floor=15)
    r.fill(112, 2, 117, 10, "#")
    r.spot(16, 18, "E").spot(44, 18, "E").spot(80, 18, "E").spot(40, 6, "G").spot(86, 8, "G")
    r.plat(14, 16, 5).spot(24, 12, "f")
    r.hint(88, 10, "Le Grand Puits. La grille est pourrie :")
    r.hint(88, 11, "attaque lourde chargée.")
    r.hint(50, 3, "Le monte-charge, en haut du terril.")

    r = mk("h08_monte_charge", "Le monte-charge", 1, 1)
    r.bottom(18, "1", ["h21_carreau", "3"])
    r.mound([(22, 28, 16)])                      # le contrepoids, tombé à côté du puits
    r.fill(14, 2, 25, 5, "#")                    # la cabine, bloquée tout en haut
    r.hint(4, 9, "La cabine est bloquée tout en haut du câble.")
    r.hint(4, 10, "Le levier doit être là-haut, sur la route.")

    r = mk("h16_clocher", "Le clocher de la mine", 1, 2)
    r.side("W", 1, "1", ["h21_carreau", "2"])
    # les planchers du clocher, chacun percé d'une trappe, et ce qui reste des escaliers
    r.fill(2, 35, 31, 35, "#").fill(8, 29, 37, 29, "#").fill(2, 23, 30, 23, "#")
    r.fill(7, 17, 37, 17, "#").fill(2, 11, 31, 11, "#")
    r.mound([(32, 35, 38)], floor=40).mound([(4, 7, 32)], floor=34)
    r.mound([(31, 34, 26)], floor=28).mound([(3, 6, 20)], floor=22).mound([(31, 35, 14)], floor=16)
    r.fill(14, 3, 25, 5, "#").spot(19, 10, "f")  # la cloche, fêlée
    r.spot(20, 20, "G").spot(12, 14, "G")
    r.hint(4, 30, "La cloche qui sonnait le début et la fin du travail.")

    # ======================================================================== les galeries
    r = mk("h06_roulage", "La galerie de roulage", 5, 1)
    r.side("E", 0, "1", ["h07_wagonnets", "1"])
    r.top(98, "2", ["h18_fond_puits", "1"])
    # sous le puits du bourg : la voûte crevée, le cuvelage et l'éboulis tombé du dessus
    r.fill(86, 2, 96, 7, "#").fill(104, 2, 114, 7, "#").fill(86, 8, 90, 8, "#").fill(110, 8, 114, 8, "#")
    r.plat(97, 7, 2).plat(101, 4, 3)
    r.plat(101, 10, 6, "-")                      # un chapeau de boisage, tombé en travers
    r.mound([(102, 107, 16), (108, 114, 13), (115, 120, 16)])
    r.fill(30, 17, 33, 18, "#").fill(56, 18, 60, 18, "^").fill(130, 18, 134, 18, "~")
    r.fill(150, 16, 155, 18, "#").fill(170, 18, 173, 18, "^")
    r.fill(10, 8, 22, 8, "#").spot(14, 7, "f").spot(18, 7, "f")      # la corniche
    r.plat(26, 16, 6, "=").plat(20, 13, 5, "=").plat(26, 10, 5, "=")
    r.spot(40, 18, "R").spot(126, 18, "R").spot(160, 18, "R").spot(70, 10, "G").spot(180, 8, "G").spot(130, 6, "G")
    r.spot(64, 18, "c").spot(140, 18, "cc")
    r.hint(80, 11, "Le puits du bourg, au-dessus.")
    r.hint(10, 13, "La nuit, la brume se fige.")

    r = mk("h07_wagonnets", "La chambre des wagonnets", 2, 2)
    r.side("W", 0, "1", ["h06_roulage", "1"])
    r.side("E", 0, "2", ["h03_lampisterie", "1"])
    r.fill(0, 19, 37, 21, "#").fill(43, 19, 79, 21, "#")   # le plancher du haut, troué au milieu
    # tout ce qui est tombé par le trou du plancher : wagonnets, rails et roche, en tas sous le trou
    r.mound([(28, 30, 36), (31, 33, 33), (34, 36, 30), (37, 38, 27), (39, 40, 24), (41, 42, 22),
             (43, 47, 25), (48, 51, 28), (52, 55, 31), (56, 59, 34), (60, 63, 37)], floor=40)
    r.bottom(18, "3", ["h11_boisage", "1"])
    r.mound([(22, 27, 38)], floor=40)            # un wagonnet, au bord du puits
    r.spot(24, 18, "R").spot(70, 40, "R").spot(14, 30, "G").spot(66, 8, "G")
    r.hint(4, 12, "Vers le puits du bourg")
    r.hint(60, 12, "Vers la lampisterie")
    r.hint(24, 34, "L'atelier du boisage, en bas")

    r = mk("h11_boisage", "L'atelier du boisage", 2, 1)
    r.top(18, "1", ["h07_wagonnets", "3"])
    # les piles de bois de mine, et la chèvre qui servait à les lever jusqu'au puits
    r.mound([(24, 27, 18), (28, 37, 15), (31, 36, 12), (33, 36, 9)])
    r.plat(21, 6, 10, "-")
    r.fill(44, 14, 60, 14, "#").spot(52, 13, "k")   # le râtelier des pics
    r.plat(40, 17, 3).plat(64, 16, 6)
    r.spot(46, 18, "R").spot(70, 18, "R").spot(56, 6, "G")
    r.hint(44, 10, "Les pics des mineurs morts, au râtelier.")

    r = mk("h03_lampisterie", "Le puits de la lampisterie", 1, 5)
    r.side("W", 0, "1", ["h07_wagonnets", "2"], ledge=12)
    r.side("E", 3, "2", ["h24_boiseurs", "1"], ledge=10)
    r.side("W", 4, "3", ["h02_corps", "2"])
    # en bas, la lampisterie : caisses de lampes, brasier, et le puits qui part en corniches
    r.mound([(24, 28, 105), (29, 37, 103)])
    r.spot(20, 106, "F")
    r.wl(100, 25, 1).wr(97, 29, 1).wl(94, 25, 1).wr(91, 28, 1).wl(88, 26, 0)
    # au milieu, un pilier de roche coupe le puits en deux cheminées
    r.fill(14, 50, 24, 82, "#")
    for y in (82, 76, 70, 64, 58, 52):
        r.fill(25, y, 28, y, "#")                # les prises sur le flanc du pilier
    for y in (79, 73, 61, 55):
        r.wr(y, 32, 1)                           # et sur la paroi d'en face
    r.wr(67, 30, 1).spot(34, 66, "R").spot(32, 66, "f")   # la niche des lampistes
    r.wl(56, 8, 1).fill(11, 53, 13, 53, "#").spot(5, 55, "f")   # la cheminée de gauche, en cul-de-sac
    # en haut, deux écailles de roche décollées de la paroi, en lacets jusqu'à la galerie
    r.wl(47, 10, 1)
    for x0, x1, y in ((14, 18, 44), (17, 21, 41), (22, 26, 38), (27, 31, 35), (32, 37, 32),
                      (26, 30, 29), (21, 25, 26), (16, 20, 23), (12, 15, 21)):
        r.fill(x0, y, x1, y, "#").fill(x0 + 1, y + 1, x1 - 1, y + 1, "#")
    r.rough(20, 102, 1)
    r.spot(20, 92, "G").spot(30, 71, "G").spot(20, 38, "G").spot(32, 20, "G")
    r.hint(12, 103, "Brasier : haut pour se reposer.")

    r = mk("h24_boiseurs", "Le passage des boiseurs", 1, 1)
    r.side("W", 0, "1", ["h03_lampisterie", "2"])
    r.side("E", 0, "2", ["h19_fosse", "2"])
    r.fill(2, 2, 37, 12, "#")                    # un boyau bas
    r.fill(18, 13, 19, 18, "X")
    r.hint(4, 15, "Un boyau vers la fosse.")

    r = mk("h23_grand_puits", "Le Grand Puits", 1, 3)
    r.top(18, "1", ["h21_carreau", "4"])
    r.bottom(18, "2", ["h19_fosse", "1"])
    # les parois de chair, la cage restée coincée à mi-hauteur ; rien ne gêne la chute (colonnes 19-20)
    r.plat(21, 59, 7).mound([(28, 33, 61)])      # le palier du fond
    LS = [(56, 14, 18), (53, 2, 10), (50, 12, 16), (35, 3, 7), (32, 12, 17), (17, 14, 18),
         (14, 2, 11), (11, 13, 17), (6, 15, 18)]
    RS = [(47, 21, 26), (44, 28, 37), (41, 23, 26), (29, 21, 25), (26, 26, 31), (23, 33, 37),
         (20, 22, 29), (9, 21, 26)]
    for y, x0, x1 in LS + RS:
        r.fill(x0, y, x1, y, "#")
    r.fill(2, 54, 7, 54, "#").fill(2, 36, 4, 36, "#").fill(2, 15, 8, 15, "#").fill(34, 45, 37, 45, "#")
    r.fill(10, 38, 18, 40, "#")                  # la cage
    r.rough(4, 60, 1)
    r.spot(6, 30, "G").spot(32, 47, "G").spot(8, 62, "R").spot(24, 62, "c")
    r.hint(26, 2, "Les parois sont tapissées de chair.")

    r = mk("h19_fosse", "La fosse du Contremaître", 2, 2)
    r.extra["boss"] = "contremaitre"
    r.top(58, "1", ["h23_grand_puits", "2"])
    r.side("W", 1, "2", ["h24_boiseurs", "2"], ledge=3)
    r.side("E", 0, "3", ["h20_extraction", "1"], ledge=11)
    # les gradins de la fosse montent vers la galerie d'extraction
    r.mound([(41, 45, 38), (46, 48, 35), (49, 53, 33), (54, 57, 30), (58, 62, 27), (63, 65, 24), (66, 68, 21)],
            floor=40)
    # au-dessus, l'orifice du Grand Puits dans la voûte, et les racines de chair qui y mènent
    r.fill(40, 2, 56, 8, "#").fill(64, 2, 77, 7, "#")
    r.plat(57, 7, 2).plat(61, 4, 3)
    r.plat(62, 16, 5).plat(54, 13, 5).plat(61, 10, 6)
    r.plat(6, 38, 8, "-").plat(16, 35, 8, "-").plat(6, 32, 8, "-")
    for x in (5, 9, 14, 22, 40):
        r.spot(x, 40, "c")
    r.spot(32, 40, "B")
    r.hint(66, 14, "La galerie d'extraction")

    r = mk("h20_extraction", "La galerie d'extraction", 2, 1)
    r.side("W", 0, "1", ["h19_fosse", "3"])
    r.side("E", 0, "2", [])
    r.fill(2, 2, 77, 5, "#")
    r.fill(20, 17, 33, 18, "#").fill(26, 15, 30, 16, "#")
    r.fill(44, 16, 49, 18, "#").fill(50, 13, 60, 18, "#").fill(61, 16, 65, 18, "#").put(70, 18, "c")
    r.hint(56, 9, "La Lande aux Pendus, à l'est")
    r.hint(56, 10, "(prochaine étape de la tranche)")

    # ======================================================================== le fond
    r = mk("h01_effondrement", "L'effondrement", 2, 1)
    r.side("W", 0, "1", ["h04_etais", "1"])
    r.side("E", 0, "2", ["h02_corps", "1"])
    r.bottom(18, "3", ["h05_veine_morte", "1"], grate=True)
    r.mound([(22, 27, 16)])                     # un bloc tombé de la voûte
    r.fill(44, 2, 48, 17, "#")                  # l'éboulis : on glisse dessous
    r.spot(10, 18, "P").spot(13, 18, "ccc").spot(30, 18, "cc").spot(36, 18, "c").spot(58, 18, "c").spot(66, 18, "R")
    r.plat(56, 16, 3).fill(60, 13, 70, 13, "#").spot(64, 12, "f")
    r.spot(30, 8, "G").spot(62, 6, "G")
    r.hint(36, 14, "Glissade (C ou RT) sous l'éboulis")

    r = mk("h02_corps", "La galerie des corps", 2, 1)
    r.side("W", 0, "1", ["h01_effondrement", "2"])
    r.side("E", 0, "2", ["h03_lampisterie", "3"])
    r.bottom(18, "3", ["h09_chapelle", "1"])
    r.mound([(22, 27, 16)])                     # l'autel des mineurs, renversé
    r.fill(34, 18, 37, 18, "^").fill(46, 16, 52, 16, "#").fill(58, 17, 62, 18, "#")
    for x in (6, 9, 28, 30, 42, 66):
        r.spot(x, 18, "c")
    r.spot(32, 18, "R").spot(54, 18, "R").spot(40, 8, "G")
    r.hint(10, 13, "Une chapelle, en contrebas.")

    r = mk("h04_etais", "Les étais", 2, 1)
    r.side("E", 0, "1", ["h01_effondrement", "1"])
    r.side("W", 0, "2", ["h10_galerie_noyee", "1"])
    r.fill(8, 2, 9, 18, "X")                    # le mur fissuré
    for x in (20, 32, 44, 56):
        r.fill(x, 2, x, 12, "#")                # les étais pourris
    r.fill(26, 18, 29, 18, "^").fill(48, 18, 51, 18, "^")
    r.put(40, 18, "R").put(30, 7, "G")
    r.hint(12, 14, "Un mur fissuré. Il faudrait un vrai marteau.")

    r = mk("h05_veine_morte", "La veine morte", 1, 1)
    r.top(18, "1", ["h01_effondrement", "3"])
    # un pilier laissé par les mineurs porte la corniche ; on monte dans la fente derrière lui
    r.fill(2, 2, 37, 3, "#").fill(2, 4, 14, 6, "#").fill(34, 4, 37, 4, "#")
    r.fill(17, 2, 22, 3, " ")
    r.fill(21, 6, 30, 6, "#").fill(27, 7, 30, 18, "#")
    r.fill(34, 16, 37, 16, "#").fill(31, 13, 33, 13, "#").fill(34, 10, 37, 10, "#").fill(31, 7, 33, 7, "#")
    r.mound([(4, 11, 16)]).spot(7, 15, "v")
    r.spot(24, 18, "R")
    r.hint(4, 10, "Une veine abandonnée.")

    r = mk("h09_chapelle", "La chapelle des mineurs", 1, 1)
    r.top(18, "1", ["h02_corps", "3"])
    # la voûte, l'escalier taillé dans la roche et la tribune de bois
    r.fill(2, 2, 37, 3, "#").fill(17, 2, 22, 3, " ").fill(2, 4, 8, 5, "#")
    r.mound([(22, 25, 16), (26, 28, 13), (29, 32, 10), (33, 37, 7)])
    r.plat(23, 7, 10, "-").fill(21, 6, 23, 6, "#")   # la tribune, et le reliquaire posé au bord
    r.fill(4, 12, 12, 18, "#")   # la porte scellée
    r.hint(2, 9, "Une porte scellée par un signe qu'on ne sait pas lire.")
    r.hint(2, 10, "Des béquilles ont usé la pierre du seuil.")

    r = mk("h10_galerie_noyee", "La galerie noyée", 2, 1)
    r.side("E", 0, "1", ["h04_etais", "2"])
    r.fill(2, 12, 60, 18, "~").fill(2, 19, 60, 21, "#")
    r.fill(2, 2, 77, 8, "#")
    r.hint(40, 10, "Le courant tire vers l'ouest.")
    r.hint(40, 11, "Il faudrait savoir nager.")

    return rooms


def to_gd(rooms):
    out = []
    out.append("class_name RoomsHautfer")
    out.append("extends RefCounted")
    out.append("## Les 24 salles des Galeries de Hautfer (Z1), d'après le plan détaillé.")
    out.append("## Fichier généré par tools/gen_hautfer.py : voir la légende dans rooms.gd.")
    out.append("")
    out.append("const DATA := {")
    for r in rooms:
        out.append(f'\t"{r.id}": {{')
        out.append(f'\t\t"name": "{r.name}",')
        out.append('\t\t"zone": "Les galeries de Hautfer",')
        for k, v in r.extra.items():
            out.append(f'\t\t"{k}": "{v}",')
        doors = ", ".join(f'"{d}": ["{v[0]}", "{v[1]}"]' for d, v in sorted(r.doors.items()) if v)
        out.append(f"\t\t\"doors\": {{{doors}}},")
        hints = ", ".join('[%d, %d, "%s"]' % (h[0], h[1], h[2].replace('"', '\\"')) for h in r.hints)
        out.append(f"\t\t\"hints\": [{hints}],")
        out.append('\t\t"rows": [')
        for row in r.rows():
            out.append(f'\t\t\t"{row}",')
        out.append("\t\t],")
        out.append("\t},")
    out.append("}")
    return "\n".join(out) + "\n"


if __name__ == "__main__":
    rooms = build()
    for r in rooms:
        assert len(r.g) == r.H and all(len(x) == r.W for x in r.g), r.id
    path = Path(__file__).resolve().parent.parent / "scripts" / "rooms_hautfer.gd"
    path.write_text(to_gd(rooms), encoding="utf-8")
    print(f"{len(rooms)} salles écrites dans {path}")
