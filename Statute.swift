// CiteCheck — statutes, constitutions, rules, regulations and other authorities:
// parsing and California Style Manual / Bluebook formatting.
import Foundation

enum AuthorityKind: String {
    case calCode, calConst, usConst, calRules, calRegs, usCode, cfr, agOpinion, municipal

    var title: String {
        switch self {
        case .calCode: return "California code section"
        case .calConst: return "California Constitution"
        case .usConst: return "U.S. Constitution"
        case .calRules: return "California Rule of Court"
        case .calRegs: return "California Code of Regulations"
        case .usCode: return "United States Code"
        case .cfr: return "Code of Federal Regulations"
        case .agOpinion: return "California Attorney General opinion"
        case .municipal: return "Municipal code"
        }
    }
}

struct CalCode: Identifiable {
    let id: String            // leginfo law code, e.g. "GOV"
    let fullName: String      // "Government Code"
    let csm: String           // "Gov. Code"
    let bluebook: String      // "Cal. Gov't Code"
    let aliases: [String]
}

enum CalCodes {
    static let all: [CalCode] = [
        CalCode(id: "BPC", fullName: "Business and Professions Code", csm: "Bus. & Prof. Code", bluebook: "Cal. Bus. & Prof. Code", aliases: ["b and p", "bp", "bpc"]),
        CalCode(id: "CIV", fullName: "Civil Code", csm: "Civ. Code", bluebook: "Cal. Civ. Code", aliases: ["cc"]),
        CalCode(id: "CCP", fullName: "Code of Civil Procedure", csm: "Code Civ. Proc.", bluebook: "Cal. Civ. Proc. Code", aliases: ["ccp"]),
        CalCode(id: "COM", fullName: "Commercial Code", csm: "Cal. U. Com. Code", bluebook: "Cal. Com. Code", aliases: ["com code", "u com code", "ucc"]),
        CalCode(id: "CORP", fullName: "Corporations Code", csm: "Corp. Code", bluebook: "Cal. Corp. Code", aliases: []),
        CalCode(id: "EDC", fullName: "Education Code", csm: "Ed. Code", bluebook: "Cal. Educ. Code", aliases: ["educ code"]),
        CalCode(id: "ELEC", fullName: "Elections Code", csm: "Elec. Code", bluebook: "Cal. Elec. Code", aliases: []),
        CalCode(id: "EVID", fullName: "Evidence Code", csm: "Evid. Code", bluebook: "Cal. Evid. Code", aliases: []),
        CalCode(id: "FAM", fullName: "Family Code", csm: "Fam. Code", bluebook: "Cal. Fam. Code", aliases: []),
        CalCode(id: "FIN", fullName: "Financial Code", csm: "Fin. Code", bluebook: "Cal. Fin. Code", aliases: []),
        CalCode(id: "FGC", fullName: "Fish and Game Code", csm: "Fish & G. Code", bluebook: "Cal. Fish & Game Code", aliases: []),
        CalCode(id: "FAC", fullName: "Food and Agricultural Code", csm: "Food & Agr. Code", bluebook: "Cal. Food & Agric. Code", aliases: []),
        CalCode(id: "GOV", fullName: "Government Code", csm: "Gov. Code", bluebook: "Cal. Gov't Code", aliases: ["govt code", "gc"]),
        CalCode(id: "HNC", fullName: "Harbors and Navigation Code", csm: "Harb. & Nav. Code", bluebook: "Cal. Harb. & Nav. Code", aliases: []),
        CalCode(id: "HSC", fullName: "Health and Safety Code", csm: "Health & Saf. Code", bluebook: "Cal. Health & Safety Code", aliases: ["h and s", "hsc"]),
        CalCode(id: "INS", fullName: "Insurance Code", csm: "Ins. Code", bluebook: "Cal. Ins. Code", aliases: []),
        CalCode(id: "LAB", fullName: "Labor Code", csm: "Lab. Code", bluebook: "Cal. Lab. Code", aliases: []),
        CalCode(id: "MVC", fullName: "Military and Veterans Code", csm: "Mil. & Vet. Code", bluebook: "Cal. Mil. & Vet. Code", aliases: []),
        CalCode(id: "PEN", fullName: "Penal Code", csm: "Pen. Code", bluebook: "Cal. Penal Code", aliases: ["pc"]),
        CalCode(id: "PROB", fullName: "Probate Code", csm: "Prob. Code", bluebook: "Cal. Prob. Code", aliases: []),
        CalCode(id: "PCC", fullName: "Public Contract Code", csm: "Pub. Contract Code", bluebook: "Cal. Pub. Cont. Code", aliases: ["pub cont code", "pcc"]),
        CalCode(id: "PRC", fullName: "Public Resources Code", csm: "Pub. Resources Code", bluebook: "Cal. Pub. Res. Code", aliases: ["pub res code", "prc"]),
        CalCode(id: "PUC", fullName: "Public Utilities Code", csm: "Pub. Util. Code", bluebook: "Cal. Pub. Util. Code", aliases: ["puc"]),
        CalCode(id: "RTC", fullName: "Revenue and Taxation Code", csm: "Rev. & Tax. Code", bluebook: "Cal. Rev. & Tax. Code", aliases: ["r and t", "rtc"]),
        CalCode(id: "SHC", fullName: "Streets and Highways Code", csm: "Sts. & Hy. Code", bluebook: "Cal. Sts. & High. Code", aliases: []),
        CalCode(id: "UIC", fullName: "Unemployment Insurance Code", csm: "Unemp. Ins. Code", bluebook: "Cal. Unemp. Ins. Code", aliases: []),
        CalCode(id: "VEH", fullName: "Vehicle Code", csm: "Veh. Code", bluebook: "Cal. Veh. Code", aliases: ["vc"]),
        CalCode(id: "WAT", fullName: "Water Code", csm: "Wat. Code", bluebook: "Cal. Water Code", aliases: []),
        CalCode(id: "WIC", fullName: "Welfare and Institutions Code", csm: "Welf. & Inst. Code", bluebook: "Cal. Welf. & Inst. Code", aliases: ["w and i", "wic"]),
    ]

    static func code(_ id: String) -> CalCode? { all.first { $0.id == id } }

    /// Lowercase, "&" → "and", punctuation → spaces.
    static func normalize(_ s: String) -> String {
        var t = s.lowercased().replacingOccurrences(of: "&", with: " and ").replacingOccurrences(of: "’", with: "'")
        t = t.replacingOccurrences(of: #"[.'`,]"#, with: " ", options: .regularExpression)
        t = t.replacingOccurrences(of: #"\bgov t\b"#, with: "govt", options: .regularExpression)
        return t.replacingOccurrences(of: #"\s+"#, with: " ", options: .regularExpression).trimmingCharacters(in: .whitespaces)
    }

    /// Every way of naming each code, longest first.
    static let aliases: [(alias: String, code: CalCode)] = {
        var list: [(String, CalCode)] = []
        for code in all {
            var names = Set([code.fullName, code.csm, code.bluebook].map(normalize))
            let bb = normalize(code.bluebook)
            if bb.hasPrefix("cal ") { names.insert(String(bb.dropFirst(4))) }
            for a in code.aliases { names.insert(normalize(a)) }
            for n in names { list.append((n, code)) }
        }
        return list.sorted { $0.0.count > $1.0.count }
    }()
}

/// A non-case authority broken into editable parts.
struct Statute: Equatable {
    var kind: AuthorityKind
    var codeID = ""          // California code (leginfo ID)
    var title = ""           // U.S.C./C.F.R./Cal. Code Regs. title; Attorney General volume
    var article = ""         // constitution article (Roman numerals)
    var amendment = ""       // U.S. Const. amendment number (1–27)
    var section = ""         // section, rule number, or AG opinion first page
    var clause = ""
    var subdivision = ""     // e.g. "(e)(4)"
    var pin = ""             // AG opinion pin page
    var multiple = false     // "§§"
    var year = ""
    var place = ""           // municipal: "Palo Alto"

    var code: CalCode? { CalCodes.code(codeID) }
}

// MARK: - Parsing

enum StatuteParser {
    private struct Found {
        let groups: [String]
        let end: Int          // UTF-16 offset just past the match
    }

    private static func find(_ pattern: String, in text: String) -> Found? {
        guard let re = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]) else { return nil }
        let ns = text as NSString
        guard let m = re.firstMatch(in: text, range: NSRange(location: 0, length: ns.length)) else { return nil }
        let groups = (0..<m.numberOfRanges).map { i -> String in
            let r = m.range(at: i)
            return r.location == NSNotFound ? "" : ns.substring(with: r)
        }
        return Found(groups: groups, end: m.range.location + m.range.length)
    }

    private static func rest(_ text: String, after f: Found) -> String {
        (text as NSString).substring(from: f.end)
    }

    /// Reads "(e)(4)" or ", subd. (e)(4)" at the start of `text`.
    private static func subdivision(_ text: String) -> String {
        // "(2024)" is a year, not a subdivision.
        let token = #"(?:\((?!\d{4}\))[a-zA-Z0-9]{1,4}\)\s*)+"#
        let f = find(#"^\s*("# + token + ")", in: text)
            ?? find(#"^\s*,?\s*subd(?:ivision|s?\.)?\s*("# + token + ")", in: text)
        return f.map { $0.groups[1].replacingOccurrences(of: " ", with: "") } ?? ""
    }

    private static func year(_ text: String) -> String {
        find(#"\((?:[^()]*?\s)?(\d{4})\)"#, in: text)?.groups[1] ?? ""
    }

    static func parse(_ raw: String) -> Statute? {
        var text = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        if text.hasPrefix("(") && text.hasSuffix(")") { text.removeFirst(); text.removeLast() }
        while let last = text.last, ".; ".contains(last) { text.removeLast() }
        guard !text.isEmpty else { return nil }

        let parsers: [(String) -> Statute?] = [
            californiaConstitution, usConstitution, rulesOfCourt, regulations,
            usCode, cfr, attorneyGeneral, municipal, californiaCode,
        ]
        for parser in parsers {
            if let found = parser(text) { return found }
        }
        return nil
    }

    private static let sectionPattern = #"(?:§|\bsec(?:tion|\.)?)\s*(\d+(?:\.\d+)?[a-z]?)"#

    private static func californiaConstitution(_ text: String) -> Statute? {
        guard find(#"\bCal(?:\.|ifornia)?\s*Const"#, in: text) != nil,
              let art = find(#"\bart(?:icle|\.)?\s*((?:[IVXL]+|\d{1,2})(?:\s?[A-D])?)\b"#, in: text) else { return nil }
        var s = Statute(kind: .calConst)
        s.article = Roman.normalizeArticle(art.groups[1])
        if let sec = find(sectionPattern, in: text) {
            s.section = sec.groups[1]
            s.subdivision = subdivision(rest(text, after: sec))
        }
        return s
    }

    private static func usConstitution(_ text: String) -> Statute? {
        guard find(#"\b(?:U\.?\s?S\.?\s*Const|United\s+States\s+Constitution|Constitution\s+of\s+the\s+United\s+States)|\bamend(?:ment|\.)?\b"#, in: text) != nil
        else { return nil }
        var s = Statute(kind: .usConst)
        if let a = find(#"\b(\d{1,2})(?:st|nd|rd|th)?\s+amend"#, in: text) {
            s.amendment = a.groups[1]
        } else if let a = find(#"\bamend(?:ment|\.)?\s+([IVXL]+|\d{1,2})\b"#, in: text) {
            s.amendment = Roman.value(a.groups[1]).map { String($0) } ?? a.groups[1]
        } else if let n = Ordinals.amendmentNumber(in: text) {
            s.amendment = String(n)
        } else if let art = find(#"\bart(?:icle|\.)?\s*([IVX]+|\d)\b"#, in: text) {
            s.article = Roman.normalizeArticle(art.groups[1])
        } else {
            return nil
        }
        if let sec = find(#"(?:§|\bsec(?:tion|\.)?)\s*(\d+)"#, in: text) { s.section = sec.groups[1] }
        if let cl = find(#"\bcl(?:ause|\.)?\s*(\d+)"#, in: text) { s.clause = cl.groups[1] }
        return s
    }

    private static func rulesOfCourt(_ text: String) -> Statute? {
        guard find(#"rules?\s+of\s+court|\bCal\.?\s*R(?:ules|\.)?\s*(?:of\s+)?Ct\b|\bCRC\b"#, in: text) != nil,
              let rule = find(#"(\d{1,2}\.\d{1,4})"#, in: text) else { return nil }
        var s = Statute(kind: .calRules)
        s.section = rule.groups[1]
        s.subdivision = subdivision(rest(text, after: rule))
        return s
    }

    private static func regulations(_ text: String) -> Statute? {
        guard find(#"Code\s+(?:of\s+)?Reg(?:ulation)?s?\b|\bC\.?C\.?R\b"#, in: text) != nil,
              let t = find(#"\btit(?:le|\.)?\s*(\d{1,2})\b|\b(\d{1,2})\s*C\.?C\.?R\b"#, in: text),
              let sec = find(#"(?:§|\bsec(?:tion|\.)?|C\.?C\.?R\.?)\s*(\d+(?:\.\d+)*)"#, in: text) else { return nil }
        var s = Statute(kind: .calRegs)
        s.title = t.groups[1].isEmpty ? t.groups[2] : t.groups[1]
        s.section = sec.groups[1]
        s.subdivision = subdivision(rest(text, after: sec))
        s.year = year(text)
        return s
    }

    private static func usCode(_ text: String) -> Statute? {
        guard let f = find(#"\b(\d{1,2})\s*U\.?\s?S\.?\s?C(?:ode)?\.?(?:\s*A\.?)?\s*(?:§§?|sec(?:tion|\.)?)?\s*(\d+[a-zA-Z]*(?:-\d+[a-zA-Z]*)?)"#, in: text)
        else { return nil }
        var s = Statute(kind: .usCode)
        s.title = f.groups[1]
        s.section = f.groups[2]
        s.subdivision = subdivision(rest(text, after: f))
        return s
    }

    private static func cfr(_ text: String) -> Statute? {
        guard let f = find(#"\b(\d{1,2})\s*C\.?\s?F\.?\s?R\.?\s*(?:§§?|sec(?:tion|\.)?|part)?\s*(\d+(?:\.\d+)?)"#, in: text)
        else { return nil }
        var s = Statute(kind: .cfr)
        s.title = f.groups[1]
        s.section = f.groups[2]
        s.subdivision = subdivision(rest(text, after: f))
        s.year = year(text)
        return s
    }

    private static func attorneyGeneral(_ text: String) -> Statute? {
        guard let f = find(#"\b(\d{1,3})\s*Ops?\.?\s*Cal\.?\s*Att(?:orney|'?y|’y)?\.?\s*Gen(?:eral)?\.?\s*(\d{1,4})(?:\s*,\s*(\d{1,4}))?"#, in: text)
        else { return nil }
        var s = Statute(kind: .agOpinion)
        s.title = f.groups[1]
        s.section = f.groups[2]
        s.pin = f.groups[3]
        s.year = year(text)
        return s
    }

    private static func municipal(_ text: String) -> Statute? {
        var s = Statute(kind: .municipal)
        if let f = find(#"\bPAMC\s*(?:§|sec(?:tion|\.)?)?\s*(\d+(?:\.\d+)*)"#, in: text) {
            s.place = "Palo Alto"
            s.section = f.groups[1]
            s.subdivision = subdivision(rest(text, after: f))
        } else if let f = find(#"\b([A-Z][A-Za-z]+(?:\s+[A-Z][A-Za-z]+){0,3})\s*,?\s*(?:Cal\.?,?\s*)?Mun(?:icipal|\.)?\s*Code\s*,?\s*(?:§|sec(?:tion|\.)?)?\s*(\d+(?:\.\d+)*)"#, in: text) {
            var place = f.groups[1]
            if place.lowercased().hasPrefix("the ") { place = String(place.dropFirst(4)) }
            s.place = place
            s.section = f.groups[2]
            s.subdivision = subdivision(rest(text, after: f))
        } else {
            return nil
        }
        s.year = year(text)
        return s
    }

    private static func californiaCode(_ text: String) -> Statute? {
        let normalized = " " + CalCodes.normalize(text) + " "
        guard let code = CalCodes.aliases.first(where: { normalized.contains(" \($0.alias) ") })?.code else { return nil }
        var s = Statute(kind: .calCode)
        s.codeID = code.id
        if let multi = find(#"(?:§§|\bsections\b)\s*([\d.]+[a-z]?(?:\s*(?:,|-|–|and|&)\s*[\d.]+[a-z]?)+)"#, in: text) {
            s.multiple = true
            s.section = multi.groups[1].replacingOccurrences(of: " and ", with: ", ")
            return s
        }
        guard let sec = find(#"(?:§|\bsec(?:tion|\.)?)\s*(\d+(?:\.\d+)*[a-z]?)"#, in: text)
                ?? find(#"(?<![\w.])(\d+(?:\.\d+)*[a-z]?)(?![\w.])"#, in: text) else { return nil }
        s.section = sec.groups[1]
        s.subdivision = subdivision(rest(text, after: sec))
        return s
    }
}

// MARK: - Numbers

enum Roman {
    private static let table: [(Int, String)] = [(1000, "M"), (900, "CM"), (500, "D"), (400, "CD"), (100, "C"), (90, "XC"),
                                                 (50, "L"), (40, "XL"), (10, "X"), (9, "IX"), (5, "V"), (4, "IV"), (1, "I")]
    static func string(_ n: Int) -> String {
        var n = n, out = ""
        for (v, s) in table { while n >= v { out += s; n -= v } }
        return out
    }
    static func value(_ s: String) -> Int? {
        let up = s.uppercased()
        if let n = Int(up) { return n }
        var i = up.startIndex, total = 0
        for (v, sym) in table {
            while up[i...].hasPrefix(sym) { total += v; i = up.index(i, offsetBy: sym.count) }
        }
        return i == up.endIndex && total > 0 ? total : nil
    }
    /// "13 a" / "xiiia" → "XIII A"
    static func normalizeArticle(_ s: String) -> String {
        let trimmed = s.trimmingCharacters(in: .whitespaces)
        if let n = Int(trimmed) { return string(n) }
        let up = trimmed.uppercased().replacingOccurrences(of: " ", with: "")
        if let last = up.last, "ABCD".contains(last), up.count > 1, value(up) == nil,
           let base = value(String(up.dropLast())) {
            return string(base) + " " + String(last)
        }
        return up
    }
}

enum Ordinals {
    static let words = ["First", "Second", "Third", "Fourth", "Fifth", "Sixth", "Seventh", "Eighth", "Ninth", "Tenth",
                        "Eleventh", "Twelfth", "Thirteenth", "Fourteenth", "Fifteenth", "Sixteenth", "Seventeenth",
                        "Eighteenth", "Nineteenth", "Twentieth", "Twenty-first", "Twenty-second", "Twenty-third",
                        "Twenty-fourth", "Twenty-fifth", "Twenty-sixth", "Twenty-seventh"]

    static func word(_ n: Int) -> String { (1...words.count).contains(n) ? words[n - 1] : "\(n)th" }

    static func numeric(_ n: Int) -> String {
        let suffix: String
        switch (n % 10, n % 100) {
        case (_, 11...13): suffix = "th"
        case (1, _): suffix = "st"
        case (2, _): suffix = "nd"
        case (3, _): suffix = "rd"
        default: suffix = "th"
        }
        return "\(n)\(suffix)"
    }

    /// Finds "Fourteenth Amendment" etc.
    static func amendmentNumber(in text: String) -> Int? {
        let lower = text.lowercased().replacingOccurrences(of: "-", with: " ")
        for (i, w) in words.enumerated().reversed() {        // reversed so "twenty-first" wins over "first"
            if lower.contains(w.lowercased().replacingOccurrences(of: "-", with: " ") + " amendment") { return i + 1 }
        }
        return nil
    }
}

// MARK: - Formatting

enum StatuteFormatter {
    struct Output {
        let csmParenthetical: String   // (Gov. Code, § 7920.000, subd. (a).)
        let csmText: String            // Government Code section 7920.000, subdivision (a)
        let csmShort: String           // (§ 7920.000, subd. (a).)
        let bluebook: String           // Cal. Gov't Code § 7920.000(a) (West 2026).
        let bluebookShort: String      // § 7920.000(a).
    }

    static func format(_ s: Statute, bluebookYear: String) -> Output {
        let o = rawFormat(s, bluebookYear: bluebookYear)
        // Avoid a doubled period when a citation already ends in one ("14th Amend.").
        func tidy(_ t: String) -> String {
            var t = t.replacingOccurrences(of: "..)", with: ".)")
            while t.hasSuffix("..") { t.removeLast() }
            return t
        }
        return Output(csmParenthetical: tidy(o.csmParenthetical), csmText: tidy(o.csmText), csmShort: tidy(o.csmShort),
                      bluebook: tidy(o.bluebook), bluebookShort: tidy(o.bluebookShort))
    }

    private static func rawFormat(_ s: Statute, bluebookYear: String) -> Output {
        let sub = s.subdivision
        let csmSub = sub.isEmpty ? "" : ", subd. \(sub)"
        let textSub = sub.isEmpty ? "" : ", subdivision \(sub)"
        let sym = s.multiple ? "§§" : "§"
        let word = s.multiple ? "sections" : "section"
        let yr = s.year.isEmpty ? "[year]" : s.year

        switch s.kind {
        case .calCode:
            let code = s.code
            let csm = code?.csm ?? "[Code]", bb = code?.bluebook ?? "[Code]", full = code?.fullName ?? "[Code]"
            let bbYear = bluebookYear.isEmpty ? "" : " (West \(bluebookYear))"
            return Output(csmParenthetical: "(\(csm), \(sym) \(s.section)\(csmSub).)",
                          csmText: "\(full) \(word) \(s.section)\(textSub)",
                          csmShort: "(\(sym) \(s.section)\(csmSub).)",
                          bluebook: "\(bb) \(sym) \(s.section)\(sub)\(bbYear).",
                          bluebookShort: "\(sym) \(s.section)\(sub).")

        case .calConst:
            let sec = s.section.isEmpty ? "" : ", § \(s.section)"
            let textSec = s.section.isEmpty ? "" : ", section \(s.section)"
            let core = "Cal. Const., art. \(s.article)\(sec)\(csmSub)"
            return Output(csmParenthetical: "(\(core).)",
                          csmText: "California Constitution, article \(s.article)\(textSec)\(textSub)",
                          csmShort: "(\(core).)",
                          bluebook: "Cal. Const. art. \(s.article)\(sec)\(sub).",
                          bluebookShort: "Cal. Const. art. \(s.article)\(sec)\(sub).")

        case .usConst:
            let sec = s.section.isEmpty ? "" : ", § \(s.section)"
            let textSec = s.section.isEmpty ? "" : ", section \(s.section)"
            let cl = s.clause.isEmpty ? "" : ", cl. \(s.clause)"
            let textCl = s.clause.isEmpty ? "" : ", clause \(s.clause)"
            if let n = Int(s.amendment) {
                let core = "U.S. Const., \(Ordinals.numeric(n)) Amend.\(sec)"
                let bb = "U.S. Const. amend. \(Roman.string(n))\(sec)"
                return Output(csmParenthetical: "(\(core).)",
                              csmText: "the \(Ordinals.word(n)) Amendment to the United States Constitution" + textSec,
                              csmShort: "(\(core).)",
                              bluebook: "\(bb).", bluebookShort: "\(bb).")
            }
            let core = "U.S. Const., art. \(s.article)\(sec)\(cl)"
            let bb = "U.S. Const. art. \(s.article)\(sec)\(cl)"
            return Output(csmParenthetical: "(\(core).)",
                          csmText: "article \(s.article)\(textSec)\(textCl) of the United States Constitution",
                          csmShort: "(\(core).)",
                          bluebook: "\(bb).", bluebookShort: "\(bb).")

        case .calRules:
            return Output(csmParenthetical: "(Cal. Rules of Court, rule \(s.section)\(sub).)",
                          csmText: "California Rules of Court, rule \(s.section)\(sub)",
                          csmShort: "(rule \(s.section)\(sub).)",
                          bluebook: "Cal. R. Ct. \(s.section)\(sub).",
                          bluebookShort: "Cal. R. Ct. \(s.section)\(sub).")

        case .calRegs:
            let core = "Cal. Code Regs., tit. \(s.title), § \(s.section)\(csmSub)"
            let bbYear = bluebookYear.isEmpty ? "" : " (\(s.year.isEmpty ? bluebookYear : s.year))"
            return Output(csmParenthetical: "(\(core).)",
                          csmText: "California Code of Regulations, title \(s.title), section \(s.section)\(textSub)",
                          csmShort: "(\(core).)",
                          bluebook: "Cal. Code Regs. tit. \(s.title), § \(s.section)\(sub)\(bbYear).",
                          bluebookShort: "§ \(s.section)\(sub).")

        case .usCode:
            let core = "\(s.title) U.S.C. \(sym) \(s.section)\(sub)"
            return Output(csmParenthetical: "(\(core).)",
                          csmText: "title \(s.title) of the United States Code, \(word) \(s.section)\(sub)",
                          csmShort: "(\(core).)",
                          bluebook: "\(core).", bluebookShort: "§ \(s.section)\(sub).")

        case .cfr:
            let core = "\(s.title) C.F.R. \(sym) \(s.section)\(sub) (\(yr))"
            return Output(csmParenthetical: "(\(core).)",
                          csmText: "title \(s.title) of the Code of Federal Regulations, \(word) \(s.section)\(sub)",
                          csmShort: "(\(s.title) C.F.R. \(sym) \(s.section)\(sub).)",
                          bluebook: "\(core).", bluebookShort: "\(s.title) C.F.R. \(sym) \(s.section)\(sub).")

        case .agOpinion:
            let pin = s.pin.isEmpty ? "" : ", \(s.pin)"
            let at = s.pin.isEmpty ? s.section : s.pin
            let csm = "\(s.title) Ops.Cal.Atty.Gen. \(s.section)\(pin) (\(yr))"
            return Output(csmParenthetical: "(\(csm).)",
                          csmText: csm,
                          csmShort: "(\(s.title) Ops.Cal.Atty.Gen., supra, at p. \(at).)",
                          bluebook: "\(s.title) Op. Cal. Att'y Gen. \(s.section)\(pin) (\(yr)).",
                          bluebookShort: "\(s.title) Op. Cal. Att'y Gen. at \(at).")

        case .municipal:
            let place = s.place.isEmpty ? "[City]" : s.place
            let bbYear = bluebookYear.isEmpty ? "" : " (\(s.year.isEmpty ? bluebookYear : s.year))"
            return Output(csmParenthetical: "(\(place) Mun. Code, \(sym) \(s.section)\(csmSub).)",
                          csmText: "\(place) Municipal Code \(word) \(s.section)\(textSub)",
                          csmShort: "(\(place) Mun. Code, \(sym) \(s.section)\(csmSub).)",
                          bluebook: "\(place), Cal., Mun. Code \(sym) \(s.section)\(sub)\(bbYear).",
                          bluebookShort: "\(sym) \(s.section)\(sub).")
        }
    }
}
