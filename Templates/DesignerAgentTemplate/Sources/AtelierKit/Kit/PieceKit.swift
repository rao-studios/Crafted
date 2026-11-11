//  WHAT: A page of a piece as one HTML document: the style's CSS, the engine's zones and blocks, the motif layers under
//        them, the designer's mark in its corner, the colophon in the margin, and the script that fits and measures.
//  OUT:  PieceRenderer (loads it in WebKit); `PIECE_HTML=<folder>` keeps each round's page to open in a browser.
//  PIN:  THE PAGE FETCHES NOTHING. Faces, the mark, motifs and pictures ride in it as data URLs, so a page draws the same
//        on any Mac and offline.

import Foundation

public enum PieceKit {
    public static func page(_ context: EngineContext, archetype: Archetype, theme: PieceTheme, colophon: Bool) -> String {
        let book = context.book
        let css = StyleCSS.css(book, format: context.format, size: context.size, theme: theme) + "\n" + archetype.engine.css + "\n" + MotifCSS.dividerCSS(book)
        let body = archetype.engine.body(context)
        var mark = ""
        if let data = book.mark, let placement = book.style.mark?.placement, placement != "none", context.page.first(.logo) == nil {
            let corner = ["top-left", "top-right", "bottom-left", "bottom-right"].contains(placement) ? placement : "top-right"
            mark = "<img class=\"mark \(corner)\" data-id=\"mark\" src=\"\(data)\" alt=\"\">"
        }
        var credit = ""
        if colophon {
            let side = colophonSide(context, archetype: archetype, mark: book.style.mark?.placement)
            credit = "<div class=\"colophon \(side)\" data-id=\"colophon\">\(PieceHTML.escape(book.style.colophon))</div>"
        }
        return """
        <!doctype html><html lang="en" data-theme="\(theme.rawValue)"><head><meta charset="utf-8"><style>
        \(css)
        </style></head><body><main class="page e-\(archetype.rawValue)" data-id="page">\(MotifCSS.layers(book))\(body)\(mark)\(credit)</main>
        \(PieceScripts.script)
        </body></html>
        """
    }

    /// The colophon's side: the words' side of a split, and away from the mark when it sits at the foot.
    static func colophonSide(_ context: EngineContext, archetype: Archetype, mark: String?) -> String {
        if archetype == .split, context.size.width >= context.size.height, SplitEngine.mediaSide(context) == "right" { return "left" }
        if mark == "bottom-right" { return "left" }
        return "right"
    }
}
