import CoreGraphics

enum Radii {
    /// Answer tiles, word cards and text fields (rounded-2xl).
    static let tile: CGFloat = 16
    static let card: CGFloat = 20
    /// The feedback panel's top corners.
    static let hero: CGFloat = 24
    /// Bottom sheets' top corners.
    static let sheet: CGFloat = 28
    /// Buttons are fully rounded; kept for the few rectangles that sit beside them.
    static let primaryAction: CGFloat = 22
    /// Icon badges, day toggles, letter tiles, skill cells (rounded-xl).
    static let chip: CGFloat = 12
    static let field: CGFloat = 16
}
