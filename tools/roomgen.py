"""Outils communs aux générateurs de salles (tools/gen_*.py).

Une case du plan vaut un écran : 40 × 22 cases de 32 pixels. Une salle se construit avec
quelques outils (murs, corniches, tas, passages), puis s'écrit en caractères (voir la légende
dans scripts/rooms.gd).
"""
import json

CW, CH = 40, 22   # une case du plan, en cases de 32 px


class R:
    def __init__(self, rid, name, w, h):
        self.id, self.name = rid, name
        self.W, self.H = CW * w, CH * h
        self.g = [["#"] * self.W for _ in range(self.H)]
        self.doors = {}
        self.hints = []
        self.labels = []
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

    def label(self, x, y, text):
        """Étiquette de DA : ce que représente un volume (dessinée discrètement, en petit)."""
        self.labels.append([x, y, text])
        return self

    def retint(self, x0, y0, x1, y1, to, frm="#"):
        """Change la matière des blocs d'une zone (roche -> bois, maçonnerie, chair...)."""
        for y in range(max(0, y0), min(self.H, y1 + 1)):
            for x in range(max(0, x0), min(self.W, x1 + 1)):
                if self.g[y][x] == frm:
                    self.g[y][x] = to
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

    def wl(self, top, end, depth=3, ch="#"):
        """Corniche de roche accrochée au mur gauche (jusqu'à la colonne end) ;
        le dessous s'épaissit vers le mur, de façon irrégulière."""
        self.fill(2, top, end, top, ch)
        for k in range(1, depth + 1):
            self.fill(2, top + k, end - 2 * k - self._jit(top, k), top + k, ch)
        return self

    def wr(self, top, start, depth=3, ch="#"):
        """Corniche de roche accrochée au mur droit (à partir de la colonne start)."""
        self.fill(start, top, self.W - 3, top, ch)
        for k in range(1, depth + 1):
            self.fill(start + 2 * k + self._jit(top, k), top + k, self.W - 3, top + k, ch)
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

    def mound(self, steps, floor=None, ch="#"):
        """Un tas (éboulis, gradins, piles) : [(x0, x1, haut), ...], plein jusqu'au sol."""
        floor = self.H - 4 if floor is None else floor
        for x0, x1, y in steps:
            self.fill(x0, y, x1, floor, ch)
        return self

    def hang(self, steps, ch="#", thick=4):
        """Une masse accrochée (pente, surplomb) : [(x0, x1, haut), ...]. Chaque colonne descend
        de `thick` cases au plus, en laissant toujours 3 cases libres au-dessus de ce qui est dessous."""
        for x0, x1, top in steps:
            for x in range(x0, x1 + 1):
                below = top + 1
                while below < self.H and self.g[below][x] == " ":
                    below += 1
                bottom = min(top + thick - 1, below - 4)
                for y in range(top, max(top, bottom) + 1):
                    self.g[y][x] = ch
        return self

    def sky(self, sides=True):
        """Salle en plein air : le haut et les bords au-dessus du sol deviennent une limite invisible."""
        self.extra["outdoor"] = True
        for y in range(self.H if sides else 0):
            for xs, xin in (((0, 1), 2), ((self.W - 2, self.W - 1), self.W - 3)):
                if self.g[y][xin] not in " -=":
                    continue
                for x in xs:
                    if self.g[y][x] == "#":
                        self.g[y][x] = "K"
        for y in (1, 0):
            for x in range(self.W):
                if self.g[y][x] == "#" and (self.g[y + 1][x] in " K" or y == 0 and self.g[1][x] == "K"):
                    self.g[y][x] = "K"
        return self

    def spot(self, x, y, s):
        """Pose un objet ou un ennemi sur une case vide (vérifié)."""
        for i in range(len(s)):
            assert self.g[y][x + i] == " ", (self.id, x + i, y, self.g[y][x + i])
        return self.put(x, y, s)

    def rows(self):
        return ["".join(r) for r in self.g]



def to_gd(rooms, class_name, zone, doc):
    out = []
    out.append(f"class_name {class_name}")
    out.append("extends RefCounted")
    for line in doc.strip().splitlines():
        out.append("## " + line)
    out.append("")
    out.append("const DATA := {")
    for r in rooms:
        assert len(r.g) == r.H and all(len(x) == r.W for x in r.g), r.id
        out.append(f'\t"{r.id}": {{')
        out.append(f'\t\t"name": "{r.name}",')
        out.append(f'\t\t"zone": "{zone}",')
        for k, v in r.extra.items():
            out.append(f'\t\t"{k}": {json.dumps(v, ensure_ascii=False)},')
        doors = ", ".join(f'"{d}": ["{v[0]}", "{v[1]}"]' for d, v in sorted(r.doors.items()) if v)
        out.append(f"\t\t\"doors\": {{{doors}}},")
        hints = ", ".join('[%d, %d, "%s"]' % (h[0], h[1], h[2].replace('"', '\\"')) for h in r.hints)
        out.append(f"\t\t\"hints\": [{hints}],")
        if r.labels:
            labels = ", ".join('[%d, %d, "%s"]' % (h[0], h[1], h[2].replace('"', '\\"')) for h in r.labels)
            out.append(f"\t\t\"labels\": [{labels}],")
        out.append('\t\t"rows": [')
        for row in r.rows():
            out.append(f'\t\t\t"{row}",')
        out.append("\t\t],")
        out.append("\t},")
    out.append("}")
    return "\n".join(out) + "\n"
