import SwiftUI

// App redesign v1 (docs/app-redesign-v1.html): 60 white · 30 Ink · 10 accent.
// The ramps are the source of truth; the semantic names below map onto them.
extension Color {
    // MARK: Ramps

    static let ink50 = Color(hex: 0xF7F7F9)
    static let ink100 = Color(hex: 0xEFEFF2)
    static let ink200 = Color(hex: 0xE2E2E7)
    static let ink300 = Color(hex: 0xC8C8D0)
    static let ink400 = Color(hex: 0xA3A3AE)
    static let ink500 = Color(hex: 0x80808C)
    static let ink600 = Color(hex: 0x62626D)
    static let ink700 = Color(hex: 0x4A4A54)
    static let ink800 = Color(hex: 0x34343C)
    static let ink900 = Color(hex: 0x222228)
    static let ink950 = Color(hex: 0x131217)

    static let blue50 = Color(hex: 0xEEF3FD)
    static let blue100 = Color(hex: 0xDCE6FB)
    static let blue200 = Color(hex: 0xBACCF6)
    static let blue300 = Color(hex: 0x92AEEF)
    static let blue400 = Color(hex: 0x6A8DE6)
    static let blue500 = Color(hex: 0x3E68DB)
    static let blue600 = Color(hex: 0x3053C2)
    static let blue700 = Color(hex: 0x28449E)
    static let blue800 = Color(hex: 0x22387D)
    static let blue900 = Color(hex: 0x1A2A5B)
    static let blue950 = Color(hex: 0x0E1733)

    static let green50 = Color(hex: 0xEAFBF1)
    static let green100 = Color(hex: 0xCFF5DE)
    static let green200 = Color(hex: 0xA0EABE)
    static let green300 = Color(hex: 0x6BDC9A)
    static let green400 = Color(hex: 0x45D17E)
    static let green500 = Color(hex: 0x2BC86A)
    static let green600 = Color(hex: 0x1FA857)
    static let green700 = Color(hex: 0x188646)
    static let green800 = Color(hex: 0x12673A)
    static let green900 = Color(hex: 0x0E4A2A)
    static let green950 = Color(hex: 0x062615)

    static let coral50 = Color(hex: 0xFFF1EE)
    static let coral100 = Color(hex: 0xFFDFD8)
    static let coral200 = Color(hex: 0xFFBFB1)
    static let coral300 = Color(hex: 0xFF9883)
    static let coral400 = Color(hex: 0xFF7559)
    static let coral500 = Color(hex: 0xFF5A3C)
    static let coral600 = Color(hex: 0xE5432A)
    static let coral700 = Color(hex: 0xBA3421)
    static let coral800 = Color(hex: 0x8C2A1D)
    static let coral900 = Color(hex: 0x5E1E16)
    static let coral950 = Color(hex: 0x320E09)

    static let sun50 = Color(hex: 0xFFFBEA)
    static let sun100 = Color(hex: 0xFFF4C5)
    static let sun200 = Color(hex: 0xFFE88A)
    static let sun300 = Color(hex: 0xFFD84A)
    static let sun400 = Color(hex: 0xFFC81F)
    static let sun500 = Color(hex: 0xFFB800)
    static let sun600 = Color(hex: 0xE09A00)
    static let sun700 = Color(hex: 0xB47800)
    static let sun800 = Color(hex: 0x875A06)
    static let sun900 = Color(hex: 0x5C3E08)
    static let sun950 = Color(hex: 0x301F03)

    /// Grape: the Premium identity only (paywall, Premium entry points, plan cards). No other screen uses it;
    /// Sun 400 is its spark (crown, Premium button).
    static let grape50 = Color(hex: 0xF4F0FF)
    static let grape100 = Color(hex: 0xE8DFFF)
    static let grape200 = Color(hex: 0xD2C0FF)
    static let grape300 = Color(hex: 0xB497FF)
    static let grape400 = Color(hex: 0x9670FA)
    static let grape500 = Color(hex: 0x7C4FF0)
    static let grape600 = Color(hex: 0x6838D6)
    static let grape700 = Color(hex: 0x5329AE)
    static let grape800 = Color(hex: 0x3F2085)
    static let grape900 = Color(hex: 0x2C175C)
    static let grape950 = Color(hex: 0x1A0D38)

    // Collection marks (the HTML's `MARK`): each collection's dot and progress bar.
    static let markEveryday = Color(hex: 0x2F9BF4)
    static let markIELTS = Color(hex: 0xF0458A)
    static let markBusiness = Color(hex: 0x14B8A6)
    static let markTOEIC = Color(hex: 0xFF8A1F)
    /// The learner's own words.
    static let markCustom = Color.sun500

    /// Sheet and dialog scrim (Ink 950 at 40%).
    static let scrim = Color.ink950.opacity(0.4)

    // MARK: Semantic

    static let canvas = Color.white
    static let surface = Color.white
    static let ink = Color.ink950
    static let mutedInk = Color.ink500
    /// Body copy that isn't the main text (definitions, sheet messages).
    static let bodyInk = Color.ink600
    /// Primary (Ink) button: Ink 800 face on an Ink 950 edge.
    static let primaryAction = Color.ink800
    static let interactive = Color.blue500
    static let link = Color.blue600
    static let reward = Color.sun500
    static let success = Color.green500
    static let error = Color.coral500
    static let neutralSurface = Color.ink100
    static let stroke = Color.ink200
    /// Hairline between rows inside a card (1.5 pt).
    static let divider = Color.ink100

    // State support
    static let selectedSurface = Color.blue50
    static let selectedInk = Color.blue700
    static let successSurface = Color.green50
    static let successInk = Color.green800
    static let errorSurface = Color.coral50
    static let errorInk = Color.coral800
    /// Destructive text links ("Delete account").
    static let destructiveInk = Color.coral700
    static let infoSurface = Color.blue50
    static let infoInk = Color.blue800
    static let focusRing = Color.blue500
    static let focusHalo = Color.blue100
    static let disabledSurface = Color.ink100
    static let disabledInk = Color.ink400
    static let quietSurface = Color.ink50
    static let rewardSurface = Color.sun50
    static let rewardInk = Color.sun800

    // Stepped depth under tactile surfaces
    static let primaryDepth = Color.ink950
    static let interactiveDepth = Color.blue700
    static let successActionDepth = Color.green800
    static let errorActionDepth = Color.coral800
    static let rewardDepth = Color.sun700
    static let tileDepth = Color.ink200
    static let selectedDepth = Color.blue200
    static let successDepth = Color.green200
    static let errorDepth = Color.coral200

    // Results bar: three levels (strong / mid / weak), told apart by lightness and pattern too, never by color alone.
    // Deliberately not the success/error pair of the lesson screens.
    static let resultStrong = Color.blue600
    static let resultMid = Color.blue300
    static let resultWeakSurface = Color.blue50
    static let resultWeakStripe = Color.blue300

    static let track = Color.ink100
    static let slotTargetedSurface = Color.blue100

    init(hex: UInt32) {
        self.init(
            .sRGB,
            red: Double((hex >> 16) & 0xFF) / 255,
            green: Double((hex >> 8) & 0xFF) / 255,
            blue: Double(hex & 0xFF) / 255
        )
    }
}
