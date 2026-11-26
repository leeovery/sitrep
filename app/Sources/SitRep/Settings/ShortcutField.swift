import AppKit
import Carbon.HIToolbox
import SitRepMenu
import SwiftUI

/// Settings' Shortcut recorder (DESIGN, "Keys"), what it shows set by `ShortcutRecorder`: SitRep's own control, as
/// AppKit has none, drawn as macOS's Keyboard Shortcuts settings draw one, of the system's parts: its rounded field,
/// the chord centred in it in the Mac's glyphs or a prompt in its placeholder's grey, and a clear button at its end
/// while there is a shortcut to clear. A click records, the field holding the focus ring while it does.
struct ShortcutField: NSViewRepresentable {
    let field: ShortcutRecorder.Field
    let canClear: Bool
    let actions: ShortcutFieldView.Actions

    func makeNSView(context: Context) -> ShortcutFieldView {
        ShortcutFieldView()
    }

    func updateNSView(_ view: ShortcutFieldView, context: Context) {
        view.actions = actions
        view.show(field, canClear: canClear)
    }

    func sizeThatFits(_ proposal: ProposedViewSize, nsView view: ShortcutFieldView, context: Context) -> CGSize? {
        view.intrinsicContentSize
    }
}

/// The recorder's view: the system's rounded field and clear button inside a view that takes the clicks and, while it
/// records, the keys, ⌘'s among them, before the menus can, so ⌘W records rather than closing the window. It records
/// while it is first responder: a click away, the window going to the back, or the view leaving it ends that.
final class ShortcutFieldView: NSView {
    /// What it tells Settings: a recording begun; the modifiers held; a key pressed, and whether it records still; a
    /// recording cancelled; the shortcut cleared.
    struct Actions {
        var record: () -> Void = {}
        var hold: (ChordModifiers) -> Void = { _ in }
        var press: (KeyChord) -> Bool = { _ in false }
        var cancel: () -> Void = {}
        var clear: () -> Void = {}
    }

    var actions = Actions()
    private let field = NSTextField(string: "")
    private let clear = NSButton()
    private var resigned: (any NSObjectProtocol)?

    /// As wide as "Record shortcut" leaves room for the clear button at either end, so it stays centred.
    static let width: CGFloat = 150

    init() {
        super.init(frame: .zero)

        field.isEditable = false
        field.isSelectable = false
        field.refusesFirstResponder = true
        field.isBezeled = true
        field.bezelStyle = .roundedBezel
        field.alignment = .center
        field.font = .systemFont(ofSize: NSFont.systemFontSize)
        field.lineBreakMode = .byClipping
        clear.image = NSImage(systemSymbolName: "xmark.circle.fill", accessibilityDescription: "Clear shortcut")
        clear.isBordered = false
        clear.imagePosition = .imageOnly
        clear.contentTintColor = .tertiaryLabelColor
        clear.refusesFirstResponder = true
        clear.target = self
        clear.action = #selector(cleared)
        addSubview(field)
        addSubview(clear)
        focusRingType = .default
        setAccessibilityElement(true)
        setAccessibilityRole(.button)
        setAccessibilityLabel("Shortcut")
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override var intrinsicContentSize: NSSize {
        NSSize(width: Self.width, height: field.intrinsicContentSize.height)
    }

    override var isFlipped: Bool { true }

    override func layout() {
        super.layout()
        field.frame = bounds

        let side = min(16, bounds.height)

        clear.frame = CGRect(x: bounds.maxX - side - 4, y: (bounds.height - side) / 2, width: side, height: side)
    }

    /// The field as `ShortcutRecorder` sets it, a prompt as the field's placeholder.
    func show(_ shown: ShortcutRecorder.Field, canClear: Bool) {
        field.stringValue = shown.isPrompt ? "" : shown.text
        field.placeholderString = shown.isPrompt ? shown.text : nil
        clear.isHidden = !canClear
        setAccessibilityValue(shown.text)
    }

    private var isRecording: Bool { window?.firstResponder === self }

    /// Clicks are the recorder's, but for the clear button's.
    override func hitTest(_ point: NSPoint) -> NSView? {
        let hit = super.hitTest(point)

        return hit === clear || hit == nil ? hit : self
    }

    override var acceptsFirstResponder: Bool { true }

    override func mouseDown(with event: NSEvent) {
        if !isRecording {
            window?.makeFirstResponder(self)
        }
    }

    override func accessibilityPerformPress() -> Bool {
        window?.makeFirstResponder(self) ?? false
    }

    override func becomeFirstResponder() -> Bool {
        actions.record()
        return true
    }

    override func resignFirstResponder() -> Bool {
        actions.cancel()
        return true
    }

    override func keyDown(with event: NSEvent) {
        guard isRecording else {
            return super.keyDown(with: event)
        }

        if !actions.press(KeyChord(event)) {
            window?.makeFirstResponder(nil)
        }
    }

    /// While it records, a key with ⌘ is its, as any other is, before the window's menus see it.
    override func performKeyEquivalent(with event: NSEvent) -> Bool {
        guard isRecording, event.type == .keyDown else {
            return super.performKeyEquivalent(with: event)
        }

        keyDown(with: event)
        return true
    }

    override func flagsChanged(with event: NSEvent) {
        if isRecording {
            actions.hold(ChordModifiers(event.modifierFlags))
        }
    }

    override func drawFocusRingMask() {
        field.cell?.drawFocusRingMask(withFrame: field.frame, in: self)
    }

    override var focusRingMaskBounds: NSRect {
        field.cell?.focusRingMaskBounds(forFrame: field.frame, in: self) ?? field.frame
    }

    /// The window going to the back ends a recording, as a click away does.
    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        resigned.map(NotificationCenter.default.removeObserver)
        resigned = window.map { window in
            NotificationCenter.default.addObserver(
                forName: NSWindow.didResignKeyNotification, object: window, queue: .main
            ) { [weak self] _ in
                MainActor.assumeIsolated { self?.stopRecording() }
            }
        }
    }

    override func viewWillMove(toWindow window: NSWindow?) {
        if window == nil {
            stopRecording()
        }
        super.viewWillMove(toWindow: window)
    }

    private func stopRecording() {
        if isRecording {
            window?.makeFirstResponder(nil)
        }
    }

    @objc private func cleared() {
        actions.clear()
        stopRecording()
    }
}

/// The keys that type a character, named as the Mac's keyboard layout types them, the one its shortcuts are read on.
enum KeyNames {
    static func typed(_ code: UInt16) -> String? {
        guard let source = TISCopyCurrentASCIICapableKeyboardLayoutInputSource()?.takeRetainedValue(),
              let property = TISGetInputSourceProperty(source, kTISPropertyUnicodeKeyLayoutData)
        else {
            return nil
        }

        let layout = Unmanaged<CFData>.fromOpaque(property).takeUnretainedValue() as Data
        var dead: UInt32 = 0, length = 0
        var typed = [UniChar](repeating: 0, count: 4)
        let status = layout.withUnsafeBytes { bytes in
            UCKeyTranslate(
                bytes.baseAddress?.assumingMemoryBound(to: UCKeyboardLayout.self), code, UInt16(kUCKeyActionDisplay), 0,
                UInt32(LMGetKbdType()), OptionBits(kUCKeyTranslateNoDeadKeysMask), &dead, typed.count, &length, &typed
            )
        }

        return status == noErr && length > 0 ? String(utf16CodeUnits: typed, count: length) : nil
    }
}

extension ChordModifiers {
    /// The modifiers AppKit read off a key, as Carbon's bits.
    init(_ flags: NSEvent.ModifierFlags) {
        self = [
            (NSEvent.ModifierFlags.command, ChordModifiers.command), (.shift, .shift), (.option, .option),
            (.control, .control),
        ].reduce(into: []) { modifiers, pair in
            if flags.contains(pair.0) {
                modifiers.insert(pair.1)
            }
        }
    }
}

extension KeyChord {
    /// A key AppKit read: its code, and the modifiers held with it.
    init(_ event: NSEvent) {
        self.init(code: event.keyCode, modifiers: ChordModifiers(event.modifierFlags))
    }
}
