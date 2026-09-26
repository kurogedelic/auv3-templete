# AUv3 Liquid Glass Test Requirements

## Primary question

Verify on real hardware whether a native SwiftUI UI embedded in an AUv3 app extension renders Apple's Liquid Glass correctly when the extension is hosted inside Logic Pro for iPad.

This is the primary purpose of this template. A successful standalone app alone is not sufficient.

## Test environment

- Current shipping iPadOS 26.x
- Physical iPad capable of running Logic Pro
- Current Logic Pro for iPad
- Build with the current Xcode / iOS SDK
- AUv3 installed by first launching the containing app

Record exact iPad model, iPadOS version, Logic Pro version and Xcode build for each result.

## UI under test

The containing app and AUv3 extension must use the same SwiftUI InstrumentView.

Required controls:

- Pitch: custom SwiftUI knob, -24...+24 semitones
- Volume: SwiftUI fader, -60...0 dB
- At least one view with explicit `.glassEffect(.regular)`
- At least one interactive glass control using `.interactive()` where appropriate
- No screenshot, pre-rendered imitation, custom blur approximation, or UIKit recreation of Liquid Glass

The test is specifically for the system Liquid Glass implementation.

## T1 — Standalone baseline

Launch the containing app on iPad. Test both modes of the app's segmented switch:

- **In-process SwiftUI** — the true baseline; InstrumentView is rendered by the app process.
- **AUv3 view (extension)** — the extension's view controller, rendered out of process as in Logic.

If in-process passes and the extension view already fails here, the cause is the remote-view path, not Logic.

PASS when:
- SwiftUI UI renders correctly.
- Explicit glass surfaces visibly render Liquid Glass.
- Touch interaction produces the expected system response.
- Pitch and Volume controls operate normally.

Capture a screenshot or short screen recording as the baseline.

## T2 — AUv3 discovery

Launch Logic Pro for iPad and create a software instrument track.

PASS when:
- The extension appears under Audio Units.
- Logic can instantiate the AUv3 instrument without crashing or falling back to a generic parameter-only UI.

## T3 — Liquid Glass inside Logic Pro

Open the AUv3 plug-in's custom UI in Logic Pro.

This is the critical test.

PASS when:
- The same SwiftUI InstrumentView appears inside Logic.
- Views carrying `.glassEffect()` retain the system Liquid Glass appearance.
- Glass remains dynamic rather than becoming an opaque/static approximation.
- Interactive glass responds to touch while hosted by Logic.
- No visual corruption occurs at the boundary between Logic's host UI and the extension UI.

FAIL when:
- Logic shows only a generic AU parameter UI.
- The custom SwiftUI UI does not load.
- `.glassEffect()` disappears or degrades to an obviously different non-glass rendering specifically when hosted.
- The extension crashes or the UI becomes unusable.

Record screenshots/video of both standalone and hosted states at the same UI settings.

Note: the extension UI runs in a separate process, so its glass cannot refract Logic's own UI behind it.
Judge the glass against InstrumentView's built-in animated backdrop, which is identical in every mode.
The on-screen context label identifies the rendering process, OS version and accessibility state.

## T4 — Host window resizing

Resize/change the plug-in Details view where Logic permits it, rotate the iPad, and reopen the plug-in UI.

PASS when:
- SwiftUI layout adapts without clipping.
- Glass shapes remain aligned to their views.
- Controls remain usable.
- State is not unexpectedly reset by ordinary UI recreation.

## T5 — MIDI/audio

Send MIDI notes from Logic.

PASS when:
- Note On starts the sine oscillator.
- Note Off stops the note.
- Pitch changes oscillator pitch by the displayed semitone offset.
- Volume changes output gain.
- UI manipulation does not cause obvious audio glitches.

Liquid Glass rendering must never be performed from the real-time audio render path.

## T6 — Accessibility appearance

At minimum test:
- Reduce Transparency ON/OFF
- Reduce Motion ON/OFF
- Light/Dark appearance where applicable

PASS when the UI remains readable and usable. Changes to Liquid Glass caused intentionally by system accessibility settings are expected and are not a failure.

## Result matrix

| Test | Standalone | Logic Pro iPad AUv3 | Notes |
|---|---|---|---|
| SwiftUI custom UI | TBD | TBD | |
| Explicit Liquid Glass | TBD | TBD | |
| Interactive glass | TBD | TBD | |
| Pitch knob | TBD | TBD | |
| Volume fader | TBD | TBD | |
| MIDI sine synth | TBD | TBD | |
| Rotation/resizing | TBD | TBD | |
| Accessibility settings | TBD | TBD | |

## Decision

Do not treat “SwiftUI/AUv3 supports this in principle” as proof.

The architecture is accepted for future products only after T3 passes on physical iPad hardware in Logic Pro for iPad. If standalone passes but T3 fails, preserve the DSP/AUv3 architecture and investigate the hosted UI path before building a product on this template.
