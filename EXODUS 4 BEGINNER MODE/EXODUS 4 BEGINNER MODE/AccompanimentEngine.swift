import AVFoundation
import Combine

class AccompanimentEngine: ObservableObject {
    private let engine = AVAudioEngine()
    private let drumSampler = AVAudioUnitSampler()
    private let chordSampler = AVAudioUnitSampler()
    private var chordTimer: Timer?
    private var currentChordIndex: Int = 0
    
    @Published var isPlaying: Bool = false
    
    // Drum pattern (basic rock: kick on 1&3, snare on 2&4, hi-hats on eighths)
    private let drumPattern: [(note: UInt8, velocity: UInt8, beat: Double)] = [
        // Beat 1
        (36, 100, 0.0),    // Kick
        (42, 80, 0.0),     // Hi-hat
        // Beat 1.5
        (42, 60, 0.5),     // Hi-hat
        // Beat 2
        (38, 90, 1.0),     // Snare
        (42, 80, 1.0),     // Hi-hat
        // Beat 2.5
        (42, 60, 1.5),     // Hi-hat
        // Beat 3
        (36, 100, 2.0),    // Kick
        (42, 80, 2.0),     // Hi-hat
        // Beat 3.5
        (42, 60, 2.5),     // Hi-hat
        // Beat 4
        (38, 90, 3.0),     // Snare
        (42, 80, 3.0),     // Hi-hat
        // Beat 3.5
        (42, 60, 3.5),     // Hi-hat
    ]
    
    init() {
        setupAudioEngine()
        loadSounds()
    }
    
    private func setupAudioEngine() {
        engine.attach(drumSampler)
        engine.attach(chordSampler)
        engine.connect(drumSampler, to: engine.mainMixerNode, format: nil)
        engine.connect(chordSampler, to: engine.mainMixerNode, format: nil)
        engine.mainMixerNode.outputVolume = 0.7
    }
    
    private func loadSounds() {
        // Try to load GeneralUser GS SoundFont first, fallback to system sound bank
        if let soundFontURL = Bundle.main.url(forResource: "GeneralUser GS", withExtension: "sf2") {
            do {
                try drumSampler.loadSoundBankInstrument(at: soundFontURL, program: 0, bankMSB: 0, bankLSB: 0)
                try chordSampler.loadSoundBankInstrument(at: soundFontURL, program: 0, bankMSB: 0, bankLSB: 0)
                print("AccompanimentEngine: Loaded GeneralUser GS SoundFont instruments")
            } catch {
                print("AccompanimentEngine: Failed to load GeneralUser GS SoundFont - \(error)")
                loadSystemSounds()
            }
        } else {
            print("AccompanimentEngine: GeneralUser GS SoundFont not found, using system sounds")
            loadSystemSounds()
        }
    }
    
    private func loadSystemSounds() {
        let drumBankURL = URL(fileURLWithPath: "/System/Library/Components/CoreAudio.component/Contents/Resources/gs_instruments.dls")
        
        do {
            try drumSampler.loadSoundBankInstrument(at: drumBankURL, program: 0, bankMSB: 0, bankLSB: 0)
            try chordSampler.loadSoundBankInstrument(at: drumBankURL, program: 0, bankMSB: 0, bankLSB: 0)
            print("AccompanimentEngine: Loaded system sound banks")
        } catch {
            print("AccompanimentEngine: Failed to load system sound banks - \(error)")
        }
    }
    
    func startAccompaniment(currentRound: Int, chordGenerator: ChordGenerator) {
        stopAccompaniment()
        
        // Generate chords for current fret
        chordGenerator.generateChords(for: currentRound, useFlats: false)
        
        guard !chordGenerator.availableChords.isEmpty else {
            print("AccompanimentEngine: No chords available")
            return
        }
        
        // Set transposition based on current round (half-step per fret)
        let transposeCents = Float(currentRound * 100)
        chordSampler.globalTuning = transposeCents
        
        do {
            try engine.start()
            isPlaying = true
            
            // Start drum loop
            startDrumLoop()
            
            // Start chord progression (change every half measure = 1 second at 120 BPM)
            startChordProgression(chordGenerator: chordGenerator)
            
            print("AccompanimentEngine: Started accompaniment for round \(currentRound)")
        } catch {
            print("AccompanimentEngine: Failed to start engine - \(error)")
        }
    }
    
    func stopAccompaniment() {
        chordTimer?.invalidate()
        chordTimer = nil
        
        // Clear all samplers by sending all notes off
        for note in 0...127 {
            drumSampler.stopNote(UInt8(note), onChannel: 9)
            chordSampler.stopNote(UInt8(note), onChannel: 0)
        }
        
        if engine.isRunning {
            engine.stop()
        }
        
        isPlaying = false
        print("AccompanimentEngine: Stopped accompaniment")
    }
    
    private func startDrumLoop() {
        // Simple drum loop using Timer instead of MIDI scheduling
        Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { [weak self] _ in
            guard let self = self else { return }
            
            // Alternate kick and snare
            let kickNote: UInt8 = 36
            let snareNote: UInt8 = 38
            
            // Play kick on even beats, snare on odd beats
            let currentTime = Date().timeIntervalSince1970
            let beatNumber = Int(currentTime) % 2
            
            if beatNumber == 0 {
                self.drumSampler.startNote(kickNote, withVelocity: 100, onChannel: 9)
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                    self.drumSampler.stopNote(kickNote, onChannel: 9)
                }
            } else {
                self.drumSampler.startNote(snareNote, withVelocity: 90, onChannel: 9)
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                    self.drumSampler.stopNote(snareNote, onChannel: 9)
                }
            }
        }
    }
    
    private func startChordProgression(chordGenerator: ChordGenerator) {
        guard let firstChord = chordGenerator.currentChord else { return }
        
        // Play first chord immediately
        playChord(firstChord)
        
        // Change chords every half measure (1 second at 120 BPM)
        chordTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            guard let self = self else { return }
            
            // Select next random chord from available chords
            if let nextChord = chordGenerator.availableChords.randomElement() {
                self.playChord(nextChord)
                chordGenerator.currentChord = nextChord
            }
        }
    }
    
    private func playChord(_ chord: ChordType) {
        let chordNotes = chord.notePattern
        
        // Convert note names to MIDI note numbers
        let midiNotes = chordNotes.compactMap { noteName -> UInt8? in
            let noteMap: [String: UInt8] = [
                "C": 60, "C#": 61, "D": 62, "D#": 63, "E": 64, "F": 65,
                "F#": 66, "G": 67, "G#": 68, "A": 69, "A#": 70, "B": 71
            ]
            return noteMap[noteName]
        }
        
        // Play chord notes (velocity 80 for accompaniment)
        for midiNote in midiNotes {
            chordSampler.startNote(midiNote, withVelocity: 80, onChannel: 0)
        }
        
        // Schedule note off after half measure (1 second)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.9) {
            for midiNote in midiNotes {
                self.chordSampler.stopNote(midiNote, onChannel: 0)
            }
        }
        
        print("AccompanimentEngine: Playing chord \(chord.rawValue)")
    }
    
    deinit {
        stopAccompaniment()
    }
}
