//  WHAT: The secret, privacy and name scans: each provider shape is found, its line named and never its value,
//        redaction replaces only the secret, and the look-alikes a package is full of (revisions, hashes, paths,
//        identifiers, example addresses) are left alone.

@testable import CraftedForge
import XCTest

final class SecretScanTests: XCTestCase {
    // Built from pieces so this file never holds a whole key shape itself.
    let aws = "AKIA" + "QWERTYUIOPASDFGH"
    let github = "ghp_" + "aB3dE5fG7hJ9kL1mN3pQ5rS7tU9vW1xY3zA5"
    let stripe = "sk_live_" + "4eC39HqLyjWDarjtT1zdp7dc"
    let google = "AIza" + "SyD3x4mpl3K3yV4lu3Th4tL00ksR34l12ab"
    let anthropic = "sk-ant-" + "api03-Zx9Qw8Er7Ty6Ui5Op4As3Df2Gh1Jk0"
    let openai = "sk-proj-" + "Ab12Cd34Ef56Gh78Ij90Kl12Mn34"
    let slack = "xoxb-" + "1234567890-0987654321-AbCdEfGhIjKl"
    let jwt = "eyJhbGciOiJIUzI1NiJ9" + ".eyJzdWIiOiIxMjM0NTY3ODkwIn0" + ".dozjgNryP4J3jVmNHl0w5N_XgL0n3I9PlFUP0THsR8U"

    func testProviderShapesAreFoundWithTheirLine() {
        let text = """
        line one
        let a = "\(aws)"
        token=\(github)
        STRIPE: \(stripe)
        google \(google)
        anthropic \(anthropic)
        openai \(openai)
        slack \(slack)
        jwt \(jwt)
        """
        let hits = SecretScan.hits(in: text, path: "Sources/App/Config.swift")
        let whats = Dictionary(hits.map { ($0.line, $0.what) }, uniquingKeysWith: { first, _ in first })
        XCTAssertEqual(whats[2], "an AWS access key")
        XCTAssertEqual(whats[3], "a GitHub token")
        XCTAssertEqual(whats[4], "a Stripe secret key")
        XCTAssertEqual(whats[5], "a Google API key")
        XCTAssertEqual(whats[6], "an Anthropic API key")
        XCTAssertEqual(whats[7], "an OpenAI API key")
        XCTAssertEqual(whats[8], "a Slack token")
        XCTAssertEqual(whats[9], "a JSON Web Token")
        XCTAssertEqual(hits.count, 8)
    }

    func testFindingsNameFileAndLineNeverTheValue() {
        let findings = SecretScan.findings(in: "x\nkey = \"\(aws)\"\n", path: "app.py")
        XCTAssertEqual(findings.count, 1)
        XCTAssertEqual(findings[0].kind, .secret)
        XCTAssertEqual(findings[0].path, "app.py")
        XCTAssertTrue(findings[0].text.contains("app.py:2"), findings[0].text)
        XCTAssertFalse(findings[0].text.contains(aws))
    }

    func testPrivateKeyBlockConnectionStringsAndAssignments() {
        let body = String(repeating: "MIIEvQIBADANBgkqhkiG9w0BAQEFAASC", count: 3)
        let pem = "-----BEGIN RSA PRIVATE KEY-----\n\(body)\n-----END RSA PRIVATE KEY-----"
        XCTAssertEqual(SecretScan.hits(in: pem).first?.what, "a private key")
        // A parser naming the header is not a key.
        XCTAssertTrue(SecretScan.hits(in: #"let header = "-----BEGIN PRIVATE KEY-----""#).isEmpty)

        let url = "DATABASE = \"postgres://admin:Hunter2Secret@db.internal:5432/app\""
        let redacted = SecretScan.redact(url)
        XCTAssertEqual(redacted, "DATABASE = \"postgres://admin:[REDACTED]@db.internal:5432/app\"")

        let assigned = SecretScan.hits(in: #"let apiKey: String = "q8Vz2LmN4pRt7XwY""#)
        XCTAssertEqual(assigned.first?.what, "a secret assigned to apiKey")
        let env = SecretScan.hits(in: "export SERVICE_TOKEN=Zq81mVn3Kp0sLr7T\n")
        XCTAssertEqual(env.first?.what, "a secret assigned to SERVICE_TOKEN")
        let random = "blob: " + "Zm9vYmFyQmF6UXV4MTIzNDU2Nzg5MGFiY2RlZmdoaWprbG1ub3A"
        XCTAssertEqual(SecretScan.hits(in: random).first?.what, "a long random string, likely a key")
    }

    func testRedactKeepsEverythingElse() {
        let text = "a \(aws) b \(github) c"
        XCTAssertEqual(SecretScan.redact(text), "a [REDACTED] b [REDACTED] c")
        XCTAssertEqual(SecretScan.redact("nothing here"), "nothing here")
    }

    func testLookAlikesAreNotSecrets() {
        let text = """
        "revision" : "8f3c1a6b0e2d4f5a6b7c8d9e0f1a2b3c4d5e6f70",
        "originHash" : "e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855",
        let id = "6F9619FF-8B86-D011-B42D-00C04FC964FF"
        let tokenKind = "identifierToken"
        let passwordHint = "Use at least twelve characters"
        let apiKey = "YOUR_API_KEY_HERE_PLEASE"
        let tokenURL = "https://api.example.com/v1/token"
        static let word = "invoicetotals"
        func testConvertsCelsiusToFahrenheitWithinTolerance() {}
        func testTheHolidaysOf2026AreTheExchanges() {}
        "model": "Qwen3-Coder-Next-REAP-48B-A3B-mlx-4bit",
        case totp2faToken = "totp_2fa_token"
        static let model = Data(base64Encoded: "CAEShQEKEQoFaW1hZ2UaCCIGCAgQCBgUUg0KBXByb2JzGgQyAhIAUhAKCmNsYXNz")
        import Sources/InvoiceTotalsCore/Logic/TaxRules
        url(data:font/woff2;base64,d09GMgABAAAAAAhcAA0AAAAAEUwAAAgGAAEAAAAAAAAAAAAAAAAAAAAAAAAAAAAAGhYbHhyBHAZgAEQRCAqQXI0BATYCJAMgCxIABCAFgwQHIBtx)
        password = "\(SecretScan.placeholder)"
        """
        let hits = SecretScan.hits(in: text)
        XCTAssertTrue(hits.isEmpty, hits.map { "\($0.line): \($0.what)" }.joined(separator: "; "))
    }

    func testSecretNames() {
        for withheld in [".env", ".env.local", "config/.env.production", "certs/server.pem", "deploy.key", "id_rsa", "id_ed25519.pub",
                         ".npmrc", ".pypirc", ".netrc", "credentials.json", "secrets.yml", "app.mobileprovision",
                         "GoogleService-Info.plist", "google-services.json", "prod.tfvars", "terraform.tfstate.backup",
                         ".htpasswd", "wp-config.php", "config/master.key", "home/.aws/config", ".ssh/known_hosts",
                         ".gnupg/pubring.kbx", "data/app.sqlite", "cache.db", "release.keystore", "upload.jks", "cert.p12", "cert.pfx"] {
            XCTAssertTrue(SecretNames.isWithheld(withheld), withheld)
        }
        for ordinary in ["README.md", "src/env.py", "Sources/App/Keys.swift", "environment.md", "secret_santa.py", "docs/credential-guide",
                         "tokens.css", "Package.swift"] {
            XCTAssertFalse(SecretNames.isWithheld(ordinary), ordinary)
        }
    }

    func testPrivacyScan() {
        let home = PrivacyScan.findings(in: "let root = \"/Users/ada/Documents/x\"", path: "Sources/App/Paths.swift")
        XCTAssertEqual(home.count, 1)
        XCTAssertFalse(home.first?.text.contains("ada") ?? true, "a finding never repeats the name")
        XCTAssertTrue(PrivacyScan.findings(in: "cd /Users/Shared/tmp", path: "Sources/App/A.swift").isEmpty)
        XCTAssertTrue(PrivacyScan.findings(in: "see https://github.com/home/about/", path: "Sources/App/A.swift").isEmpty)

        // Emails and phones count in resources, not in code or root documents.
        let data = "name,email,phone\nAda,ada@lovelace.dev,(415) 555-0134\nBob,bob@example.com,2026-11-10\n"
        let hits = PrivacyScan.hits(in: data, path: "Sources/AppCore/Resources/people.csv")
        XCTAssertEqual(hits.map(\.what), ["an email address", "a phone number"])
        XCTAssertTrue(PrivacyScan.hits(in: data, path: "README.md").isEmpty)
        XCTAssertTrue(PrivacyScan.hits(in: data, path: "Sources/AppKit/Resources/Fonts/OFL-LICENSE.txt").isEmpty)
        XCTAssertTrue(PrivacyScan.hits(in: "icon@2x.png git@github.com:org/repo.git", path: "Assets/notes.txt").isEmpty)
        XCTAssertEqual(PrivacyScan.redact("at /Users/ada/x", path: "a.swift"), "at ~/x")
    }

    func testShipGateFailsOnASecretAndPassesAClean() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("shipgate-\(UUID().uuidString)")
        defer { try? FileManager.default.removeItem(at: root) }
        let source = root.appendingPathComponent("Sources/DemoAgent")
        try FileManager.default.createDirectory(at: source, withIntermediateDirectories: true)
        try "MIT License\n\nCopyright".write(to: root.appendingPathComponent("LICENSE"), atomically: true, encoding: .utf8)
        try "let x = 1\n".write(to: source.appendingPathComponent("A.swift"), atomically: true, encoding: .utf8)
        // A secret under .build never ships, so it does not fail the gate.
        let build = root.appendingPathComponent(".build")
        try FileManager.default.createDirectory(at: build, withIntermediateDirectories: true)
        try "k = \(aws)".write(to: build.appendingPathComponent("log.txt"), atomically: true, encoding: .utf8)
        XCTAssertTrue(ShipGate.check(package: root).passed)

        try "let k = \"\(aws)\"\n".write(to: source.appendingPathComponent("B.swift"), atomically: true, encoding: .utf8)
        try "// SPDX-License-Identifier: GPL-3.0-or-later\n".write(to: source.appendingPathComponent("C.swift"), atomically: true, encoding: .utf8)
        try "x".write(to: root.appendingPathComponent("credentials.json"), atomically: true, encoding: .utf8)
        let gate = ShipGate.check(package: root)
        XCTAssertFalse(gate.passed)
        let detail = gate.detail.joined(separator: "\n")
        XCTAssertTrue(detail.contains("Sources/DemoAgent/B.swift:1"), detail)
        XCTAssertTrue(detail.contains("GPL notice"), detail)
        XCTAssertTrue(detail.contains("credentials.json"), detail)
        XCTAssertFalse(detail.contains(aws))
    }
}
