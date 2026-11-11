# Skeleton Template

The frame every engineer agent Crafted makes is built in: a Granite agent package whose wiring, router, emitters and
report kit are fixed, whose surface is generated from a port's `commands.json`, and whose logic and handlers are the
port's. It ships with a small sample port, a tip calculator, so it builds and its tests pass as it stands.

```
$skeletonword tip: bill 50, service great
$skeletonword split: bill 84.5, people 3, percent 20
```

## Layout

- `Sources/SkeletonCore`: the logic, Foundation only. `Contracts/` and `Domain/` are generated; `Logic/` holds the
  port's units; `Lifted/` holds Swift files taken as they were; `Resources/` the tables the logic reads, found by
  `CoreResources` (never `Bundle.module`).
- `Sources/SkeletonAgent`: the agent. `Surface/` is generated (the command enum, the flat input, an arguments struct
  per command, the dispatch table, the summary, fields, guide and what it makes); `Handlers/` holds the port's
  handlers; the rest is fixed: `Run/` (router, interpreter, `CommandKit`), `Products/`, `Emit/` (output, canvas,
  context), `ReportKit/` and `Render/` (reports drawn by WebKit to PNG or paged PDF), `Upstream/` (`crafted-handoff/1`).
- `Tests/SkeletonCoreTests`: every unit's vectors, called from JSON (`Vectors/`, `Generated/VectorCalls.swift`).
- `Tests/SkeletonAgentTests`: the record, the schema, every command's canonical call (`Calls/`), the interpreter, a
  hand-off written and read back, and one render of the report kit.

`template.json` names the identity tokens the assembler replaces and the folders it places byte for byte.

## Requirements

- macOS 26 or later; Swift 6.
- MIT licensed.
