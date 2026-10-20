@testable import SitRep
import SwiftUI
import Testing

/// How a row or a button shows: lightly under the pointer, strongly picked or pressed.
struct HighlightTests {
    @Test func thePickedRowShowsStrongestWhateverElse() {
        #expect(Highlight.of(isPicked: true, isPressed: false, isHovered: true) == .picked)
        #expect(Highlight.of(isPicked: false, isPressed: true, isHovered: false) == .picked)
    }

    @Test func underThePointerItShowsLightly() {
        #expect(Highlight.of(isPicked: false, isPressed: false, isHovered: true) == .hover)
    }

    @Test func aRowWithNothingOnItShowsNothing() {
        #expect(Highlight.of(isPicked: false, isPressed: false, isHovered: false) == .none)
    }
}

/// A sidebar row's fill: the pointer's, quietly, on a row not picked; the picked one keeps the system's selection, and
/// nothing of SitRep's is drawn on it, save as a still, which renders no list.
struct SidebarFillTests {
    @Test func underThePointerARowNotPickedShowsAQuietPlainFill() {
        #expect(WindowStyle.sidebarFill(.hover, isStill: false) == WindowStyle.sidebarHover)
        #expect(WindowStyle.sidebarFill(.hover, isStill: true) == WindowStyle.sidebarHover)
    }

    @Test func thePickedRowIsLeftToTheSystemsSelection() {
        #expect(WindowStyle.sidebarFill(Highlight.of(isPicked: true, isPressed: false, isHovered: true), isStill: false) == nil)
    }

    @Test func aRowWithNothingOnItShowsNothing() {
        #expect(WindowStyle.sidebarFill(.none, isStill: false) == nil)
        #expect(WindowStyle.sidebarFill(.none, isStill: true) == nil)
    }

    @Test func asAStillThePickedRowStandsInForTheSelection() {
        #expect(WindowStyle.sidebarFill(.picked, isStill: true) == WindowStyle.stillSelection)
    }
}
