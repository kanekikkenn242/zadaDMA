import Foundation
struct RemoteProduct: Codable, Identifiable {
    let id, slug, name, category, filename, digest, url: String
}
actor RemotePatchStore {
    static let shared = RemotePatchStore()
    private let base = URL(string: "https://xkeyapi.onrender.com")!
    private var cache: [String: RemoteProduct] = [:]
    func catalog() async throws -> [RemoteProduct] {
        let url = base.appendingPathComponent("/api/products/catalog")
        let (data, _) = try await URLSession.shared.data(from: url)
        let list = try JSONDecoder().decode([RemoteProduct].self, from: data)
        for p in list { cache[p.slug] = p }
        return list
    }
    func fetchFile(slug: String) async throws -> (Data, RemoteProduct) {
        guard let p = cache[slug] else { throw NSError(domain: "rps", code: 404) }
        let url = base.appendingPathComponent("/api/products/files/\(slug)")
        let (data, _) = try await URLSession.shared.data(from: url)
        return (data, p)
    }
}
