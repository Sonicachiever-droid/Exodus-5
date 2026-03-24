//
//  ContentView.swift
//  ChordAccompaniment
//
//  Created by Thomas Kane on 3/24/26.
//

import SwiftUI
import AVFoundation

struct ContentView: View {
    @StateObject private var audioEngine = AudioEngine()
    @State private var currentRound: Int = 0
    @State private var isPlaying: Bool = false
    
    // Open string notes (low to high)
    private let openNotes = ["E", "A", "D", "G", "B", "E"]
    
    // Note names for transposition
    private let noteNames = ["C", "C#", "D", "D#", "E", "F", "F#", "G", "G#", "A", "A#", "B"]
    
    // Get transposed note name for string at current fret
    private func getNoteName(for stringIndex: Int, fret: Int) -> String {
        let openNoteIndex = noteNames.firstIndex(of: openNotes[stringIndex]) ?? 0
        let transposedIndex = (openNoteIndex + fret) % 12
        return noteNames[transposedIndex]
    }
    
    var body: some View {
        VStack(spacing: 20) {
            // Simple neck visualization
            SimpleNeckView(currentFret: currentRound)
            
            // Transport controls
            HStack(spacing: 20) {
                Button(isPlaying ? "Stop" : "Play") {
                    if isPlaying {
                        audioEngine.stopAccompaniment()
                        isPlaying = false
                    } else {
                        audioEngine.startAccompaniment(currentRound: currentRound)
                        isPlaying = true
                    }
                }
                .padding()
                .background(isPlaying ? Color.red : Color.green)
                .foregroundColor(.white)
                .cornerRadius(8)
                
                Button("Reset") {
                    currentRound = 0
                    audioEngine.updateTransposition(round: currentRound)
                }
                .padding()
                .background(Color.blue)
                .foregroundColor(.white)
                .cornerRadius(8)
            }
            
            // Round controls
            HStack {
                Text("Round: \(currentRound)")
                Stepper("", value: $currentRound, in: 0...12)
                    .onChange(of: currentRound) { _, newValue in
                        audioEngine.updateTransposition(round: newValue)
                    }
            }
            
            // Six button interface with dynamic labels
            VStack(spacing: 10) {
                ForEach(Array(openNotes.enumerated()), id: \.offset) { index, _ in
                    Button(action: {
                        audioEngine.playGuitarNote(stringIndex: index, fret: currentRound)
                    }) {
                        Text(getNoteName(for: index, fret: currentRound))
                            .font(.title)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.gray)
                            .foregroundColor(.white)
                            .cornerRadius(8)
                    }
                }
            }
            .padding()
        }
        .padding()
    }
}

struct SimpleNeckView: View {
    let currentFret: Int
    
    var body: some View {
        VStack(spacing: 5) {
            Text(currentFret == 0 ? "OPEN" : "FRET \(currentFret)")
                .font(.headline)
                .foregroundColor(.blue)
            
            // Simple neck rectangle
            Rectangle()
                .fill(Color.brown)
                .frame(height: 60)
                .overlay(
                    // Fret lines
                    HStack(spacing: 0) {
                        ForEach(0..<13, id: \.self) { fret in
                            Rectangle()
                                .fill(fret == currentFret ? Color.yellow : Color.gray)
                                .frame(width: 2)
                        }
                    }
                )
                .overlay(
                    // Current fret indicator
                    Rectangle()
                        .fill(Color.yellow.opacity(0.3))
                        .frame(width: 30, height: 60)
                        .offset(x: CGFloat(currentFret * 25) - 150)
                )
        }
        .padding()
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
