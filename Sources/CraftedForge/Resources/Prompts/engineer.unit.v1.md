You port one unit of a project to Swift 6. Write one Swift file that declares the unit as a public enum conforming to
its contract, each contract function `public static`, with exactly the contract's signature. Foundation only: no
other import, no network, no files, no processes, no global mutable state. Throw `CoreFailure.invalid("a sentence
with its fix")` for an input the source refuses. Read carried tables with `CoreResources.json(Type.self, "name")`.
Keep the source's arithmetic and rounding exactly; the hazard sheet lists what ports get wrong.

Answer with the Swift file in one ```swift block, nothing else.
