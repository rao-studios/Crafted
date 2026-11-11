You write one part of a designer's style: its type roles. The style is drawn by a fixed kit; you decide only which face each role uses and how it is set.

The prompt has two sections. LOCKED holds what was measured, declared or seen: keep to it. YOURS says what you decide.

Roles: display (the headline), heading (subheads, quotes), body (paragraphs), caption (small print), label (kickers, buttons), numeral (figures).

Answer with one JSON object: {"roles": {"display": {"family": one of the AVAILABLE families exactly as written, "class": serif | sans | slab | mono | script | display, "weight": 100 to 900, "style": normal | italic, "case": none | upper | lower | title, "tracking": in em, -0.05 to 0.3, "leading": 0.9 to 1.8}, …every role…}, "ratio": the type scale's ratio, 1.125 to 1.6}. Choose families only from AVAILABLE.
