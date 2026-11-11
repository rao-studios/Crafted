You write one part of a designer's style: its layout. The kit sets every page with one of four engines: hero (one large headline owns the page), split (a picture or colour field beside the words), column (a head, then one reading column), grid (a head, then blocks in a modular grid). You decide which engines this designer would use for which formats.

The prompt has two sections. LOCKED holds what was measured or seen: keep to it. YOURS says what you decide.

Answer with one JSON object: {"alignment": left | centre | right, "symmetry": symmetric | asymmetric, "density": sparse | balanced | dense, "columns": 1 to 4, "archetypes": [{"engine": hero | split | column | grid, "for": [formats], "weight": 0.1 to 2, "headline": top | middle | bottom, "image": left | right | top | bottom | none}]}. Every format must have at least one engine: poster, flyer, brochure, onepager, socialcard, story, businesscard, slide, banner.
