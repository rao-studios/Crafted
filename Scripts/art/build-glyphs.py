"""WHAT: Build the candidate glyphs for Crafted's icon, in Craft's embroidered hand (Craft's Design/hand.svg, built by
      its Scripts/art/build-hand-svg.py): one line, stroke 1.7 on a 320-unit box, round caps and joins, every curve a
      Catmull-Rom through hand-placed points, and short alternating ticks across each seam.
OUT:  Design/glyphs/needle-folder.svg   a folder with a stitched seam; a threaded needle through it, the thread
                                        trailing up to the right as Craft's does.
      Design/glyphs/hand-folder.svg     an open hand offering a small stitched folder.
      Design/glyphs/stitched-patch.svg  an embroidered badge, a needle resting on it, a loose thread tail.
      Each has viewBox "90 60 320 320", a <g id="glyph"> (the drawing) and a <g id="stitches"> (the ticks), which is
      what Scripts/art/gen-app-icon.swift --glyph reads.
PIN:  The icon draws these at ~4.4 units of line (8.4 px on a 1024 tile) and the Dock shrinks them to 64 px and less:
      every shape is a few large strokes first, detail second. Check the contact sheet (Scripts/art/icon-candidates.sh)
      after any change.
PIN:  Points are placed by hand on the 320 box and wobbled a little (a seeded ±0.6 unit), so no line is ruled.

USAGE: python3 -I Scripts/art/build-glyphs.py
"""
import math
import os
import random

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
OUT = os.path.join(ROOT, "Design", "glyphs")
VB = (90, 60, 320, 320)


# --- the hand: curves, wobble, ticks (after Craft's build-hand-svg.py) --------------------------------------------

def wobble(points, seed, amount=0.6):
    """The points moved by a seeded ±amount, ends kept: a drawn line, not a ruled one."""
    rand = random.Random(seed)
    out = [points[0]]
    for p in points[1:-1]:
        out.append((p[0] + rand.uniform(-amount, amount), p[1] + rand.uniform(-amount, amount)))
    if len(points) > 1:
        out.append(points[-1])
    return out


def densify(points, longest=12.0):
    """Long straight runs split into short ones, so a corner between a long side and a short one stays a corner
    (Catmull-Rom's handles grow with the neighbouring segments and would bulge it)."""
    out = [points[0]]
    for a, b in zip(points, points[1:]):
        parts = max(1, math.ceil(math.dist(a, b) / longest))
        out += [(a[0] + (b[0] - a[0]) * k / parts, a[1] + (b[1] - a[1]) * k / parts) for k in range(1, parts + 1)]
    return out


def bez(points):
    """Catmull-Rom through the points, as cubic segments (p0, c1, c2, p1)."""
    points = densify(points)
    segs = []
    n = len(points)
    for i in range(n - 1):
        p0, p1, p2, p3 = points[max(i - 1, 0)], points[i], points[i + 1], points[min(i + 2, n - 1)]
        c1 = (p1[0] + (p2[0] - p0[0]) / 6, p1[1] + (p2[1] - p0[1]) / 6)
        c2 = (p2[0] - (p3[0] - p1[0]) / 6, p2[1] - (p3[1] - p1[1]) / 6)
        segs.append((p1, c1, c2, p2))
    return segs


def path_d(points):
    segs = bez(points)
    d = f"M{segs[0][0][0]:.1f},{segs[0][0][1]:.1f}"
    for _, c1, c2, p in segs:
        d += f" C{c1[0]:.1f},{c1[1]:.1f} {c2[0]:.1f},{c2[1]:.1f} {p[0]:.1f},{p[1]:.1f}"
    return d


def sample(points, k=12):
    out = []
    for p0, c1, c2, p1 in bez(points):
        for i in range(k):
            t = i / k
            u = 1 - t
            out.append(tuple(u ** 3 * a + 3 * u * u * t * b + 3 * u * t * t * c + t ** 3 * d for a, b, c, d in zip(p0, c1, c2, p1)))
    out.append(points[-1])
    return out


def ticks(points, spacing, length, t0=0.0, t1=1.0, side=1, both=False, alternate=True):
    """Short ticks across a seam, every `spacing` along it, alternating long and short as Craft's are (a satin edge
    passes alternate=False: even ticks, packed). `side` picks which side of the line they stand on (1 or -1);
    `both` centres them on the line."""
    pts = sample(points)
    acc = [0.0]
    for a, b in zip(pts, pts[1:]):
        acc.append(acc[-1] + math.dist(a, b))
    total = acc[-1]
    res = []
    s = total * t0
    i = 0
    alt = 0
    while s <= total * t1 + 1e-6:
        while i < len(acc) - 2 and acc[i + 1] < s:
            i += 1
        a, b = pts[i], pts[i + 1]
        f = (s - acc[i]) / max(acc[i + 1] - acc[i], 1e-6)
        x, y = a[0] + (b[0] - a[0]) * f, a[1] + (b[1] - a[1]) * f
        dx, dy = b[0] - a[0], b[1] - a[1]
        l = math.hypot(dx, dy) or 1
        nx, ny = -dy / l * side, dx / l * side
        L = length * (1 if alt % 2 == 0 or not alternate else 0.65)
        if both:
            res.append(((x - nx * L / 2, y - ny * L / 2), (x + nx * L / 2, y + ny * L / 2)))
        else:
            res.append(((x, y), (x + nx * L, y + ny * L)))
        alt += 1
        s += spacing
    return res


def dashes(points, dash, gap, t0=0.0, t1=1.0):
    """A running stitch: short lengths of the line, `dash` long, `gap` apart."""
    pts = sample(points, 24)
    acc = [0.0]
    for a, b in zip(pts, pts[1:]):
        acc.append(acc[-1] + math.dist(a, b))
    total = acc[-1]

    def at(s):
        i = 0
        while i < len(acc) - 2 and acc[i + 1] < s:
            i += 1
        a, b = pts[i], pts[i + 1]
        f = (s - acc[i]) / max(acc[i + 1] - acc[i], 1e-6)
        return (a[0] + (b[0] - a[0]) * f, a[1] + (b[1] - a[1]) * f)

    out = []
    s = total * t0
    while s + dash <= total * t1:
        out.append((at(s), at(s + dash)))
        s += dash + gap
    return out


def arc(cx, cy, rx, ry, a0, a1, n):
    """Points on an ellipse from angle a0 to a1 (degrees, y down)."""
    return [(cx + rx * math.cos(math.radians(a0 + (a1 - a0) * i / n)), cy + ry * math.sin(math.radians(a0 + (a1 - a0) * i / n))) for i in range(n + 1)]


def inside(point, polygon):
    """Even-odd test: is the point inside the polygon?"""
    x, y = point
    hit = False
    for i in range(len(polygon)):
        (ax, ay), (bx, by) = polygon[i], polygon[(i + 1) % len(polygon)]
        if (ay > y) != (by > y) and x < (bx - ax) * (y - ay) / (by - ay) + ax:
            hit = not hit
    return hit


def near_segment(point, a, b):
    """Distance from a point to the segment ab."""
    (px, py), (ax, ay), (bx, by) = point, a, b
    dx, dy = bx - ax, by - ay
    t = max(0.0, min(1.0, ((px - ax) * dx + (py - ay) * dy) / max(dx * dx + dy * dy, 1e-9)))
    return math.hypot(px - (ax + t * dx), py - (ay + t * dy))


def runs(points, keep):
    """The runs of consecutive points `keep` says yes to, each long enough to draw."""
    out, run = [], []
    for p in points:
        if keep(p):
            run.append(p)
        else:
            if len(run) > 1:
                out.append(run)
            run = []
    if len(run) > 1:
        out.append(run)
    return out


def occluded(points, by, radius, k=10):
    """A curve broken where something drawn over it passes: the curve sampled, less what lies within `radius` of
    the segment `by` (a, b)."""
    return runs(sample(points, k), lambda p: near_segment(p, *by) > radius)


class Needle:
    """A needle as a line icon draws one at this weight: one stroke for the shaft, and at its head an open eye, a long
    loop the thread goes through. (An outlined shaft with a slot for an eye fills in at the icon's line.)
    `hidden(point)` says where it is out of sight, under cloth; the shaft is drawn only where it is not."""

    def __init__(self, tip, head, eye_len=26, eye_w=11, step=4.0):
        self.tip, self.head = tip, head
        dx, dy = head[0] - tip[0], head[1] - tip[1]
        self.L = math.hypot(dx, dy)
        self.u = (dx / self.L, dy / self.L)
        self.n = (-self.u[1], self.u[0])
        self.eye_len, self.eye_w, self.step = eye_len, eye_w, step
        self.hw = eye_w / 2

    def at(self, t, w=0.0):
        return (self.tip[0] + self.u[0] * t + self.n[0] * w, self.tip[1] + self.u[1] * t + self.n[1] * w)

    @property
    def eye_centre(self):
        return self.at(self.L - self.eye_len / 2)

    def along(self, point):
        """How far along the axis from the tip a point lies."""
        return (point[0] - self.tip[0]) * self.u[0] + (point[1] - self.tip[1]) * self.u[1]

    def lines(self, hidden=lambda p: False):
        shank = self.L - self.eye_len
        count = max(int(shank / self.step), 4)
        ts = [shank * i / count for i in range(count + 1)]
        shaft = [[self.at(t) for t in run] for run in runs(ts, lambda t: not hidden(self.at(t)))]
        # The eye: a long loop from the top of the shank, round the head and back.
        c, a, b = self.L - self.eye_len / 2, self.eye_len / 2, self.eye_w / 2
        eye = [self.at(c + a * math.cos(math.radians(th)), b * math.sin(math.radians(th))) for th in range(180, 541, 20)]
        return shaft, eye

    def axis(self, t0=0.0, t1=1.0):
        return (self.at(self.L * t0), self.at(self.L * t1))


def shifted(lines, stitches, dx, dy):
    """Every point moved by (dx, dy): to sit a drawing in the middle of its box."""
    move = lambda p: (p[0] + dx, p[1] + dy)
    return [[move(p) for p in line] for line in lines], [(move(a), move(b)) for a, b in stitches]


def write(name, title, lines, stitches):
    svg = ['<svg xmlns="http://www.w3.org/2000/svg" viewBox="%d %d %d %d" width="%d" height="%d" fill="none" '
           'stroke="#E5E4E2" stroke-width="1.7" stroke-linecap="round" stroke-linejoin="round">' % (VB + VB[2:]),
           f'  <title>{title}</title>', '  <g id="glyph">']
    for points in lines:
        svg.append(f'    <path d="{path_d(points)}"/>')
    svg += ['  </g>', '  <g id="stitches">']
    d = " ".join(f"M{a[0]:.1f},{a[1]:.1f} L{b[0]:.1f},{b[1]:.1f}" for a, b in stitches)
    svg += [f'    <path d="{d}"/>', '  </g>', '</svg>', '']
    os.makedirs(OUT, exist_ok=True)
    with open(os.path.join(OUT, name), "w") as f:
        f.write("\n".join(svg))
    print(f"wrote Design/glyphs/{name}")


# --- the three candidates -----------------------------------------------------------------------------------------

def needle_folder():
    """A folder whose front is being stitched: the seam's ticks run up to where the needle goes in, the needle rises
    over the folder's corner, and the thread from its eye trails up toward the corner as Craft's thread does."""
    front = wobble([(110, 205), (180, 202), (260, 200), (330, 197), (331, 210), (326, 270), (322, 318), (318, 334),
                    (300, 338), (200, 340), (140, 340), (126, 337), (121, 322), (116, 260), (110, 205)], 2)
    back = wobble([(124, 214), (123, 170), (124, 150), (130, 140), (140, 138), (186, 137), (195, 141), (203, 152),
                   (212, 155), (300, 155), (310, 158), (314, 168), (315, 206)], 1)
    seam = wobble([(124, 224), (180, 222.5), (238, 221), (290, 219.5), (318, 218)], 3)
    # In at the seam: the point is under the cloth, the rest over everything.
    puncture = (240, 221)
    pin = Needle(tip=(222, 240), head=(340, 106))
    went_in = pin.along(puncture)
    shaft, eye = pin.lines(hidden=lambda p: pin.along(p) < went_in)
    over = pin.axis(went_in / pin.L + 0.02, 1.0)
    covered = lambda line: occluded(line, over, pin.hw + 3.5)
    ex, ey = pin.eye_centre
    tail = wobble([(ex, ey), (ex - 12, ey - 4), (ex - 20, ey + 2), (ex - 23, ey + 12)], 5, 0.3)
    thread = wobble([(ex, ey), (ex + 14, ey + 8), (ex + 28, ey + 10), (ex + 40, ey + 2), (ex + 48, ey - 14),
                     (ex + 54, ey - 32), (ex + 60, ey - 44), (ex + 66, ey - 50)], 6, 0.3)
    sewn = ticks(seam, 10, 9, 0.03, 0.42, side=1)
    return covered(front) + covered(back) + covered(seam) + shaft + [eye, tail, thread], sewn


def hand_folder():
    """An open hand, palm up, from a stitched cuff at the lower left, offering a stitched folder."""
    under = wobble([(140, 330), (170, 316), (205, 308), (250, 304), (300, 300), (340, 294), (372, 284), (392, 272),
                    (398, 262), (394, 254)], 11)
    top = wobble([(124, 300), (150, 288), (176, 276), (192, 262), (200, 240), (206, 222), (214, 214), (222, 216),
                  (224, 228), (220, 246), (222, 262), (238, 270), (300, 272), (350, 268), (378, 262), (394, 254)], 12)
    nail = wobble([(209, 222), (214, 228), (219, 225)], 13, 0.2)
    fingers = [wobble([(344, 282), (366, 278), (386, 268)], 14), wobble([(318, 292), (342, 289), (362, 284)], 15)]
    arm = [wobble([(124, 300), (110, 315), (96, 332)], 16), wobble([(140, 330), (126, 346), (112, 364)], 17)]
    cuff = wobble([(104, 306), (120, 324), (134, 340)], 18)
    back = wobble([(242, 200), (241, 166), (245, 156), (254, 154), (284, 154), (292, 160), (298, 166), (350, 166),
                   (357, 170), (358, 193)], 19)
    front = wobble([(228, 196), (296, 194), (366, 191), (361, 232), (356, 268), (240, 270), (235, 232), (228, 196)], 20)
    seam = wobble([(240, 212), (300, 210), (356, 207)], 21)
    stitches = ticks(seam, 10, 8, 0.04, 0.96, side=1) + ticks(cuff, 7, 10, 0.0, 1.0, side=-1)
    return shifted([under, top, nail] + fingers + arm + [cuff, back, front, seam], stitches, 3, -38)


def stitched_patch():
    """An embroidered badge: a round patch satin-stitched at its edge, a folder worked in its middle, a needle resting
    on it below the folder, and the thread from its eye loose over the edge, curling up to the right."""
    cx, cy, r = 232, 222, 110
    edge = wobble(arc(cx, cy, r, r, -90, 270, 40), 31, 0.5)
    back = wobble([(194, 200), (194, 176), (198, 170), (216, 170), (222, 176), (268, 176), (274, 180), (274, 198)], 32)
    front = wobble([(184, 196), (232, 194), (282, 192), (278, 244), (194, 246), (184, 196)], 33)
    # Lying on the patch, below the folder, its eye toward the edge.
    pin = Needle(tip=(176, 288), head=(292, 262))
    shaft, eye = pin.lines()
    ex, ey = pin.eye_centre
    # Out over the satin edge, then, clear of it, one loose loop and up toward the corner.
    thread = wobble([(ex, ey), (ex + 14, ey + 6), (ex + 32, ey + 9), (ex + 52, ey + 7), (ex + 72, ey + 1),
                     (ex + 90, ey - 10), (ex + 100, ey - 26), (ex + 94, ey - 40), (ex + 82, ey - 38), (ex + 84, ey - 26),
                     (ex + 98, ey - 30), (ex + 110, ey - 56), (ex + 118, ey - 96), (ex + 124, ey - 150)], 35, 0.3)
    crossing = ((ex + 40, ey + 8), (ex + 76, ey))
    covered = lambda line: occluded(line, crossing, 6)
    clear = lambda s: near_segment(s[0], *crossing) > 6 and near_segment(s[1], *crossing) > 6
    satin = [s for s in ticks(edge, 5.2, 12, 0.0, 0.995, side=-1, alternate=False) if clear(s)]
    return shifted(covered(edge) + [back, front] + shaft + [eye, thread], satin, 0, 0)


if __name__ == "__main__":
    write("needle-folder.svg", "Crafted: a needle through a folder", *needle_folder())
    write("hand-folder.svg", "Crafted: a hand offering a folder", *hand_folder())
    write("stitched-patch.svg", "Crafted: a stitched patch", *stitched_patch())
