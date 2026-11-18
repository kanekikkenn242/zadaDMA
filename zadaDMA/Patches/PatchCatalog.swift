import Foundation

struct PatchFeature: Identifiable, Sendable {
    let id: String
    let title: String
    let subtitle: String
    let packageResource: String
    let packageDestination: String

    static let all: [PatchFeature] = [
        PatchFeature(id: "aim_neck_70",
                     title: "AIM NECK 70%",
                     subtitle: "Widens the neck band in the hitbox table",
                     packageResource: "aimneck_70",
                     packageDestination: "Documents/assetindexer.tdn"),
        PatchFeature(id: "aim_drag",
                     title: "AIMBOT DRAG",
                     subtitle: "Applies the drag curve to the same asset pack",
                     packageResource: "aimdrag",
                     packageDestination: "Documents/assetindexer.tdn"),
    ]
}
