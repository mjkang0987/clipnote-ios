import Foundation

actor APIClient {
    private let baseURL: URL
    private let session: URLSession

    init(baseURL: URL, session: URLSession = .shared) {
        self.baseURL = baseURL
        self.session = session
    }

    static let shared: APIClient = {
        let raw = Bundle.main.object(forInfoDictionaryKey: "API_BASE") as? String
        let base = URL(string: (raw?.isEmpty == false ? raw! : "https://clipnote.co.kr"))!
        return APIClient(baseURL: base)
    }()

    struct ClipsResponse: Codable {
        let loggedIn: Bool
        let clips: [DbClip]
    }

    // GET /api/metadata?url=...
    func fetchMetadata(url: String) async throws -> ClipMetadata {
        var comps = URLComponents(url: baseURL.appendingPathComponent("api/metadata"),
                                  resolvingAgainstBaseURL: false)!
        comps.queryItems = [URLQueryItem(name: "url", value: url)]
        let (data, resp) = try await session.data(from: comps.url!)
        guard let http = resp as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            throw URLError(.badServerResponse)
        }
        return try JSONDecoder().decode(ClipMetadata.self, from: data)
    }

    // POST /api/clip
    func createClip(_ input: CreateClipInput, accessToken: String?) async -> CreateClipResult {
        var req = URLRequest(url: baseURL.appendingPathComponent("api/clip"))
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        if let t = accessToken { req.setValue("Bearer \(t)", forHTTPHeaderField: "Authorization") }
        req.httpBody = try? JSONEncoder().encode(input)
        do {
            let (data, resp) = try await session.data(for: req)
            let http = resp as? HTTPURLResponse
            let decoded = try? JSONDecoder().decode(CreateClipResult.self, from: data)
            if let http, !(200..<300).contains(http.statusCode) {
                return CreateClipResult(slug: nil, shareUrl: nil, alreadySaved: nil,
                                        error: decoded?.error ?? "clip \(http.statusCode)")
            }
            // 2xx: use decoded result if available; otherwise treat as success (error: nil)
            return decoded ?? CreateClipResult(slug: nil, shareUrl: nil, alreadySaved: nil, error: nil)
        } catch {
            return CreateClipResult(slug: nil, shareUrl: nil, alreadySaved: nil, error: "network")
        }
    }

    // GET /api/og?title=...&g=...&desc=...&site=...
    func ogImageURL(title: String, description: String?, siteName: String?, gradient: String) -> URL {
        var comps = URLComponents(url: baseURL.appendingPathComponent("api/og"),
                                  resolvingAgainstBaseURL: false)!
        var items = [URLQueryItem(name: "title", value: title),
                     URLQueryItem(name: "g", value: gradient)]
        if let d = description, !d.isEmpty { items.append(URLQueryItem(name: "desc", value: d)) }
        if let s = siteName, !s.isEmpty { items.append(URLQueryItem(name: "site", value: s)) }
        comps.queryItems = items
        return comps.url!
    }

    // GET /api/clips
    func getClips(accessToken: String?) async -> (loggedIn: Bool, clips: [DbClip]) {
        var req = URLRequest(url: baseURL.appendingPathComponent("api/clips"))
        if let t = accessToken { req.setValue("Bearer \(t)", forHTTPHeaderField: "Authorization") }
        do {
            let (data, resp) = try await session.data(for: req)
            guard let http = resp as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
                return (false, [])
            }
            let decoded = try JSONDecoder().decode(ClipsResponse.self, from: data)
            return (decoded.loggedIn, decoded.clips)
        } catch {
            return (false, [])
        }
    }

    // PATCH /api/clip/{slug}
    func updateClip(slug: String, title: String?, tags: [String]?, shared: Bool?,
                    accessToken: String?) async -> Bool {
        var req = URLRequest(url: baseURL.appendingPathComponent("api/clip/\(slug)"))
        req.httpMethod = "PATCH"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        if let t = accessToken { req.setValue("Bearer \(t)", forHTTPHeaderField: "Authorization") }
        var patch: [String: Any] = [:]
        if let title { patch["title"] = title }
        if let tags { patch["tags"] = tags }
        if let shared { patch["shared"] = shared }
        req.httpBody = try? JSONSerialization.data(withJSONObject: patch)
        return await is2xx(req)
    }

    // DELETE /api/clip/{slug}
    func deleteClip(slug: String, accessToken: String?) async -> Bool {
        var req = URLRequest(url: baseURL.appendingPathComponent("api/clip/\(slug)"))
        req.httpMethod = "DELETE"
        if let t = accessToken { req.setValue("Bearer \(t)", forHTTPHeaderField: "Authorization") }
        return await is2xx(req)
    }

    private func is2xx(_ req: URLRequest) async -> Bool {
        do {
            let (_, resp) = try await session.data(for: req)
            guard let http = resp as? HTTPURLResponse else { return false }
            return (200..<300).contains(http.statusCode)
        } catch {
            return false
        }
    }
}
