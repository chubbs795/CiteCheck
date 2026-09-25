// CiteCheck — app state: the pasted citation, its parts, verification, copying.
import AppKit
import SwiftUI

enum VerificationState {
    case idle, noToken, checking
    case done(VerifyResult)
}

final class CiteModel: ObservableObject {
    @Published var input = ""
    @Published var citation = Citation()
    @Published var verification: VerificationState = .idle
    @Published var token: String
    @Published var showAccount: Bool
    @Published var tokenStatus = ""
    @Published var copiedKey = ""

    // Statutes and other non-case authorities
    enum Mode { case none, caseLaw, statute }
    @Published var mode: Mode = .none
    @Published var statute: Statute?
    @Published var statuteCheck: StatuteCheck = .idle
    @Published var includeCodeYear: Bool { didSet { UserDefaults.standard.set(includeCodeYear, forKey: "includeCodeYear") } }
    @Published var codeYear: String { didSet { UserDefaults.standard.set(codeYear, forKey: "codeYear") } }

    init() {
        let saved = TokenStore.load() ?? ""
        token = saved
        showAccount = saved.isEmpty
        let defaults = UserDefaults.standard
        defaults.register(defaults: ["includeCodeYear": true])
        includeCodeYear = defaults.bool(forKey: "includeCodeYear")
        codeYear = defaults.string(forKey: "codeYear") ?? String(Calendar.current.component(.year, from: Date()))
    }

    var hasCitation: Bool { mode == .caseLaw && !citation.isEmpty }
    var hasStatute: Bool { mode == .statute && statute != nil }

    // MARK: Checking

    func check() {
        copiedKey = ""
        // A case with a recognized reporter wins; then statutes and other authorities;
        // then a case with an unrecognized reporter.
        let asCase = CitationParser.parse(input)
        if let c = asCase, c.knownReporter != nil { return checkCase(c) }
        if let s = StatuteParser.parse(input) { return checkStatute(s) }
        if let c = asCase { return checkCase(c) }
        mode = .none
        citation = Citation()
        statute = nil
        verification = .done(.invalid("That doesn't look like a citation CiteCheck knows. Try a case (“Smith v. Jones, 12 Cal. 4th 345 (1995)”), a code section (“Gov. Code § 7920.000”), a rule, a regulation or a constitutional provision."))
    }

    // MARK: Statutes

    private func checkStatute(_ s: Statute) {
        mode = .statute
        statute = s
        verification = .idle
        recheckStatute()
    }

    func recheckStatute() {
        guard let s = statute else { return }
        statuteCheck = .checking
        let query = statuteOutput?.csmText ?? input
        StatuteVerifier.check(s, searchQuery: query) { [weak self] result in
            guard let self, self.statute == s else { return }   // ignore stale answers
            self.statuteCheck = result
        }
    }

    var statuteOutput: StatuteFormatter.Output? {
        statute.map { StatuteFormatter.format($0, bluebookYear: includeCodeYear ? codeYear : "") }
    }

    func statuteBinding(_ keyPath: WritableKeyPath<Statute, String>) -> Binding<String> {
        Binding(get: { self.statute?[keyPath: keyPath] ?? "" },
                set: { newValue in self.statute?[keyPath: keyPath] = newValue })
    }

    func statuteFlag(_ keyPath: WritableKeyPath<Statute, Bool>) -> Binding<Bool> {
        Binding(get: { self.statute?[keyPath: keyPath] ?? false },
                set: { newValue in self.statute?[keyPath: keyPath] = newValue })
    }

    static func plain(_ text: String) -> Styled {
        var s = Styled()
        s.add(text)
        return s
    }

    // MARK: Cases

    private func checkCase(_ parsed: Citation) {
        mode = .caseLaw
        statute = nil
        statuteCheck = .idle
        citation = parsed
        copiedKey = ""
        let key = token.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !key.isEmpty else {
            verification = .noToken
            showAccount = true
            return
        }
        verification = .checking
        let lookup = parsed.lookupText
        CourtListener.verify(lookup, token: key) { [weak self] result in
            guard let self, self.citation.lookupText == lookup else { return }   // ignore stale answers
            self.verification = .done(result)
            if case .verified(let match) = result { self.fillBlanks(from: match) }
        }
    }

    /// Fills in whatever the pasted citation left out (name, year, court).
    private func fillBlanks(from match: CourtListenerMatch) {
        if citation.caseName.isEmpty { citation.caseName = match.caseName }
        if citation.year.isEmpty { citation.year = match.year }
        if citation.court.isEmpty, citation.knownReporter?.kind.needsCourt ?? true { citation.court = match.courtAbbrev }
    }

    /// Picks one case when a citation matches several.
    func use(_ match: CourtListenerMatch) {
        citation.caseName = match.caseName
        citation.year = match.year
        if citation.knownReporter?.kind.needsCourt ?? true { citation.court = match.courtAbbrev }
        verification = .done(.verified(match))
    }

    /// Differences between what was pasted and what CourtListener has on record.
    func warnings(for match: CourtListenerMatch) -> [String] {
        var notes: [String] = []
        if !citation.year.isEmpty, !match.year.isEmpty, citation.year != match.year {
            notes.append("Year: the citation says \(citation.year), but CourtListener shows the decision filed \(match.dateFiled).")
        }
        let short = CitationFormatter.shortName(citation.caseName).lowercased()
        if !short.isEmpty, !match.caseName.isEmpty,
           !match.caseName.lowercased().contains(short.components(separatedBy: " ").first ?? short) {
            notes.append("Case name: CourtListener lists this citation as “\(match.caseName).”")
        }
        return notes
    }

    // MARK: Token

    func saveToken() {
        let key = token.trimmingCharacters(in: .whitespacesAndNewlines)
        TokenStore.save(key)
        tokenStatus = key.isEmpty ? "Token removed." : "Token saved in your Mac's keychain."
        if !key.isEmpty, hasCitation { check() }
    }

    // MARK: Display and copying

    func attributed(_ styled: Styled) -> AttributedString {
        var out = AttributedString()
        for piece in styled.pieces {
            var part = AttributedString(piece.text)
            if piece.italic { part.inlinePresentationIntent = .emphasized }
            out += part
        }
        return out
    }

    /// Copies as rich text (italics survive pasting into Word) plus plain text.
    func copy(_ styled: Styled, key: String) {
        let regular = NSFont(name: "Times New Roman", size: 12) ?? .systemFont(ofSize: 12)
        let italic = NSFontManager.shared.convert(regular, toHaveTrait: .italicFontMask)
        let rich = NSMutableAttributedString()
        for piece in styled.pieces {
            rich.append(NSAttributedString(string: piece.text, attributes: [.font: piece.italic ? italic : regular]))
        }
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        if let rtf = try? rich.data(from: NSRange(location: 0, length: rich.length),
                                    documentAttributes: [.documentType: NSAttributedString.DocumentType.rtf]) {
            pasteboard.setData(rtf, forType: .rtf)
        }
        pasteboard.setString(styled.plain, forType: .string)
        copiedKey = key
    }
}
