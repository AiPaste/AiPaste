import AppKit
import Foundation

enum SoundEffectEvent {
    case capture
    case paste
    case error
}

@MainActor
final class SoundEffectPlayer {
    static let shared = SoundEffectPlayer()

    private var cachedSounds: [SoundEffectEvent: NSSound] = [:]

    private init() {}

    func play(_ event: SoundEffectEvent) {
        guard isEnabled else { return }

        let sound = cachedSounds[event] ?? makeSound(for: event)
        cachedSounds[event] = sound

        if let sound {
            sound.stop()
            sound.play()
        } else {
            NSSound.beep()
        }
    }

    private var isEnabled: Bool {
        UserDefaults.standard.object(forKey: AppPreferences.soundEffects) as? Bool ?? true
    }

    private func makeSound(for event: SoundEffectEvent) -> NSSound? {
        let name: NSSound.Name = switch event {
        case .capture:
            NSSound.Name("Pop")
        case .paste:
            NSSound.Name("Glass")
        case .error:
            NSSound.Name("Basso")
        }

        return NSSound(named: name)
    }
}
