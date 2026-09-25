// CiteCheck — parses a case citation and formats it in California Style Manual
// (4th ed.) and Bluebook style.
import Foundation

enum ReporterKind {
    case calSupreme, calAppeal, calRptr, regional, scotus, fedAppeal, fedDistrict, unknown

    /// Whether a court abbreviation belongs in the parenthetical (e.g. "9th Cir. 2001").
    var needsCourt: Bool {
        switch self {
        case .calRptr, .regional, .fedAppeal, .fedDistrict, .unknown: return true
        case .calSupreme, .calAppeal, .scotus: return false
        }
    }
}

struct Reporter {
    let csm: String        // e.g. "Cal.App.4th"
    let bluebook: String   // e.g. "Cal. App. 4th"
    let kind: ReporterKind
}

enum Reporters {
    static func key(_ s: String) -> String {
        s.lowercased().filter { $0 != " " && $0 != "." }
    }

    static func lookup(_ s: String) -> Reporter? { table[key(s)] }

    static let table: [String: Reporter] = {
        var t: [String: Reporter] = [:]
        func add(_ csm: String, _ bb: String, _ kind: ReporterKind, _ aliases: [String] = []) {
            let r = Reporter(csm: csm, bluebook: bb, kind: kind)
            for name in [csm, bb] + aliases { t[key(name)] = r }
        }
        add("Cal.", "Cal.", .calSupreme)
        add("Cal.App.", "Cal. App.", .calAppeal)
        add("Cal.Rptr.", "Cal. Rptr.", .calRptr)
        for s in ["2d", "3d", "4th", "5th"] {
            add("Cal.\(s)", "Cal. \(s)", .calSupreme)
            add("Cal.App.\(s)", "Cal. App. \(s)", .calAppeal)
            add("Cal.App.\(s) Supp.", "Cal. App. \(s) Supp.", .calAppeal)
        }
        for s in ["2d", "3d"] { add("Cal.Rptr.\(s)", "Cal. Rptr. \(s)", .calRptr) }
        add("P.", "P.", .regional)
        add("P.2d", "P.2d", .regional)
        add("P.3d", "P.3d", .regional)
        add("U.S.", "U.S.", .scotus)
        add("S.Ct.", "S. Ct.", .scotus)
        add("L.Ed.", "L. Ed.", .scotus)
        add("L.Ed.2d", "L. Ed. 2d", .scotus)
        add("F.", "F.", .fedAppeal)
        for s in ["2d", "3d", "4th"] { add("F.\(s)", "F.\(s)", .fedAppeal) }
        add("Fed.Appx.", "F. App'x", .fedAppeal, ["F.App'x", "Fed. App'x", "F.Appx"])
        add("F.Supp.", "F. Supp.", .fedDistrict)
        for s in ["2d", "3d"] { add("F.Supp.\(s)", "F. Supp. \(s)", .fedDistrict) }
        return t
    }()
}

/// A citation broken into editable parts.
struct Citation: Equatable {
    var caseName = ""
    var year = ""
    var court = ""       // Bluebook-style court abbreviation, e.g. "9th Cir." or "N.D. Cal."
    var volume = ""
    var reporter = ""
    var page = ""
    var pin = ""

    var isEmpty: Bool { volume.isEmpty && reporter.isEmpty && page.isEmpty }
    var knownReporter: Reporter? { Reporters.lookup(reporter) }

    /// "12 Cal. 4th 345" — the form sent to CourtListener.
    var lookupText: String {
        "\(volume) \(knownReporter?.bluebook ?? reporter) \(page)"
    }
}

// MARK: - Parsing

enum CitationParser {
    private static let core = try! NSRegularExpression(
        pattern: #"(?<!\d)(\d{1,4})\s+([A-Za-z][A-Za-z0-9.' ]*?)\s+(\d{1,6})(?!\w)"#)
    private static let yearAtEnd = try! NSRegularExpression(pattern: #"\(([^()]*?)\s*(\d{4})\)\s*$"#)
    private static let yearAnywhere = try! NSRegularExpression(pattern: #"\(([^()]*?)\s*(\d{4})\)"#)
    private static let pinCite = try! NSRegularExpression(pattern: #"^\s*,\s*(?:at\s+)?(?:pp?\.\s*)?(\d[\d\-–, ]*\d|\d)"#)
    private static let versus = try! NSRegularExpression(pattern: #"\s+vs?\.?\s+"#)

    static func parse(_ raw: String) -> Citation? {
        var text = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        // A citation wrapped in parentheses, e.g. "(People v. Smith (2019) 32 Cal.App.5th 1071.)"
        if text.hasPrefix("(") && text.hasSuffix(")") { text.removeFirst(); text.removeLast() }
        while let last = text.last, ".; ".contains(last) { text.removeLast() }
        let ns = text as NSString
        let matches = core.matches(in: text, range: NSRange(location: 0, length: ns.length))
        // Prefer the first match whose reporter we recognize.
        guard let match = matches.first(where: { Reporters.lookup(ns.substring(with: $0.range(at: 2))) != nil })
                ?? matches.first else { return nil }

        var c = Citation()
        c.volume = ns.substring(with: match.range(at: 1))
        c.reporter = ns.substring(with: match.range(at: 2)).trimmingCharacters(in: .whitespaces)
        c.page = ns.substring(with: match.range(at: 3))
        if let known = Reporters.lookup(c.reporter) { c.reporter = known.csm }

        // Before the citation: case name, maybe a CSM-style "(court year)".
        var before = ns.substring(to: match.range.location)
        let beforeNS = before as NSString
        if let m = yearAtEnd.firstMatch(in: before, range: NSRange(location: 0, length: beforeNS.length)) {
            c.court = beforeNS.substring(with: m.range(at: 1)).trimmingCharacters(in: .whitespaces)
            c.year = beforeNS.substring(with: m.range(at: 2))
            before = beforeNS.substring(to: m.range.location)
        }
        var name = before.trimmingCharacters(in: .whitespaces)
        while let last = name.last, last == "," { name.removeLast() }
        name = name.trimmingCharacters(in: .whitespaces)
        name = versus.stringByReplacingMatches(in: name, range: NSRange(location: 0, length: (name as NSString).length),
                                               withTemplate: " v. ")
        c.caseName = name

        // After the citation: pin cite and/or a Bluebook-style "(court year)".
        var after = ns.substring(from: match.range.location + match.range.length)
        let afterNS = after as NSString
        if let m = pinCite.firstMatch(in: after, range: NSRange(location: 0, length: afterNS.length)) {
            c.pin = afterNS.substring(with: m.range(at: 1)).trimmingCharacters(in: CharacterSet(charactersIn: " ,"))
            after = afterNS.substring(from: m.range.location + m.range.length)
        }
        let rest = after as NSString
        if let m = yearAnywhere.firstMatch(in: after, range: NSRange(location: 0, length: rest.length)) {
            c.court = rest.substring(with: m.range(at: 1)).trimmingCharacters(in: CharacterSet(charactersIn: " ,"))
            c.year = rest.substring(with: m.range(at: 2))
        }
        return c
    }
}

// MARK: - Formatting

/// Formatted text as pieces, some italic (case names, "supra").
struct Styled {
    var pieces: [(text: String, italic: Bool)] = []
    mutating func add(_ s: String, italic: Bool = false) { if !s.isEmpty { pieces.append((s, italic)) } }
    var plain: String { pieces.map(\.text).joined() }
}

enum CitationFormatter {
    private static let governmentParties: Set<String> = [
        "people", "the people", "united states", "state", "state of california", "commonwealth",
    ]

    /// Short-form name: first party, or the other party when the first is the government.
    static func shortName(_ caseName: String) -> String {
        let parts = caseName.components(separatedBy: " v. ")
        guard parts.count >= 2 else { return caseName }
        let first = parts[0].trimmingCharacters(in: .whitespaces)
        var name = governmentParties.contains(first.lowercased())
            ? parts[1].trimmingCharacters(in: .whitespaces) : first
        // "Acme, Inc." → "Acme"
        for suffix in [", Inc.", " Inc.", ", LLC", " LLC", ", Corp.", " Corp.", " Co.", ", Ltd.", " Ltd."]
        where name.hasSuffix(suffix) && name.count > suffix.count {
            name = String(name.dropLast(suffix.count))
            break
        }
        return name
    }

    /// Converts a Bluebook court abbreviation to California Style Manual spacing ("N.D. Cal." → "N.D.Cal.").
    static func csmCourt(_ court: String) -> String {
        court.contains("Cir.") ? court : court.replacingOccurrences(of: ". ", with: ".")
    }

    private static func year(_ c: Citation) -> String { c.year.isEmpty ? "[year]" : c.year }
    private static func pinIsRange(_ pin: String) -> Bool { pin.contains { "-–,".contains($0) } }

    // California Style Manual: Smith v. Jones (1995) 12 Cal.4th 345, 350
    static func csmFull(_ c: Citation) -> Styled {
        var s = Styled()
        let reporter = c.knownReporter
        if !c.caseName.isEmpty { s.add(c.caseName, italic: true); s.add(" ") }
        let needsCourt = (reporter?.kind.needsCourt ?? true) && !c.court.isEmpty
        s.add("(" + (needsCourt ? csmCourt(c.court) + " " : "") + year(c) + ") ")
        s.add("\(c.volume) \(reporter?.csm ?? c.reporter) \(c.page)")
        if !c.pin.isEmpty { s.add(", \(c.pin)") }
        return s
    }

    static func csmParenthetical(_ c: Citation) -> Styled {
        var s = Styled()
        s.add("(")
        s.pieces += csmFull(c).pieces
        s.add(".)")
        return s
    }

    // (Smith, supra, 12 Cal.4th at p. 350.)
    static func csmShort(_ c: Citation) -> Styled {
        var s = Styled()
        let pin = c.pin.isEmpty ? c.page : c.pin
        s.add("(")
        if !c.caseName.isEmpty {
            s.add(shortName(c.caseName), italic: true)
            s.add(", ")
            s.add("supra", italic: true)
            s.add(", ")
        }
        s.add("\(c.volume) \(c.knownReporter?.csm ?? c.reporter) at \(pinIsRange(pin) ? "pp." : "p.") \(pin).)")
        return s
    }

    // Bluebook: Smith v. Jones, 12 Cal. 4th 345, 350 (1995).
    static func bluebookFull(_ c: Citation) -> Styled {
        var s = Styled()
        let reporter = c.knownReporter
        if !c.caseName.isEmpty { s.add(c.caseName, italic: true); s.add(", ") }
        s.add("\(c.volume) \(reporter?.bluebook ?? c.reporter) \(c.page)")
        if !c.pin.isEmpty { s.add(", \(c.pin)") }
        let needsCourt = (reporter?.kind.needsCourt ?? true) && !c.court.isEmpty
        s.add(" (" + (needsCourt ? c.court + " " : "") + year(c) + ").")
        return s
    }

    // Smith, 12 Cal. 4th at 350.
    static func bluebookShort(_ c: Citation) -> Styled {
        var s = Styled()
        let pin = c.pin.isEmpty ? c.page : c.pin
        if !c.caseName.isEmpty { s.add(shortName(c.caseName), italic: true); s.add(", ") }
        s.add("\(c.volume) \(c.knownReporter?.bluebook ?? c.reporter) at \(pin).")
        return s
    }
}

// MARK: - Court names from CourtListener court IDs

enum Courts {
    /// Bluebook abbreviation and a readable name for common CourtListener court IDs.
    static let known: [String: (abbrev: String, name: String)] = {
        var m: [String: (abbrev: String, name: String)] = [
            "scotus": ("", "U.S. Supreme Court"),
            "cal": ("Cal.", "California Supreme Court"),
            "calctapp": ("Cal. Ct. App.", "California Court of Appeal"),
            "calappdeptsuper": ("Cal. App. Dep't Super. Ct.", "Appellate Division, Superior Court"),
            "cadc": ("D.C. Cir.", "U.S. Court of Appeals, D.C. Circuit"),
            "cafc": ("Fed. Cir.", "U.S. Court of Appeals, Federal Circuit"),
            "cand": ("N.D. Cal.", "U.S. District Court, N.D. California"),
            "cacd": ("C.D. Cal.", "U.S. District Court, C.D. California"),
            "caed": ("E.D. Cal.", "U.S. District Court, E.D. California"),
            "casd": ("S.D. Cal.", "U.S. District Court, S.D. California"),
            "nysd": ("S.D.N.Y.", "U.S. District Court, S.D. New York"),
            "nyed": ("E.D.N.Y.", "U.S. District Court, E.D. New York"),
            "dcd": ("D.D.C.", "U.S. District Court, District of Columbia"),
        ]
        let ordinals = ["1st", "2d", "3d", "4th", "5th", "6th", "7th", "8th", "9th", "10th", "11th"]
        for (i, o) in ordinals.enumerated() {
            m["ca\(i + 1)"] = ("\(o) Cir.", "U.S. Court of Appeals, \(o) Circuit")
        }
        return m
    }()
}
