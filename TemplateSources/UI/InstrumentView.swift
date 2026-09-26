import SwiftUI

/// Reusable UI surface for both the containing app and the AUv3 extension.
/// `AUv3TemplateExtensionMainView` binds it to the AU parameter tree.
///
/// The view draws its own animated backdrop: an out-of-process AUv3 view cannot
/// sample the host's pixels, so glass is only comparable standalone vs. hosted
/// if there is identical content behind it in both cases.
struct InstrumentView: View {
    @Binding var pitch: Float
    @Binding var volume: Float
    var onPitchEditingChanged: (Bool) -> Void = { _ in }
    var onVolumeEditingChanged: (Bool) -> Void = { _ in }

    static let pitchRange: ClosedRange<Float> = -24...24
    static let volumeRange: ClosedRange<Float> = -60...0

    var body: some View {
        ZStack {
            GlassTestBackdrop()

            VStack(spacing: 24) {
                Text("SINE")
                    .font(.system(.title2, design: .rounded, weight: .semibold))

                GlassControlGroup {
                    HStack(alignment: .bottom, spacing: 44) {
                        VStack(spacing: 12) {
                            PitchKnob(value: $pitch, range: Self.pitchRange, onEditingChanged: onPitchEditingChanged)
                                .frame(width: 120, height: 120)
                            Text("PITCH")
                                .font(.caption)
                            Text(String(format: "%+.1f st", pitch))
                                .font(.caption.monospacedDigit())
                                .foregroundStyle(.secondary)
                        }

                        VStack(spacing: 12) {
                            VolumeFader(value: $volume, range: Self.volumeRange, onEditingChanged: onVolumeEditingChanged)
                                .frame(width: 48, height: 160)
                            Text("VOLUME")
                                .font(.caption)
                            Text(volume <= Self.volumeRange.lowerBound ? "-inf dB" : String(format: "%.1f dB", volume))
                                .font(.caption.monospacedDigit())
                                .foregroundStyle(.secondary)
                        }
                    }
                }

                TestContextLabel()
            }
            .padding(32)
            .modifier(GlassPanel())
            .padding()
        }
    }
}

// MARK: - Controls

private struct PitchKnob: View {
    @Binding var value: Float
    let range: ClosedRange<Float>
    let onEditingChanged: (Bool) -> Void

    private var fraction: Double {
        Double((value - range.lowerBound) / (range.upperBound - range.lowerBound))
    }

    var body: some View {
        ZStack {
            Circle()
                .trim(from: 0, to: 0.75)
                .stroke(.primary.opacity(0.15), style: StrokeStyle(lineWidth: 4, lineCap: .round))
                .rotationEffect(.degrees(135))
            Circle()
                .trim(from: 0, to: 0.75 * fraction)
                .stroke(.tint, style: StrokeStyle(lineWidth: 4, lineCap: .round))
                .rotationEffect(.degrees(135))
            Capsule()
                .fill(.primary)
                .frame(width: 3, height: 30)
                .offset(y: -28)
                .rotationEffect(.degrees(-135 + fraction * 270))
        }
        .padding(10)
        .modifier(InteractiveGlass(shape: Circle()))
        .contentShape(Circle())
        .modifier(ParameterDrag(value: $value, range: range, onEditingChanged: onEditingChanged) { start, translation in
            start - Float(translation.height) * 0.15
        })
        .accessibilityElement()
        .accessibilityLabel("Pitch")
        .accessibilityValue(String(format: "%+.1f semitones", value))
        .accessibilityAdjustableAction { direction in
            let step: Float = direction == .increment ? 1 : -1
            value = min(range.upperBound, max(range.lowerBound, value + step))
        }
    }
}

private struct VolumeFader: View {
    @Binding var value: Float
    let range: ClosedRange<Float>
    let onEditingChanged: (Bool) -> Void

    private let thumbHeight: CGFloat = 28

    private var fraction: CGFloat {
        CGFloat((value - range.lowerBound) / (range.upperBound - range.lowerBound))
    }

    var body: some View {
        GeometryReader { proxy in
            let travel = max(1, proxy.size.height - thumbHeight)

            ZStack(alignment: .bottom) {
                Capsule()
                    .fill(.primary.opacity(0.12))
                    .frame(width: 6)
                Capsule()
                    .fill(.tint)
                    .frame(width: 6, height: thumbHeight / 2 + travel * fraction)
                Capsule()
                    .fill(.clear)
                    .frame(width: proxy.size.width, height: thumbHeight)
                    .modifier(InteractiveGlass(shape: Capsule()))
                    .offset(y: -travel * fraction)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
            .contentShape(Rectangle())
            .modifier(ParameterDrag(value: $value, range: range, onEditingChanged: onEditingChanged) { start, translation in
                start - Float(translation.height / travel) * (range.upperBound - range.lowerBound)
            })
        }
        .accessibilityElement()
        .accessibilityLabel("Volume")
        .accessibilityValue(String(format: "%.1f decibels", value))
        .accessibilityAdjustableAction { direction in
            let step: Float = direction == .increment ? 1 : -1
            value = min(range.upperBound, max(range.lowerBound, value + step))
        }
    }
}

/// Relative drag that reports begin/end editing for correct AU automation (touch/release).
/// `@GestureState` resets on cancellation too, so editing always ends even if `onEnded` never fires.
private struct ParameterDrag: ViewModifier {
    @Binding var value: Float
    let range: ClosedRange<Float>
    let onEditingChanged: (Bool) -> Void
    let valueForDrag: (_ start: Float, _ translation: CGSize) -> Float

    @State private var dragStart: Float?
    @GestureState private var isDragging = false

    func body(content: Content) -> some View {
        content
            .gesture(
                DragGesture(minimumDistance: 0)
                    .updating($isDragging) { _, state, _ in state = true }
                    .onChanged { gesture in
                        if dragStart == nil {
                            dragStart = value
                            onEditingChanged(true)
                        }
                        let proposed = valueForDrag(dragStart ?? value, gesture.translation)
                        value = min(range.upperBound, max(range.lowerBound, proposed))
                    }
            )
            .onChange(of: isDragging) { _, dragging in
                if !dragging, dragStart != nil {
                    dragStart = nil
                    onEditingChanged(false)
                }
            }
    }
}

// MARK: - Liquid Glass

/// Groups the interactive glass controls so they render as one glass layer.
private struct GlassControlGroup<Content: View>: View {
    @ViewBuilder var content: Content

    var body: some View {
        if #available(iOS 26.0, macOS 26.0, *) {
            GlassEffectContainer(spacing: 24) { content }
        } else {
            content
        }
    }
}

private struct InteractiveGlass<S: Shape>: ViewModifier {
    let shape: S

    func body(content: Content) -> some View {
        if #available(iOS 26.0, macOS 26.0, *) {
            content.glassEffect(.regular.interactive(), in: shape)
        } else {
            content.background(.thinMaterial, in: shape)
        }
    }
}

private struct GlassPanel: ViewModifier {
    func body(content: Content) -> some View {
        if #available(iOS 26.0, macOS 26.0, *) {
            content.glassEffect(.regular, in: .rect(cornerRadius: 28))
        } else {
            content.background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 28))
        }
    }
}

// MARK: - Test fixtures

/// Moving, high-contrast content behind the glass so refraction and dynamics are visible.
/// Honors Reduce Motion by freezing the animation.
private struct GlassTestBackdrop: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        TimelineView(.animation(paused: reduceMotion)) { context in
            let t = context.date.timeIntervalSinceReferenceDate

            Canvas { ctx, size in
                ctx.fill(Path(CGRect(origin: .zero, size: size)),
                         with: .linearGradient(Gradient(colors: [.indigo, .teal]),
                                               startPoint: .zero,
                                               endPoint: CGPoint(x: size.width, y: size.height)))

                let stripe: CGFloat = 24
                var x: CGFloat = -size.height
                while x < size.width {
                    var path = Path()
                    path.move(to: CGPoint(x: x, y: size.height))
                    path.addLine(to: CGPoint(x: x + size.height, y: 0))
                    ctx.stroke(path, with: .color(.white.opacity(0.18)), lineWidth: 6)
                    x += stripe * 2
                }

                let blobs: [(Color, Double, Double)] = [(.orange, 0.7, 0), (.pink, 0.5, 2), (.yellow, 0.9, 4)]
                for (color, speed, offset) in blobs {
                    let center = CGPoint(x: size.width * (0.5 + 0.35 * sin(t * speed + offset)),
                                         y: size.height * (0.5 + 0.35 * cos(t * speed * 0.8 + offset)))
                    let r = min(size.width, size.height) * 0.22
                    ctx.fill(Path(ellipseIn: CGRect(x: center.x - r, y: center.y - r, width: r * 2, height: r * 2)),
                             with: .color(color.opacity(0.85)))
                }
            }
        }
        .ignoresSafeArea()
        .accessibilityHidden(true)
    }
}

/// Printed on screen so screenshots/recordings identify which process rendered them.
private struct TestContextLabel: View {
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.colorScheme) private var colorScheme

    private var process: String {
        Bundle.main.bundleURL.pathExtension == "appex" ? "AUv3 extension process" : "App process (in-process SwiftUI)"
    }

    var body: some View {
        VStack(spacing: 2) {
            Text(process)
            Text(ProcessInfo.processInfo.operatingSystemVersionString)
            Text("ReduceTransparency \(reduceTransparency ? "ON" : "OFF") · ReduceMotion \(reduceMotion ? "ON" : "OFF") · \(colorScheme == .dark ? "Dark" : "Light")")
        }
        .font(.caption2.monospaced())
        .foregroundStyle(.secondary)
        .multilineTextAlignment(.center)
    }
}

#Preview {
    @Previewable @State var pitch: Float = 0
    @Previewable @State var volume: Float = -12
    InstrumentView(pitch: $pitch, volume: $volume)
}
