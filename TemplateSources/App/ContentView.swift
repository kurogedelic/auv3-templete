import AudioToolbox
import SwiftUI

// Replaces the generated containing-app ContentView.
// Requires one addition to the generated AudioUnitHostModel (see SETUP.md):
//     var auAudioUnit: AUAudioUnit? { playEngine.avAudioUnit?.auAudioUnit }
struct ContentView: View {
    let hostModel: AudioUnitHostModel
    @State private var isSheetPresented = false
    @State private var mode: Mode = .inProcess
    @State private var localParameterTree: ObservableAUParameterGroup?

    enum Mode: String, CaseIterable, Identifiable {
        case inProcess = "In-process SwiftUI"
        case remote = "AUv3 view (extension)"
        var id: Self { self }
    }

    var body: some View {
        VStack(spacing: 12) {
            HStack(spacing: 4) {
                Text(hostModel.viewModel.title)
                    .textSelection(.enabled)
                    .bold()
                if hostModel.audioUnitCrashed {
                    Text("crashed!")
                        .foregroundStyle(.red)
                }
            }
            ValidationView(hostModel: hostModel, isSheetPresented: $isSheetPresented)

            Picker("UI", selection: $mode) {
                ForEach(Mode.allCases) { Text($0.rawValue).tag($0) }
            }
            .pickerStyle(.segmented)
            .fixedSize()

            Group {
                switch mode {
                case .inProcess:
                    // T1 baseline: InstrumentView rendered by this process, driving the loaded AU's parameters.
                    if let tree = localParameterTree {
                        AUv3TemplateExtensionMainView(parameterTree: tree)
                    } else {
                        Text(hostModel.viewModel.message)
                    }
                case .remote:
                    // The extension's own view controller: same view, rendered out of process like in Logic.
                    if let viewController = hostModel.viewModel.viewController {
                        AUViewControllerUI(viewController: viewController)
                    } else {
                        Text(hostModel.viewModel.message)
                    }
                }
            }
            .frame(minWidth: 400, maxWidth: .infinity, minHeight: 420, maxHeight: .infinity)

            if hostModel.viewModel.showMIDIContols {
                Text("MIDI Input: Enabled")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
        .padding()
        .onChange(of: hostModel.auAudioUnit, initial: true) { _, audioUnit in
            // Build once per AU instance; observableParameterTree creates new observers on every call.
            localParameterTree = audioUnit?.observableParameterTree
        }
    }
}

#Preview {
    ContentView(hostModel: AudioUnitHostModel())
}
