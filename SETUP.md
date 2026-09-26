# Setup

Verified against the Audio Unit Extension App template in Xcode 27.0 (27A5209h).
File names assume the product name `AUv3Template`; Xcode then names the extension `AUv3TemplateExtension`
and prefixes generated files with it. If you pick another name, rename the `AUv3TemplateExtension` prefix accordingly.

## 1. Generate the project

Xcode > File > New > Project > Multiplatform > **Audio Unit Extension App**

- Product name: `AUv3Template`
- Audio Unit Type: **Instrument**
- User interface: **SwiftUI**

## 2. Extension target — replace generated files

| TemplateSources file | Replaces generated file |
|---|---|
| `Parameters/AUv3TemplateExtensionParameterAddresses.h` | `Parameters/AUv3TemplateExtensionParameterAddresses.h` |
| `Parameters/Parameters.swift` | `Parameters/Parameters.swift` |
| `DSP/AUv3TemplateExtensionDSPKernel.hpp` | `DSP/AUv3TemplateExtensionDSPKernel.hpp` |
| `UI/AUv3TemplateExtensionMainView.swift` | `UI/AUv3TemplateExtensionMainView.swift` |

Add `UI/InstrumentView.swift` to the extension's UI group.

`DSP/SinOscillator.h` and `UI/ParameterSlider.swift` are no longer referenced and may be deleted.
Keep everything else generated (AudioUnit, AUProcessHelper, AudioUnitViewController, ObservableAUParameter, ParameterSpecBase).

## 3. App target — in-process baseline

The generated app already shows the extension's own view (out of process). To also render the same
`InstrumentView` in-process for the T1 baseline:

1. Add these files to the **app** target membership as well (they stay in the extension too):
   - `UI/InstrumentView.swift`
   - `UI/AUv3TemplateExtensionMainView.swift`
   - the generated `Common/UI/ObservableAUParameter.swift`
2. Add one line to the generated `Model/AudioUnitHostModel.swift`, next to `isPlaying`:
   ```swift
   var auAudioUnit: AUAudioUnit? { playEngine.avAudioUnit?.auAudioUnit }
   ```
3. Replace the generated `ContentView.swift` with `App/ContentView.swift`.

The app then has a segmented switch: **In-process SwiftUI** vs **AUv3 view (extension)**.

## What changed vs. the generated Instrument

- Parameters: `gain` (address 0) is replaced by `pitch` (0, semitones, -24...+24) and `volume` (1, dB, -60...0; -60 = silence).
- DSP: mono last-note priority (releasing a non-sounding note no longer cuts the current one), 5 ms attack / 30 ms release,
  ~10 ms smoothing on pitch and volume, phase-continuous legato, CC 120/123 all-off.
  Parameter targets are relaxed atomics written from the main thread; frequency/gain math runs only on change.
- UI: interactive Liquid Glass knob and fader in a `GlassEffectContainer`, a glass panel, an animated test backdrop,
  and an on-screen label with process / OS / accessibility state for screenshots.

## Test

Build and run the containing app once on the iPad so the extension registers, then follow `TEST_REQUIREMENTS.md`.
