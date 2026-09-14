//
//  IceSlider.swift
//  Project: xBar
//
//  Copyright (Ice) © 2023–2025 Jordan Baird
//  Copyright (xBar) © 2026 Toni Förster
//  Licensed under the GNU GPLv3

import SwiftUI

struct IceSlider: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Binding private var value: Double

    private let bounds: ClosedRange<Double>
    private let step: Double?
    private let reversed: Bool
    private let showsValue: Bool
    private let unit: String?
    private let valueLabel: AnyView

    @State private var isLabelActive: Bool

    init<Value: BinaryFloatingPoint, ValueLabel: View>(
        value: Binding<Value>,
        in bounds: ClosedRange<Value>,
        step: Value? = nil,
        reversed: Bool = false,
        showsValue: Bool = false,
        unit: String? = nil,
        @ViewBuilder valueLabel: () -> ValueLabel
    ) {
        self._value = Binding(
            get: { Double(value.wrappedValue) },
            set: { value.wrappedValue = Value($0) }
        )
        self.bounds = Double(bounds.lowerBound)...Double(bounds.upperBound)
        self.step = step.map { Double($0) }
        self.reversed = reversed
        self.showsValue = showsValue
        self.unit = unit
        self.valueLabel = AnyView(valueLabel())
        self._isLabelActive = State(initialValue: false)
    }

    init<Value: BinaryFloatingPoint>(
        _ valueLabelKey: LocalizedStringKey,
        value: Binding<Value>,
        in bounds: ClosedRange<Value>,
        step: Value? = nil,
        reversed: Bool = false,
        showsValue: Bool = false,
        unit: String? = nil
    ) {
        self.init(
            value: value,
            in: bounds,
            step: step,
            reversed: reversed,
            showsValue: showsValue,
            unit: unit
        ) {
            Text(valueLabelKey)
        }
    }

    private var height: CGFloat {
        24
    }

    private var borderShape: some InsettableShape {
        RoundedRectangle(cornerRadius: 10, style: .continuous)
    }

    private var progress: Double {
        let span = bounds.upperBound - bounds.lowerBound
        guard span > 0 else { return 0 }
        let current = value - bounds.lowerBound
        return min(max(current / span, 0), 1)
    }

    private func updateValue(for progress: Double) {
        let span = bounds.upperBound - bounds.lowerBound
        var newValue = bounds.lowerBound + (progress * span)
        if let step = step {
            newValue = (newValue / step).rounded() * step
        }
        let clamped = min(max(newValue, bounds.lowerBound), bounds.upperBound)
        value = clamped
    }

    var body: some View {
        GeometryReader { proxy in
            let width = proxy.size.width
            let fillWidth = max(0, min(width, width * progress))
            ZStack(alignment: reversed ? .trailing : .leading) {
                // Progress fill
                Rectangle()
                    .fill(Color.accentColor.opacity(0.85))
                    .frame(width: fillWidth)

                // Label and value overlay
                HStack(spacing: 4) {
                    valueLabel
                        .scaleEffect(x: reversed ? -1 : 1, y: 1)
                    if showsValue {
                        Spacer()
                        if reversed {
                            if let unit {
                                Text(unit)
                                    .scaleEffect(x: -1, y: 1)
                            }
                            Text(value.formatted())
                                .monospacedDigit()
                                .scaleEffect(x: -1, y: 1)
                        } else {
                            Text(value.formatted())
                                .monospacedDigit()
                            if let unit {
                                Text(unit)
                            }
                        }
                    }
                }
                .padding(.horizontal, 8)
                .frame(height: height)
                .opacity(isLabelActive ? 0.9 : 0.6)
                .animation(reduceMotion ? nil : .easeInOut(duration: 0.15), value: isLabelActive)
                .allowsHitTesting(false)
            }
            .contentShape(borderShape)
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { gesture in
                        let locationX = reversed ? (width - gesture.location.x) : gesture.location.x
                        let newProgress = max(0, min(1, Double(locationX / width)))
                        updateValue(for: newProgress)
                    }
            )
            .onContinuousHover { phase in
                switch phase {
                case .active:
                    isLabelActive = true
                case .ended:
                    isLabelActive = false
                }
            }
        }
        .frame(height: height)
        .glassEffect(.regular, in: borderShape)
        .overlay(
            borderShape.strokeBorder(Color(nsColor: .separatorColor), lineWidth: 0.5)
        )
        .clipShape(borderShape)
    }
}
