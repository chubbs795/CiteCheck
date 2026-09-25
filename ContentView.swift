// CiteCheck — main window. Uses only @ObservedObject so it builds with any
// version of Apple's Command Line Tools.
import SwiftUI

struct ContentView: View {
    @ObservedObject var model: CiteModel

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                HStack {
                    TextField("Paste a citation — a case, code section, rule, regulation or constitutional provision", text: $model.input)
                        .textFieldStyle(.roundedBorder)
                        .font(.system(size: 14))
                        .onSubmit { model.check() }
                    Button("Check") { model.check() }
                        .keyboardShortcut(.defaultAction)
                }

                status

                if model.hasCitation {
                    details
                    outputs
                }

                if model.hasStatute {
                    statuteStatus
                    statuteDetails
                    statuteOutputs
                }

                account
            }
            .padding(20)
        }
        .frame(minWidth: 740, minHeight: 600)
    }

    // MARK: Verification status

    @ViewBuilder private var status: some View {
        switch model.verification {
        case .idle:
            EmptyView()
        case .noToken:
            banner("exclamationmark.triangle.fill", .orange,
                   "Not verified. Add your free CourtListener API token below to confirm the case exists.")
        case .checking:
            HStack(spacing: 8) {
                ProgressView().controlSize(.small)
                Text("Checking CourtListener…").foregroundStyle(.secondary)
            }
        case .done(let result):
            switch result {
            case .verified(let match):
                VStack(alignment: .leading, spacing: 6) {
                    banner("checkmark.seal.fill", .green, "Found on CourtListener")
                    matchSummary(match)
                    ForEach(model.warnings(for: match), id: \.self) { note in
                        Label(note, systemImage: "exclamationmark.triangle.fill")
                            .foregroundStyle(.orange)
                    }
                }
            case .multiple(let matches):
                VStack(alignment: .leading, spacing: 8) {
                    banner("questionmark.circle.fill", .orange, "Several cases match this citation. Choose the right one:")
                    ForEach(Array(matches.enumerated()), id: \.offset) { _, match in
                        HStack {
                            matchSummary(match)
                            Spacer()
                            Button("Use This Case") { model.use(match) }
                        }
                    }
                }
            case .notFound:
                banner("xmark.octagon.fill", .red,
                       "Not found on CourtListener. Check the volume, reporter and page. (CourtListener's coverage is broad but not complete, so confirm in Westlaw or Lexis before concluding it doesn't exist.)")
            case .invalid(let message):
                banner("xmark.octagon.fill", .red, message)
            case .failed(let message):
                banner("wifi.exclamationmark", .orange, message)
            }
        }
    }

    private func banner(_ symbol: String, _ color: Color, _ text: String) -> some View {
        Label {
            Text(text).fixedSize(horizontal: false, vertical: true)
        } icon: {
            Image(systemName: symbol).foregroundStyle(color)
        }
        .font(.system(size: 13, weight: .medium))
    }

    private func matchSummary(_ match: CourtListenerMatch) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(match.caseName).italic()
            HStack(spacing: 6) {
                Text([match.courtName, match.dateFiled].filter { !$0.isEmpty }.joined(separator: " · "))
                if !match.citations.isEmpty { Text("· " + match.citations.joined(separator: "; ")) }
                if let url = match.url { Link("View opinion", destination: url) }
            }
            .font(.caption)
            .foregroundStyle(.secondary)
        }
        .padding(.leading, 26)
    }

    // MARK: Editable parts

    private var details: some View {
        GroupBox("Citation Details — edit anything that's wrong") {
            Grid(alignment: .leading, horizontalSpacing: 10, verticalSpacing: 8) {
                GridRow {
                    Text("Case name")
                    TextField("Smith v. Jones", text: $model.citation.caseName).gridCellColumns(5)
                }
                GridRow {
                    Text("Volume")
                    TextField("12", text: $model.citation.volume).frame(width: 80)
                    Text("Reporter")
                    TextField("Cal.4th", text: $model.citation.reporter).frame(width: 140)
                    Text("Page")
                    TextField("345", text: $model.citation.page).frame(width: 80)
                }
                GridRow {
                    Text("Pin cite")
                    TextField("350", text: $model.citation.pin).frame(width: 80)
                    Text("Year")
                    TextField("1995", text: $model.citation.year).frame(width: 140)
                    Text("Court")
                    TextField("9th Cir.", text: $model.citation.court).frame(width: 120)
                }
            }
            .padding(6)
            if model.citation.knownReporter == nil {
                Text("Reporter not recognized. It will be used exactly as typed.")
                    .font(.caption)
                    .foregroundStyle(.orange)
                    .padding([.leading, .bottom], 6)
            }
        }
    }

    // MARK: Formatted output

    private var outputs: some View {
        let c = model.citation
        return VStack(alignment: .leading, spacing: 12) {
            GroupBox("California Style Manual") {
                VStack(alignment: .leading, spacing: 10) {
                    outputRow("Citation", CitationFormatter.csmFull(c), key: "csm-full")
                    outputRow("In parentheses", CitationFormatter.csmParenthetical(c), key: "csm-paren")
                    outputRow("Short form", CitationFormatter.csmShort(c), key: "csm-short")
                }
                .padding(6)
            }
            GroupBox("Bluebook") {
                VStack(alignment: .leading, spacing: 10) {
                    outputRow("Citation", CitationFormatter.bluebookFull(c), key: "bb-full")
                    outputRow("Short form", CitationFormatter.bluebookShort(c), key: "bb-short")
                }
                .padding(6)
            }
        }
    }

    private func outputRow(_ label: String, _ styled: Styled, key: String) -> some View {
        HStack(alignment: .firstTextBaseline) {
            Text(label)
                .foregroundStyle(.secondary)
                .frame(width: 110, alignment: .leading)
            Text(model.attributed(styled))
                .font(.system(size: 15, design: .serif))
                .textSelection(.enabled)
                .fixedSize(horizontal: false, vertical: true)
            Spacer()
            Button(model.copiedKey == key ? "Copied" : "Copy") { model.copy(styled, key: key) }
                .frame(width: 70)
        }
    }

    // MARK: Statutes and other authorities

    @ViewBuilder private var statuteStatus: some View {
        switch model.statuteCheck {
        case .idle:
            EmptyView()
        case .checking:
            HStack(spacing: 8) {
                ProgressView().controlSize(.small)
                Text("Checking the official text…").foregroundStyle(.secondary)
            }
        case .found(let heading, let preview, let url, let warnings):
            VStack(alignment: .leading, spacing: 6) {
                banner("checkmark.seal.fill", .green, "Found: \(heading)")
                if !preview.isEmpty {
                    Text(preview + (preview.count >= 420 ? "…" : ""))
                        .font(.callout)
                        .foregroundStyle(.secondary)
                        .textSelection(.enabled)
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(10)
                        .background(RoundedRectangle(cornerRadius: 6).fill(Color.secondary.opacity(0.08)))
                        .padding(.leading, 26)
                }
                ForEach(warnings, id: \.self) { note in
                    Label(note, systemImage: "exclamationmark.triangle.fill").foregroundStyle(.orange)
                }
                Link("Open the full text", destination: url).padding(.leading, 26)
            }
        case .notFound(let message, let url):
            VStack(alignment: .leading, spacing: 6) {
                banner("xmark.octagon.fill", .red, message)
                if let url { Link("Open the source page", destination: url).padding(.leading, 26) }
            }
        case .unverifiable(let url):
            VStack(alignment: .leading, spacing: 6) {
                banner("info.circle.fill", .secondary,
                       "\(model.statute?.kind.title ?? "This authority") can't be checked automatically, so confirm it yourself.")
                Link("Search for it online", destination: url).padding(.leading, 26)
            }
        case .failed(let message):
            banner("wifi.exclamationmark", .orange, message)
        }
    }

    private func statuteField(_ label: String, _ keyPath: WritableKeyPath<Statute, String>, width: CGFloat = 110) -> some View {
        HStack(spacing: 6) {
            Text(label).foregroundStyle(.secondary)
            TextField(label, text: model.statuteBinding(keyPath)).frame(width: width)
        }
    }

    private var statuteDetails: some View {
        GroupBox((model.statute?.kind.title ?? "Authority") + " — edit anything that's wrong") {
            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 16) {
                    switch model.statute?.kind ?? .calCode {
                    case .calCode:
                        Picker("Code", selection: model.statuteBinding(\.codeID)) {
                            ForEach(CalCodes.all) { Text($0.fullName).tag($0.id) }
                        }
                        .frame(width: 320)
                        statuteField("Section", \.section, width: 140)
                        statuteField("Subdivision", \.subdivision, width: 90)
                    case .calConst:
                        statuteField("Article", \.article, width: 70)
                        statuteField("Section", \.section, width: 70)
                        statuteField("Subdivision", \.subdivision, width: 90)
                    case .usConst:
                        statuteField("Amendment", \.amendment, width: 50)
                        statuteField("or Article", \.article, width: 60)
                        statuteField("Section", \.section, width: 50)
                        statuteField("Clause", \.clause, width: 50)
                    case .calRules:
                        statuteField("Rule", \.section, width: 90)
                        statuteField("Subdivision", \.subdivision, width: 90)
                    case .calRegs, .usCode, .cfr:
                        statuteField("Title", \.title, width: 50)
                        statuteField("Section", \.section, width: 110)
                        statuteField("Subdivision", \.subdivision, width: 90)
                        if model.statute?.kind == .cfr { statuteField("Year", \.year, width: 60) }
                    case .agOpinion:
                        statuteField("Volume", \.title, width: 50)
                        statuteField("Page", \.section, width: 60)
                        statuteField("Pin", \.pin, width: 60)
                        statuteField("Year", \.year, width: 60)
                    case .municipal:
                        statuteField("City", \.place, width: 140)
                        statuteField("Section", \.section, width: 110)
                        statuteField("Subdivision", \.subdivision, width: 90)
                    }
                }
                HStack(spacing: 16) {
                    if model.statute?.kind == .calCode || model.statute?.kind == .usCode {
                        Toggle("Several sections (§§)", isOn: model.statuteFlag(\.multiple))
                    }
                    if model.statute?.kind == .calCode || model.statute?.kind == .calRegs || model.statute?.kind == .municipal {
                        Toggle("Bluebook: include code year", isOn: $model.includeCodeYear)
                        TextField("Year", text: $model.codeYear)
                            .frame(width: 60)
                            .disabled(!model.includeCodeYear)
                    }
                    Spacer()
                    Button("Check Again") { model.recheckStatute() }
                }
            }
            .padding(6)
        }
    }

    private var statuteOutputs: some View {
        VStack(alignment: .leading, spacing: 12) {
            if let out = model.statuteOutput {
                GroupBox("California Style Manual") {
                    VStack(alignment: .leading, spacing: 10) {
                        outputRow("In parentheses", CiteModel.plain(out.csmParenthetical), key: "st-csm-paren")
                        outputRow("In text", CiteModel.plain(out.csmText), key: "st-csm-text")
                        outputRow("Short form", CiteModel.plain(out.csmShort), key: "st-csm-short")
                    }
                    .padding(6)
                }
                GroupBox("Bluebook") {
                    VStack(alignment: .leading, spacing: 10) {
                        outputRow("Citation", CiteModel.plain(out.bluebook), key: "st-bb-full")
                        outputRow("Short form", CiteModel.plain(out.bluebookShort), key: "st-bb-short")
                    }
                    .padding(6)
                }
            }
        }
    }

    // MARK: CourtListener account

    private var account: some View {
        DisclosureGroup("CourtListener Account", isExpanded: $model.showAccount) {
            VStack(alignment: .leading, spacing: 8) {
                Text("CiteCheck confirms cases with CourtListener, a free public case-law database run by the nonprofit Free Law Project. Only the citation (e.g. “12 Cal. 4th 345”) is sent. Create a free account, copy your API token from your account's API settings, and paste it here.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                HStack {
                    SecureField("API token", text: $model.token)
                        .textFieldStyle(.roundedBorder)
                        .onSubmit { model.saveToken() }
                    Button("Save") { model.saveToken() }
                }
                HStack {
                    Link("Sign up for CourtListener", destination: URL(string: "https://www.courtlistener.com/register/")!)
                    Text("·").foregroundStyle(.secondary)
                    Link("API help", destination: URL(string: "https://www.courtlistener.com/help/api/rest/")!)
                    Spacer()
                    Text(model.tokenStatus).font(.caption).foregroundStyle(.secondary)
                }
            }
            .padding(.top, 6)
        }
    }
}
