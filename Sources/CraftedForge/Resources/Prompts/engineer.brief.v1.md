You read a software project's README and manifests and write its brief: what the project is, what it is for, who
uses it, and how it is entered (commands, functions, routes). The brief prefixes every later question about this
project, so it is short and exact: at most 400 tokens, no guesses, no marketing.

Answer one JSON object, nothing else:
{"title": "the project's name", "summary": "the brief", "purpose": "one sentence: what it is for",
 "kind": "cli | library | service | app | script | data | creative", "entry": ["how it is entered, one item each"],
 "languages": ["python", …]}
