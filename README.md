# AUv3 SwiftUI Instrument Template

Minimal iOS/iPadOS AUv3 instrument starter for current Xcode.

- AUv3 Instrument (MIDI in, audio out)
- monophonic sine oscillator
- Pitch parameter: -24...+24 semitones
- Volume parameter: -60...0 dB
- SwiftUI UI shared by the containing app and Audio Unit extension
- Liquid Glass controls on iOS/iPadOS 26+
- C++ real-time DSP via Apple's current Audio Unit Extension App template architecture

## Why this repo is source-first

Apple's Audio Unit Extension App template is versioned with Xcode and is the recommended project scaffold. Generate the Xcode project with **File > New > Project > Multiplatform > Audio Unit Extension App**, select **Instrument** and **SwiftUI**, then replace/add the files in `TemplateSources/`.

This avoids freezing a stale hand-written `.pbxproj` while keeping the reusable AU code here.

See `SETUP.md`.

## Component identity

Use your own 4-character manufacturer/subtype when turning this into a product. Do not ship multiple copied plug-ins with the same component identity.
