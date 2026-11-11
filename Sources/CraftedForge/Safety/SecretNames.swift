//  WHAT: The file names that are never read, whatever is in them: environment files, private keys and keystores,
//        package-registry and cloud credentials, provisioning profiles, Terraform state, databases.
//  IN:   A path relative to the dropped folder (or to a package's root).
//  OUT:  The engineer walk and the designer inventory (a withheld file's verdict is "withheld: secret-name"), the
//        ship gate (a package carrying such a name does not ship).
//  PIN:  BY NAME, BEFORE ANY READ. A file is withheld on its path alone, so its bytes never reach a prompt, a cache
//        or a log. The content scan (SecretScan) is the second net, for secrets in ordinary files.

import Foundation

public enum SecretNames {
    /// Whether the file at `relativePath` is never read.
    public static func isWithheld(_ relativePath: String) -> Bool { reason(relativePath) != nil }

    /// What the name says the file is ("a private key"), or nil when it is an ordinary name.
    public static func reason(_ relativePath: String) -> String? {
        let parts = relativePath.split(separator: "/").map { $0.lowercased() }
        guard let name = parts.last else { return nil }
        if parts.contains(where: { privateFolders.contains($0) }) { return "a file in a credentials folder" }
        if parts.count >= 2, parts[parts.count - 2] == "config", name == "master.key" { return "a Rails master key" }
        if exactNames[name] != nil { return exactNames[name] }
        for (prefix, why) in prefixes where name.hasPrefix(prefix) { return why }
        let ext = (name as NSString).pathExtension
        if let why = extensions[ext] { return why }
        return nil
    }

    /// Folders whose whole content is credentials.
    static let privateFolders: Swift.Set<String> = [".aws", ".ssh", ".gnupg"]

    static let exactNames: [String: String] = [
        ".npmrc": "a package-registry credentials file",
        ".pypirc": "a package-registry credentials file",
        ".netrc": "a login credentials file",
        ".htpasswd": "a password file",
        "wp-config.php": "a WordPress configuration with database credentials",
        "googleservice-info.plist": "a Firebase configuration",
        "google-services.json": "a Firebase configuration",
    ]

    static let prefixes: [(String, String)] = [
        (".env", "an environment file"),
        ("id_rsa", "an SSH key"),
        ("id_ed25519", "an SSH key"),
        ("id_ecdsa", "an SSH key"),
        ("id_dsa", "an SSH key"),
        ("credentials", "a credentials file"),
        ("secrets.", "a secrets file"),
        ("terraform.tfstate", "Terraform state"),
    ]

    static let extensions: [String: String] = [
        "pem": "a private key or certificate",
        "key": "a private key",
        "p12": "a keystore",
        "pfx": "a keystore",
        "jks": "a keystore",
        "keystore": "a keystore",
        "mobileprovision": "a provisioning profile",
        "tfvars": "Terraform variables",
        "sqlite": "a database",
        "sqlite3": "a database",
        "db": "a database",
    ]
}
