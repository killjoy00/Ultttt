import AVFoundation
import SwiftUI
import UIKit

enum PlaySettings {
    static let soundKey = "ultttt.sound.enabled"
    static let hapticsKey = "ultttt.haptics.enabled"

    static var soundEnabled: Bool {
        UserDefaults.standard.object(forKey: soundKey) as? Bool ?? true
    }
    static var hapticsEnabled: Bool {
        UserDefaults.standard.object(forKey: hapticsKey) as? Bool ?? true
    }
}

/// Short original tones synthesized at runtime. No bundled or licensed music.
@MainActor
final class GameFeedback {
    static let shared = GameFeedback()

    enum Event {
        case move, boardWon, gameWon
    }

    private var audioPlayer: AVAudioPlayer?
    private var audioReady = false

    func play(_ event: Event) {
        if PlaySettings.hapticsEnabled {
            switch event {
            case .move:
                UIImpactFeedbackGenerator(style: .light).impactOccurred()
            case .boardWon:
                UINotificationFeedbackGenerator().notificationOccurred(.success)
            case .gameWon:
                UINotificationFeedbackGenerator().notificationOccurred(.success)
            }
        }
        if PlaySettings.soundEnabled {
            do {
                if !audioReady {
                    try AVAudioSession.sharedInstance().setCategory(
                        .ambient, mode: .default, options: [.mixWithOthers]
                    )
                    audioReady = true
                }
                audioPlayer = try AVAudioPlayer(data: Self.soundData(for: event))
                audioPlayer?.prepareToPlay()
                audioPlayer?.play()
            } catch {
                // Feedback must never interrupt gameplay.
            }
        }
    }

    private static func soundData(for event: Event) -> Data {
        let sampleRate = 22_050
        let seconds: Double = event == .move ? 0.085 : event == .boardWon ? 0.22 : 0.34
        let count = Int(Double(sampleRate) * seconds)
        var samples = [Int16]()
        samples.reserveCapacity(count)

        for frame in 0..<count {
            let time = Double(frame) / Double(sampleRate)
            let progress = Double(frame) / Double(count)
            let frequency: Double
            switch event {
            case .move: frequency = 640
            case .boardWon: frequency = progress < 0.47 ? 680 : 900
            case .gameWon: frequency = progress < 0.33 ? 523 : (progress < 0.66 ? 659 : 784)
            }
            let envelope = pow(max(0, 1 - progress), 1.7)
            let value = sin(2 * Double.pi * frequency * time) * envelope * 8_500
            samples.append(Int16(value))
        }

        var data = Data()
        func bytes(_ string: String) { data.append(contentsOf: string.utf8) }
        func u16(_ value: UInt16) {
            data.append(UInt8(truncatingIfNeeded: value))
            data.append(UInt8(truncatingIfNeeded: value >> 8))
        }
        func u32(_ value: UInt32) {
            u16(UInt16(truncatingIfNeeded: value))
            u16(UInt16(truncatingIfNeeded: value >> 16))
        }

        bytes("RIFF")
        u32(UInt32(36 + count * 2))
        bytes("WAVEfmt ")
        u32(16)                 // PCM fmt chunk
        u16(1)                  // uncompressed
        u16(1)                  // mono
        u32(UInt32(sampleRate))
        u32(UInt32(sampleRate * 2))
        u16(2)                  // frame alignment
        u16(16)                 // 16-bit samples
        bytes("data")
        u32(UInt32(count * 2))
        for sample in samples {
            u16(UInt16(bitPattern: sample))
        }
        return data
    }
}
