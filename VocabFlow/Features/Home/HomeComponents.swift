import SwiftUI

// Pieces shared by Home and My Words (docs/app-redesign-v1.html, frames 1.1 and 2.x).

/// Each collection's mark colour (the HTML's `MARK`): its dot and every progress bar of it.
/// The backend has no colours, so a collection is recognised by its slug (or id/name), then by its icon.
/// Words the learner added use Sun 500.
enum CollectionMarkColor {
    /// The learner's own words.
    static let custom = Color.markCustom

    static func color(for collection: VocabCollection) -> Color {
        // By slug first: backend slugs ("business-work") needn't match the bundled ids that give the icon.
        let key = [collection.slug, collection.id, collection.name].compactMap { $0 }.joined(separator: " ").lowercased()
        if key.contains("everyday") { return .markEveryday }
        if key.contains("ielts") { return .markIELTS }
        if key.contains("business") { return .markBusiness }
        if key.contains("toeic") { return .markTOEIC }
        switch collection.systemImage {
        case "sun.max": return .markEveryday
        case "graduationcap": return .markIELTS
        case "briefcase": return .markBusiness
        case "checkmark.seal": return .markTOEIC
        default: return .interactive
        }
    }
}

/// Small round dot in a collection's mark colour.
struct CollectionMarkDot: View {
    let color: Color
    var size: CGFloat = 10

    var body: some View {
        Circle()
            .fill(color)
            .frame(width: size, height: size)
            .accessibilityHidden(true)
    }
}

/// A two-up Home card: icon badge, bold title, one muted line. The whole card is the button.
struct HomeTile<Detail: View>: View {
    let systemImage: String
    let tone: IconBadge.Tone
    let title: LocalizedStringKey
    var isEnabled = true
    let action: () -> Void
    @ViewBuilder let detail: Detail

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 0) {
                IconBadge(systemImage: systemImage, tone: tone)
                Text(title)
                    .font(Typography.emphasis)
                    .foregroundStyle(Color.ink)
                    .padding(.top, Spacing.s)
                detail
                    .font(Typography.micro)
                    .foregroundStyle(Color.mutedInk)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .multilineTextAlignment(.leading)
            .padding(Spacing.m)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .cardSurface()
            .contentShape(RoundedRectangle(cornerRadius: Radii.card, style: .continuous))
        }
        .buttonStyle(PressScaleButtonStyle())
        .disabled(!isEnabled)
        .accessibilityElement(children: .combine)
    }
}
