#pragma once

#import <AudioToolbox/AudioToolbox.h>
#import <CoreMIDI/CoreMIDI.h>
#import <algorithm>
#import <array>
#import <atomic>
#import <cmath>
#import <cstdint>
#import <limits>
#import <numbers>
#import <span>

#import "AUv3TemplateExtensionParameterAddresses.h"

/// Lock-free float for values written on the main thread and read on the render thread.
/// Copyable (unlike std::atomic) so the kernel stays importable into Swift as a value type.
struct RelaxedAtomicFloat {
    RelaxedAtomicFloat(float v = 0.0f) : mValue(v) {}
    RelaxedAtomicFloat(const RelaxedAtomicFloat& other) : mValue(other.load()) {}
    RelaxedAtomicFloat& operator=(const RelaxedAtomicFloat& other) { store(other.load()); return *this; }

    float load() const { return mValue.load(std::memory_order_relaxed); }
    void store(float v) { mValue.store(v, std::memory_order_relaxed); }

private:
    std::atomic<float> mValue;
};

/*
 AUv3TemplateExtensionDSPKernel
 Replaces the generated kernel of the same name (SinOscillator.h is no longer used).

 Monophonic sine, last-note priority, click-free:
 - linear attack/release envelope
 - one-pole smoothing for pitch and volume
 - parameter targets are relaxed atomics, so the main thread can write them while rendering

 As a non-ObjC class, this is safe to use from render thread.
 */
class AUv3TemplateExtensionDSPKernel {
public:
    static constexpr float kPitchMin = -24.0f;
    static constexpr float kPitchMax = 24.0f;
    static constexpr float kVolumeMin = -60.0f; // treated as silence
    static constexpr float kVolumeMax = 0.0f;

    void initialize(int channelCount, double inSampleRate) {
        mSampleRate = inSampleRate;
        mSmoothCoef = 1.0 - std::exp(-1.0 / (0.010 * mSampleRate)); // ~10 ms
        mAttackStep = 1.0 / (0.005 * mSampleRate);                   // 5 ms
        mReleaseStep = 1.0 / (0.030 * mSampleRate);                  // 30 ms

        mPhase = 0.0;
        mEnvelope = 0.0;
        mHeldCount = 0;
        mGate = false;

        updateTargets(true);
        mIncrement = mTargetIncrement;
        mGain = mTargetGain;
    }

    void deInitialize() {
    }

    // MARK: - Bypass
    bool isBypassed() {
        return mBypassed;
    }

    void setBypass(bool shouldBypass) {
        mBypassed = shouldBypass;
    }

    // MARK: - Parameter Getter / Setter
    // May be called from the main thread (implementorValueObserver) or the render thread (parameter events).
    void setParameter(AUParameterAddress address, AUValue value) {
        switch (address) {
            case AUv3TemplateExtensionParameterAddress::pitch:
                mPitchTarget.store(std::clamp(value, kPitchMin, kPitchMax));
                break;
            case AUv3TemplateExtensionParameterAddress::volume:
                mVolumeTarget.store(std::clamp(value, kVolumeMin, kVolumeMax));
                break;
        }
    }

    AUValue getParameter(AUParameterAddress address) {
        // Return the goal. It is not thread safe to return the ramping value.
        switch (address) {
            case AUv3TemplateExtensionParameterAddress::pitch:
                return mPitchTarget.load();
            case AUv3TemplateExtensionParameterAddress::volume:
                return mVolumeTarget.load();
            default: return 0.f;
        }
    }

    // MARK: - Max Frames
    AUAudioFrameCount maximumFramesToRender() const {
        return mMaxFramesToRender;
    }

    void setMaximumFramesToRender(const AUAudioFrameCount &maxFrames) {
        mMaxFramesToRender = maxFrames;
    }

    // MARK: - Musical Context
    void setMusicalContextBlock(AUHostMusicalContextBlock contextBlock) {
        mMusicalContextBlock = contextBlock;
    }

    // MARK: - MIDI Protocol
    MIDIProtocolID AudioUnitMIDIProtocol() const {
        return kMIDIProtocol_2_0;
    }

    /**
     MARK: - Internal Process

     Called by AUProcessHelper for each segment between render events,
     so note/parameter changes are picked up at the start of every segment.
     */
    void process(std::span<float *> outputBuffers, AUEventSampleTime bufferStartTime, AUAudioFrameCount frameCount) {
        if (mBypassed) {
            for (UInt32 channel = 0; channel < outputBuffers.size(); ++channel) {
                std::fill_n(outputBuffers[channel], frameCount, 0.f);
            }
            return;
        }

        updateTargets(false);

        for (UInt32 frameIndex = 0; frameIndex < frameCount; ++frameIndex) {
            const double envelopeTarget = mGate ? mVelocity : 0.0;
            if (mEnvelope < envelopeTarget) {
                mEnvelope = std::min(envelopeTarget, mEnvelope + mAttackStep);
            } else if (mEnvelope > envelopeTarget) {
                mEnvelope = std::max(envelopeTarget, mEnvelope - mReleaseStep);
            }

            mIncrement += (mTargetIncrement - mIncrement) * mSmoothCoef;
            mGain += (mTargetGain - mGain) * mSmoothCoef;

            const auto sample = float(std::sin(mPhase * (std::numbers::pi_v<double> * 2.0)) * mEnvelope * mGain);

            mPhase += mIncrement;
            mPhase -= std::floor(mPhase);

            for (UInt32 channel = 0; channel < outputBuffers.size(); ++channel) {
                outputBuffers[channel][frameIndex] = sample;
            }
        }
    }

    void handleOneEvent(AUEventSampleTime now, AURenderEvent const *event) {
        switch (event->head.eventType) {
            case AURenderEventParameter: {
                handleParameterEvent(now, event->parameter);
                break;
            }

            case AURenderEventMIDIEventList: {
                handleMIDIEventList(now, &event->MIDIEventsList);
                break;
            }

            default:
                break;
        }
    }

    void handleParameterEvent(AUEventSampleTime now, AUParameterEvent const& parameterEvent) {
        setParameter(parameterEvent.parameterAddress, parameterEvent.value);
    }

    void handleMIDIEventList(AUEventSampleTime now, AUMIDIEventList const* midiEvent) {
        auto visitor = [] (void* context, MIDITimeStamp timeStamp, MIDIUniversalMessage message) {
            auto thisObject = static_cast<AUv3TemplateExtensionDSPKernel *>(context);

            switch (message.type) {
                case kMIDIMessageTypeChannelVoice2: {
                    thisObject->handleMIDI2VoiceMessage(message);
                }
                    break;

                default:
                    break;
            }
        };

        MIDIEventListForEachEvent(&midiEvent->eventList, visitor, this);
    }

    void handleMIDI2VoiceMessage(const struct MIDIUniversalMessage& message) {
        const auto& note = message.channelVoice2.note;

        switch (message.channelVoice2.status) {
            case kMIDICVStatusNoteOff: {
                noteOff(note.number);
            }
                break;

            case kMIDICVStatusNoteOn: {
                if (note.velocity == 0) {
                    noteOff(note.number);
                } else {
                    noteOn(note.number, (double)note.velocity / (double)std::numeric_limits<std::uint16_t>::max());
                }
            }
                break;

            case kMIDICVStatusControlChange: {
                const auto index = message.channelVoice2.controlChange.index;
                if (index == 120 || index == 123) { // All Sound Off / All Notes Off
                    mHeldCount = 0;
                    mGate = false;
                }
            }
                break;

            default:
                break;
        }
    }

private:
    static constexpr int kMaxHeldNotes = 16;

    void noteOn(std::uint8_t number, double velocity) {
        removeHeld(number);
        if (mHeldCount == kMaxHeldNotes) {
            std::copy(mHeld.begin() + 1, mHeld.end(), mHeld.begin());
            --mHeldCount;
        }
        mHeld[mHeldCount++] = number;

        if (mEnvelope == 0.0) {
            mPhase = 0.0; // start from a zero crossing when silent
        }
        mCurrentNote = number;
        mVelocity = velocity;
        mGate = true;
        mNoteChanged = true;
    }

    void noteOff(std::uint8_t number) {
        removeHeld(number);
        if (!mGate || number != mCurrentNote) {
            return; // releasing a note that is not sounding must not stop the current one
        }
        if (mHeldCount > 0) {
            mCurrentNote = mHeld[mHeldCount - 1]; // fall back to the most recent held note
            mNoteChanged = true;
        } else {
            mGate = false;
        }
    }

    void removeHeld(std::uint8_t number) {
        const auto end = std::remove(mHeld.begin(), mHeld.begin() + mHeldCount, number);
        mHeldCount = int(end - mHeld.begin());
    }

    // Converts parameter/note state to per-sample targets. Transcendental math only runs on change.
    void updateTargets(bool force) {
        const float pitch = mPitchTarget.load();
        const float volume = mVolumeTarget.load();

        if (force || mNoteChanged || pitch != mCachedPitch) {
            const double noteNumber = double(mCurrentNote) + double(pitch);
            mTargetIncrement = 440.0 * std::exp2((noteNumber - 69.0) / 12.0) / mSampleRate;
            if (mNoteChanged) {
                mIncrement = mTargetIncrement; // new notes jump; only the Pitch knob glides
            }
            mCachedPitch = pitch;
            mNoteChanged = false;
        }

        if (force || volume != mCachedVolume) {
            mTargetGain = volume <= kVolumeMin ? 0.0 : std::pow(10.0, double(volume) / 20.0);
            mCachedVolume = volume;
        }
    }

    // MARK: - Member Variables
    AUHostMusicalContextBlock mMusicalContextBlock;

    RelaxedAtomicFloat mPitchTarget { 0.0f };
    RelaxedAtomicFloat mVolumeTarget { -12.0f };
    float mCachedPitch = 0.0f;
    float mCachedVolume = -12.0f;

    double mSampleRate = 44100.0;
    double mSmoothCoef = 1.0;
    double mAttackStep = 1.0;
    double mReleaseStep = 1.0;

    double mPhase = 0.0;
    double mIncrement = 0.0;
    double mTargetIncrement = 0.0;
    double mGain = 0.0;
    double mTargetGain = 0.0;
    double mEnvelope = 0.0;
    double mVelocity = 0.0;

    std::array<std::uint8_t, kMaxHeldNotes> mHeld {};
    int mHeldCount = 0;
    std::uint8_t mCurrentNote = 69;
    bool mGate = false;
    bool mNoteChanged = false;

    bool mBypassed = false;
    AUAudioFrameCount mMaxFramesToRender = 1024;
};
