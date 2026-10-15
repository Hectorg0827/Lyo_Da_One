import SwiftUI

/// Design tokens for the Active Lesson screen.
///
/// Composes with the global `DesignTokens` (typography, spacing, radius)
/// and uses the shared brand palette for the teaching workspace:
/// frosted glass surfaces, lavender accents, calm restraint.
enum ClassroomTokens {

    // MARK: - Background gradient

    /// Deep indigo-to-navy gradient that fills the screen.
    /// Goes top-leading (slightly brighter) → bottom-trailing (deepest) so
    /// the page has a sense of depth without being busy.
    static let backgroundGradient = LinearGradient(
        colors: [
            DesignTokens.Colors.surface,  // top — soft indigo
            DesignTokens.Colors.background,  // mid — deep navy
            DesignTokens.Colors.background,  // bottom — almost black
        ],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    /// Subtle radial glow centered behind the teaching card to draw the eye.
    static let ambientGlow = RadialGradient(
        colors: [
            DesignTokens.Colors.accent.opacity(0.18),
            DesignTokens.Colors.accent.opacity(0.0),
        ],
        center: .center,
        startRadius: 40,
        endRadius: 320
    )

    // MARK: - Glass surfaces

    /// Standard frosted-glass card fill. Pairs with `glassBorder` and the
    /// system `.ultraThinMaterial` background.
    static let glassFill = DesignTokens.Colors.surface

    /// Slightly more opaque glass for the primary teaching card so it reads
    /// as the page hero.
    static let glassFillElevated = DesignTokens.Colors.surfaceElevated

    /// Hairline luminous border around glass cards. Soft enough to read as
    /// "edge of light," not as a hard outline.
    static let glassBorder = DesignTokens.Colors.accentSecondary.opacity(0.22)

    /// Stronger border for the focused/elevated card.
    static let glassBorderElevated = DesignTokens.Colors.accentSecondaryLight.opacity(0.35)

    // MARK: - Accents

    /// Primary lavender — used for the avatar, "Lyo" label, primary button.
    static let accent = DesignTokens.Colors.accentSecondaryLight

    /// Deeper purple used in the primary button gradient.
    static let accentDeep = DesignTokens.Colors.accent

    /// Soft glow color for highlighted elements (avatar ring, button shadow).
    static let accentGlow = DesignTokens.Colors.accentSecondary

    // MARK: - Text

    static let textPrimary = DesignTokens.Colors.textPrimary
    static let textSecondary = DesignTokens.Colors.textSecondary
    static let textTertiary = DesignTokens.Colors.textTertiary
    static let textOnAccent = Color.white

    // MARK: - Spacing & radius

    /// Outer page padding (left/right).
    static let pagePadding: CGFloat = 20

    /// Vertical spacing between top-level cards on the lesson screen.
    static let cardSpacing: CGFloat = 16

    /// Inner padding inside cards.
    static let cardPadding: CGFloat = 20

    /// Card corner radius — generous, matches premium iOS feel.
    static let cardRadius: CGFloat = 24

    /// Compact strip corner radius (key term, etc.).
    static let stripRadius: CGFloat = 16

    /// Pill / button corner radius.
    static let pillRadius: CGFloat = 999

    // MARK: - Shadows

    /// Soft shadow under cards. Cool-toned to blend with the dark background.
    static let cardShadow = Color.black.opacity(0.45)

    /// Faint accent halo under the primary teaching card.
    static let elevatedShadow = DesignTokens.Colors.accent.opacity(0.28)

    // MARK: - Typography
    //
    // Lesson content is the page's main reason to exist, so it gets its own
    // type ramp instead of inheriting the global one. Rounded design throughout
    // — more inviting than the SF default for educational content.

    /// Hero/banner title — only used on the lesson hero card.
    static let titleHero = Font.system(.largeTitle, design: .rounded).weight(.bold)
    /// Section heading (markdown h1).
    static let titleSection = Font.system(.title, design: .rounded).weight(.bold)
    /// Sub-heading (markdown h2).
    static let titleSub = Font.system(.title2, design: .rounded).weight(.semibold)
    /// Minor heading (markdown h3+).
    static let titleMinor = Font.system(.title3, design: .rounded).weight(.semibold)
    /// Body text — slightly larger than .body for comfortable lesson reading.
    static let bodyLesson = Font.system(size: 17, weight: .regular, design: .rounded)
    /// Bold runs in markdown body.
    static let bodyLessonBold = Font.system(size: 17, weight: .semibold, design: .rounded)
    /// Caption under images, diagrams, code blocks.
    static let captionMeta = Font.system(.caption, design: .rounded).weight(.medium)
    /// Code blocks — monospaced, slightly smaller so longer lines fit.
    static let codeBody = Font.system(.callout, design: .monospaced)
    /// Comfortable line spacing for lesson body text.
    static let bodyLineSpacing: CGFloat = 7

    // Hero/topic palette lives in `TopicArt` so every surface that shows a
    // course (hero, chat proposal, stack chip, catalog) draws from the same
    // gradient bank instead of forking.
}

// MARK: - Reusable view modifiers

extension View {
    /// Apply a frosted-glass card surface (background, border, corner radius).
    /// `elevated: true` is reserved for the primary teaching card.
    func classroomGlassCard(elevated: Bool = false) -> some View {
        let radius = ClassroomTokens.cardRadius
        let fill = elevated ? ClassroomTokens.glassFillElevated : ClassroomTokens.glassFill
        let border = elevated ? ClassroomTokens.glassBorderElevated : ClassroomTokens.glassBorder
        return self
            .background(
                RoundedRectangle(cornerRadius: radius, style: .continuous)
                    .fill(.ultraThinMaterial)
                    .overlay(
                        RoundedRectangle(cornerRadius: radius, style: .continuous)
                            .fill(fill)
                    )
            )
            .overlay(
                RoundedRectangle(cornerRadius: radius, style: .continuous)
                    .stroke(border, lineWidth: 1)
            )
            .shadow(
                color: elevated ? ClassroomTokens.elevatedShadow : ClassroomTokens.cardShadow,
                radius: elevated ? 24 : 12,
                x: 0,
                y: elevated ? 12 : 6
            )
    }
}
