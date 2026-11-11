import AppKit

enum MainMenu {
    /// One line of the app menu; nil title is a separator.
    struct AppItem {
        let title: String?
        let action: Selector?
        let key: String
        static let separator = AppItem(title: nil, action: nil, key: "")
    }

    /// The app menu, in order. About is the Settings page, not the standard panel, so the build is in one place.
    /// Models sits here, not on a window's menu: it is global, and reachable while the onboarding is up.
    static func appItems() -> [AppItem] {
        [
            AppItem(title: "About Crafted", action: #selector(AppDelegate.showAbout(_:)), key: ""),
            .separator,
            AppItem(title: "Settings…", action: #selector(AppDelegate.showSettings(_:)), key: ","),
            AppItem(title: "Models…", action: #selector(AppDelegate.showModels(_:)), key: "M"),
            .separator,
            AppItem(title: "Hide Crafted", action: #selector(NSApplication.hide(_:)), key: "h"),
            AppItem(title: "Quit Crafted", action: #selector(NSApplication.terminate(_:)), key: "q"),
        ]
    }

    static func install() {
        let main = NSMenu()

        let appItem = NSMenuItem()
        let appMenu = NSMenu()
        for item in appItems() {
            guard let title = item.title else { appMenu.addItem(.separator()); continue }
            appMenu.addItem(withTitle: title, action: item.action, keyEquivalent: item.key)
        }
        appItem.submenu = appMenu
        main.addItem(appItem)

        let fileItem = NSMenuItem()
        let fileMenu = NSMenu(title: "File")
        fileMenu.addItem(withTitle: "New Generation from Folder…", action: #selector(AppDelegate.newGeneration(_:)), keyEquivalent: "o")
        fileMenu.addItem(withTitle: "Library", action: #selector(AppDelegate.showLibrary(_:)), keyEquivalent: "l")
        fileMenu.addItem(.separator())
        fileMenu.addItem(withTitle: "Close", action: #selector(NSWindow.performClose(_:)), keyEquivalent: "w")
        fileItem.submenu = fileMenu
        main.addItem(fileItem)

        let editItem = NSMenuItem()
        let editMenu = NSMenu(title: "Edit")
        editMenu.addItem(withTitle: "Undo", action: Selector(("undo:")), keyEquivalent: "z")
        editMenu.addItem(withTitle: "Redo", action: Selector(("redo:")), keyEquivalent: "Z")
        editMenu.addItem(.separator())
        editMenu.addItem(withTitle: "Cut", action: #selector(NSText.cut(_:)), keyEquivalent: "x")
        editMenu.addItem(withTitle: "Copy", action: #selector(NSText.copy(_:)), keyEquivalent: "c")
        editMenu.addItem(withTitle: "Paste", action: #selector(NSText.paste(_:)), keyEquivalent: "v")
        editMenu.addItem(withTitle: "Select All", action: #selector(NSText.selectAll(_:)), keyEquivalent: "a")
        editItem.submenu = editMenu
        main.addItem(editItem)

        let windowItem = NSMenuItem()
        let windowMenu = NSMenu(title: "Window")
        windowMenu.addItem(withTitle: "Minimize", action: #selector(NSWindow.miniaturize(_:)), keyEquivalent: "m")
        windowMenu.addItem(withTitle: "Zoom", action: #selector(NSWindow.zoom(_:)), keyEquivalent: "")
        windowItem.submenu = windowMenu
        main.addItem(windowItem)
        NSApp.windowsMenu = windowMenu

        NSApp.mainMenu = main
    }
}
