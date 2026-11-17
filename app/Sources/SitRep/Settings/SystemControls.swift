import AppKit
import SitRepPanel
import SwiftUI

/// The system's pop-up button, its choices in sections, a separator between each two, at its own width: its widest
/// choice's.
struct PopUp<Value: Hashable>: NSViewRepresentable {
    let label: String
    let sections: [[Value]]
    let title: (Value) -> String
    @Binding var selection: Value

    func makeNSView(context: Context) -> NSPopUpButton {
        let button = NSPopUpButton(frame: .zero, pullsDown: false)

        button.target = context.coordinator
        button.action = #selector(Coordinator.chose(_:))
        button.setAccessibilityLabel(label)
        return button
    }

    func updateNSView(_ button: NSPopUpButton, context: Context) {
        let values = sections.flatMap(\.self)
        let titles = sections.map { $0.map(title) }
        let selection = $selection

        if context.coordinator.titles != titles {
            context.coordinator.titles = titles
            fill(button.menu, with: titles)
        }
        context.coordinator.choose = { selection.wrappedValue = values[$0] }
        button.selectItem(withTag: values.firstIndex(of: self.selection) ?? -1)
    }

    /// The menu's items, each tagged with its place among every choice.
    private func fill(_ menu: NSMenu?, with titles: [[String]]) {
        var place = 0

        menu?.removeAllItems()
        for (offset, section) in titles.enumerated() {
            if offset > 0 {
                menu?.addItem(.separator())
            }
            for title in section {
                let item = NSMenuItem(title: title, action: nil, keyEquivalent: "")

                item.tag = place
                place += 1
                menu?.addItem(item)
            }
        }
    }

    func sizeThatFits(_ proposal: ProposedViewSize, nsView button: NSPopUpButton, context: Context) -> CGSize? {
        button.intrinsicContentSize
    }

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    @MainActor
    final class Coordinator: NSObject {
        var titles: [[String]] = []
        var choose: (Int) -> Void = { _ in }

        @objc func chose(_ button: NSPopUpButton) {
            choose(button.selectedTag())
        }
    }
}

/// The system's time field with its stepper, as System Settings sets Night Shift's schedule: a time of day, its hour
/// and minute in the Mac's own clock, 12-hour or 24, its digits of one width so a step never shifts them, each change
/// saved through `time`. It holds the time on a fixed day in UTC, so no change of the clocks moves it.
struct TimeField: NSViewRepresentable {
    let label: String
    @Binding var time: TimeOfDay

    func makeNSView(context: Context) -> NSDatePicker {
        let picker = NSDatePicker()

        picker.datePickerStyle = .textFieldAndStepper
        picker.datePickerElements = .hourMinute
        picker.font = .monospacedDigitSystemFont(ofSize: NSFont.systemFontSize, weight: .regular)
        picker.calendar = Self.calendar
        picker.timeZone = Self.calendar.timeZone
        picker.target = context.coordinator
        picker.action = #selector(Coordinator.changed(_:))
        picker.setAccessibilityLabel(label)
        return picker
    }

    func updateNSView(_ picker: NSDatePicker, context: Context) {
        let date = Self.date(of: time)

        context.coordinator.time = $time
        if picker.dateValue != date {
            picker.dateValue = date
        }
    }

    func sizeThatFits(_ proposal: ProposedViewSize, nsView picker: NSDatePicker, context: Context) -> CGSize? {
        let size = picker.intrinsicContentSize

        return CGSize(width: size.width + Self.room, height: size.height)
    }

    /// More than AppKit gives the field: at its own width, drawn offscreen on 17 November 2026 at 1× and at 2×, the
    /// last 0 of 18:00 ran into the field's edge; this gives it the field's inset at its right too.
    static let room: CGFloat = 6

    func makeCoordinator() -> Coordinator {
        Coordinator(time: $time)
    }

    /// The Gregorian calendar in UTC, which has no change of the clocks.
    static let calendar: Calendar = {
        var calendar = Calendar(identifier: .gregorian)

        calendar.timeZone = TimeZone(identifier: "UTC")!
        return calendar
    }()

    /// The time on the field's day.
    static func date(of time: TimeOfDay) -> Date {
        calendar.date(from: DateComponents(year: 2001, month: 1, day: 1, hour: time.hour, minute: time.minute))!
    }

    /// The time a date on the field holds.
    static func time(of date: Date) -> TimeOfDay {
        let parts = calendar.dateComponents([.hour, .minute], from: date)

        return TimeOfDay(hour: parts.hour!, minute: parts.minute!)
    }

    @MainActor
    final class Coordinator: NSObject {
        var time: Binding<TimeOfDay>

        init(time: Binding<TimeOfDay>) {
            self.time = time
        }

        @objc func changed(_ picker: NSDatePicker) {
            time.wrappedValue = TimeField.time(of: picker.dateValue)
        }
    }
}

/// The system's text field, rounded, holding exactly what is typed, its every change saved through `text`: a command
/// for a shell, which macOS's smart quotes, smart dashes, text replacement or spelling correction would break, all off
/// in its editor. Its text in the face given, against the row's words by its first baseline.
struct LiteralField: NSViewRepresentable {
    let label: String
    let font: NSFont
    @Binding var text: String

    func makeNSView(context: Context) -> LiteralTextField {
        let field = LiteralTextField(string: text)

        field.font = font
        field.bezelStyle = .roundedBezel
        field.usesSingleLineMode = true
        field.lineBreakMode = .byClipping
        field.cell?.isScrollable = true
        field.delegate = context.coordinator
        field.setAccessibilityLabel(label)
        return field
    }

    func updateNSView(_ field: LiteralTextField, context: Context) {
        context.coordinator.text = $text
        if field.stringValue != text {
            field.stringValue = text
        }
    }

    func sizeThatFits(_ proposal: ProposedViewSize, nsView field: LiteralTextField, context: Context) -> CGSize? {
        CGSize(width: proposal.width ?? field.intrinsicContentSize.width, height: field.intrinsicContentSize.height)
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(text: $text)
    }

    @MainActor
    final class Coordinator: NSObject, NSTextFieldDelegate {
        var text: Binding<String>

        init(text: Binding<String>) {
            self.text = text
        }

        func controlTextDidChange(_ notification: Notification) {
            if let field = notification.object as? NSTextField {
                text.wrappedValue = field.stringValue
            }
        }
    }
}

/// A text field whose editor, as it takes the focus, changes nothing typed into it.
final class LiteralTextField: NSTextField {
    override func becomeFirstResponder() -> Bool {
        let became = super.becomeFirstResponder()

        if let editor = currentEditor() as? NSTextView {
            editor.isAutomaticQuoteSubstitutionEnabled = false
            editor.isAutomaticDashSubstitutionEnabled = false
            editor.isAutomaticTextReplacementEnabled = false
            editor.isAutomaticSpellingCorrectionEnabled = false
        }
        return became
    }
}
