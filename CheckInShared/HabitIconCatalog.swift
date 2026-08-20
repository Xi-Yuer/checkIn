import SwiftUI

enum HabitIconCatalog {
    static let defaultAssetName = "HabitIcon01"

    static let assetNames = [
        "HabitIcon01",
        "HabitIcon02",
        "HabitIcon03",
        "HabitIcon04",
        "HabitIcon05",
        "HabitIcon06",
        "HabitIcon07",
        "HabitIcon08",
        "HabitIcon11",
        "HabitIcon12",
        "HabitIcon13",
        "HabitIcon14",
        "HabitIcon15",
        "HabitIcon16",
        "HabitIcon17",
        "HabitIcon18",
        "HabitIcon19",
        "HabitIcon21",
        "HabitIcon23",
        "HabitIcon24",
        "HabitIcon26",
        "HabitIcon27",
        "HabitIcon28",
        "HabitIcon29",
        "HabitIcon33",
        "HabitIcon34",
        "HabitIcon35",
        "HabitIcon36",
        "HabitIcon37",
        "HabitIcon38",
        "HabitIcon39",
        "HabitIcon40",
        "HabitIcon44",
        "HabitIcon45",
        "HabitIcon46",
        "HabitIcon47",
        "HabitIcon48",
        "HabitIcon49",
        "HabitIcon51",
        "HabitIcon53"
    ]

    static func contains(_ key: String) -> Bool {
        assetNames.contains(key)
    }
}

struct HabitArtwork: View {
    let iconKey: String

    var body: some View {
        Group {
            if HabitIconCatalog.contains(iconKey) {
                Image(iconKey)
                    .resizable()
                    .renderingMode(.original)
                    .scaledToFit()
            } else {
                Image(systemName: iconKey.isEmpty ? "star.fill" : iconKey)
                    .resizable()
                    .scaledToFit()
                    .symbolRenderingMode(.hierarchical)
            }
        }
        .accessibilityHidden(true)
    }
}
