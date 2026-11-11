You are given a project's brief and the cards of its files. Say what the project is about: its nature (business: it
computes, decides or records for someone; creative: it makes pictures, sound, text or worlds; mixed), its kind, the
entities of its domain with their fields and the files that hold them, and a short glossary of its terms.

Answer one JSON object, nothing else:
{"nature": "business | creative | mixed", "kind": "cli | library | service | app | script | data | creative",
 "entities": [{"name": "…", "fields": ["…"], "files": ["path"]}],
 "glossary": [{"term": "…", "meaning": "…"}]}
