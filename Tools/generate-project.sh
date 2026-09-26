#!/bin/zsh
# Generates a buildable Xcode project without the Xcode GUI:
# Apple's Audio Unit Extension App (Instrument, SwiftUI) template sources from the installed Xcode,
# overlaid with TemplateSources/, wired up by XcodeGen as one multiplatform (iOS + macOS) app + extension.
#
#   Tools/generate-project.sh [output-dir]      (default: build/AUv3Template)
#
# Environment overrides:
#   DEVELOPER_DIR   Xcode to take the template from   (default: xcode-select, falling back to /Applications/Xcode-beta.app)
#   TEAM_ID         signing team                       (default: empty = set it in Xcode)
#   BUNDLE_PREFIX   bundle identifier prefix           (default: com.example)
#   AU_MANUFACTURER 4-char manufacturer code           (default: Demo)
#   AU_SUBTYPE      4-char subtype code                (default: LqGl)
set -euo pipefail

REPO=${0:A:h:h}
OUT=${1:-$REPO/build/AUv3Template}
TEAM_ID=${TEAM_ID:-}
BUNDLE_PREFIX=${BUNDLE_PREFIX:-com.example}
AU_MANUFACTURER=${AU_MANUFACTURER:-Demo}
AU_SUBTYPE=${AU_SUBTYPE:-LqGl}
AU_TYPE=aumu

APP=AUv3Template
EXT=${APP}Extension

if [[ -z ${DEVELOPER_DIR:-} ]]; then
    DEVELOPER_DIR=$(xcode-select -p)
    [[ $DEVELOPER_DIR == */CommandLineTools ]] && DEVELOPER_DIR=/Applications/Xcode-beta.app/Contents/Developer
fi
TEMPLATES="$DEVELOPER_DIR/Library/Xcode/Templates/Project Templates/MultiPlatform"
APP_T="$TEMPLATES/Application/Audio Unit Extension App.xctemplate"
EXT_T="$TEMPLATES/Application Extension/Audio Unit Extension.xctemplate"
[[ -d $APP_T && -d $EXT_T ]] || { echo "Audio Unit templates not found under $TEMPLATES" >&2; exit 1; }
command -v xcodegen >/dev/null || { echo "xcodegen is required (brew install xcodegen)" >&2; exit 1; }

# copy_template <src> <dst> <package identifier>
copy_template() {
    mkdir -p ${2:h}
    if [[ $1 == *.swift || $1 == *.h || $1 == *.hpp ]]; then
        sed -e 's/___FILEHEADER___//' \
            -e "s/___PACKAGENAMEASIDENTIFIER___/$3/g" \
            -e "s/___PACKAGENAMEASRFC1034IDENTIFIER___/$3/g" \
            -e "s/___VARIABLE_bundleIdentifierPrefix:bundleIdentifier___/$BUNDLE_PREFIX/g" \
            -e "s/___VARIABLE_audioUnitTypeCode___/$AU_TYPE/g" \
            -e "s/___VARIABLE_audioUnitSubtypeCode___/$AU_SUBTYPE/g" \
            -e "s/___VARIABLE_audioUnitManufacturerCode___/$AU_MANUFACTURER/g" \
            "$1" > "$2"
    else
        cp "$1" "$2"
    fi
}

rm -rf "$OUT"
mkdir -p "$OUT/$APP" "$OUT/$EXT"

# App target: generated sources. App.entitlements (inter-app-audio) is required on iOS,
# otherwise the system never registers the embedded AUv3 component.
(cd "$APP_T" && find . -type f ! -name TemplateInfo.plist) | while read -r f; do
    f=${f#./}
    dst=${f//___PACKAGENAMEASIDENTIFIER___/$APP}
    [[ $f == App.swift ]] && dst=${APP}App.swift
    copy_template "$APP_T/$f" "$OUT/$APP/$dst" $APP
done

# Extension target: shared + UI-specific + Instrument sources.
for part in _Shared _UISpecific Instrument; do
    (cd "$EXT_T/$part" && find . -type f) | while read -r f; do
        f=${f#./}
        [[ $f == */SinOscillator.h || $f == */ParameterSlider.swift ]] && continue # superseded by TemplateSources
        [[ $f == README.md ]] && continue
        copy_template "$EXT_T/$part/$f" "$OUT/$EXT/${f//___PACKAGENAMEASIDENTIFIER___/$EXT}" $EXT
    done
done

# Overlay TemplateSources (see SETUP.md for the manual equivalent).
cp "$REPO/TemplateSources/Parameters/"* "$OUT/$EXT/Parameters/"
cp "$REPO/TemplateSources/DSP/"* "$OUT/$EXT/DSP/"
cp "$REPO/TemplateSources/UI/"* "$OUT/$EXT/UI/"
cp "$REPO/TemplateSources/App/ContentView.swift" "$OUT/$APP/ContentView.swift"
perl -0pi -e 's/(    var isPlaying: Bool \{ playEngine\.isPlaying \}\n)/$1\n    var auAudioUnit: AUAudioUnit? { playEngine.avAudioUnit?.auAudioUnit }\n/' "$OUT/$APP/Model/AudioUnitHostModel.swift"
grep -q 'var auAudioUnit' "$OUT/$APP/Model/AudioUnitHostModel.swift" || { echo "Failed to patch AudioUnitHostModel.swift" >&2; exit 1; }

cat > "$OUT/project.yml" <<YAML
name: $APP
options:
  bundleIdPrefix: $BUNDLE_PREFIX
  deploymentTarget:
    iOS: "26.0"
    macOS: "26.0"
settings:
  base:
    DEVELOPMENT_TEAM: "$TEAM_ID"
    CODE_SIGN_STYLE: Automatic
    SWIFT_VERSION: "6.0"
    MARKETING_VERSION: "1.0"
    CURRENT_PROJECT_VERSION: "1"
    CLANG_CXX_LANGUAGE_STANDARD: c++20
    CLANG_CXX_LIBRARY: libc++
    ENABLE_APP_SANDBOX: YES
    ENABLE_USER_SELECTED_FILES: readonly
targets:
  $APP:
    type: application
    supportedDestinations: [iOS, macOS]
    sources:
      - path: $APP
      # Same view, rendered in-process for the T1 baseline.
      - path: $EXT/UI/InstrumentView.swift
      - path: $EXT/UI/${EXT}MainView.swift
      - path: $EXT/Common/UI/ObservableAUParameter.swift
    settings:
      base:
        PRODUCT_BUNDLE_IDENTIFIER: $BUNDLE_PREFIX.$APP
        GENERATE_INFOPLIST_FILE: YES
        INFOPLIST_KEY_CFBundleDisplayName: $APP
        INFOPLIST_KEY_UILaunchScreen_Generation: YES
        INFOPLIST_KEY_UIApplicationSceneManifest_Generation: YES
        INFOPLIST_KEY_UISupportedInterfaceOrientations: "UIInterfaceOrientationPortrait UIInterfaceOrientationPortraitUpsideDown UIInterfaceOrientationLandscapeLeft UIInterfaceOrientationLandscapeRight"
        INFOPLIST_KEY_NSMicrophoneUsageDescription: "Not used; required by some audio session configurations."
        ENABLE_HARDENED_RUNTIME: YES
        ASSETCATALOG_COMPILER_APPICON_NAME: "" # the template ships no AppIcon set
        CODE_SIGN_ENTITLEMENTS[sdk=iphoneos*]: $APP/App.entitlements
        OTHER_LDFLAGS: "-framework AudioToolbox -framework AVFoundation"
        TARGETED_DEVICE_FAMILY: "1,2"
    dependencies:
      - target: $EXT
        embed: true
  $EXT:
    type: app-extension
    supportedDestinations: [iOS, macOS]
    sources:
      - path: $EXT
    info:
      path: $EXT/Info.plist
      properties:
        CFBundleDisplayName: $EXT
        NSExtension:
          NSExtensionPointIdentifier: com.apple.AudioUnit-UI
          NSExtensionPrincipalClass: \$(PRODUCT_MODULE_NAME).AudioUnitViewController
          NSExtensionAttributes:
            AudioComponents:
              - description: $EXT
                factoryFunction: \$(PRODUCT_MODULE_NAME).AudioUnitViewController
                manufacturer: $AU_MANUFACTURER
                name: "AUv3Template: Liquid Glass Sine"
                sandboxSafe: true
                subtype: $AU_SUBTYPE
                tags: [Synthesizer]
                type: $AU_TYPE
                version: 67072
    settings:
      base:
        PRODUCT_BUNDLE_IDENTIFIER: $BUNDLE_PREFIX.$APP.$EXT
        SWIFT_OBJC_BRIDGING_HEADER: $EXT/Common/$EXT-Bridging-Header.h
        SWIFT_OBJC_INTEROP_MODE: objcxx
        TARGETED_DEVICE_FAMILY: "1,2"
YAML

(cd "$OUT" && xcodegen generate --quiet)
echo "Generated $OUT/$APP.xcodeproj"
