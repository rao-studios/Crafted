"""Renders Crafted's README plates in the Rao plate style (Weave's and Craft's plates.py), from HTML, through the
installed Google Chrome driven by Playwright (pip install playwright). No server, no model.

    python3 -I Docs/README_Assets/src/plates.py Docs/README_Assets [hero] [how] [mac] [time]

Inputs:  this folder's rr-mark.png (Rao's current mark, from rao.nyc's public/rr-mark.png); Playfair Display Italic from
         ~/Library/Fonts.
Outputs in argv[1]: hero.png (1200x630 at 2x: 2400x1260); how.png, mac.png and time.png (1600 wide at 2x).

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



# MARK: What a Mac needs, and where the time goes

SKY = "#8ea5bc"
GREY = "#cbc8c0"

PLATE_HEAD = """<style>{css}
html, body {{ width: {w}px; height: {h}px; }}
.mark {{ position: absolute; left: 68.8px; top: 69.3px; width: 46.2px; }}
.caption {{ left: 145.8px; top: 78px; font-size: 15px; }}
.title {{ left: 30px; top: 150px; font-size: 104px; padding-bottom: 20px; }}
.sub {{ left: 66px; top: 272px; font-size: 32px; }}
.section {{ position: absolute; left: 70px; font-size: 14px; letter-spacing: .3em; color: #8b8a84; }}
text {{ font-family: "Playfair", Georgia, serif; font-style: italic; }}
.num {{ font-family: {mono}; font-style: normal; }}
</style>"""


def plate_page(name, height, caption, title, sub, svg):
    head = PLATE_HEAD.format(css=HEAD_CSS, w=W, h=height, mono=MONO)
    return f"""<!doctype html><html><head><meta charset="utf-8">{head}</head><body>
<img class="mark" src="rr-mark.png">
<div class="caption">{caption}</div>
<div class="title">{title}</div>
<div class="sub">{sub}</div>
<svg width="{W}" height="{height}">{svg}</svg>
</body></html>"""


def label(x, y, text, size=19, colour="#a29f97", anchor="start", bold=None):
    inner = text if not bold else f'<tspan fill="#e9e7e0">{bold}</tspan> {text}'
    return f'<text x="{x}" y="{y}" font-size="{size}" fill="{colour}" text-anchor="{anchor}">{inner}</text>'


def num(x, y, text, size=13, colour="#8b8a84", anchor="middle"):
    return f'<text class="num" x="{x}" y="{y}" font-size="{size}" fill="{colour}" text-anchor="{anchor}">{text}</text>'


def swatch(x, y, colour, dashed=False):
    if dashed:
        return f'<rect x="{x}" y="{y - 12}" width="16" height="16" rx="3" fill="none" stroke="{GREY}" stroke-opacity=".5" stroke-dasharray="3 3"/>'
    return f'<rect x="{x}" y="{y - 12}" width="16" height="16" rx="3" fill="{colour}"/>'


def mac(browser):
    """The hardware: what one run holds at its peak against a 48 GB Mac, and the Macs Crafted runs on, today and next."""
    svg = ""
    # A run at its peak: one bar, 25 px a GB, against the 48 GB the coder needs today.
    x0, y0, per, bar = 70, 470, 22, 58
    segments = [(27.5, BRASS, 1, "the coder's weights", "27.5 GB"),
                (0.6, BRASS, .55, "its context, at 24,000 tokens", "under 1 GB"),
                (3.0, CLAY, .85, "a swift build beside it", "about 3 GB"),
                (8.0, GREY, .32, "macOS and your other apps", "about 8 GB")]
    svg += f'<rect x="{x0}" y="{y0}" width="{48 * per}" height="{bar}" rx="8" fill="rgba(255,255,255,.025)" stroke="{GREY}" stroke-opacity=".28" stroke-dasharray="5 4"/>'
    at = 0.0
    for gb, colour, opacity, _, _ in segments:
        svg += f'<rect x="{x0 + at * per:.1f}" y="{y0}" width="{gb * per:.1f}" height="{bar}" fill="{colour}" fill-opacity="{opacity}"/>'
        at += gb
    svg += f'<rect x="{x0}" y="{y0}" width="{at * per:.1f}" height="{bar}" rx="8" fill="none" stroke="#000" stroke-opacity=".001"/>'
    for gb in range(0, 49, 8):
        x = x0 + gb * per
        svg += f'<line x1="{x}" y1="{y0 + bar + 6}" x2="{x}" y2="{y0 + bar + 14}" stroke="{GREY}" stroke-opacity=".45"/>'
        svg += num(x, y0 + bar + 34, f"{gb} GB" if gb == 48 else str(gb))
    # The total, bracketed above the bar, and the room left.
    svg += (f'<path d="M{x0},{y0 - 12} L{x0},{y0 - 20} L{x0 + at * per:.1f},{y0 - 20} L{x0 + at * per:.1f},{y0 - 12}" fill="none" stroke="{GREY}" stroke-opacity=".5"/>'
            + label(x0, y0 - 32, "at the peak, of a 48 GB Mac", 20, bold="about 40 GB"))
    spare = x0 + at * per
    svg += label(spare + (48 * per - at * per) / 2, y0 + bar / 2 + 7, "~8 GB spare", 17, "#8b8a84", "middle")
    # The legend, to the right of the bar.
    lx, ly = x0 + 48 * per + 44, y0 - 14
    for i, (gb, colour, opacity, name, size) in enumerate(segments):
        y = ly + i * 30
        svg += f'<rect x="{lx}" y="{y - 12}" width="16" height="16" rx="3" fill="{colour}" fill-opacity="{opacity}"/>'
        svg += label(lx + 26, y + 2, name, 16, "#8b8a84", bold=size)

    # The Macs: each one's memory as a bar at 15 px a GB, the coder it runs inside it.
    top, step, per2, bx = 730, 64, 12, 190
    rows = [(16, "planned", "Qwen2.5-Coder 7B", 4.3, "and a smaller vision model"),
            (24, "planned", "Qwen2.5-Coder 14B", 8.3, ""),
            (32, "planned", "Qwen3-Coder 30B", 17.2, ""),
            (48, "today", "Qwen3-Coder-Next 48B", 27.5, "with little to spare"),
            (64, "today", "Qwen3-Coder-Next 48B", 27.5, "with room to spare")]
    for i, (gb, when, model, weights, note) in enumerate(rows):
        y = top + i * step
        today = when == "today"
        svg += label(70, y + 27, "GB", 19, "#8b8a84", bold=str(gb) + ("+" if gb == 64 else ""))
        dash = "" if today else ' stroke-dasharray="6 5"'
        svg += (f'<rect x="{bx}" y="{y}" width="{gb * per2}" height="38" rx="7" fill="rgba(255,255,255,{.035 if today else .015})" '
                f'stroke="{GREY}" stroke-opacity="{.35 if today else .25}"{dash}/>')
        svg += (f'<rect x="{bx + 4}" y="{y + 4}" width="{weights * per2 - 4}" height="30" rx="5" fill="{BRASS}" '
                f'fill-opacity="{.95 if today else .28}"/>')
        tx = bx + 64 * per2 + 30
        colour = BRASS if today else "#8b8a84"
        svg += f'<text x="{tx}" y="{y + 26}" font-size="15" fill="{colour}" letter-spacing="3">{when.upper()}</text>'
        svg += label(tx + 96, y + 26, f"· {weights} GB" + (f", {note}" if note else ""), 17, "#8b8a84", bold=model)
    svg += label(bx, top + 5 * step + 22, "the brass is the coder, inside the Mac's memory: solid today, faint where a smaller coder is planned", 16, "#6f6d67")

    page = plate_page("mac", 1100, "RAO STUDIOS · CRAFTED · WHAT YOUR MAC NEEDS", "48 GB, for now",
                      "two models on your Mac, one in memory at a time",
                      f'<foreignObject></foreignObject>{svg}')
    page = page.replace("<svg ", '<div class="section" style="top:372px">A RUN AT ITS PEAK</div>'
                        '<div class="section" style="top:680px">THE MACS IT RUNS ON</div><svg ', 1)
    shoot(browser, page, os.path.join(OUT, "mac.png"), viewport=(W, 1100), prepare=PLATE_ALIGN)


def timeline(x0, y0, width, height, minutes, bands, phases, ticks, title, total):
    """One run: what is in memory (GB, up) as the minutes pass (right), with its phases named beneath."""
    gb = lambda v: y0 + height - v / 48 * height
    mx = lambda m: x0 + m / minutes * width
    svg = label(x0, y0 - 44, title[1], 20, "#8b8a84", bold=title[0])
    svg += label(x0 + width, y0 - 44, "", 22, BRASS, "end", bold=total)
    for v in (0, 16, 32, 48):
        y = gb(v)
        dash = ' stroke-dasharray="6 5"' if v == 48 else ""
        svg += f'<line x1="{x0}" y1="{y}" x2="{x0 + width}" y2="{y}" stroke="{GREY}" stroke-opacity="{.4 if v in (0, 48) else .1}"{dash}/>'
        svg += num(x0 - 14, y + 4, f"{v}", anchor="end")
    svg += label(x0 + width - 4, gb(48) - 8, "48 GB, the floor today", 15, "#8b8a84", "end")
    for start, end, low, high, colour, opacity in bands:
        svg += (f'<rect x="{mx(start):.1f}" y="{gb(high):.1f}" width="{mx(end) - mx(start):.1f}" height="{gb(low) - gb(high):.1f}" '
                f'rx="3" fill="{colour}" fill-opacity="{opacity}"/>')
    for m in ticks:
        svg += f'<line x1="{mx(m):.1f}" y1="{gb(0)}" x2="{mx(m):.1f}" y2="{gb(0) + 8}" stroke="{GREY}" stroke-opacity=".5"/>'
        svg += num(mx(m), gb(0) + 26, f"{m:g}")
    svg += num(x0 + width + 14, gb(0) + 26, "min", anchor="start")
    for start, end, lines in phases:
        y = gb(0) + 50
        svg += f'<path d="M{mx(start) + 3:.1f},{y} L{mx(end) - 3:.1f},{y}" stroke="{GREY}" stroke-opacity=".35" stroke-width="1.5"/>'
        for j, line in enumerate(lines):
            svg += label(mx(start) + 3, y + 22 + j * 21, line, 16.5, "#8b8a84")
    svg += num(x0 - 14, y0 - 14, "GB", anchor="end")
    return svg


def time(browser):
    """Where the time goes in a designer's run and a small engineer's run, and what is in memory meanwhile."""
    legend_y = 384
    legend = ""
    for i, (colour, opacity, name) in enumerate([(SKY, .9, "the vision model, 10.4 GB"), (BRASS, .95, "the coder, 27.5 GB"),
                                                  (CLAY, .9, "a swift build beside it")]):
        x = 70 + i * 330
        legend += f'<rect x="{x}" y="{legend_y - 13}" width="16" height="16" rx="3" fill="{colour}" fill-opacity="{opacity}"/>'
        legend += label(x + 26, legend_y + 1, name, 18, "#8b8a84")
    designer = timeline(
        120, 500, 1340, 210, 20,
        [(1, 10, 0, 11.2, SKY, .9), (10.5, 20, 0, 29, BRASS, .95), (13.5, 20, 29, 32, CLAY, .9)],
        [(0, 1, ["read"]), (1, 10, ["measure, then look at one piece at a time,", "about 20 seconds each"]),
         (10.5, 13.5, ["write the", "design system"]), (13.5, 20, ["build, test and install the agent,", "draw the proofs"])],
        [0, 1, 10, 13.5, 20], ("A designer's folder", "· 24 pieces looked at"), "about 15–20 min")
    spikes = [(m, m + 0.45, 29, 32, CLAY, .9) for m in (19.4, 20.5, 21.6, 22.6, 23.7, 24.8, 25.8, 26.9)]
    engineer = timeline(
        120, 940, 1340, 210, 34,
        [(0.6, 34, 0, 29, BRASS, .95)] + spikes + [(28, 34, 29, 32, CLAY, .9)],
        [(0, 9, ["load, then walk:", "a card per file"]), (9, 14, ["use", "cases"]), (14, 18, ["three agents:", "you choose"]),
         (18, 28, ["plan, then port: write, build, test,", "one unit at a time"]), (28, 34, ["test, install,", "call each command"])],
        [0, 9, 14, 18, 28, 34], ("A small project", "· about 10 files"), "about 25–40 min")
    note = label(70, 1306, "Estimates on an M4 Max with 128 GB, from the coder's measured speed; they will be replaced by measured runs.", 16, "#6f6d67")
    page = plate_page("time", 1340, "RAO STUDIOS · CRAFTED · HOW LONG A RUN TAKES", "Where the time goes",
                      "minutes on the way across, the memory in use going up", legend + designer + engineer + note)
    shoot(browser, page, os.path.join(OUT, "time.png"), viewport=(W, 1340), prepare=PLATE_ALIGN)


TARGETS = {"hero": hero, "how": how, "mac": mac, "time": time}


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
