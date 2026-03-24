import AVFoundation
import Combine

class AudioEngine: ObservableObject {
    private let engine = AVAudioEngine()
    private let chordSampler = AVAudioUnitSampler()
    private let guitarSampler = AVAudioUnitSampler()
    
    // Drum players for better sound
    private let kickPlayer = AVAudioPlayerNode()
    private let snarePlayer = AVAudioPlayerNode()
    private let hihatPlayer = AVAudioPlayerNode()
    
    private var chordTimer: Timer?
    private var drumTimer: Timer?
    
    // 12 chords for open strings, transposed for all frets
    private let chords = [
        ["G", "B", "D"],           // G major
        ["E", "G", "B"],           // E minor
        ["G", "B", "D", "E"],      // G6
        ["E", "G", "B", "D"],      // E minor 7
        ["G", "A", "B", "D"],      // G add 9
        ["G", "A", "B", "D", "E"], // G6 9
        ["E", "F#", "G", "B"],     // E minor add 9
        ["E", "G", "A", "B"],      // E minor add 11
        ["E", "F#", "G", "A", "B"], // E minor 11
        ["D", "G", "A"],           // Dsus4
        ["A", "B", "E"],           // Asus2
        ["E", "A", "B", "D"]       // E7sus4
    ]
    
    private var currentChordIndex: Int = 0
    
    init() {
        setupAudioEngine()
        loadSounds()
    }
    
    private func setupAudioEngine() {
        engine.attach(chordSampler)
        engine.attach(guitarSampler)
        
        engine.connect(chordSampler, to: engine.mainMixerNode, format: nil)
        engine.connect(guitarSampler, to: engine.mainMixerNode, format: nil)
        
        engine.mainMixerNode.outputVolume = 0.7
    }
    
    private func loadSounds() {
        // Try to load GeneralUser GS SoundFont first, fallback to system sound bank
        if let soundFontURL = Bundle.main.url(forResource: "GeneralUser GS", withExtension: "sf2") {
            do {
                try chordSampler.loadSoundBankInstrument(at: soundFontURL, program: 0, bankMSB: 0, bankLSB: 0)
                try guitarSampler.loadSoundBankInstrument(at: soundFontURL, program: 24, bankMSB: 0, bankLSB: 0) // Guitar patch
                print("AudioEngine: Loaded GeneralUser GS SoundFont instruments")
            } catch {
                print("AudioEngine: Failed to load GeneralUser GS SoundFont - \(error)")
                loadSystemSounds()
            }
        } else {
            print("AudioEngine: GeneralUser GS SoundFont not found, using system sounds")
            loadSystemSounds()
        }
    }
    
    private func loadSystemSounds() {
        let soundBankPath = "/System/Library/Components/CoreAudio.component/Contents/Resources/gs_instruments.dls"
        let soundBankURL = URL(fileURLWithPath: soundBankPath)
        
        do {
            try chordSampler.loadSoundBankInstrument(at: soundBankURL, program: 0, bankMSB: 0, bankLSB: 0)
            try guitarSampler.loadSoundBankInstrument(at: soundBankURL, program: 24, bankMSB: 0, bankLSB: 0) // Guitar patch
            print("AudioEngine: Loaded system sound banks")
        } catch {
            print("AudioEngine: Failed to load system sound banks - \(error)")
        }
    }
    
    func startAccompaniment(currentRound: Int) {
        stopAccompaniment()
        
        // Set transposition based on current round (half-step per fret)
        let transposeCents = Float(currentRound * 100)
        chordSampler.globalTuning = transposeCents
        
        do {
            try engine.start()
            
            // Start drum loop
            startDrumLoop()
            
            // Start chord progression (change every half measure = 1 second at 120 BPM)
            startChordProgression()
            
            print("AudioEngine: Started accompaniment for round \(currentRound)")
        } catch {
            print("AudioEngine: Failed to start engine - \(error)")
        }
    }
    
    func stopAccompaniment() {
        chordTimer?.invalidate()
        chordTimer = nil
        drumTimer?.invalidate()
        drumTimer = nil
        
        // Clear all samplers by sending all notes off (including drum channel 9)
        for note in 0...127 {
            chordSampler.stopNote(UInt8(note), onChannel: 0) // Chords
            chordSampler.stopNote(UInt8(note), onChannel: 9) // Drums
            guitarSampler.stopNote(UInt8(note), onChannel: 0) // Guitar
        }
        
        if engine.isRunning {
            engine.stop()
        }
        
        print("AudioEngine: Stopped accompaniment")
    }
    
    func updateTransposition(round: Int) {
        let transposeCents = Float(round * 100)
        chordSampler.globalTuning = transposeCents
        guitarSampler.globalTuning = transposeCents
        print("AudioEngine: Updated transposition to \(transposeCents) cents")
    }
    
    private func startDrumLoop() {
        // Use proper MIDI drum notes that will sound good with SoundFont
        var beatCount = 0
        
        drumTimer = Timer.scheduledTimer(withTimeInterval: 0.25, repeats: true) { [weak self] _ in
            guard let self = self else { return }
            
            let beat = beatCount % 16 // 4 measures of 4 beats
            let eighthNote = beat % 2
            
            // Kick on beats 1, 5, 9, 13 - MIDI note 36 (C2, standard kick)
            if beat == 0 || beat == 4 || beat == 8 || beat == 12 {
                self.chordSampler.startNote(36, withVelocity: 100, onChannel: 9) // Channel 9 = drums
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    self.chordSampler.stopNote(36, onChannel: 9)
                }
            }
            
            // Snare on beats 2, 6, 10, 14 - MIDI note 38 (D2, standard snare)
            if beat == 2 || beat == 6 || beat == 10 || beat == 14 {
                self.chordSampler.startNote(38, withVelocity: 90, onChannel: 9) // Channel 9 = drums
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.08) {
                    self.chordSampler.stopNote(38, onChannel: 9)
                }
            }
            
            // Hi-hat on all 8th notes - MIDI note 42 (F#2, standard hi-hat)
            if eighthNote == 0 {
                self.chordSampler.startNote(42, withVelocity: 60, onChannel: 9) // Channel 9 = drums
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.03) {
                    self.chordSampler.stopNote(42, onChannel: 9)
                }
            }
            
            beatCount += 1
        }
    }
    
    private func startChordProgression() {
        // Play first chord immediately
        playCurrentChord()
        
        // Change chords twice per measure (2 seconds at 120 BPM)
        chordTimer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true) { [weak self] _ in
            guard let self = self else { return }
            self.currentChordIndex = (self.currentChordIndex + 1) % self.chords.count
            self.playCurrentChord()
        }
    }
    
    private func playCurrentChord() {
        let chordNotes = chords[currentChordIndex]
        
        // Convert note names to MIDI note numbers (including sharps/flats)
        let midiNotes = chordNotes.compactMap { noteName -> UInt8? in
            let noteMap: [String: UInt8] = [
                "C": 60, "C#": 61, "Db": 61, "D": 62, "D#": 63, "Eb": 63,
                "E": 64, "F": 65, "F#": 66, "Gb": 66, "G": 67, "G#": 68, "Ab": 68,
                "A": 69, "A#": 70, "Bb": 70, "B": 71
            ]
            return noteMap[noteName]
        }
        
        // Play chord notes
        for midiNote in midiNotes {
            chordSampler.startNote(midiNote, withVelocity: 80, onChannel: 0)
        }
        
        // Schedule note off after 2 seconds (full measure)
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.9) {
            for midiNote in midiNotes {
                self.chordSampler.stopNote(midiNote, onChannel: 0)
            }
        }
        
        print("AudioEngine: Playing chord \(chordNotes)")
    }
    
    func playGuitarNote(stringIndex: Int, fret: Int) {
        // Open string notes (low to high)
        let openNotes: [UInt8] = [40, 45, 50, 55, 59, 64] // E, A, D, G, B, E
        
        guard stringIndex < openNotes.count else { return }
        
        let midiNote = openNotes[stringIndex] + UInt8(fret)
        
        // Ensure engine is running for guitar playback
        if !engine.isRunning {
            do {
                try engine.start()
            } catch {
                print("AudioEngine: Failed to start engine for guitar - \(error)")
                return
            }
        }
        
        guitarSampler.startNote(midiNote, withVelocity: 100, onChannel: 0)
        
        // Stop note after 0.5 seconds
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            self.guitarSampler.stopNote(midiNote, onChannel: 0)
        }
        
        print("AudioEngine: Playing note \(midiNote) (string \(stringIndex + 1), fret \(fret))")
    }
    
    deinit {
        stopAccompaniment()
    }
}
