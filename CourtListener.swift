// CiteCheck — verifies citations against CourtListener's citation lookup API
// (https://www.courtlistener.com). Only the citation itself (e.g. "12 Cal. 4th 345") is sent.
import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking   // Linux (used only for testing)
#endif
#if canImport(Security)
import Security
#endif

struct CourtListenerMatch {
    let caseName: String
    let dateFiled: String       // "1995-07-20"
    let courtID: String         // e.g. "cal", "ca9" (may be empty)
    let url: URL?
    let citations: [String]     // e.g. ["12 Cal. 4th 345", "904 P.2d 1"]

    var year: String { String(dateFiled.prefix(4)) }
    var courtName: String { Courts.known[courtID]?.name ?? courtID }
    var courtAbbrev: String { Courts.known[courtID]?.abbrev ?? "" }
}

enum VerifyResult {
    case verified(CourtListenerMatch)
    case multiple([CourtListenerMatch])
    case notFound
    case invalid(String)
    case failed(String)
}

enum CourtListener {
    private static let base = "https://www.courtlistener.com/api/rest/v4"

    // MARK: Response types

    private struct FlexibleString: Decodable {
        let value: String
        init(from decoder: Decoder) throws {
            let c = try decoder.singleValueContainer()
            if let i = try? c.decode(Int.self) { value = String(i) } else { value = (try? c.decode(String.self)) ?? "" }
        }
    }
    private struct CitationObj: Decodable { let volume: FlexibleString?; let reporter: String?; let page: FlexibleString? }
    private struct Cluster: Decodable {
        let caseName: String?
        let dateFiled: String?
        let absoluteUrl: String?
        let docketId: Int?
        let citations: [CitationObj]?
    }
    private struct LookupResult: Decodable {
        let status: Int
        let errorMessage: String?
        let clusters: [Cluster]?
    }
    private struct Docket: Decodable { let courtId: String? }

    private static let decoder: JSONDecoder = {
        let d = JSONDecoder()
        d.keyDecodingStrategy = .convertFromSnakeCase
        return d
    }()

    // MARK: Lookup

    static func verify(_ citationText: String, token: String, completion: @escaping (VerifyResult) -> Void) {
        var request = URLRequest(url: URL(string: base + "/citation-lookup/")!)
        request.httpMethod = "POST"
        request.timeoutInterval = 20
        request.setValue("Token \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        var form = URLComponents()
        form.queryItems = [URLQueryItem(name: "text", value: citationText)]
        request.httpBody = form.percentEncodedQuery?.data(using: .utf8)

        URLSession.shared.dataTask(with: request) { data, response, error in
            let finish: (VerifyResult) -> Void = { r in DispatchQueue.main.async { completion(r) } }
            if let error { return finish(.failed("Couldn't reach CourtListener: \(error.localizedDescription)")) }
            let http = response as? HTTPURLResponse
            switch http?.statusCode ?? 0 {
            case 200: break
            case 401, 403: return finish(.failed("CourtListener rejected the API token. Check it in the CourtListener section below."))
            case 429: return finish(.failed("CourtListener's rate limit was reached. Wait a minute and try again."))
            default: return finish(.failed("CourtListener returned an error (HTTP \(http?.statusCode ?? 0))."))
            }
            guard let data, let results = try? decoder.decode([LookupResult].self, from: data) else {
                return finish(.failed("Couldn't read CourtListener's response."))
            }
            guard let result = results.first else { return finish(.notFound) }

            switch result.status {
            case 200, 300:
                let clusters = result.clusters ?? []
                resolveCourts(clusters, token: token) { matches in
                    if matches.isEmpty { finish(.notFound) }
                    else if result.status == 300 || matches.count > 1 { finish(.multiple(matches)) }
                    else { finish(.verified(matches[0])) }
                }
            case 404: finish(.notFound)
            case 400: finish(.invalid(result.errorMessage?.isEmpty == false ? result.errorMessage! : "CourtListener doesn't recognize that reporter."))
            case 429: finish(.failed("CourtListener's rate limit was reached. Wait a minute and try again."))
            default: finish(.failed("Unexpected CourtListener status \(result.status)."))
            }

        }.resume()
    }

    // Looks up each cluster's court (needed for the Bluebook/CSM court abbreviation).
    private static func resolveCourts(_ clusters: [Cluster], token: String, done: @escaping ([CourtListenerMatch]) -> Void) {
        let group = DispatchGroup()
        var courts = [Int: String]()
        let lock = NSLock()
        for id in Set(clusters.compactMap(\.docketId)) {
            group.enter()
            var docketRequest = URLRequest(url: URL(string: base + "/dockets/\(id)/?fields=court_id")!)
            docketRequest.setValue("Token \(token)", forHTTPHeaderField: "Authorization")
            docketRequest.timeoutInterval = 15
            URLSession.shared.dataTask(with: docketRequest) { data, _, _ in
                if let data, let docket = try? decoder.decode(Docket.self, from: data), let court = docket.courtId {
                    lock.lock(); courts[id] = court; lock.unlock()
                }
                group.leave()
            }.resume()
        }
        group.notify(queue: .global()) {
            done(clusters.map { cluster in
                CourtListenerMatch(
                    caseName: cluster.caseName ?? "",
                    dateFiled: cluster.dateFiled ?? "",
                    courtID: cluster.docketId.flatMap { courts[$0] } ?? "",
                    url: cluster.absoluteUrl.flatMap { URL(string: "https://www.courtlistener.com" + $0) },
                    citations: (cluster.citations ?? []).map {
                        "\($0.volume?.value ?? "") \($0.reporter ?? "") \($0.page?.value ?? "")"
                    })
            })
        }
    }
}

#if canImport(Security)
// MARK: - API token storage (macOS Keychain)

enum TokenStore {
    private static let service = "com.markvanni.citecheck"
    private static let account = "courtlistener-api-token"

    static func load() -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne,
        ]
        var item: CFTypeRef?
        guard SecItemCopyMatching(query as CFDictionary, &item) == errSecSuccess,
              let data = item as? Data else { return nil }
        return String(data: data, encoding: .utf8)
    }

    static func save(_ token: String) {
        let base: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
        ]
        SecItemDelete(base as CFDictionary)
        guard !token.isEmpty else { return }
        var add = base
        add[kSecValueData as String] = Data(token.utf8)
        SecItemAdd(add as CFDictionary, nil)
    }
}
#endif
