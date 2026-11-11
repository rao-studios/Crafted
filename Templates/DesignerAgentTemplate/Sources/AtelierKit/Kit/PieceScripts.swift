import Foundation

/// What the page does in WebKit: grow, fit, then measure.
///
/// `grow` raises the whole page's type (`--grow`, every size is a multiple of it) as far as the style's ceiling while
/// nothing overflows, so a short piece fills its page instead of sitting in a corner of it. `fit` then shrinks a zone's type (`--fit`, every size in the zone is a multiple of it) a step at a time while what it
/// holds runs past its box, down to `floor`; zones are walked together until none overflows or none can shrink.
/// `measure` answers what still overflows (a zone too tall, a block too wide), what lies past the page, each zone's
/// fit, and the computed face and colour of the page's parts, for the tests to hold to the style.
///
/// PIN: THE KIT FITS BEFORE THE MODEL CUTS. A model told its headline overflowed rewrites it, often worse; the kit
/// sets it smaller first and the model hears only what no size within the floor can hold.
public enum PieceScripts {
    public static let floor = 0.68

    public static let script = """
    <script>
    window.__piece = {
      floor: \(floor),
      zones() { return [...document.querySelectorAll('[data-zone]')]; },
      over(z) {
        if (z.scrollHeight > z.clientHeight + 1) return true;
        for (const b of z.querySelectorAll('.blk')) if (b.scrollWidth > b.clientWidth + 1) return true;
        return false;
      },
      fitOf(z) { return parseFloat(z.style.getPropertyValue('--fit') || '1'); },
      anyOver() { return this.zones().some((z) => this.over(z)); },
      async grow(ceiling) {
        await document.fonts.ready;
        const root = document.documentElement, set = (g) => root.style.setProperty('--grow', String(g));
        set(1);
        if (this.anyOver() || ceiling <= 1) return 1;
        let lo = 1, hi = ceiling;
        set(hi);
        if (!this.anyOver()) return hi;
        for (let i = 0; i < 8; i++) { const mid = (lo + hi) / 2; set(mid); if (this.anyOver()) hi = mid; else lo = mid; }
        const kept = Math.max(1, Math.floor(lo * 0.97 * 1000) / 1000);
        set(kept);
        return kept;
      },
      async fit() {
        await document.fonts.ready;
        const zones = this.zones();
        for (let pass = 0; pass < 80; pass++) {
          const over = zones.filter((z) => this.over(z));
          if (!over.length) break;
          let moved = false;
          for (const z of over) {
            const f = this.fitOf(z);
            if (f > this.floor + 0.001) { z.style.setProperty('--fit', String(Math.max(this.floor, Math.round((f - 0.03) * 100) / 100))); moved = true; }
          }
          if (!moved) break;
        }
        return true;
      },
      measure() {
        const page = document.querySelector('.page');
        const pr = page.getBoundingClientRect();
        const overflow = [], outside = [], fits = {};
        for (const z of this.zones()) {
          const key = z.dataset.page + ':' + z.dataset.zone;
          fits[key] = this.fitOf(z);
          if (z.scrollHeight > z.clientHeight + 1) {
            const blocks = [...z.querySelectorAll('[data-block]')].map((b) => ({id: b.dataset.block, chars: (b.textContent || '').trim().length}));
            overflow.push({zone: z.dataset.zone, page: +z.dataset.page, axis: 'height', block: '', scroll: z.scrollHeight, client: z.clientHeight, blocks});
          }
          for (const b of z.querySelectorAll('.blk')) {
            if (b.scrollWidth > b.clientWidth + 1) overflow.push({zone: z.dataset.zone, page: +z.dataset.page, axis: 'width', block: b.dataset.block || '', scroll: b.scrollWidth, client: b.clientWidth, blocks: []});
          }
        }
        for (const el of document.querySelectorAll('[data-block], .colophon, .mark')) {
          const r = el.getBoundingClientRect();
          if (r.width <= 0 || r.height <= 0) continue;
          if (r.left < pr.left - 1 || r.top < pr.top - 1 || r.right > pr.right + 1 || r.bottom > pr.bottom + 1)
            outside.push({id: el.dataset.block || el.dataset.id || '', left: Math.round(r.left), top: Math.round(r.top), right: Math.round(r.right), bottom: Math.round(r.bottom)});
        }
        const probe = (selector) => {
          const el = document.querySelector(selector);
          if (!el) return null;
          const cs = getComputedStyle(el);
          return {family: cs.fontFamily, colour: cs.color, background: cs.backgroundColor, size: parseFloat(cs.fontSize), weight: cs.fontWeight};
        };
        const probes = {};
        for (const [name, selector] of [['page', '.page'], ['headline', '.b-headline'], ['body', '.b-body'], ['lead', '.b-lead'], ['kicker', '.b-kicker'],
                                        ['subhead', '.b-subhead'], ['footer', '.b-footer'], ['colophon', '.colophon']]) {
          const found = probe(selector);
          if (found) probes[name] = found;
        }
        const loaded = [...document.fonts].filter((f) => f.status === 'loaded').map((f) => f.family.replace(/"/g, ''));
        const grow = parseFloat(document.documentElement.style.getPropertyValue('--grow') || '1');
        return JSON.stringify({width: Math.round(pr.width), height: Math.round(pr.height), grow, overflow, outside, fits, probes, loaded});
      }
    };
    </script>
    """
}
