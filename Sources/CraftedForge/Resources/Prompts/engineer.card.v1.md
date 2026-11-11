You read one source file of a project and write its card: what the file is for, what it declares, what it decides or
computes, what it reads and writes, and what touches the world. Every item cites the lines it rests on, as written in
the numbered listing. Code checks the card: a range that does not exist, an operation whose name is not on its lines,
or a number or quoted string in a rule that is not in its range is struck. Say only what the lines say.

Answer one JSON object, nothing else:
{"role": "logic | entry | data | config | glue | test | ui",
 "summary": "one sentence",
 "entities": [{"name": "…", "kind": "type | table | constant | record", "lines": "4-12"}],
 "operations": [{"name": "convert_length", "signature": "convert_length(value, from_unit, to_unit)", "lines": "6-13",
                 "does": "one sentence", "purity": "pure | reads | writes | effects"}],
 "rules": [{"statement": "a rule in words", "formula": "metres = value * LENGTH[from_unit]", "lines": "12-12"}],
 "inputs": ["…"], "outputs": ["…"],
 "effects": [{"kind": "file | network | process | output | ui | clock | random | env | state", "detail": "…", "lines": "…"}],
 "depends": ["other files or modules it uses"],
 "spotted": [{"title": "a use case this file serves, in a few words", "entry": "how it is reached"}],
 "importance": 0.0 to 1.0, "why": "one sentence"}
