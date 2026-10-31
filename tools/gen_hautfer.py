#!/usr/bin/env python3
"""Génère scripts/rooms_hautfer.gd : les 24 salles des Galeries de Hautfer (Z1).

Le plan vient de la carte détaillée de Hautfer et de la Lande. Une case du plan vaut un écran,
soit 40 × 22 cases de 32 pixels. Chaque salle est construite ici avec quelques outils
(murs, plateformes, passages, échafaudages), puis écrite en caractères comme les autres salles.

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

    def climb(self, x, y_low, y_high, width=8):
        """Échafaudages traversables par dessous, empilés toutes les 3 cases (de y_low à y_high)."""
        y = y_low
        while y >= y_high:
            self.plat(x, y, width, "-")
            y -= 3
        return self

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
    r.climb(28, 38, 23).plat(28, 21, 8, "-")
    r.put(8, 18, "l").put(14, 18, "c")
    r.fill(8, 38, 12, 40, "#").put(16, 40, "f")  # l'établi de l'atelier
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
    r.climb(21, 15, 6)
    r.put(6, 18, "c").put(30, 18, "R")
    r.hint(4, 10, "Une corde pend encore.")

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
    r.climb(61, 16, 4)
    for x in (6, 9, 12, 16, 22, 25, 30, 34, 40, 44, 50):
        r.put(x, 18, "c")
    r.put(18, 18, "R").put(46, 18, "R").put(20, 8, "G").put(44, 6, "G").put(70, 12, "G")
    r.plat(14, 16, 5).plat(4, 13, 8).put(6, 12, "f")
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
    r.climb(61, 16, 4)
    r.bottom(98, "4", ["h23_grand_puits", "1"], grate=True)
    r.fill(96, 18, 97, 18, "w").fill(102, 18, 103, 18, "w")
    r.plat(101, 15, 8, "-")
    r.fill(20, 13, 34, 13, "#").fill(26, 9, 27, 12, "#")    # le chevalement effondré
    r.fill(112, 2, 117, 10, "#")
    r.put(16, 18, "E").put(44, 18, "E").put(80, 18, "E").put(40, 6, "G").put(86, 8, "G")
    r.plat(14, 16, 5).put(24, 12, "f")
    r.hint(88, 10, "Le Grand Puits. La grille est pourrie :")
    r.hint(88, 11, "attaque lourde chargée.")
    r.hint(50, 2, "Le monte-charge.")

    r = mk("h08_monte_charge", "Le monte-charge", 1, 1)
    r.bottom(18, "1", ["h21_carreau", "3"])
    r.plat(21, 15, 8, "-")
    r.fill(14, 2, 25, 5, "#")                   # la cabine, bloquée tout en haut
    r.hint(4, 9, "La cabine est bloquée tout en haut du câble.")
    r.hint(4, 10, "Le levier doit être là-haut, sur la route.")

    r = mk("h16_clocher", "Le clocher de la mine", 1, 2)
    r.side("W", 1, "1", ["h21_carreau", "2"])
    r.climb(14, 38, 8, width=10)
    r.fill(14, 3, 25, 5, "#").put(19, 6, "f")   # la cloche, fêlée
    r.put(28, 20, "G").put(10, 12, "G")
    r.hint(4, 30, "La cloche qui sonnait le début et la fin du travail.")

    # ======================================================================== les galeries
    r = mk("h06_roulage", "La galerie de roulage", 5, 1)
    r.side("E", 0, "1", ["h07_wagonnets", "1"])
    r.top(98, "2", ["h18_fond_puits", "1"])
    r.climb(101, 16, 4)
    r.fill(30, 17, 33, 18, "#").fill(56, 18, 60, 18, "^").fill(130, 18, 134, 18, "~")
    r.fill(150, 16, 155, 18, "#").fill(170, 18, 173, 18, "^")
    r.fill(10, 8, 22, 8, "#").put(14, 7, "f").put(18, 7, "f")      # la corniche
    r.plat(26, 16, 6, "=").plat(20, 13, 5, "=").plat(26, 10, 5, "=")
    r.put(40, 18, "R").put(120, 18, "R").put(160, 18, "R").put(70, 10, "G").put(180, 8, "G").put(130, 6, "G")
    r.put(64, 18, "c").put(140, 18, "cc")
    r.hint(84, 10, "Le puits du bourg, au-dessus.")
    r.hint(10, 13, "La nuit, la brume se fige.")

    r = mk("h07_wagonnets", "La chambre des wagonnets", 2, 2)
    r.side("W", 0, "1", ["h06_roulage", "1"])
    r.side("E", 0, "2", ["h03_lampisterie", "1"])
    r.fill(0, 19, 35, 21, "#").fill(44, 19, 79, 21, "#")   # le plancher du haut, troué au milieu
    r.climb(40, 38, 23).plat(40, 21, 8, "-")
    r.bottom(18, "3", ["h11_boisage", "1"])
    r.plat(21, 37, 8, "-")
    r.fill(52, 39, 60, 40, "#").fill(54, 37, 58, 38, "#")  # un wagonnet renversé
    r.put(24, 18, "R").put(62, 40, "R").put(30, 30, "G").put(66, 8, "G")
    r.hint(4, 12, "Vers le puits du bourg")
    r.hint(60, 12, "Vers la lampisterie")
    r.hint(24, 34, "L'atelier du boisage, en bas")

    r = mk("h11_boisage", "L'atelier du boisage", 2, 1)
    r.top(18, "1", ["h07_wagonnets", "3"])
    r.climb(21, 16, 4)
    r.fill(44, 14, 60, 14, "#").put(52, 13, "k")   # le râtelier des pics
    r.plat(36, 17, 5).plat(64, 16, 6)
    r.put(30, 18, "R").put(70, 18, "R").put(56, 6, "G")
    r.hint(44, 10, "Les pics des mineurs morts, au râtelier.")

    r = mk("h03_lampisterie", "Le puits de la lampisterie", 1, 5)
    r.side("W", 0, "1", ["h07_wagonnets", "2"], ledge=10)
    r.side("E", 3, "2", ["h24_boiseurs", "1"], ledge=10)
    r.side("W", 4, "3", ["h02_corps", "2"])
    r.climb(14, 104, 20, width=12)
    r.put(26, 106, "F")
    r.plat(30, 64, 8).put(34, 63, "R").put(32, 63, "f")
    r.plat(2, 46, 8).put(5, 45, "f")
    r.put(8, 90, "G").put(30, 70, "G").put(8, 40, "G").put(30, 24, "G")
    r.hint(18, 100, "Brasier : haut pour se reposer.")
    r.hint(4, 96, "Les échafaudages se traversent par dessous.")

    r = mk("h24_boiseurs", "Le passage des boiseurs", 1, 1)
    r.side("W", 0, "1", ["h03_lampisterie", "2"])
    r.side("E", 0, "2", ["h19_fosse", "2"])
    r.fill(2, 2, 37, 12, "#")                    # un boyau bas
    r.fill(18, 13, 19, 18, "X")
    r.hint(4, 15, "Un boyau vers la fosse.")

    r = mk("h23_grand_puits", "Le Grand Puits", 1, 3)
    r.top(18, "1", ["h21_carreau", "4"])
    r.bottom(18, "2", ["h19_fosse", "1"])
    r.climb(21, 59, 5)
    r.put(6, 30, "G").put(32, 46, "G").put(8, 62, "R").put(32, 62, "c")
    r.hint(26, 2, "Les parois sont tapissées de chair.")

    r = mk("h19_fosse", "La fosse du Contremaître", 2, 2)
    r.extra["boss"] = "contremaitre"
    r.top(58, "1", ["h23_grand_puits", "2"])
    r.side("W", 1, "2", ["h24_boiseurs", "2"], ledge=3)
    r.side("E", 0, "3", ["h20_extraction", "1"], ledge=11)
    r.climb(61, 38, 5)
    r.plat(6, 38, 8, "-").plat(16, 35, 8, "-").plat(6, 32, 8, "-")
    for x in (5, 9, 14, 22, 40, 46, 52, 72, 75):
        r.put(x, 40, "c")
    r.put(32, 40, "B")
    r.hint(66, 16, "La galerie d'extraction")

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
    r.plat(21, 15, 8, "-")
    r.fill(44, 2, 48, 17, "#")                  # l'éboulis : on glisse dessous
    r.put(10, 18, "P").put(13, 18, "ccc").put(26, 18, "cc").put(34, 18, "c").put(58, 18, "c").put(66, 18, "R")
    r.plat(56, 16, 3).fill(60, 13, 70, 13, "#").put(64, 12, "f")
    r.put(30, 8, "G").put(62, 6, "G")
    r.hint(36, 14, "Glissade (C ou RT) sous l'éboulis")

    r = mk("h02_corps", "La galerie des corps", 2, 1)
    r.side("W", 0, "1", ["h01_effondrement", "2"])
    r.side("E", 0, "2", ["h03_lampisterie", "3"])
    r.bottom(18, "3", ["h09_chapelle", "1"])
    r.plat(21, 15, 8, "-")
    r.fill(34, 18, 37, 18, "^").fill(46, 16, 52, 16, "#").fill(58, 17, 62, 18, "#")
    for x in (6, 9, 28, 30, 42, 66):
        r.put(x, 18, "c")
    r.put(26, 18, "R").put(54, 18, "R").put(40, 8, "G")
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
    r.climb(21, 16, 4)
    r.plat(4, 16, 8).put(7, 15, "v")
    r.put(30, 18, "R")
    r.hint(4, 10, "Une veine abandonnée.")

    r = mk("h09_chapelle", "La chapelle des mineurs", 1, 1)
    r.top(18, "1", ["h02_corps", "3"])
    r.climb(21, 16, 4)
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
