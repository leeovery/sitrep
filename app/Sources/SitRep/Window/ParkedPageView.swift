import SitRepWindow
import SwiftUI

/// A parked item beside Parked's list, under the toolbar's band, as A4 revised draws it: "Project › Session" as a
/// breadcrumb; the stroked diamond and the item's title, 22 semibold; "Parked 3 hours ago" under it; its `where` as
/// its body, and its `ref` in mono; then Parked from, the session's card, with Back to its session; then Since it was
/// parked, its session's log lines since, while there are any.
struct ParkedPageView: View {
    let page: ParkedPage
    let now: Date

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Color.clear.frame(height: WindowStyle.barHeight)
            Breadcrumb(projectKey: page.projectKey, projectName: page.projectName, session: page.from.name)
                .frame(height: 28)
                .padding(.top, 6)
            item.padding(.top, 18)
            VStack(alignment: .leading, spacing: 0) {
                PageHeading(name: Words.parkedFrom)
                ParkedFromCard(from: page.from)
            }
            .padding(.top, WindowStyle.parkedSectionGap)
            if let failure = page.failure {
                Text(failure).font(WindowStyle.ui(12)).foregroundStyle(WindowStyle.faint).padding(.top, 20)
            }
            if page.hasBoard, !page.since.isEmpty {
                SinceParkedSection(page: page, now: now).padding(.top, WindowStyle.parkedSectionGap)
            }
        }
        .padding(.bottom, 34)
    }

    /// Its diamond and title, when it was parked, and its body, 22 in from the diamond's edge.
    private var item: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .top, spacing: 10) {
                Diamond()
                    .stroke(WindowStyle.parkedMark, style: StrokeStyle(lineWidth: 1.3, lineJoin: .round))
                    .frame(width: 9, height: 9)
                    .frame(width: WindowStyle.lane.width, height: 28)
                    .accessibilityHidden(true)
                Text(page.item.title)
                    .font(WindowStyle.ui(22, .semibold))
                    .spacing(-0.02, of: 22)
                    .foregroundStyle(WindowStyle.text)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(minHeight: 28)
                    .accessibilityAddTraits(.isHeader)
            }
            VStack(alignment: .leading, spacing: 0) {
                Text(Words.parkedAgo(page.item.at, at: now))
                    .font(WindowStyle.ui(13))
                    .foregroundStyle(WindowStyle.parkedWhen)
                if let words = page.item.where {
                    Text(words)
                        .font(WindowStyle.ui(14))
                        .lineSpacing(5)
                        .foregroundStyle(WindowStyle.parkedBody)
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(.top, 18)
                }
                if let ref = page.item.ref {
                    Text(ref)
                        .font(WindowStyle.mono(12))
                        .foregroundStyle(WindowStyle.soft)
                        .textSelection(.enabled)
                        .padding(.top, 8)
                }
            }
            .padding(.leading, WindowStyle.wordsEdge)
        }
    }
}

/// The session an item was parked from, as A4 revised draws its card: on the raise, its corners 12, a hairline inside
/// its edge; the session's mark; its name, 13 semibold, and under it its now line and its asks waiting, 13 in white at
/// 55%, both dimming as one while no window holds it; and Back to its session, outlined, which pushes its page, a step
/// Back returns from.
private struct ParkedFromCard: View {
    let from: ParkedPage.From

    @Environment(\.windowActions) private var act

    var body: some View {
        HStack(spacing: 10) {
            HStack(alignment: .top, spacing: 10) {
                MarkView(mark: from.mark)
                VStack(alignment: .leading, spacing: 3) {
                    Text(from.name)
                        .font(WindowStyle.ui(13, .semibold))
                        .spacing(-0.01, of: 13)
                        .foregroundStyle(WindowStyle.text)
                    if !from.parts.isEmpty {
                        Text(from.parts.joined(separator: " · "))
                            .font(WindowStyle.ui(13))
                            .foregroundStyle(WindowStyle.soft)
                    }
                }
                .lineLimit(1)
                .opacity(Away.dimming(from.isAway))
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .spoken(Spoken.parkedFrom(from))
            Button { act.backToSession(from.id) } label: {
                HStack(spacing: 6) {
                    Text(Words.backToSession).foregroundStyle(WindowStyle.text)
                    Chevron(isFolded: true).foregroundStyle(WindowStyle.soft)
                }
                .font(WindowStyle.ui(12, .medium))
                .frame(height: 28)
                .padding(.horizontal, 11)
            }
            .jumpButton()
            .fixedSize()
        }
        .padding(.vertical, 12)
        .padding(.horizontal, 14)
        .background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(WindowStyle.raise))
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous).strokeBorder(WindowStyle.parkedRing, lineWidth: 0.5)
        )
    }
}

extension WindowStyle {
    // MARK: A parked item's page (A4 revised)

    /// Above Parked from and above Since it was parked.
    static let parkedSectionGap: CGFloat = 28
    /// Its diamond, white at 60%; when it was parked, white at 45%; its body, white at 75%.
    static let parkedMark = Color.white.opacity(0.6)
    static let parkedWhen = Color.white.opacity(Double(0x73) / 255)
    static let parkedBody = Color.white.opacity(Double(0xBF) / 255)
    /// The hairline inside the edge of Parked from's card, white at 5%.
    static let parkedRing = Color.white.opacity(Double(0x0D) / 255)
}
