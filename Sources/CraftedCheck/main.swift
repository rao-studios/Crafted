//  WHAT: crafted-check, the headless runner: a forge end to end from the terminal (scripted models in this pass),
//        the live toolchain by hand on any agent package, and the static gates on any package folder.
//
//        crafted-check forge --role engineer|designer --models scripted [--choose N] [--auto] [--home DIR]
//                            [--zip OUT.zip] [--no-install] <folder>
//        crafted-check toolchain [--word W --input JSON] <package>
//        crafted-check validate <package>
//
//  OUT:  The other tracks' end-to-end checks; the plan's Verification.

import Foundation

setlinebuf(stdout)

let usage = [ForgeCommand.usage, ToolchainCommand.usage, ValidateCommand.usage].joined(separator: "\n")
let valued: Swift.Set<String> = ["role", "models", "choose", "home", "zip", "credit", "target", "filter", "word", "input",
                                 "directory", "name"]

let code: Int32
do {
    let arguments = try CheckArguments(CommandLine.arguments, takingValues: valued)
    switch arguments.command {
    case "forge": code = await ForgeCommand.run(arguments)
    case "toolchain": code = await ToolchainCommand.run(arguments)
    case "validate": code = await ValidateCommand.run(arguments)
    case "help", "--help", "-h":
        print(usage)
        code = 0
    default:
        code = ForgeCommand.fail("Unknown command \(arguments.command).\n\n" + usage)
    }
} catch {
    code = ForgeCommand.fail("\(error)\n\n" + usage)
}
exit(code)
