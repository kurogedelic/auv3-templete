import SwiftUI

/// Reusable UI surface for both the containing app and the AUv3 extension.
/// Bind these values to the generated AUParameter wrappers in the extension.
struct InstrumentView: View {
    @Binding var pitch: Float
    @Binding var volume: Float

    var body: some View {
        VStack(spacing: 28) {
            Text("SINE")
                .font(.system(.title2, design: .rounded, weight: .semibold))

            HStack(alignment: .center, spacing: 44) {
                VStack(spacing: 12) {
                    PitchKnob(value: $pitch)
                        .frame(width: 120, height: 120)
                    Text("PITCH")
                        .font(.caption)
                    Text(String(format: "%+.1f st", pitch))
                        .font(.caption.monospacedDigit())
                        .foregroundStyle(.secondary)
                }

                VStack(spacing: 12) {
                    Slider(value: $volume, in: -60...0)
                        .rotationEffect(.degrees(-90))
                        .frame(width: 120, height: 120)
                    Text("VOLUME")
                        .font(.caption)
                    Text(String(format: "%.1f dB", volume))
                        .font(.caption.monospacedDigit())
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding(32)
        .modifier(GlassPanel())
    }
}

private struct PitchKnob: View {
    @Binding var value: Float
    @State private var dragStart: Float?

    private var angle: Double {
        let t = Double((value + 24) / 48)
        return -135 + t * 270
    }

    var body: some View {
        ZStack {
            Circle().fill(.thinMaterial)
            Circle().stroke(.primary.opacity(0.16), lineWidth: 1)
            Capsule()
                .fill(.primary)
                .frame(width: 3, height: 38)
                .offset(y: -24)
                .rotationEffect(.degrees(angle))
        }
        .contentShape(Circle())
        .gesture(
            DragGesture(minimumDistance: 0)
                .onChanged { gesture in
                    if dragStart == nil { dragStart = value }
                    let start = dragStart ?? value
                    value = min(24, max(-24, start - Float(gesture.translation.height) * 0.15))
                }
                .onEnded { _ in dragStart = nil }
        )
        .accessibilityLabel("Pitch")
        .accessibilityValue(String(format: "%+.1f semitones", value))
        .accessibilityAdjustableAction { direction in
            let step: Float = direction == .increment ? 1 : -1
            value = min(24, max(-24, value + step))
        }
    }
}

private struct GlassPanel: ViewModifier {
    func body(content: Content) -> some View {
        if #available(iOS 26.0, *) {
            content
                .padding(8)
                .glassEffect(.regular, in: .rect(cornerRadius: 28))
        } else {
            content
                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 28))
        }
    }
}

#Preview {
    @Previewable @State var pitch: Float = 0
    @Previewable @State var volume: Float = -12
    InstrumentView(pitch: $pitch, volume: $volume)
        .padding()
}
