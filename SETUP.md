# Setup

1. Xcode > File > New > Project > Multiplatform > **Audio Unit Extension App**.
2. Product name: `AUv3Template`.
3. Audio Unit Type: **Instrument**.
4. Include a custom user interface.
5. Keep the generated SwiftUI/C++ architecture.
6. Copy the files under `TemplateSources/UI` into the extension UI group.
7. Add the two parameters from `TemplateSources/Parameters/ParameterSpec.swift` to the generated parameter specification.
8. Apply the DSP fragment in `TemplateSources/DSP/SineDSP.hpp` to the generated DSP kernel.
9. Use `TemplateSources/App/ContentView.swift` as the containing-app view.

The generated Instrument already implements MIDI note input and a mono sine oscillator. Keep Apple's generated event/render plumbing; the DSP fragment only adds pitch offset and volume behavior.

## Test

Build the containing app once on the iPad so the extension registers. Then open Logic Pro for iPad, add an Instrument plug-in, and select the AUv3 component. Play MIDI notes. Pitch changes tuning in semitones; Volume changes output level.

The SwiftUI view uses Liquid Glass on iOS/iPadOS 26+ and a material fallback on older systems.
