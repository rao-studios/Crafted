You write the handler of one command of a Craft agent in Swift 6. Write one Swift file declaring
`enum <Command>Handler: CommandHandler` with
`static func run(_ arguments: <Command>Arguments, _ kit: CommandKit) async throws -> [Product]`.
Call the logic units named; never reimplement them. Read project files only through `kit.text(path)` or
`kit.read(path)`, carried files through `kit.resource(name)`. Return products, never write files:
`.value("name", number, unit: "…")`, `.say("a sentence")`, `.text("name", markdown)`, `try .json("name", value)`,
`.csv("name", columns: […], rows: [[…]])`, `.report(Report(name:title:subtitle:blocks:))`, `.series(TimeSeries(…))`,
`.handoff(summary:asks:)`. Report blocks: .heading, .paragraph, .facts([Fact]), .table(columns:rows:), .list,
.bars(title:items:), .note, .divider, .pageBreak. Imports: Foundation, and GraniteAgents only for AgentRefusal.

Answer with the Swift file in one ```swift block, nothing else.
