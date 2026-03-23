import AVFoundation

final class GuitarNoteEngine {
    static let shared = GuitarNoteEngine()

    private struct ToneConfiguration: Equatable {
        let preset: GuitarTonePreset
        let reverbLevel: AudioEffectLevel
        let delayLevel: AudioEffectLevel
    }

    private struct InstrumentDescriptor {
        let bundledResourceName: String
        let bundledFileExtension: String
        let program: UInt8
    }

    private let engine = AVAudioEngine()
    private let sampler = AVAudioUnitSampler()
    private let delay = AVAudioUnitDelay()
    private let reverb = AVAudioUnitReverb()
    private var activeMIDINote: UInt8?
    private var notePlaybackToken: UInt64 = 0
    private var toneConfiguration = ToneConfiguration(
        preset: .acoustic,
        reverbLevel: .off,
        delayLevel: .off
    )
    private let openMIDINotesByString: [Int: Int] = [
        6: 40,
        5: 45,
        4: 50,
        3: 55,
        2: 59,
        1: 64,
    ]

    private let instrumentByPreset: [GuitarTonePreset: InstrumentDescriptor] = [
        .acoustic: InstrumentDescriptor(bundledResourceName: "guitar_acoustic", bundledFileExtension: "sf2", program: 24),
        .electricClean: InstrumentDescriptor(bundledResourceName: "guitar_clean", bundledFileExtension: "sf2", program: 27),
        .electricDirty: InstrumentDescriptor(bundledResourceName: "guitar_dirty", bundledFileExtension: "sf2", program: 30),
    ]

    init() {
        engine.attach(sampler)
        engine.attach(delay)
        engine.attach(reverb)
        engine.connect(sampler, to: delay, format: nil)
        engine.connect(delay, to: reverb, format: nil)
        engine.connect(reverb, to: engine.mainMixerNode, format: nil)
        engine.mainMixerNode.outputVolume = 0.92
        configureEffects()
        loadInstrument(for: toneConfiguration.preset)
        configureAudioSession()
        startEngineIfNeeded()
    }

    func play(string: Int, fret: Int, velocity: Float = 0.92) {
        guard let openMIDINote = openMIDINotesByString[string] else { return }
        let midiNote = openMIDINote + max(fret, 0)
        play(midiNote: midiNote, velocity: velocity)
    }

    func configure(
        preset: GuitarTonePreset,
        reverbLevel: AudioEffectLevel,
        delayLevel: AudioEffectLevel
    ) {
        let newConfiguration = ToneConfiguration(
            preset: preset,
            reverbLevel: reverbLevel,
            delayLevel: delayLevel
        )
        guard newConfiguration != toneConfiguration else { return }
        let presetChanged = newConfiguration.preset != toneConfiguration.preset
        toneConfiguration = newConfiguration
        configureEffects()
        if presetChanged {
            loadInstrument(for: preset)
        }
    }

    func play(midiNote: Int, velocity: Float = 0.92) {
        let clampedMIDINote = min(max(midiNote, 24), 88)
        startEngineIfNeeded()
        if let activeMIDINote {
            sampler.stopNote(activeMIDINote, onChannel: 0)
        }
        engine.mainMixerNode.outputVolume = max(0.15, min(velocity, 1.0))
        let noteValue = UInt8(clampedMIDINote)
        let velocityValue = UInt8(max(1, min(Int(velocity * 127.0), 127)))
        sampler.startNote(noteValue, withVelocity: velocityValue, onChannel: 0)
        activeMIDINote = noteValue
        notePlaybackToken &+= 1
        let playbackToken = notePlaybackToken
        let releaseDelay = noteLength(for: toneConfiguration.preset)
        DispatchQueue.main.asyncAfter(deadline: .now() + releaseDelay) { [weak self] in
            guard let self else { return }
            guard self.notePlaybackToken == playbackToken else { return }
            guard self.activeMIDINote == noteValue else { return }
            self.sampler.stopNote(noteValue, onChannel: 0)
            self.activeMIDINote = nil
        }
    }

    private func loadInstrument(for preset: GuitarTonePreset) {
        guard let descriptor = instrumentByPreset[preset] else { return }

        let bundledCandidates: [URL?] = [
            Bundle.main.url(forResource: descriptor.bundledResourceName, withExtension: descriptor.bundledFileExtension),
            Bundle.main.url(forResource: descriptor.bundledResourceName, withExtension: "dls")
        ]

        for candidate in bundledCandidates {
            guard let instrumentURL = candidate else { continue }
            do {
                try sampler.loadSoundBankInstrument(
                    at: instrumentURL,
                    program: descriptor.program,
                    bankMSB: UInt8(kAUSampler_DefaultMelodicBankMSB),
                    bankLSB: 0
                )
                return
            } catch {
            }
        }

        for fallbackURL in fallbackSoundBankURLs() {
            do {
                try sampler.loadSoundBankInstrument(
                    at: fallbackURL,
                    program: descriptor.program,
                    bankMSB: UInt8(kAUSampler_DefaultMelodicBankMSB),
                    bankLSB: 0
                )
                return
            } catch {
            }
        }
    }

    private func configureEffects() {
        delay.bypass = toneConfiguration.delayLevel == .off
        delay.wetDryMix = wetDryMix(for: toneConfiguration.delayLevel)
        delay.delayTime = delayTime(for: toneConfiguration.preset)
        delay.feedback = feedback(for: toneConfiguration.delayLevel, preset: toneConfiguration.preset)
        delay.lowPassCutoff = toneConfiguration.preset == .electricDirty ? 8_500 : 11_500

        reverb.loadFactoryPreset(reverbPreset(for: toneConfiguration.preset))
        reverb.wetDryMix = wetDryMix(for: toneConfiguration.reverbLevel)
        reverb.bypass = toneConfiguration.reverbLevel == .off
    }

    private func wetDryMix(for level: AudioEffectLevel) -> Float {
        switch level {
        case .off:
            return 0
        case .low:
            return 18
        case .medium:
            return 32
        case .high:
            return 48
        }
    }

    private func feedback(for level: AudioEffectLevel, preset: GuitarTonePreset) -> Float {
        let base: Float
        switch level {
        case .off:
            base = 0
        case .low:
            base = 14
        case .medium:
            base = 24
        case .high:
            base = 34
        }
        return preset == .electricDirty ? base + 6 : base
    }

    private func delayTime(for preset: GuitarTonePreset) -> TimeInterval {
        switch preset {
        case .acoustic:
            return 0.12
        case .electricClean:
            return 0.16
        case .electricDirty:
            return 0.18
        }
    }

    private func noteLength(for preset: GuitarTonePreset) -> TimeInterval {
        switch preset {
        case .acoustic:
            return 1.35
        case .electricClean:
            return 1.6
        case .electricDirty:
            return 1.8
        }
    }

    private func reverbPreset(for preset: GuitarTonePreset) -> AVAudioUnitReverbPreset {
        switch preset {
        case .acoustic:
            return .mediumRoom
        case .electricClean:
            return .mediumHall
        case .electricDirty:
            return .largeHall
        }
    }

    private func fallbackSoundBankURLs() -> [URL] {
        [
            URL(fileURLWithPath: "/System/Library/Components/CoreAudio.component/Contents/Resources/gs_instruments.dls")
        ]
    }

    private func configureAudioSession() {
        let session = AVAudioSession.sharedInstance()
        do {
            try session.setCategory(.playback, mode: .default, options: [.mixWithOthers])
            try session.setActive(true)
        } catch {
        }
    }

    private func startEngineIfNeeded() {
        guard !engine.isRunning else { return }
        do {
            try engine.start()
        } catch {
        }
    }
}
