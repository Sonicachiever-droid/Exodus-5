import AVFoundation

final class BackingTrackEngine {
    private let intendedLoopLengthInBeats: TimeInterval = 16
    private let engine = AVAudioEngine()
    private let keysSampler = AVAudioUnitSampler()
    private let bassSampler = AVAudioUnitSampler()
    private let drumsSampler = AVAudioUnitSampler()
    private lazy var sequencer = AVAudioSequencer(audioEngine: engine)
    private var midiPlayer: AVMIDIPlayer?
    private(set) var currentTrack: BackingTrack?
    private(set) var isPlaying: Bool = false
    private var currentArrangement: BackingArrangementPreset = .epDrumsPad
    private var currentTransposeSemitones: Int = 0
    private var hasLoadedVoices: Bool = false
    private var soundbankURL: URL?

    init() {
        // Load bundled DLS first; fall back to system GS bank
        if let bundledDLS = Bundle.main.url(forResource: "gs_instruments", withExtension: "dls") {
            soundbankURL = bundledDLS
            print("[BackingTrackEngine] Loaded bundled DLS: \(bundledDLS.lastPathComponent)")
        } else if let systemDLS = defaultSoundBankURL() {
            soundbankURL = systemDLS
            print("[BackingTrackEngine] Using system GS soundbank: \(systemDLS.lastPathComponent)")
        } else {
            print("[BackingTrackEngine] ⚠️ No SoundFont found – MIDI may be silent or use default synth")
        }

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
        guard arrangement != currentArrangement || normalizedTranspose != currentTransposeSemitones || !hasLoadedVoices else { return }
        currentArrangement = arrangement
        currentTransposeSemitones = normalizedTranspose
        print("[BackingTrackEngine] Configure: arrangement=\(arrangement.rawValue), transpose=\(normalizedTranspose) semitones")
        loadSamplerVoices(for: arrangement)
        applyArrangementMix()
        applyTranspose()
        hasLoadedVoices = true
    }

    func togglePlayback(for track: BackingTrack) {
        if currentTrack == track, isPlaying {
            stop()
        } else {
            play(track: track)
        }
    }

    func play(track: BackingTrack) {
        guard let trackURL = track.resourceURL() else {
            print("❌ MIDI file not found: \(track.resourceName)")
            return
        }
        print("MIDI URL: \(trackURL.absoluteString)")

        stop(clearTrackSelection: false)

        // Use sequencer for real-time transposition support during gameplay
        do {
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
            print("[BackingTrackEngine] Started track \(track.resourceName) via sequencer for transposition support")
            print("[BackingTrackEngine] Sequencer tracks: \(sequencer.tracks.count), routed to samplers")
            return
        } catch {
            print("[BackingTrackEngine] Sequencer failed for \(track.resourceName): \(error.localizedDescription)")
        }

        // Fallback to MIDI player (no real-time transposition)
        do {
            midiPlayer = try AVMIDIPlayer(contentsOf: trackURL, soundBankURL: soundbankURL)
            midiPlayer?.prepareToPlay()
            midiPlayer?.play { [weak self] in
                DispatchQueue.main.async {
                    guard let self else { return }
                    guard self.isPlaying, self.currentTrack == track else { return }
                    self.play(track: track)
                }
            }
            currentTrack = track
            isPlaying = true
            print("▶️ Playing MIDI: \(track.resourceName) with soundbank: \(soundbankURL?.lastPathComponent ?? "NONE") (no transposition)")
            return
        } catch {
            print("❌ Failed to create AVMIDIPlayer: \(error)")
        }

        currentTrack = nil
        isPlaying = false
    }

    func stop() {
        stop(clearTrackSelection: true)
    }

    private func stop(clearTrackSelection: Bool) {
        midiPlayer?.stop()
        midiPlayer = nil
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
        for (index, track) in sequencer.tracks.enumerated() {
            track.isMuted = false
            switch index {
            case 2:
                track.destinationAudioUnit = bassSampler
            case 3:
                track.destinationAudioUnit = drumsSampler
            default:
                track.destinationAudioUnit = keysSampler
            }
        }
    }

    private func applyTranspose() {
        let cents = Float(currentTransposeSemitones * 100)
        keysSampler.globalTuning = cents
        bassSampler.globalTuning = cents
        drumsSampler.globalTuning = 0
        print("[BackingTrackEngine] Transpose: \(currentTransposeSemitones) semitones = \(cents) cents")
    }

    private func configureLooping() {
        for track in sequencer.tracks {
            track.loopRange = AVBeatRange(start: 0, length: intendedLoopLengthInBeats)
            track.numberOfLoops = -1
            track.isLoopingEnabled = true
        }
    }

    private func applyArrangementMix() {
        // Force full mix to eliminate arrangement gating as a variable
        let keysVolume: Float = 0.88
        let bassVolume: Float = 0.78
        let drumsVolume: Float = 0.86

        keysSampler.volume = keysVolume
        bassSampler.volume = bassVolume
        drumsSampler.volume = drumsVolume

        // Explicitly unmute bass and drums at sequencer level if present
        if sequencer.tracks.count > 2 {
            sequencer.tracks[2].isMuted = false
        }
        if sequencer.tracks.count > 3 {
            sequencer.tracks[3].isMuted = false
        }
    }

    private func loadSamplerVoices(for arrangement: BackingArrangementPreset) {
        guard let soundBankURL = defaultSoundBankURL() else {
            print("[BackingTrackEngine] No soundbank URL resolved for arrangement \(arrangement.rawValue)")
            return
        }
        loadInstrument(on: keysSampler, program: keysProgram(for: arrangement), bankMSB: UInt8(kAUSampler_DefaultMelodicBankMSB), bankLSB: 0, soundBankURL: soundBankURL)
        loadInstrument(on: bassSampler, program: 33, bankMSB: UInt8(kAUSampler_DefaultMelodicBankMSB), bankLSB: 0, soundBankURL: soundBankURL)
        loadInstrument(on: drumsSampler, program: 0, bankMSB: UInt8(kAUSampler_DefaultPercussionBankMSB), bankLSB: 0, soundBankURL: soundBankURL)
        hasLoadedVoices = true
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
            print("[BackingTrackEngine] Loaded soundbank instrument program \(program) from \(soundBankURL.lastPathComponent)")
        } catch {
            print("[BackingTrackEngine] Failed loading program \(program) from \(soundBankURL.lastPathComponent): \(error.localizedDescription)")
        }
    }

    private func defaultSoundBankURL() -> URL? {
        let systemURL = URL(fileURLWithPath: "/System/Library/Components/CoreAudio.component/Contents/Resources/gs_instruments.dls")
        if FileManager.default.fileExists(atPath: systemURL.path) {
            print("[BackingTrackEngine] Using system soundbank at \(systemURL.path)")
            return systemURL
        }
        print("[BackingTrackEngine] System soundbank missing at \(systemURL.path)")
        return nil
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
