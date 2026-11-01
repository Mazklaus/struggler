#!/usr/bin/env python3
"""Génère scripts/rooms_lande.gd : les salles de la Lande aux Pendus (Z2).

Le plan vient de la carte détaillée de Hautfer et de la Lande (une case du plan = un écran,
40 × 22 cases de 32 pixels). Les salles fermées par une capacité qu'on n'a pas encore
(L08 la falaise des gibets, L14 et L22 le donjon, L15 le cercle des pendus) ne sont pas
construites : un panneau les annonce dans les salles voisines.

Usage : python3 tools/gen_lande.py   (réécrit scripts/rooms_lande.gd)
"""
from pathlib import Path
from roomgen import R, CW, CH, to_gd


def build():
    rooms = []

    def mk(*a):
        r = R(*a)
        rooms.append(r)
        return r

    def stump(r, x, w=1, top=14, floor=18):
        """Un poteau ou un tronc planté dans un tas de pierres : on monte sur le tas, puis dessus."""
        r.fill(x - 3, 17, x - 1, floor, "t").fill(x + w, 17, x + w + 2, floor, "t")
        r.fill(x, top, x + w - 1, floor, "b")
        return r

    def gibbet(r, x, hanged=True):
        """Un gibet : un poteau dans son tas de pierres, une traverse (on peut s'y poser), un pendu."""
        stump(r, x)
        r.plat(x, 11, 5, "-")
        if hanged:
            r.spot(x + 3, 12, "p")
        return r

    # ======================================================================== sous le plateau
    r = mk("l01_ravin", "Le ravin de sortie", 2, 1)
    r.side("W", 0, "1", ["h20_extraction", "2"])
    r.side("E", 0, "2", ["l02_montee", "1"])
    # la bouche de la galerie, puis le ciel
    r.fill(2, 2, 17, 9, "#").fill(18, 2, 22, 7, "#").fill(23, 2, 26, 4, "#")
    r.mound([(32, 37, 17)])
    r.mound([(50, 58, 16), (52, 56, 14)], ch="t")
    r.mound([(66, 71, 17)])
    r.spot(12, 18, "c").spot(54, 13, "C").spot(44, 18, "E").spot(74, 18, "c")
    r.spot(40, 6, "G").spot(62, 6, "G")
    r.hint(28, 12, "Le ciel. Le premier depuis l'effondrement.")
    r.sky()
    r.label(4, 3, "bouche de la galerie").label(50, 12, "éboulis du ravin").label(31, 15, "rocher")

    r = mk("l02_montee", "La montée des charrettes", 1, 5)
    r.side("W", 4, "1", ["l01_ravin", "2"])
    r.side("E", 4, "2", ["l20_bourbes", "1"])
    r.side("E", 1, "3", ["l03_gibets", "1"], ledge=6)
    r.side("W", 0, "4", ["l19_sentier", "1"], ledge=10)
    # le chemin creux grimpe en lacets entre des rochers, des racines et des déblais.
    # A : rochers contre la paroi ouest ; B : racines et blocs au milieu ; C : déblais à l'est.
    A, C = (3, 12), (23, 33)
    B_up, B_dn = (15, 20), (13, 18)       # B vers C (sortie à droite), B vers A (sortie à gauche)
    seq = ["A", "Bu", "C", "Bd"]
    top = 104
    k = 0
    while top >= 47:
        kind = seq[k % 4]
        if kind == "A":
            x0, x1 = A
            r.hang([(x0 + r._jit(k) % 2, x1, top)], "#", thick=3)
        elif kind == "C":
            x0, x1 = C
            r.hang([(x0, x1 - r._jit(k) % 2, top)], "t", thick=3)
        else:
            x0, x1 = B_up if kind == "Bu" else B_dn
            r.hang([(x0, x1, top)], "b", thick=1)
        top -= 3
        k += 1
    # la charrette renversée au pied de la montée
    r.fill(3, 104, 12, 104, "b")
    # le palier de la borne de sel
    r.fill(23, 74, 37, 74, "t").spot(30, 73, "S")
    # vers le passage est (Les premiers gibets)
    r.hang([(14, 20, 47)], "b", thick=1)
    r.hang([(25, 33, 44)], "t", thick=2)
    # au-dessus : le mur lisse du donjon effondré (L14, Crochet de forge)
    r.fill(32, 6, 37, 33, "M")
    r.hang([(23, 30, 38)], "t", thick=2)
    r.hang([(13, 18, 35)], "b", thick=1)
    r.hang([(3, 12, 32)], "#", thick=2)
    r.hang([(15, 20, 29)], "b", thick=1)
    r.hang([(23, 30, 26)], "t", thick=2)
    r.hang([(13, 18, 23)], "b", thick=1)
    r.fill(2, 20, 12, 20, "#")
    r.spot(6, 103, "c").spot(26, 97, "C").spot(8, 67, "E").spot(6, 31, "C")
    r.spot(20, 60, "G").spot(10, 40, "G").spot(30, 91, "G")
    r.hint(24, 70, "Une borne de sel. Quelqu'un l'entretient.")
    r.hint(24, 30, "Les murs lisses d'un donjon. Il faudrait de quoi s'y accrocher.")
    r.sky(sides=False)
    r.label(3, 101, "charrette renversée").label(25, 71, "borne de sel").label(33, 8, "donjon effondré")
    r.label(3, 30, "rochers").label(14, 98, "racines").label(24, 95, "déblais")

    r = mk("l20_bourbes", "Les bourbes", 2, 2)
    r.side("W", 1, "1", ["l02_montee", "2"])
    r.side("E", 0, "2", ["l11_faille", "2"])
    r.side("E", 1, "3", ["l12_fosse", "2"])
    r.fill(14, 40, 34, 40, "~").fill(40, 40, 52, 40, "~")
    # un saule mort sur ses racines : on grimpe par les branches
    r.fill(60, 22, 61, 37, "b").fill(57, 38, 59, 38, "b").fill(62, 38, 64, 38, "b")
    for y, x0, x1 in ((35, 52, 59), (32, 46, 54), (29, 52, 59), (26, 46, 54), (23, 52, 59)):
        r.plat(x0, y, x1 - x0 + 1, "-")
    r.plat(50, 20, 22, "-")
    # la nuit, la brume monte du marais jusqu'à une cache
    for y, x0, x1 in ((38, 12, 17), (35, 18, 23), (32, 12, 17), (29, 18, 23), (26, 12, 17), (23, 6, 11)):
        r.plat(x0, y, x1 - x0 + 1, "=")
    r.fill(2, 20, 9, 20, "#").spot(4, 19, "f").spot(7, 19, "f")
    r.spot(26, 39, "R").spot(46, 39, "R").spot(30, 30, "G").spot(70, 12, "G").spot(20, 16, "G")
    r.hint(4, 14, "Quelque chose brille, là-haut, au-dessus du marais.")
    r.sky(sides=False)
    r.label(56, 12, "saule mort").label(14, 41, "boue").label(2, 17, "cache")

    r = mk("l11_faille", "La faille", 3, 2)
    r.side("E", 0, "1", ["l10_moulin", "2"])
    r.side("W", 1, "2", ["l20_bourbes", "2"])
    r.bottom(58, "3", ["l12_fosse", "1"])
    r.fill(62, 19, 117, 40, "#").fill(41, 19, 54, 40, "#").fill(55, 41, 57, 42, "#")
    # les gradins de la faille, côté ouest
    r.mound([(8, 40, 38), (12, 40, 35), (16, 40, 32), (20, 40, 29), (24, 40, 26), (29, 40, 23), (34, 40, 20)], floor=40)
    r.spot(90, 18, "C").spot(74, 18, "c").spot(18, 31, "c").spot(80, 8, "G").spot(30, 10, "G")
    r.hint(66, 13, "Une faille, trop large pour un saut.")
    r.sky()
    r.label(55, 24, "la faille").label(9, 35, "gradins de roche").label(80, 25, "plateau")

    r = mk("l12_fosse", "La fosse commune", 3, 1)
    r.top(58, "1", ["l11_faille", "3"])
    r.side("W", 0, "2", ["l20_bourbes", "3"])
    r.side("E", 0, "3", ["l13_cabane", "1"])
    r.mound([(16, 24, 17)], ch="o")
    r.mound([(40, 52, 16), (43, 49, 14)], ch="o")
    r.mound([(70, 88, 16), (73, 85, 13), (76, 82, 10)], ch="o")
    r.mound([(100, 106, 17)], ch="o")
    r.spot(79, 9, "v")
    for x in (10, 28, 34, 56, 62, 66, 92, 96, 110):
        r.spot(x, 18, "c")
    r.spot(30, 18, "R").spot(94, 18, "R").spot(20, 8, "G").spot(60, 8, "G").spot(100, 8, "G").spot(46, 6, "G")
    r.hint(4, 12, "Ici, l'armée jetait ses morts.")
    r.sky()
    r.label(70, 11, "corps entassés").label(40, 13, "corps entassés")

    r = mk("l13_cabane", "La cabane du bourreau", 1, 1)
    r.side("W", 0, "1", ["l12_fosse", "3"])
    r.fill(8, 2, 9, 18, "X")
    r.fill(10, 2, 37, 6, "b").fill(30, 15, 34, 18, "b")
    r.spot(32, 14, "r").spot(22, 18, "f")
    r.plat(14, 12, 6, "-").spot(16, 13, "p")
    r.hint(2, 12, "Une porte de planches clouées.")
    r.label(12, 4, "toit de la cabane").label(29, 13, "table du registre")

    # ======================================================================== le plateau
    r = mk("l03_gibets", "Les premiers gibets", 2, 1)
    r.side("W", 0, "1", ["l02_montee", "3"])
    r.side("E", 0, "2", ["l04_corbeaux", "1"])
    r.mound([(8, 14, 18)]).mound([(40, 46, 17)]).mound([(68, 72, 18)])
    for x in (18, 30, 52, 60):
        gibbet(r, x)
    r.spot(36, 18, "E").spot(64, 18, "E").spot(43, 16, "C").spot(56, 18, "c")
    r.spot(24, 6, "G").spot(56, 6, "G")
    r.hint(4, 12, "Des paysans. Pendus par des soldats.")
    r.sky()
    r.label(17, 9, "gibet").label(40, 15, "talus")

    r = mk("l04_corbeaux", "Le champ des corbeaux", 3, 1)
    r.side("W", 0, "1", ["l03_gibets", "2"])
    r.side("E", 0, "2", ["l05_lande", "1"])
    r.mound([(14, 22, 17)], ch="b").mound([(44, 50, 17), (46, 48, 15)], ch="t").mound([(80, 88, 17)], ch="b")
    stump(r, 60).plat(58, 11, 5, "-")
    stump(r, 100)
    for x in (8, 26, 32, 38, 54, 66, 72, 92, 108):
        r.spot(x, 18, "c")
    r.spot(18, 16, "C").spot(47, 14, "C").spot(60, 9, "C").spot(100, 11, "C").spot(84, 16, "C")
    r.spot(76, 18, "E")
    r.spot(30, 6, "G").spot(70, 6, "G").spot(104, 6, "G")
    r.hint(52, 6, "Des murmures, là-haut. On ne voit personne.")
    r.sky()
    r.label(13, 15, "charrette").label(80, 15, "charrette").label(43, 13, "tertre").label(56, 8, "étendard")

    r = mk("l05_lande", "La lande nue", 4, 1)
    r.side("W", 0, "1", ["l04_corbeaux", "2"])
    r.side("E", 0, "2", ["l06_tour", "1"])
    r.bottom(98, "3", ["l10_moulin", "3"])
    r.extra["event"] = "premiere_nuit"
    r.extra["event_x"] = 44
    r.extra["spirits"] = 6
    r.mound([(26, 32, 17)]).mound([(70, 80, 16), (73, 78, 14)]).mound([(126, 132, 17)])
    stump(r, 110, w=2).plat(105, 11, 5, "-").plat(112, 9, 5, "-")
    for x, y in ((20, 8), (40, 6), (56, 9), (88, 6), (104, 5), (120, 8), (140, 6), (150, 10), (64, 12), (96, 12)):
        r.spot(x, y, "G")
    r.spot(60, 18, "c").spot(142, 18, "c")
    r.hint(146, 12, "Une tour blanche, cerclée de sel.")
    r.hint(94, 14, "Un trou : l'escalier du vieux moulin.")
    r.sky()
    r.label(70, 13, "tertre").label(105, 7, "arbre mort").label(96, 17, "trappe du moulin")

    r = mk("l06_tour", "La Tour de sel", 1, 3)
    r.side("W", 2, "1", ["l05_lande", "2"])
    r.side("E", 0, "2", ["l21_promontoire", "1"])
    r.side("E", 2, "3", ["l07_bornes", "1"])
    r.bottom(24, "4", ["l09_tranchees", "1"])
    # l'escalier de bois de la tour : des paliers qu'on traverse par dessous
    y, left = 59, True
    while y >= 20:
        if left:
            r.plat(6, y, 12, "-")
        else:
            r.plat(20, y, 12, "-")
        y -= 3
        left = not left
    r.fill(2, 20, 31, 20, " ").plat(2, 20, 26, "-")
    r.fill(14, 61, 15, 62, "a")                  # l'enclume de Corvin
    r.spot(7, 62, "N").spot(30, 62, "S").spot(20, 19, "f")
    r.extra["npcs"] = {"7,62": "corvin"}
    r.hint(4, 54, "Une tour cerclée de sel. Les esprits n'y entrent pas.")
    r.retint(0, 0, 39, 65, "M")
    r.label(12, 59, "enclume").label(22, 64, "trappe des tranchées").label(6, 21, "escalier de bois")

    r = mk("l21_promontoire", "Le promontoire", 2, 1)
    r.side("W", 0, "1", ["l06_tour", "2"])
    r.fill(62, 19, 77, 19, " ").fill(62, 20, 77, 20, "t")
    r.mound([(30, 36, 17)])
    r.spot(70, 19, "f").spot(50, 18, "C")
    r.spot(40, 6, "G").spot(66, 8, "G")
    r.hint(46, 12, "À l'est, la Tour d'Albion. Et derrière, le Bastion du Pendu.")
    r.sky()
    r.label(30, 15, "rocher").label(56, 17, "bout de l'éperon")

    r = mk("l07_bornes", "Le chemin des bornes", 2, 1)
    r.side("W", 0, "1", ["l06_tour", "3"])
    for x in (14, 28, 42, 56):
        r.fill(x, 16, x + 1, 18, "M")
    r.fill(70, 2, 77, 18, "#")
    r.spot(36, 18, "E").spot(50, 18, "E").spot(24, 6, "G").spot(48, 6, "G")
    r.hint(56, 11, "Une falaise hérissée d'anneaux de fer.")
    r.hint(56, 12, "Il faudrait une chaîne pour y monter.")
    r.sky()
    r.label(13, 14, "borne de sel").label(41, 14, "borne de sel").label(71, 6, "falaise des gibets")

    # ======================================================================== sous la tour
    r = mk("l09_tranchees", "Les tranchées", 3, 1)
    r.top(24, "1", ["l06_tour", "4"])
    r.side("W", 0, "2", ["l16_bergerie", "1"])
    r.extra["epreuve"] = True
    r.extra["spirits"] = 5
    # le remblai des tranchées, sous la trappe de la tour
    r.mound([(12, 32, 17), (15, 31, 14), (18, 30, 11), (21, 30, 8), (24, 28, 5)], ch="t")
    # les tranchées : des fossés derrière des parapets
    for x0, x1 in ((40, 52), (62, 78), (90, 104)):
        r.fill(x0, 19, x1, 20, " ")
        r.fill(x0 - 2, 17, x0 - 1, 18, "t").fill(x1 + 1, 17, x1 + 2, 18, "t")
    r.spot(70, 20, "S")
    for x, y in ((44, 8), (58, 6), (70, 10), (84, 7), (100, 9), (112, 6), (36, 12)):
        r.spot(x, y, "G")
    r.spot(48, 20, "c").spot(96, 20, "c")
    r.hint(60, 12, "Ici, Corvin a fait tenir des hommes. Un cercle de sel attend.")
    r.sky()
    r.label(14, 15, "remblai").label(62, 21, "tranchée").label(36, 15, "parapet")

    r = mk("l16_bergerie", "La bergerie", 1, 1)
    r.side("E", 0, "1", ["l09_tranchees", "2"])
    r.side("W", 0, "2", ["l10_moulin", "1"])
    r.fill(10, 16, 11, 18, "M").fill(28, 16, 29, 18, "M")
    r.plat(12, 10, 16, "-")
    r.spot(20, 18, "N")
    r.extra["npcs"] = {"20,18": "berger"}
    r.sky()
    r.label(9, 14, "muret").label(13, 8, "toit de chaume crevé")

    r = mk("l10_moulin", "Le moulin des déserteurs", 3, 1)
    r.side("E", 0, "1", ["l16_bergerie", "2"])
    r.side("W", 0, "2", ["l11_faille", "1"])
    r.top(98, "3", ["l05_lande", "3"])
    # le moulin : murs de pierre, toit percé, escalier de bois jusqu'à la lande
    r.fill(86, 2, 111, 3, "M").fill(98, 2, 101, 3, " ")
    r.fill(86, 4, 87, 14, "M").fill(110, 4, 111, 14, "M")
    for y, x0, x1 in ((16, 90, 98), (13, 100, 108), (11, 90, 98), (8, 100, 108), (6, 94, 103)):
        r.plat(x0, y, x1 - x0 + 1, "-")
    # le camp
    r.mound([(30, 36, 17)], ch="b").mound([(52, 58, 17)], ch="b")
    r.plat(11, 13, 7, "-")
    r.spot(14, 18, "N").spot(40, 18, "E").spot(62, 18, "E").spot(72, 18, "Q").spot(80, 18, "s")
    r.extra["npcs"] = {"14,18": "paysan"}
    r.spot(20, 6, "G").spot(70, 6, "G")
    r.hint(4, 12, "Une cage. Quelqu'un dedans.")
    r.sky()
    r.label(88, 5, "moulin").label(10, 11, "cage").label(29, 15, "tente").label(51, 15, "tente").label(77, 16, "sacs de sel")

    # ======================================================================== le gibet
    r = mk("l19_sentier", "Le sentier des pendus", 1, 1)
    r.side("E", 0, "1", ["l02_montee", "4"])
    r.top(6, "2", ["l17_grand_gibet", "2"])
    # à l'est, le rocher du sentier ; on y monte depuis le passage
    r.fill(23, 14, 31, 16, "#").fill(33, 17, 35, 18, "#")
    # le fossé devant la herse ; il ramène sous le rocher
    r.fill(16, 14, 22, 19, " ").fill(16, 20, 22, 20, "#")
    # à l'ouest, la porte du gibet et la montée vers le Grand Gibet
    r.fill(2, 14, 15, 18, "#").fill(11, 2, 15, 7, "M")
    r.fill(9, 11, 12, 11, "#").fill(3, 8, 6, 8, "#").fill(5, 5, 10, 5, "#")
    r.extra["herse"] = {"gate": [13, 8, 1, 6], "chain": [25, 13], "flag": "boss:gibets", "open_time": 1.4}
    r.spot(11, 8, "p").spot(19, 6, "C")
    r.hint(24, 10, "Une chaîne. La herse retombe aussitôt.")
    r.sky()
    r.label(11, 3, "porte du gibet").label(17, 21, "fossé").label(24, 15, "rocher")

    r = mk("l17_grand_gibet", "Le Grand Gibet", 2, 2)
    r.side("W", 0, "1", ["l18_route", "1"], ledge=8)
    r.bottom(46, "2", ["l19_sentier", "2"])
    r.extra["boss"] = "gibets"
    # le chêne mort, ses racines autour de la fente, ses branches chargées de pendus
    r.fill(42, 38, 45, 40, "b").fill(50, 38, 53, 40, "b")
    r.fill(58, 6, 61, 40, "b")
    for y, x0, x1 in ((35, 50, 57), (32, 41, 49), (29, 50, 57), (26, 41, 49), (23, 30, 40)):
        r.plat(x0, y, x1 - x0 + 1, "-")
    r.plat(8, 20, 22, "-")
    r.plat(62, 14, 10, "-").plat(48, 10, 10, "-")
    for x, y in ((44, 33), (54, 30), (36, 24), (20, 21), (12, 21), (26, 21), (66, 15), (52, 11)):
        r.spot(x, y, "p")
    r.spot(16, 40, "B")
    r.hint(4, 12, "La route de Koka, à l'ouest.")
    r.sky()
    r.label(56, 4, "chêne mort").label(40, 41, "racines").label(14, 18, "maîtresse branche")

    r = mk("l18_route", "La route de Koka", 10, 1)
    r.side("E", 0, "1", ["l17_grand_gibet", "1"])
    r.side("W", 0, "2", [])
    hills = [(20, 30, 17), (60, 74, 16), (64, 70, 14), (120, 128, 17), (170, 186, 16), (174, 182, 14),
             (230, 236, 17), (280, 296, 16), (284, 292, 14), (340, 348, 17)]
    for x0, x1, y in hills:
        r.mound([(x0, x1, y)], ch="#")
    for x in (44, 100, 150, 210, 260, 320, 370):
        gibbet(r, x, hanged=(x % 20 == 0))
    for x in (90, 200, 310):
        r.spot(x, 18, "E")
    for x in (67, 177, 287):
        r.spot(x, 13, "C")
    for x in (30, 110, 190, 250, 330, 380):
        r.spot(x, 6, "G")
    r.hint(240, 10, "En contrebas, les toits morts de Hautfer. Une dernière fois.")
    r.hint(8, 12, "La Vallée de Brume, à l'ouest.")
    r.hint(8, 13, "(fin de la tranche)")
    r.sky()
    r.label(60, 12, "colline").label(170, 12, "colline").label(43, 9, "gibet")

    return rooms


if __name__ == "__main__":
    rooms = build()
    path = Path(__file__).resolve().parent.parent / "scripts" / "rooms_lande.gd"
    path.write_text(to_gd(rooms, "RoomsLande", "La Lande aux Pendus",
                          f"Les {len(rooms)} salles de la Lande aux Pendus (Z2), d'après le plan détaillé.\n"
                          "Fichier généré par tools/gen_lande.py : voir la légende dans rooms.gd."), encoding="utf-8")
    print(f"{len(rooms)} salles écrites dans {path}")
