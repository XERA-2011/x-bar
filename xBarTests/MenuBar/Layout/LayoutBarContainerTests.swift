//
//  LayoutBarContainerTests.swift
//  Project: xBar
//
//  Copyright (Ice) © 2023–2025 Jordan Baird
//  Copyright (xBar) © 2026 Toni Förster
//  Licensed under the GNU GPLv3

import Cocoa
import Testing
@testable import xBar

@MainActor
final class TestLayoutBarArrangedView: LayoutBarArrangedView {
    override var kind: Kind {
        .item(.fixture(tag: .appItem(bundleID: "com.test.app", title: "Test"), windowID: 1))
    }
}

@MainActor
@Suite("Layout section drops")
struct LayoutBarContainerTests {
    @Test("An empty section inserts its first item at the beginning")
    func emptySectionInsertionIndexStartsAtBeginning() {
        let insertionIndex = LayoutBarContainer.emptyTargetInsertionIndex(
            for: 500,
            in: []
        )

        #expect(insertionIndex == 0)
    }

    @Test("Dragging within Hidden section is rejected")
    func hiddenReorderingIsRejected() {
        let appState = AppState()
        let hidden = LayoutBarContainer(appState: appState, section: .hidden)
        let view1 = TestLayoutBarArrangedView()
        let view2 = TestLayoutBarArrangedView()
        hidden.arrangedViews = [view1, view2]
        view1.oldContainerInfo = (hidden, 0)

        // Mock dragging info with source from hidden itself
        final class MockDraggingInfo: NSObject, NSDraggingInfo {
            var draggingSource: Any?
            var draggingLocation: NSPoint = .zero
            var draggingDestinationWindow: NSWindow?
            var draggingSourceOperationMask: NSDragOperation = .move
            var numberOfValidItemsForDrop: Int = 1
            var draggedImageState: Any?
            var draggingFormation: NSDraggingFormation = .default
            var animatesToDestination: Bool = false
            var draggingSequenceNumber: Int = 1
            var draggingPasteboard: NSPasteboard = .init(name: .drag)
            func draggingItem(at index: Int) -> NSDraggingItem { fatalError() }
            func enumerateDraggingItems(options: NSDraggingItemEnumerationOptions = [], for view: NSView?, classes: [AnyClass], searchOptions: [NSPasteboard.ReadingOptionKey : Any] = [:], using block: @escaping (NSDraggingItem, Int, UnsafeMutablePointer<ObjCBool>) -> Void) {}
            func resetSpringLoading() {}
        }

        let info = MockDraggingInfo()
        info.draggingSource = view1
        let operation = hidden.updateArrangedViewsForDrag(with: info, phase: .updated)
        #expect(operation == [])
    }
}

@Suite("Layout item activation")
struct LayoutBarItemActivationTests {
    @Test("A left click released inside the icon activates its menu bar item")
    func leftClickActivates() {
        #expect(LayoutBarItemView.shouldActivateRepresentedItem(
            buttonNumber: 0,
            didBeginDragging: false,
            mouseUpInsideBounds: true
        ))
    }

    @Test("A drag never activates the app on mouse-up")
    func dragDoesNotActivate() {
        #expect(!LayoutBarItemView.shouldActivateRepresentedItem(
            buttonNumber: 0,
            didBeginDragging: true,
            mouseUpInsideBounds: true
        ))
    }

    @Test("Clicks released outside the icon and non-left clicks do not activate")
    func unrelatedClicksDoNotActivate() {
        #expect(!LayoutBarItemView.shouldActivateRepresentedItem(
            buttonNumber: 0,
            didBeginDragging: false,
            mouseUpInsideBounds: false
        ))
        #expect(!LayoutBarItemView.shouldActivateRepresentedItem(
            buttonNumber: 1,
            didBeginDragging: false,
            mouseUpInsideBounds: true
        ))
    }
}

@Suite("Layout item drag presentation")
struct LayoutBarItemDragPresentationTests {
    @Test("A dragged item keeps a visible dimmed placeholder")
    func draggedItemKeepsVisiblePlaceholder() {
        let fraction = LayoutBarItemView.iconFraction(
            isDraggingPlaceholder: true,
            isEnabled: true
        )

        #expect(fraction > 0)
        #expect(fraction < 1)
    }

    @Test("A frozen container keeps its last stable thumbnail")
    func frozenContainerRejectsTransientThumbnail() {
        #expect(!LayoutBarItemView.shouldUpdateCachedImage(
            hasContainer: true,
            containerAllowsUpdates: false
        ))
        #expect(LayoutBarItemView.shouldUpdateCachedImage(
            hasContainer: true,
            containerAllowsUpdates: true
        ))
        #expect(LayoutBarItemView.shouldUpdateCachedImage(
            hasContainer: false,
            containerAllowsUpdates: false
        ))
    }

    @Test("Geometry-only cache changes keep the existing item view")
    func geometryChangeReusesItemView() {
        let tag = MenuBarItemTag.appItem(
            bundleID: "com.example.status-item",
            title: "Item-0",
            windowID: 711
        )
        let beforeMove = MenuBarItem.fixture(
            tag: tag,
            windowID: 711,
            bounds: CGRect(x: 1400, y: 0, width: 24, height: 33),
            isOnScreen: true
        )
        let afterMove = MenuBarItem.fixture(
            tag: tag,
            windowID: 711,
            bounds: CGRect(x: -3700, y: 0, width: 24, height: 33),
            isOnScreen: false
        )

        #expect(LayoutBarContainer.canReuseItemView(
            representing: beforeMove,
            for: afterMove
        ))
    }

    @Test("A recreated status-item window gets a new item view")
    func recreatedWindowDoesNotReuseItemView() {
        let oldItem = MenuBarItem.fixture(
            tag: .appItem(bundleID: "com.example.status-item", title: "Item-0", windowID: 711),
            windowID: 711
        )
        let recreatedItem = MenuBarItem.fixture(
            tag: .appItem(bundleID: "com.example.status-item", title: "Item-0", windowID: 812),
            windowID: 812
        )

        #expect(!LayoutBarContainer.canReuseItemView(
            representing: oldItem,
            for: recreatedItem
        ))
    }

    @Test("A changed status-item size gets a new item view")
    func resizedItemDoesNotReuseItemView() {
        let tag = MenuBarItemTag.appItem(
            bundleID: "com.example.status-item",
            title: "Item-0",
            windowID: 711
        )
        let oldItem = MenuBarItem.fixture(
            tag: tag,
            windowID: 711,
            bounds: CGRect(x: 1400, y: 0, width: 24, height: 33)
        )
        let resizedItem = MenuBarItem.fixture(
            tag: tag,
            windowID: 711,
            bounds: CGRect(x: -3700, y: 0, width: 36, height: 33),
            isOnScreen: false
        )

        #expect(!LayoutBarContainer.canReuseItemView(
            representing: oldItem,
            for: resizedItem
        ))
    }

    @Test("A cancelled cross-row drag restores the original view exactly once")
    @MainActor
    func cancelledCrossRowDragRestoresOriginalView() {
        let appState = AppState()
        let source = LayoutBarContainer(appState: appState, section: .visible)
        let destination = LayoutBarContainer(appState: appState, section: .hidden)
        let draggedView = TestLayoutBarArrangedView()

        source.arrangedViews = [draggedView]
        source.arrangedViews.removeAll()
        destination.arrangedViews = [draggedView]

        source.restoreArrangedViewAfterCancelledDrag(
            draggedView,
            from: destination,
            at: 0
        )

        #expect(source.arrangedViews.count { $0 === draggedView } == 1)
        #expect(!destination.arrangedViews.contains { $0 === draggedView })
        #expect(draggedView.superview === source)
    }

    @Test("A row frozen by another drag rejects a new drag")
    func frozenRowRejectsUnrelatedDrag() {
        #expect(!LayoutBarPaddingView.canAcceptDrag(
            containerAllowsUpdates: false,
            beganInContainer: false,
            alreadyAccepted: false
        ))
        #expect(LayoutBarPaddingView.canAcceptDrag(
            containerAllowsUpdates: false,
            beganInContainer: true,
            alreadyAccepted: false
        ))
        #expect(LayoutBarPaddingView.canAcceptDrag(
            containerAllowsUpdates: false,
            beganInContainer: false,
            alreadyAccepted: true
        ))
    }
}

@Suite("Layout bar drag identity")
struct LayoutBarDragIdentityTests {
    private let provisional = MenuBarItem.fixture(
        tag: MenuBarItemTag(
            namespace: .controlCenter,
            title: "Item-0",
            windowID: 5467,
            instanceIndex: 0
        ),
        windowID: 5467,
        sourcePID: nil,
        ownerPID: 645
    )

    private let resolved = MenuBarItem.fixture(
        tag: .appItem(bundleID: "IconSwitcher", title: "Item-0", windowID: 5467),
        windowID: 5467,
        sourcePID: 12460,
        ownerPID: 645
    )

    private let otherItem = MenuBarItem.fixture(
        tag: .appItem(bundleID: "com.example.other", title: "Item-0", windowID: 2556),
        windowID: 2556
    )

    @Test("The same window is the same item after its identity resolves")
    func sameWindowIsSameItem() {
        #expect(LayoutBarPaddingView.isSameItem(resolved, provisional))
        #expect(!LayoutBarPaddingView.isSameItem(otherItem, provisional))
    }

    @Test("A recreated window still matches by tag")
    func recreatedWindowMatchesByTag() {
        let recreated = MenuBarItem.fixture(
            tag: .appItem(bundleID: "IconSwitcher", title: "Item-0", windowID: 5744),
            windowID: 5744,
            sourcePID: 12460,
            ownerPID: 645
        )

        #expect(LayoutBarPaddingView.isSameItem(recreated, resolved))
    }

    @Test("The dragged item is found beside its target under its resolved name")
    func reachedPositionUnderResolvedName() {
        let reached = LayoutBarPaddingView.itemReachedIntendedPosition(
            item: provisional,
            destination: .leftOfItem(otherItem),
            sectionItems: [resolved, otherItem]
        )

        #expect(reached)
    }

    @Test("The wrong side of the target is not the intended position")
    func wrongSideIsNotReached() {
        let reached = LayoutBarPaddingView.itemReachedIntendedPosition(
            item: provisional,
            destination: .rightOfItem(otherItem),
            sectionItems: [resolved, otherItem]
        )

        #expect(!reached)
    }

    @Test("Containment is enough when the target is a section divider")
    func dividerTargetNeedsOnlyContainment() {
        let divider = MenuBarItem.fixture(
            tag: .hiddenControlItem,
            windowID: 5134,
            sourcePID: nil
        )
        let reached = LayoutBarPaddingView.itemReachedIntendedPosition(
            item: provisional,
            destination: .leftOfItem(divider),
            sectionItems: [otherItem, resolved]
        )

        #expect(reached)
    }

    @Test("An item missing from the section has not reached its position")
    func missingItemIsNotReached() {
        let reached = LayoutBarPaddingView.itemReachedIntendedPosition(
            item: provisional,
            destination: .leftOfItem(otherItem),
            sectionItems: [otherItem]
        )

        #expect(!reached)
    }
}
