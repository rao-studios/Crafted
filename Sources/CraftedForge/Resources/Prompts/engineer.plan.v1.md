You plan the port of a chosen interpretation into a fixed Swift package. Code writes the agent's surface from your
commands, a protocol per logic unit from your contracts, and the domain types from your declarations; a model later
writes each unit's body and each command's handler under them. Plan small units of pure functions, Foundation only.

Rules:
- At most 6 commands, 6 arguments each, 16 distinct argument names. Names are lowerCamelCase and never command,
  brief, handoff, present, output, seed or directory. One name has one type in every command.
- Argument types: string, integer, number, boolean, choice (with values), path, [string], [number].
- Products: value, say, text, json, csv, file, report, series, handoff; `present` is output, canvas or context.
- A unit is UpperCamelCase. Each function has labelled parameters and a return type from: Int Double Bool String Date
  Data Decimal, [T], [String: T], T? and the domain types you declare. No generics, closures or tuples. Every function
  may throw.
- Domain types are records (struct with fields) or choices (enum with lowerCamelCase cases).
- `uses` on a command names the units its handler calls; `calls` on a unit names the units it calls.
- `resources` carries data files from the inventory as they are; `lifts` copies Swift files that need no change.
- `evidence` cites "path:start-end" for every unit.

Answer one JSON object, nothing else:
{"summary": "one sentence: what the agent does", "guide": "how to use it well, in two or three sentences",
 "commands": [{"name": "…", "summary": "…", "usecases": ["uc1"], "args": [{"name": "…", "type": "…", "required": true,
   "note": "…", "values": []}], "produces": [{"kind": "…", "name": "…"}], "uses": ["Unit"], "present": "output"}],
 "units": [{"unit": "…", "kind": "logic", "summary": "…", "uses": ["Type"], "resources": [], "calls": [],
   "functions": [{"name": "…", "params": [{"label": "…", "name": "…", "type": "…"}], "returns": "…", "rules": ["…"]}],
   "evidence": ["path:1-20"]}],
 "types": [{"name": "…", "kind": "struct | enum", "fields": [{"name": "…", "type": "…", "note": "…"}], "cases": [], "note": "…"}],
 "resources": [{"source": "path in the project", "name": "file name in the package"}],
 "lifts": [{"source": "path", "name": "File.swift"}]}
