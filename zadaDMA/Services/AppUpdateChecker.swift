import Foundation
enum AppUpdateChecker {
    static func check(_ done: @escaping (Bool, String?) -> Void) {
        let url = URL(string: "https://xkeyapi.onrender.com/api/version/check")!
        var req = URLRequest(url: url); req.httpMethod = "POST"
        let v = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? ""
        let b = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? ""
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.httpBody = try? JSONSerialization.data(withJSONObject: ["version": v, "build": b])
        URLSession.shared.dataTask(with: req) { data, _, _ in
            guard let data, let j = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
                DispatchQueue.main.async { done(false, nil) }; return
            }
            let blocked = (j["blocked"] as? Bool) ?? false
            let reason = j["reason"] as? String
            DispatchQueue.main.async { done(blocked, reason) }
        }.resume()
    }
}
