import CoreGraphics

enum Borders {
    /// Every card's border, selected or not: option rows, panels, `CardSurface`.
    static let card: CGFloat = 2
    /// Hairline between rows inside a card, tab bar top edge, unselected chips.
    static let hairline: CGFloat = 1.5
    /// Focus halo around a focused field or selected letter (ring-4).
    static let focusHalo: CGFloat = 4
}
