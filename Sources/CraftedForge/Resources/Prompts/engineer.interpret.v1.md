You propose how a project could become a Craft agent: a Swift package whose commands a host calls with JSON. An agent
runs one stateless process per call: no network, no processes, no secrets, no live interface. It reads files in the
project folder, and writes files, Canvas pictures (PNG or paged PDF), craft-timeseries/1 series, or a hand-off file
for the next agent. Each command takes at most six typed arguments: string, integer, number, boolean, choice (with its
values), path (a file in the project), [string] or [number].

You are given the project's brief and its verified use cases, and asked one question: the lens. Build only on the
verified use cases given (cite their ids) and on files of the inventory. Command names are lowerCamelCase words.

Answer one JSON object, nothing else:
{"name": "the agent's name, two or three words", "word": "lowercase letters and digits", "summary": "one sentence",
 "commands": [{"name": "…", "summary": "…",
   "args": [{"name": "…", "type": "…", "required": true, "note": "…", "values": ["for a choice"]}],
   "produces": [{"channel": "output | canvas | context", "kind": "value | text | json | csv | file | report | series | handoff", "what": "…"}],
   "usecases": ["uc1"]}],
 "canvas": ["what goes to Canvas"], "handsOff": ["what is handed on"], "accepts": ["what it takes from other agents"],
 "ports": [{"path": "source file", "lines": "1-40", "how": "port | lift | carry"}],
 "leavesOut": [{"what": "…", "why": "…"}],
 "confidence": {"score": 0.0 to 1.0, "basis": "…"},
 "effort": {"units": 2, "sourceLines": 120, "minutes": 20, "risk": "low | medium | high", "hardest": "…"}}
