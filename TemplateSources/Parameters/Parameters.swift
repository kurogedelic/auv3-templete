import Foundation
import AudioToolbox

// Replaces the generated Parameters.swift.
// Ranges must match the clamps in AUv3TemplateExtensionDSPKernel.hpp.
let AUv3TemplateExtensionParameterSpecs = ParameterTreeSpec {
    ParameterGroupSpec(identifier: "global", name: "Global") {
        ParameterSpec(
            address: .pitch,
            identifier: "pitch",
            name: "Pitch",
            units: .relativeSemiTones,
            valueRange: -24.0...24.0,
            defaultValue: 0.0
        )
        ParameterSpec(
            address: .volume,
            identifier: "volume",
            name: "Volume",
            units: .decibels,
            valueRange: -60.0...0.0,
            defaultValue: -12.0
        )
    }
}

extension ParameterSpec {
    init(
        address: AUv3TemplateExtensionParameterAddress,
        identifier: String,
        name: String,
        units: AudioUnitParameterUnit,
        valueRange: ClosedRange<AUValue>,
        defaultValue: AUValue,
        unitName: String? = nil,
        flags: AudioUnitParameterOptions = [AudioUnitParameterOptions.flag_IsWritable, AudioUnitParameterOptions.flag_IsReadable],
        valueStrings: [String]? = nil,
        dependentParameters: [NSNumber]? = nil
    ) {
        self.init(address: address.rawValue,
                  identifier: identifier,
                  name: name,
                  units: units,
                  valueRange: valueRange,
                  defaultValue: defaultValue,
                  unitName: unitName,
                  flags: flags,
                  valueStrings: valueStrings,
                  dependentParameters: dependentParameters)
    }
}
