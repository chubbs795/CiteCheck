// CiteCheck — checks statutes and other authorities against official or standard
// public sources: leginfo.legislature.ca.gov (California codes and Constitution),
// courts.ca.gov (Rules of Court) and Cornell LII (U.S. Code, C.F.R., U.S. Constitution).
import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking   // Linux (used only for testing)
#endif

enum StatuteCheck {
    case idle
    case checking
    case found(heading: String, preview: String, url: URL, warnings: [String])
    case notFound(message: String, url: URL?)
    case unverifiable(url: URL)
    case failed(String)
}

enum StatuteVerifier {
    private static let crcTitles = [1: "one", 2: "two", 3: "three", 4: "four", 5: "five",
                                    7: "seven", 8: "eight", 9: "nine", 10: "ten"]

    private static func encode(_ s: String) -> String {
        s.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed.subtracting(CharacterSet(charactersIn: "&=+"))) ?? s
    }

    /// First section of a list like "7920.000, 7920.005" or "54950-54963".
    private static func firstSection(_ s: Statute) -> String {
        s.section.components(separatedBy: CharacterSet(charactersIn: ",-–& ")).first { !$0.isEmpty } ?? s.section
    }

    /// Where the official or standard text lives.
    static func sourceURL(_ s: Statute) -> URL? {
        switch s.kind {
        case .calCode:
            return URL(string: "https://leginfo.legislature.ca.gov/faces/codes_displaySection.xhtml?lawCode=\(s.codeID)&sectionNum=\(encode(firstSection(s)))")
        case .calConst:
            if s.section.isEmpty { return URL(string: "https://leginfo.legislature.ca.gov/faces/codesTOCSelected.xhtml?tocCode=CONS") }
            return URL(string: "https://leginfo.legislature.ca.gov/faces/codes_displaySection.xhtml?lawCode=CONS&sectionNum=\(encode("SEC. \(s.section)."))&article=\(encode(s.article))")
        case .usConst:
            if let n = Int(s.amendment) { return URL(string: "https://www.law.cornell.edu/constitution/amendment\(Roman.string(n).lowercased())") }
            return URL(string: "https://www.law.cornell.edu/constitution/article\(s.article.lowercased())")
        case .calRules:
            let parts = s.section.split(separator: ".")
            guard parts.count == 2, let t = Int(parts[0]), let word = crcTitles[t] else { return nil }
            return URL(string: "https://courts.ca.gov/cms/rules/index/\(word)/rule\(parts[0])_\(parts[1])")
        case .usCode:
            return URL(string: "https://www.law.cornell.edu/uscode/text/\(s.title)/\(encode(s.section))")
        case .cfr:
            return URL(string: "https://www.law.cornell.edu/cfr/text/\(s.title)/\(encode(s.section))")
        case .calRegs, .agOpinion, .municipal:
            return nil
        }
    }

    static func searchURL(_ query: String) -> URL {
        URL(string: "https://www.google.com/search?q=\(encode(query))")!
    }

    static func check(_ s: Statute, searchQuery: String, completion: @escaping (StatuteCheck) -> Void) {
        let done: (StatuteCheck) -> Void = { r in DispatchQueue.main.async { completion(r) } }

        // Authorities without a dependable public page get a search link instead.
        guard let url = sourceURL(s) else { return done(.unverifiable(url: searchURL(searchQuery))) }

        // The U.S. Constitution can be checked without going online.
        if s.kind == .usConst {
            if let n = Int(s.amendment) {
                return done((1...27).contains(n)
                    ? .found(heading: "\(Ordinals.word(n)) Amendment", preview: "", url: url, warnings: [])
                    : .notFound(message: "The Constitution has 27 amendments.", url: nil))
            }
            let article = Roman.value(s.article) ?? 0
            return done((1...7).contains(article)
                ? .found(heading: "Article \(s.article)", preview: "", url: url, warnings: [])
                : .notFound(message: "The Constitution has seven articles.", url: nil))
        }

        var request = URLRequest(url: url)
        request.timeoutInterval = 20
        request.setValue("Mozilla/5.0 (Macintosh; Intel Mac OS X) CiteCheck/1.0", forHTTPHeaderField: "User-Agent")
        URLSession.shared.dataTask(with: request) { data, response, error in
            if let error { return done(.failed("Couldn't reach \(url.host ?? "the source"): \(error.localizedDescription)")) }
            let status = (response as? HTTPURLResponse)?.statusCode ?? 0
            let html = data.flatMap { String(data: $0, encoding: .utf8) ?? String(data: $0, encoding: .isoLatin1) } ?? ""

            switch s.kind {
            case .calCode, .calConst:
                guard status == 200, html.contains("codeLawSectionNoHead") else {
                    let message = s.kind == .calCode
                        ? "Not found in the current California codes. The section may have been repealed or renumbered (for example, the Public Records Act moved from Gov. Code § 6250 et seq. to § 7920.000 et seq. in 2023)."
                        : "That article and section weren't found in the current California Constitution."
                    return done(.notFound(message: message, url: url))
                }
                let text = sectionText(html)
                var warnings: [String] = []
                if s.multiple { warnings.append("Only the first section listed (\(firstSection(s))) was checked.") }
                if let first = s.subdivision.components(separatedBy: ")").first, !first.isEmpty,
                   !text.contains(first + ")") {
                    warnings.append("Subdivision \(first)) doesn't appear in the current text of this section.")
                }
                let heading = s.kind == .calCode
                    ? "\(s.code?.fullName ?? "") section \(firstSection(s))"
                    : "California Constitution, article \(s.article), section \(s.section)"
                done(.found(heading: heading, preview: String(text.prefix(420)), url: url, warnings: warnings))

            default:   // Rules of Court, U.S. Code, C.F.R.
                guard status == 200, !html.localizedCaseInsensitiveContains("<title>Page not found"),
                      !html.contains("404-not-found") else {
                    return done(.notFound(message: "No page was found for this citation at \(url.host ?? "the source").", url: url))
                }
                done(.found(heading: pageTitle(html), preview: "", url: url, warnings: []))
            }
        }.resume()
    }

    // MARK: HTML helpers

    private static func pageTitle(_ html: String) -> String {
        guard let start = html.range(of: "<title>"), let end = html.range(of: "</title>", range: start.upperBound..<html.endIndex)
        else { return "" }
        let title = decode(String(html[start.upperBound..<end.lowerBound]))
        return title.components(separatedBy: " | ").first?.trimmingCharacters(in: .whitespacesAndNewlines) ?? title
    }

    /// The section's text from a leginfo page.
    private static func sectionText(_ html: String) -> String {
        guard let anchor = html.range(of: "codeLawSectionNoHead"),
              let h6 = html.range(of: "<h6", range: anchor.upperBound..<html.endIndex) else { return "" }
        let tail = html[h6.lowerBound...]
        let end = tail.range(of: "javax.faces.ViewState")?.lowerBound ?? tail.index(tail.startIndex, offsetBy: min(20000, tail.count))
        var text = String(tail[..<end])
        text = text.replacingOccurrences(of: "<[^>]+>", with: " ", options: .regularExpression)
        text = decode(text)
        return text.replacingOccurrences(of: #"\s+"#, with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespaces)
    }

    private static func decode(_ s: String) -> String {
        var out = s
        for (entity, char) in [("&nbsp;", " "), ("&amp;", "&"), ("&quot;", "\""), ("&#39;", "'"), ("&apos;", "'"),
                               ("&sect;", "§"), ("&lt;", "<"), ("&gt;", ">"), ("&mdash;", "—"), ("&ndash;", "–"),
                               ("&rsquo;", "’"), ("&lsquo;", "‘"), ("&ldquo;", "“"), ("&rdquo;", "”")] {
            out = out.replacingOccurrences(of: entity, with: char)
        }
        // Numeric entities like &#8217; or &#x2019;
        let re = try! NSRegularExpression(pattern: "&#(x?)([0-9a-fA-F]+);")
        let ns = out as NSString
        var result = ""
        var last = 0
        for m in re.matches(in: out, range: NSRange(location: 0, length: ns.length)) {
            result += ns.substring(with: NSRange(location: last, length: m.range.location - last))
            let hex = ns.substring(with: m.range(at: 1)) == "x"
            if let code = UInt32(ns.substring(with: m.range(at: 2)), radix: hex ? 16 : 10), let scalar = UnicodeScalar(code) {
                result += String(Character(scalar))
            }
            last = m.range.location + m.range.length
        }
        result += ns.substring(from: last)
        return result
    }
}
