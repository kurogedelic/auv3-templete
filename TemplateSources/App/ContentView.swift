import SwiftUI

struct ContentView: View {
    @State private var pitch: Float = 0
    @State private var volume: Float = -12

    var body: some View {
        InstrumentView(pitch: $pitch, volume: $volume)
            .padding()
    }
}
