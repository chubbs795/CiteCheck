<p align="center">
  <img src="icons/AppIcon-256.png" width="128" alt="CiteCheck icon">
</p>

<h1 align="center">CiteCheck</h1>

<p align="center">Paste a citation — a case, statute, rule, regulation or constitutional provision — confirm it's real, and copy it in California Style Manual or Bluebook form.</p>

---

## What it does

Paste a citation in almost any common form:

```
Smith v. Jones, 12 Cal. 4th 345, 350 (1995)
Smith v. Jones (1995) 12 Cal.4th 345, 350
(People v. Smith (2019) 32 Cal.App.5th 1071, 1080.)
Doe v. Roe, 250 F.3d 100, 105 (9th Cir. 2001)
45 Cal. App. 5th 100
```

CiteCheck then:

1. **Verifies it on [CourtListener](https://www.courtlistener.com)**, the free case-law database run by the nonprofit Free Law Project, showing the case name, court, filing date and a link to the opinion. It flags citations that aren't found, match several cases, or whose year or case name doesn't match the record, and fills in anything missing (e.g. the case name for a bare "45 Cal.App.5th 100").
2. **Formats it both ways**, ready to copy (italics are kept when pasted into Word):

| | Example |
|---|---|
| California Style Manual | *Smith v. Jones* (1995) 12 Cal.4th 345, 350 |
| CSM, in parentheses | (*Smith v. Jones* (1995) 12 Cal.4th 345, 350.) |
| CSM short form | (*Smith*, *supra*, 12 Cal.4th at p. 350.) |
| Bluebook | *Smith v. Jones*, 12 Cal. 4th 345, 350 (1995). |
| Bluebook short form | *Smith*, 12 Cal. 4th at 350. |

Every part of the citation (name, volume, reporter, page, pin cite, year, court) can be edited, and the output updates as you type.

**Supported reporters:** Cal., Cal.2d–5th; Cal.App., Cal.App.2d–5th (and Supp.); Cal.Rptr., 2d, 3d; P., P.2d, P.3d; U.S., S.Ct., L.Ed., L.Ed.2d; F., F.2d–F.4th; F.Supp., 2d, 3d; Fed.Appx. Other reporters are passed through as typed.

## Statutes and other authorities

CiteCheck also recognizes, checks and formats:

| Authority | You can paste | CSM | Bluebook | Checked against |
|---|---|---|---|---|
| California codes (all 29) | `CCP 425.16(e)(4)`, `Gov't Code § 7920.000` | (Code Civ. Proc., § 425.16, subd. (e)(4).) | Cal. Civ. Proc. Code § 425.16(e)(4) (West 2026). | leginfo.legislature.ca.gov — flags repealed/renumbered sections and missing subdivisions, and shows the section text |
| California Constitution | `Cal. Const. art. I, § 7` | (Cal. Const., art. I, § 7.) | Cal. Const. art. I, § 7. | leginfo.legislature.ca.gov |
| U.S. Constitution | `14th Amendment`, `art. I, § 8, cl. 3` | (U.S. Const., 14th Amend.) | U.S. Const. amend. XIV. | Validated locally; links to Cornell LII |
| California Rules of Court | `CRC 8.204(c)(1)` | (Cal. Rules of Court, rule 8.204(c)(1).) | Cal. R. Ct. 8.204(c)(1). | courts.ca.gov |
| U.S. Code | `42 USC 1983` | (42 U.S.C. § 1983.) | 42 U.S.C. § 1983. | Cornell LII |
| Code of Federal Regulations | `29 CFR 1604.11` | (29 C.F.R. § 1604.11 (2026).) | 29 C.F.R. § 1604.11 (2026). | Cornell LII |
| California Code of Regulations | `2 CCR 11019` | (Cal. Code Regs., tit. 2, § 11019.) | Cal. Code Regs. tit. 2, § 11019 (2026). | Search link only |
| Attorney General opinions | `80 Ops.Cal.Atty.Gen. 297` | (80 Ops.Cal.Atty.Gen. 297 (1997).) | 80 Op. Cal. Att'y Gen. 297 (1997). | Search link only |
| Municipal codes | `PAMC 2.30.010`, `Palo Alto Mun. Code § 2.30.010` | (Palo Alto Mun. Code, § 2.30.010.) | Palo Alto, Cal., Mun. Code § 2.30.010 (2026). | Search link only |

Each gives a parenthetical citation, an in-text version ("Code of Civil Procedure section 425.16, subdivision (e)(4)") and a short form. The Bluebook code year can be turned off or changed.

## Setup

1. Requires macOS 13+ and Apple's Command Line Tools (`xcode-select --install`).
2. Download this repository, unzip it, and double-click **Install or Update.command** (or run `bash build.sh`).
3. Create a free [CourtListener account](https://www.courtlistener.com/register/), copy your API token from your account's API settings, and paste it into the **CourtListener Account** section of the app. The token is stored in your Mac's keychain.

## Privacy

Only the citation itself is sent: cases to CourtListener; statutes, rules and constitutions to the public official or standard sources listed above. Formatting happens entirely on your Mac.

## Limitations

- Formatting follows the *California Style Manual* (4th ed. 2000) and common Bluebook conventions. It doesn't cover subsequent history, parallel citations, session laws, legislative history, secondary sources or case-name abbreviation rules. Pin-cite ranges are kept exactly as typed.
- Statute checks use current law only, so a section valid when a case was decided may show as not found today.
- CourtListener's coverage is broad but not complete; a "not found" result means "check it," not "it doesn't exist."
- Always review citations before filing.

## License

[MIT](LICENSE)
