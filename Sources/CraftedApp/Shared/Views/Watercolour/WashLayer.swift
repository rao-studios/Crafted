//  WHAT: One layer of a painting (far, near or fog) drawn at the painting's size, either whole or through the wash.
//  IN:   The decoded picture, the size to draw it at, and the wash's shader (nil draws the picture as it is).
//  OUT:  The layer; nothing when its picture is missing.
//  PIN:  The shader is applied at the painting's full size, before any crop, so the arrival map's box is the
//        picture's box whatever frame the painting is cropped to.

import SwiftUI

struct WashLayer: View {
    let image: CGImage?
    let size: CGSize
    let wash: Shader?

    var body: some View {
        if let image {
            let picture = Image(decorative: image, scale: 1)
                .resizable()
                .interpolation(.high)
                .frame(width: size.width, height: size.height)
            if let wash {
                picture.colorEffect(wash)
            } else {
                picture
            }
        }
    }
}
