"""Renders Crafted's README plates in the Rao plate style (Weave's and Craft's plates.py), from HTML, through the
installed Google Chrome driven by Playwright (pip install playwright). No server, no model.

    python3 -I Docs/README_Assets/src/plates.py Docs/README_Assets [hero] [how]

Inputs:  this folder's rr-mark.png (Rao's current mark, from rao.nyc's public/rr-mark.png); Playfair Display Italic from
         ~/Library/Fonts.
Outputs in argv[1]: hero.png (1200x630 at 2x: 2400x1260) and how.png (1600 wide at 2x).

What the hero draws follows the app: two folders come in from the left, a designer's work (its palette showing)
and an engineer's project (its code showing), each on its own thread, brass and blue. Both pass through the eye
of one needle, the two models on this Mac, and the needle stitches them into one tile on the right: the agent,
ringed with the app icon's French knots, ready for the Craft Agent Store.
"""

import math
import os
import sys
import tempfile

from playwright.sync_api import sync_playwright

HERE = os.path.dirname(os.path.abspath(__file__))
OUT = os.path.abspath(sys.argv[1]) if len(sys.argv) > 1 else os.path.dirname(HERE)
PLAYFAIR = os.path.expanduser("~/Library/Fonts/PlayfairDisplay-Italic-VariableFont_wght.ttf")

# The plate palette (AII's, Braid's, Craft's, Weave's): brass for the designer, blue for the engineer.
BRASS, BLUE, GREEN, CLAY, LINE = "#c7a659", "#5e8fda", "#28a883", "#d8773f", "#cbc8c0"
PAPER = "#efe8d9"
MONO = "Menlo, 'SF Mono', monospace"


def shoot(browser, page_html, path, viewport=(1200, 630), scale=2, prepare=None):
    """Writes `page_html` beside the inputs (so relative URLs resolve) and screenshots it."""
    with tempfile.NamedTemporaryFile("w", suffix=".html", dir=HERE, delete=False, encoding="utf-8") as f:
        f.write(page_html)
        name = f.name
    try:
        page = browser.new_page(device_scale_factor=scale, viewport={"width": viewport[0], "height": viewport[1]})
        page.goto("file://" + name)
        if prepare:
            page.evaluate(prepare)
        page.wait_for_timeout(250)
        page.screenshot(path=path, full_page=True)
        page.close()
    finally:
        os.unlink(name)


# The title's and subtitle's first ink sit on the mark's left edge (Weave's ALIGN).
EDGE = 66
ALIGN = f"""document.fonts.ready.then(() => {{ const ctx = document.createElement('canvas').getContext('2d');
    for (const el of document.querySelectorAll('.title, .sub')) {{ const cs = getComputedStyle(el), text = el.textContent.trim();
        ctx.font = `italic ${{cs.fontWeight}} ${{cs.fontSize}} Playfair`;
        el.style.left = ({EDGE} - parseFloat(cs.paddingLeft) + ctx.measureText(text[0]).actualBoundingBoxLeft) + 'px'; }} }})"""

# Rao's plates put the header's ink on the mark's, 70.5 px in (Braid's INK); the hero keeps EDGE.
PLATE_ALIGN = ALIGN.replace(f"({EDGE} -", "(70.5 -")

HEAD_CSS = f"""
@font-face {{ font-family: "Playfair"; font-style: italic; font-weight: 400 900; src: url("file://{PLAYFAIR}") format("truetype"), local("Playfair Display Italic"); }}
body {{ position: relative; margin: 0; overflow: hidden; font-family: "Playfair", Georgia, serif; font-style: italic; color: #a29f97;
       font-variant-numeric: lining-nums; background: radial-gradient(ellipse 90% 100% at 22% 20%, #20201c 0%, #191917 45%, #121211 100%); }}
.title {{ position: absolute; padding-left: 40px; padding-right: 30px; line-height: 1; font-weight: 500; letter-spacing: -.005em; white-space: nowrap;
         background: linear-gradient(100deg, #8d9097 0%, #c8cad0 35%, #f2f3f6 58%, #b6b9c1 100%);
         -webkit-background-clip: text; background-clip: text; color: transparent; }}
.sub {{ position: absolute; color: #9b9991; white-space: nowrap; }}
.caption {{ position: absolute; letter-spacing: .3em; color: #8b8a84; }}
.lab {{ position: absolute; font-size: 19px; color: #8b8a84; white-space: nowrap; }}
.lab b {{ font-weight: 400; color: #e9e7e0; }}
.small {{ font-size: 15.5px; color: #8b8a84; }}
.dot {{ display: inline-block; width: 13px; height: 13px; border-radius: 50%; margin-right: 10px; transform: translateY(-1px); }}
.needle {{ display: inline-block; width: 26px; height: 4px; margin: 0 10px 0 2px; transform: translateY(-6px) rotate(45deg);
           background: linear-gradient(180deg, #f4f5f7, #c3c8cf 45%, #7f858e); clip-path: polygon(0 0, 80% 0, 100% 50%, 80% 100%, 0 100%); border-radius: 2px 0 0 2px; }}
svg {{ position: absolute; left: 0; top: 0; }}
"""

STEEL = """<defs><linearGradient id="steel" x1="0" y1="0" x2="0" y2="1"><stop offset="0" stop-color="#f4f5f7"/>
<stop offset=".45" stop-color="#c3c8cf"/><stop offset="1" stop-color="#7f858e"/></linearGradient>
<linearGradient id="paper" x1="0" y1="0" x2="0" y2="1"><stop offset="0" stop-color="#fffdf7"/><stop offset="1" stop-color="#e9e3d4"/></linearGradient></defs>"""


def squircle_points(cx, cy, side, spacing, n=5, samples=2048):
    """Points on a superellipse, evenly spaced by length: the app icon's ring of French knots."""
    r = side / 2
    pts = []
    for i in range(samples + 1):
        t = i / samples * 2 * math.pi
        c, s = math.cos(t), math.sin(t)
        pts.append((cx + r * math.copysign(abs(c) ** (2 / n), c), cy + r * math.copysign(abs(s) ** (2 / n), s)))
    lengths = [0.0]
    for i in range(1, len(pts)):
        lengths.append(lengths[-1] + math.dist(pts[i], pts[i - 1]))
    count = max(8, round(lengths[-1] / spacing))
    out, j = [], 0
    for k in range(count):
        d = k / count * lengths[-1]
        while lengths[j + 1] < d:
            j += 1
        f = (d - lengths[j]) / (lengths[j + 1] - lengths[j])
        out.append((pts[j][0] + (pts[j + 1][0] - pts[j][0]) * f, pts[j][1] + (pts[j + 1][1] - pts[j][1]) * f))
    return out


def folder(x, y, w, h, colour, inner):
    """A line-drawn folder, its tab up-left, with what it holds peeking out of it."""
    tab = (f'M{x},{y + 10} L{x},{y - 6} Q{x},{y - 12} {x + 6},{y - 12} L{x + w * 0.32},{y - 12} '
           f'L{x + w * 0.40},{y - 2} L{x + w - 6},{y - 2} Q{x + w},{y - 2} {x + w},{y + 4} L{x + w},{y + 10}')
    return (f'{inner}<path d="{tab}" fill="none" stroke="{colour}" stroke-width="2.2" stroke-linejoin="round" stroke-linecap="round"/>'
            f'<rect x="{x - 3}" y="{y + 10}" width="{w + 6}" height="{h}" rx="5" fill="#1d1d1a" stroke="{colour}" stroke-width="2.2"/>'
            # The seam, stitched: the icon's ticks along the folder's front.
            + "".join(f'<line x1="{x + 10 + i * 9}" y1="{y + 22}" x2="{x + 10 + i * 9}" y2="{y + 28 - (i % 2) * 2}" stroke="{colour}" stroke-opacity=".7" stroke-width="1.4" stroke-linecap="round"/>'
                      for i in range(int((w - 14) / 9))))


def needle(x, y, length=150, angle=40, w=5.4):
    body = (f"M-20,0 Q-20,{-w} -12,{-w} L{length - 34},{-w * .75} L{length},0 L{length - 34},{w * .75} L-12,{w} Q-20,{w} -20,0 Z")
    return (f'<g transform="translate({x} {y}) rotate({angle})">'
            f'<path d="{body}" fill="#000" fill-opacity=".38" transform="translate(2 4)"/>'
            f'<path d="{body}" fill="url(#steel)"/>'
            f'<path d="M-12,{-w * .45} L{length - 40},{-w * .35}" stroke="#fff" stroke-opacity=".75" stroke-width="1.2" stroke-linecap="round"/>'
            f'<rect x="-8" y="-1.9" width="16" height="3.8" rx="1.9" fill="#121211"/>'
            f'<rect x="-6" y="-1.9" width="5" height="3.8" fill="{BRASS}"/><rect x="0" y="-1.9" width="5" height="3.8" fill="{BLUE}"/></g>')


# MARK: The hero

EYE_X, EYE_Y = 884, 424
NEEDLE_LENGTH, NEEDLE_ANGLE = 128, 38
TILE = (1004, 398, 140)     # the agent tile: left, top, side
# Each folder's left and its tab's base. Its outline is drawn 3 px left of `left` at 2.2 px, so its ink starts
# 4.1 px left of it: 70.1 puts it on EDGE, under the subtitle's first ink and over the legend's.
FOLDERS = {"designer": (EDGE + 4.1, 404), "engineer": (EDGE + 4.1, 488)}
FOLDER_W, FOLDER_H = 112, 36


def hero(browser):
    # The two folders, and what each holds: a designer's palette and a piece; an engineer's code.
    dx, dy = FOLDERS["designer"]
    swatches = "".join(f'<rect x="{dx + 10 + i * 15}" y="{dy - 30}" width="12" height="20" rx="2" fill="{c}" '
                       f'transform="rotate({-8 + i * 5} {dx + 16 + i * 15} {dy - 10})"/>'
                       for i, c in enumerate([BRASS, CLAY, "#7a8f68", "#9fb3c6"]))
    piece = (f'<g transform="rotate(9 {dx + 82} {dy - 14})"><rect x="{dx + 66}" y="{dy - 36}" width="30" height="40" rx="3" fill="{PAPER}"/>'
             f'<rect x="{dx + 71}" y="{dy - 29}" width="18" height="4.5" fill="{CLAY}"/></g>')
    ex, ey = FOLDERS["engineer"]
    code = (f'<rect x="{ex + 6}" y="{ey - 28}" width="96" height="30" rx="3" fill="#232320"/>'
            + "".join(f'<rect x="{ex + 14 + (i % 3) * 8}" y="{ey - 22 + i * 6}" width="{[46, 30, 58, 38][i]}" height="3" rx="1.5" '
                      f'fill="{BLUE}" fill-opacity="{[.9, .6, .75, .55][i]}"/>' for i in range(4)))
    designer = folder(dx, dy, FOLDER_W, FOLDER_H, BRASS, swatches + piece)
    engineer = folder(ex, ey, FOLDER_W, FOLDER_H, BLUE, code)

    # Each thread from its folder into the needle's eye: level, then rising late, clear of the words.
    def thread(x0, y0, colour):
        x1, y1 = EYE_X, EYE_Y
        return (f'<path d="M{x0},{y0} C{x1 - 380},{y0} {x1 - 160},{y1} {x1},{y1}" fill="none" stroke="{colour}" '
                f'stroke-width="3.4" stroke-linecap="round"/>')
    threads = thread(dx + FOLDER_W + 4, dy + 10 + FOLDER_H / 2, BRASS) + thread(ex + FOLDER_W + 4, ey + 10 + FOLDER_H / 2, BLUE)

    # The agent tile: paper, the icon's knot ring, a stitched folder, and the running stitch the needle leaves.
    left, top, side = TILE
    cx, cy = left + side / 2, top + side / 2
    knots = "".join(f'<circle cx="{px:.1f}" cy="{py:.1f}" r="2" fill="{BRASS}" fill-opacity=".85"/>'
                    for px, py in squircle_points(cx, cy, side * 0.86, 10))
    tile = (f'<g filter="url(#lift)"><rect x="{left}" y="{top}" width="{side}" height="{side}" rx="{side * 0.225}" fill="url(#paper)"/></g>'
            f'{knots}'
            f'<path d="M{cx - 32},{cy - 6} L{cx - 32},{cy - 17} Q{cx - 32},{cy - 21} {cx - 28},{cy - 21} L{cx - 11},{cy - 21} L{cx - 5},{cy - 14} '
            f'L{cx + 28},{cy - 14} Q{cx + 32},{cy - 14} {cx + 32},{cy - 10} L{cx + 32},{cy + 24} Q{cx + 32},{cy + 28} {cx + 28},{cy + 28} '
            f'L{cx - 28},{cy + 28} Q{cx - 32},{cy + 28} {cx - 32},{cy + 24} Z" fill="none" stroke="#37352f" stroke-width="2.3" stroke-linejoin="round"/>'
            + "".join(f'<line x1="{cx - 24 + i * 7}" y1="{cy - 6}" x2="{cx - 24 + i * 7}" y2="{cy - 1 - (i % 2) * 2}" stroke="#37352f" stroke-width="1.5" stroke-linecap="round"/>' for i in range(7))
            + f'<path d="M{cx - 26},{cy + 11} L{cx + 26},{cy + 11}" stroke="#37352f" stroke-width="1.7" stroke-dasharray="5 4" stroke-linecap="round"/>')
    tip_x = EYE_X + NEEDLE_LENGTH * math.cos(math.radians(NEEDLE_ANGLE))
    tip_y = EYE_Y + NEEDLE_LENGTH * math.sin(math.radians(NEEDLE_ANGLE))
    stitch = (f'<path d="M{tip_x - 3},{tip_y - 2} C{tip_x + 10},{tip_y + 16} {cx - 44},{top + side - 16} {cx + 6},{top + side - 20}" '
              f'fill="none" stroke="{BRASS}" stroke-width="2.4" stroke-dasharray="7 5" stroke-linecap="round"/>')

    page = f"""<!doctype html><html><head><meta charset="utf-8"><style>{HEAD_CSS}
html, body {{ width: 1200px; height: 630px; }}
.mark {{ position: absolute; left: 64.6px; top: 62.6px; width: 51.9px; }}
.caption {{ left: 138.8px; top: 72px; font-size: 16.5px; }}
.title {{ left: 34px; top: 108px; font-size: 186px; }}
.sub {{ left: 65.5px; top: 300px; font-size: 36px; }}
.legend {{ position: absolute; left: 66px; top: 568px; display: flex; gap: 28px; align-items: baseline; font-size: 21px; color: #8b8a84; white-space: nowrap; }}
.legend b {{ font-weight: 400; color: #e9e7e0; }}
.agent {{ text-align: right; line-height: 1.3; }}
</style></head><body>
<img class="mark" src="rr-mark.png">
<div class="caption">RAO STUDIOS · CRAFTED · FOLDERS, CRAFTED INTO AGENTS</div>
<div class="title">Crafted</div>
<div class="sub">drop a folder, download an agent for Craft</div>
<svg width="1200" height="630">{STEEL}<defs><filter id="lift" x="-30%" y="-30%" width="160%" height="160%">
<feDropShadow dx="0" dy="10" stdDeviation="10" flood-color="#000" flood-opacity=".55"/></filter></defs>
{threads}{designer}{engineer}{tile}{stitch}{needle(EYE_X, EYE_Y, NEEDLE_LENGTH, NEEDLE_ANGLE)}</svg>
<div class="lab" style="left:{dx + FOLDER_W + 22}px; top:{dy - 12}px"><b>a designer's work</b></div>
<div class="lab" style="left:{ex + FOLDER_W + 22}px; top:{ey - 14}px"><b>an engineer&#39;s project</b></div>
<div class="lab" style="left:{EYE_X - 112}px; top:{EYE_Y - 56}px"><b>two models</b> <span class="small">on this Mac</span></div>
<div class="lab agent" style="left:{left - 90}px; top:{top - 58}px; width:{side + 90}px"><b>an agent</b><br><span class="small">for the Craft Agent Store</span></div>
<div class="legend">
  <span><i class="needle"></i><b>vision</b> · Ministral 3 8B</span>
  <span><i class="needle"></i><b>coder</b> · Qwen3-Coder-Next</span>
  <span><i class="dot" style="background:{BRASS}"></i><b>designer</b> · style agent</span>
  <span><i class="dot" style="background:{BLUE}"></i><b>engineer</b> · ported agent</span>
</div>
</body></html>"""
    shoot(browser, page, os.path.join(OUT, "hero.png"), prepare=ALIGN)


# MARK: How it works

W = 1600


def card(x, y, w, h, name, lines, chips=(), colour=None):
    accent = f"border-color: {colour}55; background: {colour}0d;" if colour else ""
    body = "".join(f'<div class="line">{line}</div>' for line in lines)
    tags = "".join(f'<span class="chip">{chip}</span>' for chip in chips)
    return (f'<div class="card" style="left:{x}px; top:{y}px; width:{w}px; height:{h}px; {accent}">'
            f'<div class="name">{name}</div>{body}<div>{tags}</div></div>')


def how(browser):
    col = [70, 366, 662, 958]
    cw, ch = 262, 168
    lane_y = {"designer": 418, "engineer": 646}
    designer = [
        ("Your folder", ["pieces, PDFs, SVG, fonts,", "CSS and design tokens"], ["drop"]),
        ("Measure", ["palette in OKLab, type,", "margins, marks: by code"], ["no model"]),
        ("Look", ["one piece at a time:", "layout, hierarchy, motifs"], ["vision"]),
        ("Synthesise", ["one design system,", "measured facts win"], ["coder", "style.json"]),
    ]
    engineer = [
        ("Your project", ["any language: every file,", "secrets never read"], ["drop"]),
        ("Walk", ["a card per file, every claim", "cited to its lines"], ["coder"]),
        ("Use cases", ["entry, rule, data, effect,", "intent; then three agents"], ["you choose"]),
        ("Port", ["to Swift, unit by unit:", "compile, test, repair"], ["coder", "swift build"]),
    ]
    cards = ""
    wires = ""
    for lane, steps, colour in (("designer", designer, BRASS), ("engineer", engineer, BLUE)):
        y = lane_y[lane]
        cards += f'<div class="lanename" style="top:{y - 34}px; color:{colour}">{lane.upper()}</div>'
        for i, (name, lines, chips) in enumerate(steps):
            cards += card(col[i], y, cw, ch, name, lines, chips, colour if i == 0 else None)
            if i < len(steps) - 1:
                x0, x1, my = col[i] + cw, col[i + 1], y + ch / 2
                wires += (f'<line x1="{x0 + 6}" y1="{my}" x2="{x1 - 8}" y2="{my}" stroke="{colour}" stroke-width="2.4" stroke-linecap="round"/>'
                          f'<path d="M{x1 - 16},{my - 7} L{x1 - 7},{my} L{x1 - 16},{my + 7}" fill="none" stroke="{colour}" stroke-width="2.2" stroke-linecap="round" stroke-linejoin="round"/>')
    # Both lanes run into the agent: the listing the person edits, the gates, the zip.
    ax, ay, aw, ah = 1262, 418, 272, 396
    for lane, colour in (("designer", BRASS), ("engineer", BLUE)):
        y = lane_y[lane] + ch / 2
        x0 = col[3] + cw
        wires += (f'<path d="M{x0 + 6},{y} C{x0 + 40},{y} {ax - 40},{ay + ah / 2} {ax - 8},{ay + ah / 2}" fill="none" stroke="{colour}" stroke-width="2.4" stroke-linecap="round"/>')
    wires += f'<path d="M{ax - 16},{ay + ah / 2 - 7} L{ax - 7},{ay + ah / 2} L{ax - 16},{ay + ah / 2 + 7}" fill="none" stroke="{LINE}" stroke-width="2.2" stroke-linecap="round" stroke-linejoin="round"/>'
    knots = "".join(f'<circle cx="{px:.1f}" cy="{py:.1f}" r="2" fill="{BRASS}" fill-opacity=".8"/>'
                    for px, py in squircle_points(ax + aw / 2, ay + 62, 76, 9))
    agent = (f'<div class="card" style="left:{ax}px; top:{ay}px; width:{aw}px; height:{ah}px; border-color:{BRASS}66; background:{BRASS}0f; padding-top:124px">'
             f'<div class="name">Your agent</div>'
             f'<div class="line">a Swift package on Granite,</div><div class="line">its listing and icon yours</div>'
             f'<div class="step"><b>gates</b> store rules · secrets · build · install</div>'
             f'<div class="step"><b>zip</b> a repo, ready to push</div>'
             f'<div><span class="chip">credits the designer</span><span class="chip">PNG · PDF · data · hand-off</span></div></div>')
    models = (f'<div class="card" style="left:70px; top:870px; width:1464px; height:52px; padding:12px 18px; border-color:{BRASS}44; background:{BRASS}0a">'
              f'<span class="model"><b>Ministral 3 8B</b> vision · 10.4 GB</span><span class="model"><b>Qwen3-Coder-Next 48B</b> coder · 27.5 GB</span>'
              f'<span class="model">one in memory at a time · shared with Craft in <span class="mono">~/.rao/models</span> · nothing leaves this Mac until you push</span></div>')

    page = f"""<!doctype html><html><head><meta charset="utf-8"><style>{HEAD_CSS}
html, body {{ width: {W}px; height: 960px; }}
.mark {{ position: absolute; left: 68.8px; top: 69.3px; width: 46.2px; }}
.caption {{ left: 145.8px; top: 78px; font-size: 15px; }}
.title {{ left: 30px; top: 150px; font-size: 104px; padding-bottom: 20px; }}
.sub {{ left: 66px; top: 272px; font-size: 32px; }}
.card {{ position: absolute; box-sizing: border-box; border: 1px solid rgba(255,255,255,.11); border-radius: 14px; background: rgba(255,255,255,.03); padding: 16px 20px; }}
.card .name {{ font-size: 27px; color: #e9e7e0; margin-bottom: 6px; }}
.card .line {{ font-size: 17.5px; color: #8b8a84; line-height: 1.35; }}
.card .step {{ font-size: 17px; color: #8b8a84; margin-top: 14px; line-height: 1.35; }}
.card .step b {{ font-weight: 400; color: #e9e7e0; margin-right: 6px; }}
.chip {{ display: inline-block; font-family: {MONO}; font-style: normal; font-size: 11.5px; padding: 3px 8px; border-radius: 6px; margin: 12px 6px 0 0;
         background: rgba(255,255,255,.06); color: #b9b6ad; }}
.lanename {{ position: absolute; left: 70px; font-size: 14px; letter-spacing: .3em; }}
.model {{ font-size: 18px; color: #8b8a84; margin-right: 34px; white-space: nowrap; }}
.model b {{ font-weight: 400; color: #e9e7e0; margin-right: 6px; }}
.mono {{ font-family: {MONO}; font-style: normal; font-size: 13px; color: #b9b6ad; }}
</style></head><body>
<img class="mark" src="rr-mark.png">
<div class="caption">RAO STUDIOS · CRAFTED · HOW A FOLDER BECOMES AN AGENT</div>
<div class="title">Two paths, one agent</div>
<div class="sub">the model says what it means; fixed code places it, builds it and checks it</div>
<svg width="{W}" height="960">{wires}</svg>
{cards}{agent}{models}
<svg width="{W}" height="960" style="pointer-events:none">{knots}</svg>
</body></html>"""
    shoot(browser, page, os.path.join(OUT, "how.png"), viewport=(W, 960), prepare=PLATE_ALIGN)


TARGETS = {"hero": hero, "how": how}


def main():
    os.makedirs(OUT, exist_ok=True)
    wanted = [name for name in sys.argv[2:] if name in TARGETS] or list(TARGETS)
    with sync_playwright() as p:
        browser = p.chromium.launch(channel="chrome")
        for name in wanted:
            TARGETS[name](browser)
            print("wrote", os.path.join(OUT, f"{name}.png"))
        browser.close()


if __name__ == "__main__":
    main()
