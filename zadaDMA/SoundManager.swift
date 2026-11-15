import Foundation
import AVFoundation

class SoundManager {
    static let shared = SoundManager()
    private var player: AVAudioPlayer?
    
    init() {
        // Konfigurojme sesionin e zërit
        do {
            try AVAudioSession.sharedInstance().setCategory(.ambient, mode: .default, options: [])
            try AVAudioSession.sharedInstance().setActive(true)
        } catch {
            print("[-] Gabim ne konfigurimin e AVAudioSession: \(error)")
        }
    }
    
    func play(sound: String) {
        guard let url = Bundle.main.url(forResource: sound, withExtension: "wav") else {
            print("[-] Zanorja \(sound).wav mungon në bundle.")
            return
        }
        do {
            player = try AVAudioPlayer(contentsOf: url)
            player?.prepareToPlay()
            player?.play()
            print("[+] Duke luajtur: \(sound).wav")
        } catch {
            print("[-] Gabim në luajtjen e zërit: \(error)")
        }
    }
}
