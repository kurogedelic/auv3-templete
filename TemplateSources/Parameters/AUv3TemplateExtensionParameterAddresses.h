#pragma once

#include <AudioToolbox/AUParameters.h>

// Replaces the generated file of the same name.
// Shared by Swift (via the bridging header) and the C++ DSP kernel.
typedef NS_ENUM(AUParameterAddress, AUv3TemplateExtensionParameterAddress) {
    pitch = 0,
    volume = 1
};
