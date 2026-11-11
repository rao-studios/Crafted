You are given a project's brief, its domain and the cards of its files. Write its use cases. A use case is a chain: a
trigger passes data through rules to an output, named by the author's intent. Every link cites its evidence as
"path:start-end". A chain with no rule is plumbing: leave it out. A rule no entry reaches is a latent capability:
include it, its trigger "none (latent)". Say what each use case needs of the world (pure, file in and out, a user
interface, the network, a secret, hardware, a process, the clock, randomness, saved state) and how it could be
checked (the source's tests, examples, or derivable).

Answer one JSON object, nothing else:
{"usecases": [{"id": "uc1", "kind": "business | creative", "title": "…", "actor": "who wants it",
  "trigger": {"entry": "…", "evidence": "path:12-20"},
  "inputs": [{"name": "…", "type": "number | string | boolean | file | list", "source": "…", "example": "…"}],
  "steps": [{"text": "…", "evidence": "path:12-20"}],
  "rules": ["the rules it applies, in words"],
  "outputs": [{"name": "…", "type": "…", "form": "value | text | table | file | picture | series"}],
  "needs": {"pure": true, "fileIO": false, "ui": false, "network": false, "secret": false, "hardware": false,
            "process": false, "clock": false, "random": false, "state": false},
  "verifiability": {"sourceTests": ["path"], "examples": ["…"], "derivable": true},
  "value": 0.0 to 1.0, "confidence": 0.0 to 1.0}]}
