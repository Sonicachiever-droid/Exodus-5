import AVFoundation

final class BackingTrackEngine {
    private let intendedLoopLengthInBeats: TimeInterval = 16
    private let engine = AVAudioEngine()
    private let keysSampler = AVAudioUnitSampler()
    private let bassSampler = AVAudioUnitSampler()
    private let drumsSampler = AVAudioUnitSampler()
    private lazy var sequencer = AVAudioSequencer(audioEngine: engine)
    private(set) var currentTrack: BackingTrack?
    private(set) var isPlaying: Bool = false
    private var currentArrangement: BackingArrangementPreset = .epDrumsPad
    private var currentTransposeSemitones: Int = 0

    init() {
        engine.attach(keysSampler)
        engine.attach(bassSampler)
        engine.attach(drumsSampler)
        engine.connect(keysSampler, to: engine.mainMixerNode, format: nil)
        engine.connect(bassSampler, to: engine.mainMixerNode, format: nil)
        engine.connect(drumsSampler, to: engine.mainMixerNode, format: nil)
        engine.mainMixerNode.outputVolume = 0.72
        configureAudioSession()
        loadSamplerVoices(for: currentArrangement)
        startEngineIfNeeded()
    }

    func configure(arrangement: BackingArrangementPreset, transposeSemitones: Int) {
        let normalizedTranspose = max(-24, min(transposeSemitones, 24))
        guard arrangement != currentArrangement || normalizedTranspose != currentTransposeSemitones else { return }
        currentArrangement = arrangement
        currentTransposeSemitones = normalizedTranspose
        loadSamplerVoices(for: arrangement)
        applyArrangementMix()
        applyTranspose()
    }

    func togglePlayback(for track: BackingTrack) {
        if currentTrack == track, isPlaying {
            stop()
        } else {
            play(track: track)
        }
    }

    func play(track: BackingTrack) {
        guard let trackURL = track.resourceURL() else { return }
        do {
            stop(clearTrackSelection: false)
            sequencer = AVAudioSequencer(audioEngine: engine)
            try sequencer.load(from: trackURL, options: [])
            routeTracksToSamplers()
            configureLooping()
            applyArrangementMix()
            startEngineIfNeeded()
            sequencer.prepareToPlay()
            try sequencer.start()
            currentTrack = track
            isPlaying = true
        } catch {
            currentTrack = nil
            isPlaying = false
        }
    }

    func stop() {
        stop(clearTrackSelection: true)
    }

    private func stop(clearTrackSelection: Bool) {
        if sequencer.isPlaying {
            sequencer.stop()
        }
        sequencer.currentPositionInBeats = 0
        keysSampler.reset()
        bassSampler.reset()
        drumsSampler.reset()
        if clearTrackSelection {
            currentTrack = nil
        }
        isPlaying = false
    }

    private func routeTracksToSamplers() {
        for track in sequencer.tracks {
            track.destinationAudioUnit = nil
            track.isMuted = false
        }

        guard sequencer.tracks.count > 1 else { return }

        if sequencer.tracks.count > 1 {
            sequencer.tracks[1].destinationAudioUnit = keysSampler
        }
        if sequencer.tracks.count > 2 {
            sequencer.tracks[2].destinationAudioUnit = bassSampler
        }
        if sequencer.tracks.count > 3 {
            sequencer.tracks[3].destinationAudioUnit = drumsSampler
        }
    }

    private func applyTranspose() {
        let cents = Float(currentTransposeSemitones * 100)
        keysSampler.globalTuning = cents
        bassSampler.globalTuning = cents
        drumsSampler.globalTuning = 0
    }

    private func configureLooping() {
        for track in sequencer.tracks {
            track.loopRange = AVBeatRange(start: 0, length: intendedLoopLengthInBeats)
            track.numberOfLoops = -1
            track.isLoopingEnabled = true
        }
    }

    private func applyArrangementMix() {
        let keysVolume: Float
        let bassVolume: Float
        let drumsVolume: Float

        switch currentArrangement {
        case .epDrumsPad:
            keysVolume = 0.82
            bassVolume = 0.72
            drumsVolume = 0.82
        case .keysDrumsStrings:
            keysVolume = 0.88
            bassVolume = 0.76
            drumsVolume = 0.8
        case .epDrumsOnly:
            keysVolume = 0.84
            bassVolume = 0
            drumsVolume = 0.86
        case .padDrumsOnly:
            keysVolume = 0.42
            bassVolume = 0
            drumsVolume = 0.84
        }

        keysSampler.volume = keysVolume
        bassSampler.volume = bassVolume
        drumsSampler.volume = drumsVolume

        if sequencer.tracks.count > 2 {
            sequencer.tracks[2].isMuted = bassVolume == 0
        }
    }

    private func loadSamplerVoices(for arrangement: BackingArrangementPreset) {
        guard let soundBankURL = defaultSoundBankURL() else { return }
        loadInstrument(on: keysSampler, program: keysProgram(for: arrangement), bankMSB: UInt8(kAUSampler_DefaultMelodicBankMSB), bankLSB: 0, soundBankURL: soundBankURL)
        loadInstrument(on: bassSampler, program: 33, bankMSB: UInt8(kAUSampler_DefaultMelodicBankMSB), bankLSB: 0, soundBankURL: soundBankURL)
        loadInstrument(on: drumsSampler, program: 0, bankMSB: UInt8(kAUSampler_DefaultPercussionBankMSB), bankLSB: 0, soundBankURL: soundBankURL)
        applyTranspose()
    }

    private func keysProgram(for arrangement: BackingArrangementPreset) -> UInt8 {
        switch arrangement {
        case .epDrumsPad:
            return 4
        case .keysDrumsStrings:
            return 48
        case .epDrumsOnly:
            return 4
        case .padDrumsOnly:
            return 89
        }
    }

    private func loadInstrument(on sampler: AVAudioUnitSampler, program: UInt8, bankMSB: UInt8, bankLSB: UInt8, soundBankURL: URL) {
        do {
            try sampler.loadSoundBankInstrument(
                at: soundBankURL,
                program: program,
                bankMSB: bankMSB,
                bankLSB: bankLSB
            )
        } catch {
        }
    }

    private func defaultSoundBankURL() -> URL? {
        [
            Bundle.main.url(forResource: "gs_instruments", withExtension: "dls"),
            URL(string: "file:///System/Library/Components/CoreAudio.component/Contents/Resources/gs_instruments.dls")
        ].compactMap { $0 }.first
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
