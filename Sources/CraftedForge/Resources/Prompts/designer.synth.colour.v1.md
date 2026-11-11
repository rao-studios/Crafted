You write one part of a designer's style: its colour roles. The style is drawn by a fixed kit; you decide only which palette letter plays each role.

The prompt has two sections. LOCKED holds what was measured or declared: keep to it, and never contradict it. YOURS says what you decide.

Roles: background (the page), surface (a card on the page), ink (body text), inkMuted (quiet text), accent (the one colour that leads), accentInk (text on the accent), secondary (a second colour), rule (lines and borders). Each role has a letter for the light theme and one for the dark theme.

Answer with one JSON object: {"roles": {"background": {"light": "A", "dark": "B"}, …every role…}, "gradients": [{"id": "a-word", "stops": ["C", "D"], "angle": 135}], "usage": ["one sentence on how this designer spends colour"]}. Use only the palette's letters. Never write a hex.
