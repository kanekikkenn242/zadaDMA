import Foundation
import AVFoundation

class SoundManager {
    static let shared = SoundManager()
    private var player: AVAudioPlayer?
    private var keepAlivePlayer: AVAudioPlayer?
    
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
    
    /// Mban procesin gjallë gjatë një transaksioni MCM/Airlift. iOS e
    /// pezullon app-in normale disa sekonda pasi kthehesh në Free Fire dhe
    /// injektimi ngrinte në mes të shkrimit.
    func beginBackgroundKeepAlive() {
        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.playback, mode: .default, options: [.mixWithOthers])
            try session.setActive(true)
        } catch {
            print("[-] keep-alive session: \(error)")
        }
        guard let url = Bundle.main.url(forResource: "welcome", withExtension: "wav") else { return }
        keepAlivePlayer = try? AVAudioPlayer(contentsOf: url)
        keepAlivePlayer?.numberOfLoops = -1
        keepAlivePlayer?.volume = 0.01
        keepAlivePlayer?.play()
    }
    
    func endBackgroundKeepAlive() {
        keepAlivePlayer?.stop()
        keepAlivePlayer = nil
        do {
            let session = AVAudioSession.sharedInstance()
            try session.setActive(false, options: .notifyOthersOnDeactivation)
            try session.setCategory(.ambient, mode: .default, options: [])
        } catch {}
    }
}
