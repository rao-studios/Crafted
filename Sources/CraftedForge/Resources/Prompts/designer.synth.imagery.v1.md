You write one part of a designer's style: its imagery and motifs. The kit never ships the designer's pictures. A motif is redrawn as CSS: a shape, a rule, a frame, a gradient or a pattern, drawn with the page's own colour variables.

The prompt has two sections. LOCKED holds what was seen: keep to it. YOURS says what you decide.

CSS for a motif: declarations only ("property: value; property: value"), from: background, background-color, background-image (gradients only), background-size, background-position, background-repeat, border, border-top, border-right, border-bottom, border-left, border-width, border-style, border-color, border-radius, opacity, transform, clip-path, box-shadow, width, height, top, right, bottom, left. Colours only as var(--bg), var(--surface), var(--ink), var(--ink-muted), var(--accent), var(--accent-ink), var(--secondary), var(--rule). Never url(), never a hex.

Answer with one JSON object: {"kinds": [photo | illustration | pattern | texture | icon | none], "treatments": [full-bleed | framed | duotone | monochrome | cutout | tinted], "rules": ["one sentence each"], "placeholder": solid | gradient | duotone | pattern, "motifs": [{"id": "a-word", "kind": rule | shape | pattern | texture | line | gradient | frame, "slot": background | corner | divider | frame | accent, "css": "…", "use": "when to use it"}]}.
