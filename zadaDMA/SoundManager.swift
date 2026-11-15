import Foundation
import AVFoundation

class SoundManager {
    static let shared = SoundManager()
    private var player: AVAudioPlayer?
    
    func play(sound: String) {
        guard let url = Bundle.main.url(forResource: sound, withExtension: "wav") else {
            print("[-] Zanorja \(sound).wav mungon.")
            return
        }
        do {
            player = try AVAudioPlayer(contentsOf: url)
            player?.play()
        } catch {
            print("[-] Gabim: \(error)")
        }
    }
}
