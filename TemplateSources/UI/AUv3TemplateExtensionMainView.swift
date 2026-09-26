import SwiftUI

// Replaces the generated MainView. Also added to the app target so the containing
// app can render the same view in-process for the standalone baseline.
struct AUv3TemplateExtensionMainView: View {
    var parameterTree: ObservableAUParameterGroup

    var body: some View {
        ParameterBoundInstrumentView(
            pitch: parameterTree.global.pitch,
            volume: parameterTree.global.volume
        )
    }
}

private struct ParameterBoundInstrumentView: View {
    @Bindable var pitch: ObservableAUParameter
    @Bindable var volume: ObservableAUParameter

    var body: some View {
        InstrumentView(
            pitch: $pitch.value,
            volume: $volume.value,
            onPitchEditingChanged: pitch.onEditingChanged,
            onVolumeEditingChanged: volume.onEditingChanged
        )
    }
}
