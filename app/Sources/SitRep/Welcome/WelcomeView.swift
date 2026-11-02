import SitRepMenu
import SwiftUI

/// The welcome's sizes, colours and type, from Paper's "Welcome window" boards; the system font at Paper's sizes and
/// weights, as Settings sets it.
enum WelcomeStyle {
    /// The window, never resized.
    static let size = CGSize(width: 840, height: 540)
    /// The words' column, on the left.
    static let column: CGFloat = 330
    static let footer: CGFloat = 64
    /// The stage's inset from the window's right and from its top.
    static let stageInset: CGFloat = 12
    /// The stage's menu bar, which the edge's screen on it starts under.
    static let stageMenuBar: CGFloat = 20
    /// The stage, the rest of the window.
    static let stage = CGSize(
        width: size.width - column - stageInset, height: size.height - footer - stageInset
    )

    static let text = Color(hex: 0xF5F5F7)
    static let soft = Color(hex: 0x98989F)
    static let faint = Color(hex: 0x5C5C63)
    /// A card in the column: the form, the sound list, the login row, the command and the playback.
    static let card = Color(hex: 0x141416)
    static let cardRadius: CGFloat = 10
    static let hairline = Color.white.opacity(0x12 / 255)
}

/// The welcome window's content (DESIGN, "The welcome window"): the words on the left in a column of 330, a headline,
/// one grey paragraph and the step's controls; the stage inset on the right; and the footer, which never moves.
struct WelcomeView: View {
    let welcome: WelcomeModel
    let stage: StageEdge

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 0) {
                WelcomeColumn(welcome: welcome)
                    .frame(width: WelcomeStyle.column)
                StageView(welcome: welcome, edge: stage)
                    .frame(width: WelcomeStyle.stage.width, height: WelcomeStyle.stage.height)
                    .padding(.top, WelcomeStyle.stageInset)
                    .padding(.trailing, WelcomeStyle.stageInset)
                    .frame(maxHeight: .infinity, alignment: .top)
            }
            WelcomeFooterView(welcome: welcome, footer: welcome.steps.footer)
        }
        .frame(width: WelcomeStyle.size.width, height: WelcomeStyle.size.height)
        .background(.black)
        .ignoresSafeArea()
        .environment(\.colorScheme, .dark)
    }
}

/// The left column: under the traffic lights' row, the step's words and its controls.
private struct WelcomeColumn: View {
    let welcome: WelcomeModel

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // the traffic lights' row, which the system's own lights stand in
            Color.clear.frame(height: 20)
            step
        }
        .padding(.top, 16)
        .padding(.leading, 28)
        .padding(.trailing, 32)
        .frame(maxHeight: .infinity, alignment: .top)
    }

    @ViewBuilder private var step: some View {
        switch welcome.step {
        case .hello: HelloStep()
        case .edge: EdgeStep(welcome: welcome)
        case .sound: SoundStep(welcome: welcome)
        case .ready: ReadyStep(welcome: welcome)
        }
    }
}

/// A step's headline, two lines at most, over its grey paragraph.
struct StepWords: View {
    let step: WelcomeStep

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(step.headline)
                .font(.system(size: 26, weight: .bold))
                .spacing(-0.02, of: 26)
                .foregroundStyle(WelcomeStyle.text)
                .lineLimit(2)
                .accessibilityAddTraits(.isHeader)
            Text(step.paragraph)
                .font(.system(size: 13))
                .lineSpacing(3)
                .foregroundStyle(WelcomeStyle.soft)
        }
        .fixedSize(horizontal: false, vertical: true)
    }
}

/// The footer: the back chevron, dimmed at the first step; a dash for each step, the one Lee is on long and blue;
/// Skip setup, but at the last step; and Continue ↵, a white pill that Return presses.
struct WelcomeFooterView: View {
    let welcome: WelcomeModel
    let footer: WelcomeFooter

    var body: some View {
        HStack(spacing: 16) {
            Button(action: welcome.goBack) {
                Image(systemName: "chevron.left")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(WelcomeStyle.text)
                    .frame(width: 28, height: 28)
                    .background(Circle().fill(.white.opacity(0x0F / 255)))
            }
            .buttonStyle(.plain)
            .opacity(footer.canGoBack ? 1 : 0.35)
            .disabled(!footer.canGoBack)
            .accessibilityLabel("Back")
            Dashes(dashes: footer.dashes)
            Spacer(minLength: 0)
            if footer.showsSkip {
                Button("Skip setup", action: welcome.skip)
                    .buttonStyle(.plain)
                    .font(.system(size: 13))
                    .foregroundStyle(WelcomeStyle.soft)
            }
            ContinuePill(title: footer.continueTitle, action: welcome.goOn)
        }
        .padding(.leading, 20)
        .padding(.trailing, 16)
        .frame(height: WelcomeStyle.footer)
    }
}

/// A dash for each step: those behind lit, the one Lee is on long and in the accent, those ahead faint.
private struct Dashes: View {
    let dashes: [WelcomeFooter.Dash]

    var body: some View {
        HStack(spacing: 5) {
            ForEach(Array(dashes.enumerated()), id: \.offset) { _, dash in
                RoundedRectangle(cornerRadius: 2)
                    .fill(colour(dash))
                    .frame(width: dash == .current ? 22 : 10, height: 4)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Step \((dashes.firstIndex(of: .current) ?? 0) + 1) of \(dashes.count)")
    }

    private func colour(_ dash: WelcomeFooter.Dash) -> Color {
        switch dash {
        case .done: .white.opacity(0x66 / 255)
        case .current: .accentColor
        case .ahead: .white.opacity(0x2E / 255)
        }
    }
}

/// Continue ↵: a white pill, its key cap showing Return, which presses it.
private struct ContinuePill: View {
    let title: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                Text(title)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Color(hex: 0x111113))
                Text("↵")
                    .font(.system(size: 11))
                    .foregroundStyle(Color(hex: 0x3A3A3E))
                    .frame(width: 20, height: 18)
                    .background(Color(hex: 0x111113).opacity(0.1), in: .rect(cornerRadius: 5))
                    .accessibilityHidden(true)
            }
            .padding(.leading, 16)
            .padding(.trailing, 8)
            .frame(height: 32)
            .background(WelcomeStyle.text, in: Capsule())
        }
        .buttonStyle(.plain)
        .keyboardShortcut(.defaultAction)
    }
}
