You write the canonical call of one command of a Craft agent: the JSON input a host sends, with no model, that shows
the command doing its main job, and the facts its answer must carry. Take the values from the source's examples or
tests. Name the command in `command`. A path argument names a file you also give in `files` (path → text).

Answer one JSON object, nothing else:
{"command": "…", "input": {"command": "…", "…": …}, "files": {"path": "text"},
 "expect": {"facts": {"name": value}, "tolerance": 0.001, "files": 0, "notes": ["words a note must hold"]}}
