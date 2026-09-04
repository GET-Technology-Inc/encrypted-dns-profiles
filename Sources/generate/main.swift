// generate: builds unsigned .mobileconfig files for encrypted DNS providers.
//
// Usage: swift run generate [--providers DIR] [--config FILE] [--out DIR] [--site FILE]
//
// Every provider JSON in the providers directory produces two profiles,
// one for DNS over HTTPS and one for DNS over TLS. Identifiers and UUIDs are
// derived deterministically from the provider id, so re-running the generator
// never changes a profile unless its data changed.

import CryptoKit
import Foundation

// MARK: - Input models

struct LocalizedText: Decodable {
    let en: String
    let zhHant: String

    enum CodingKeys: String, CodingKey {
        case en
        case zhHant = "zh-Hant"
    }

    var combined: String { "\(en)\n\(zhHant)" }
}

struct Config: Decodable {
    let organization: String
    let identifierPrefix: String
    let siteTitle: String
    let siteURL: String
    let consentText: LocalizedText
}

struct DoHSettings: Decodable {
    let serverURL: String
    let addresses: [String]?
}

struct DoTSettings: Decodable {
    let serverName: String
    let addresses: [String]?
}

struct Provider: Decodable {
    let id: String
    let name: String
    let website: String
    let description: LocalizedText
    let addresses: [String]
    let doh: DoHSettings?
    let dot: DoTSettings?
}

enum Transport: String, CaseIterable {
    case doh, dot

    var label: String {
        switch self {
        case .doh: return "DoH"
        case .dot: return "DoT"
        }
    }

    var longName: String {
        switch self {
        case .doh: return "DNS over HTTPS"
        case .dot: return "DNS over TLS"
        }
    }

    var dnsProtocol: String {
        switch self {
        case .doh: return "HTTPS"
        case .dot: return "TLS"
        }
    }
}

// MARK: - Deterministic UUID (RFC 4122 version 5)

let uuidNamespace = UUID(uuidString: "6ba7b810-9dad-11d1-80b4-00c04fd430c8")! // RFC 4122 DNS namespace

func uuidV5(name: String) -> UUID {
    var data = withUnsafeBytes(of: uuidNamespace.uuid) { Data($0) }
    data.append(contentsOf: Array(name.utf8))
    var hash = Array(Insecure.SHA1.hash(data: data))
    hash[6] = (hash[6] & 0x0F) | 0x50
    hash[8] = (hash[8] & 0x3F) | 0x80
    let bytes = (hash[0], hash[1], hash[2], hash[3], hash[4], hash[5], hash[6], hash[7],
                 hash[8], hash[9], hash[10], hash[11], hash[12], hash[13], hash[14], hash[15])
    return UUID(uuid: bytes)
}

// MARK: - Profile construction

struct GeneratedProfile {
    let provider: Provider
    let transport: Transport
    let fileName: String
    let identifier: String
    let endpoint: String
}

func buildProfile(provider: Provider, transport: Transport, config: Config) -> ([String: Any], GeneratedProfile)? {
    var dnsSettings: [String: Any] = ["DNSProtocol": transport.dnsProtocol]
    let endpoint: String
    switch transport {
    case .doh:
        guard let doh = provider.doh else { return nil }
        dnsSettings["ServerURL"] = doh.serverURL
        dnsSettings["ServerAddresses"] = doh.addresses ?? provider.addresses
        endpoint = doh.serverURL
    case .dot:
        guard let dot = provider.dot else { return nil }
        dnsSettings["ServerName"] = dot.serverName
        dnsSettings["ServerAddresses"] = dot.addresses ?? provider.addresses
        endpoint = dot.serverName
    }

    let profileIdentifier = "\(config.identifierPrefix).\(provider.id).\(transport.rawValue)"
    let payloadIdentifier = "\(profileIdentifier).dnsSettings"
    let displayName = "\(provider.name) (\(transport.label))"

    let payload: [String: Any] = [
        "PayloadType": "com.apple.dnsSettings.managed",
        "PayloadVersion": 1,
        "PayloadIdentifier": payloadIdentifier,
        "PayloadUUID": uuidV5(name: payloadIdentifier).uuidString,
        "PayloadDisplayName": "\(transport.longName): \(provider.name)",
        "PayloadDescription": "\(transport.longName) via \(endpoint)",
        "DNSSettings": dnsSettings,
        "ProhibitDisablement": false,
    ]

    let profile: [String: Any] = [
        "PayloadType": "Configuration",
        "PayloadVersion": 1,
        "PayloadIdentifier": profileIdentifier,
        "PayloadUUID": uuidV5(name: profileIdentifier).uuidString,
        "PayloadDisplayName": displayName,
        "PayloadDescription": "\(provider.description.combined)\n\n\(transport.longName): \(endpoint)",
        "PayloadOrganization": config.organization,
        "PayloadRemovalDisallowed": false,
        "ConsentText": [
            "default": config.consentText.en,
            "en": config.consentText.en,
            "zh-Hant": config.consentText.zhHant,
        ],
        "PayloadContent": [payload],
    ]

    let generated = GeneratedProfile(
        provider: provider,
        transport: transport,
        fileName: "\(provider.id)-\(transport.rawValue).mobileconfig",
        identifier: profileIdentifier,
        endpoint: endpoint
    )
    return (profile, generated)
}

// MARK: - Site index

func escape(_ s: String) -> String {
    s.replacingOccurrences(of: "&", with: "&amp;")
        .replacingOccurrences(of: "<", with: "&lt;")
        .replacingOccurrences(of: ">", with: "&gt;")
        .replacingOccurrences(of: "\"", with: "&quot;")
}

func buildIndex(config: Config, profiles: [GeneratedProfile]) -> String {
    let grouped = Dictionary(grouping: profiles, by: { $0.provider.id })
    let providerOrder = profiles.map { $0.provider.id }.reduce(into: [String]()) { if !$0.contains($1) { $0.append($1) } }

    var cards = ""
    for id in providerOrder {
        guard let items = grouped[id], let first = items.first else { continue }
        let p = first.provider
        var links = ""
        for item in items {
            links += """
                <a class="btn" href="\(escape(item.fileName))" download>\(escape(item.transport.label)) · \(escape(item.transport.longName))<small>\(escape(item.endpoint))</small></a>

            """
        }
        cards += """
            <section class="card">
              <h2>\(escape(p.name))</h2>
              <p>\(escape(p.description.zhHant))</p>
              <p class="en">\(escape(p.description.en))</p>
              <p class="addr">\(escape(p.addresses.joined(separator: " · ")))</p>
              <div class="links">
            \(links)      </div>
              <p class="src"><a href="\(escape(p.website))" rel="noopener">官方文件 / Official documentation</a></p>
            </section>

        """
    }

    return """
    <!doctype html>
    <html lang="zh-Hant">
    <head>
    <meta charset="utf-8">
    <meta name="viewport" content="width=device-width, initial-scale=1">
    <title>\(escape(config.siteTitle))</title>
    <meta name="description" content="Signed iOS / iPadOS / macOS configuration profiles for encrypted DNS (DNS over HTTPS, DNS over TLS) from Google, Cloudflare, AdGuard and more. 已簽章的加密 DNS 描述檔。">
    <style>
      :root { color-scheme: light dark; --fg: #1d1d1f; --bg: #fff; --muted: #6e6e73; --card: #f5f5f7; --accent: #0071e3; }
      @media (prefers-color-scheme: dark) { :root { --fg: #f5f5f7; --bg: #000; --muted: #a1a1a6; --card: #1c1c1e; --accent: #2997ff; } }
      * { box-sizing: border-box; }
      body { margin: 0; padding: 2rem 1rem 4rem; font: 16px/1.6 -apple-system, BlinkMacSystemFont, "PingFang TC", "Helvetica Neue", sans-serif; color: var(--fg); background: var(--bg); }
      main { max-width: 720px; margin: 0 auto; }
      h1 { font-size: 1.9rem; margin: 0 0 .25rem; }
      .lead { color: var(--muted); margin-top: 0; }
      .card { background: var(--card); border-radius: 14px; padding: 1.25rem 1.25rem 1rem; margin: 1rem 0; }
      .card h2 { margin: 0 0 .25rem; font-size: 1.25rem; }
      .card p { margin: .25rem 0; }
      .en, .addr, .src { color: var(--muted); font-size: .9rem; }
      .addr { font-family: ui-monospace, SFMono-Regular, Menlo, monospace; }
      .links { display: grid; gap: .6rem; grid-template-columns: repeat(auto-fit, minmax(240px, 1fr)); margin: .75rem 0; }
      .btn { display: block; padding: .7rem .9rem; border-radius: 10px; background: var(--accent); color: #fff; text-decoration: none; font-weight: 600; }
      .btn small { display: block; font-weight: 400; opacity: .85; font-family: ui-monospace, SFMono-Regular, Menlo, monospace; font-size: .8rem; }
      .howto { margin-top: 2rem; }
      .howto ol { padding-left: 1.25rem; }
      footer { margin-top: 2.5rem; color: var(--muted); font-size: .85rem; }
      a { color: var(--accent); }
    </style>
    </head>
    <body>
    <main>
      <h1>\(escape(config.siteTitle))</h1>
      <p class="lead">加密 DNS 描述檔（DoH / DoT），適用 iOS 14、iPadOS 14、macOS 11 以上。所有描述檔皆由 \(escape(config.organization)) 以 Apple Developer ID 簽章，安裝時會顯示「已驗證」。<br>
      Signed configuration profiles for encrypted DNS on iOS 14+, iPadOS 14+ and macOS 11+.</p>

    \(cards)
      <section class="howto">
        <h2>安裝方式 / How to install</h2>
        <ol>
          <li>在 iPhone 或 iPad 上用 Safari 點選上方的下載連結，允許下載描述檔。<br>Open this page in Safari on your iPhone or iPad and tap a download link, then allow the profile download.</li>
          <li>前往「設定」，點最上方的「已下載描述檔」，確認簽署者顯示為已驗證後安裝。<br>Go to Settings, tap "Profile Downloaded" at the top, check that the signer shows as Verified, then install.</li>
          <li>要換供應商就安裝另一份，舊的會自動被取代；要恢復預設就到「設定 › 一般 › VPN 與裝置管理」移除描述檔。<br>Installing another profile replaces the previous one. Remove the profile under Settings › General › VPN &amp; Device Management to go back to the default resolver.</li>
        </ol>
        <p class="en">描述檔只設定 DNS 解析器，不會安裝憑證、VPN 或任何管理設定。原始碼與產生方式公開於 <a href="\(escape(config.siteURL))">GitHub</a>。<br>
        These profiles only set the DNS resolver. No certificates, VPNs or management payloads are installed. Source and build pipeline are on <a href="\(escape(config.siteURL))">GitHub</a>.</p>
      </section>

      <footer>\(escape(config.organization))</footer>
    </main>
    </body>
    </html>

    """
}

// MARK: - Main

func parseArgs() -> (providers: String, config: String, out: String, site: String?) {
    var providers = "providers"
    var config = "config.json"
    var out = "profiles"
    var site: String? = "site/index.html"
    var args = Array(CommandLine.arguments.dropFirst())
    while !args.isEmpty {
        let flag = args.removeFirst()
        switch flag {
        case "--providers": providers = args.removeFirst()
        case "--config": config = args.removeFirst()
        case "--out": out = args.removeFirst()
        case "--site": site = args.removeFirst()
        case "--no-site": site = nil
        default:
            FileHandle.standardError.write("Unknown argument: \(flag)\n".data(using: .utf8)!)
            exit(2)
        }
    }
    return (providers, config, out, site)
}

func fail(_ message: String) -> Never {
    FileHandle.standardError.write("error: \(message)\n".data(using: .utf8)!)
    exit(1)
}

let options = parseArgs()
let fm = FileManager.default
let decoder = JSONDecoder()

guard let configData = fm.contents(atPath: options.config) else { fail("cannot read \(options.config)") }
let config: Config
do { config = try decoder.decode(Config.self, from: configData) } catch { fail("invalid config.json: \(error)") }

guard let entries = try? fm.contentsOfDirectory(atPath: options.providers) else { fail("cannot list \(options.providers)") }
let providerFiles = entries.filter { $0.hasSuffix(".json") }.sorted()
if providerFiles.isEmpty { fail("no provider JSON files found in \(options.providers)") }

try? fm.createDirectory(atPath: options.out, withIntermediateDirectories: true)

var generated: [GeneratedProfile] = []
var seenIdentifiers = Set<String>()

for file in providerFiles {
    let path = (options.providers as NSString).appendingPathComponent(file)
    guard let data = fm.contents(atPath: path) else { fail("cannot read \(path)") }
    let provider: Provider
    do { provider = try decoder.decode(Provider.self, from: data) } catch { fail("invalid \(file): \(error)") }

    let expectedId = (file as NSString).deletingPathExtension
    if provider.id != expectedId { fail("\(file): id \"\(provider.id)\" must match the file name") }
    if provider.addresses.isEmpty { fail("\(file): addresses must not be empty") }
    if provider.doh == nil && provider.dot == nil { fail("\(file): needs at least one of doh / dot") }

    for transport in Transport.allCases {
        guard let (plist, info) = buildProfile(provider: provider, transport: transport, config: config) else { continue }
        if !seenIdentifiers.insert(info.identifier).inserted { fail("duplicate identifier \(info.identifier)") }

        let plistData: Data
        do {
            plistData = try PropertyListSerialization.data(fromPropertyList: plist, format: .xml, options: 0)
        } catch { fail("cannot serialize \(info.fileName): \(error)") }

        let outPath = (options.out as NSString).appendingPathComponent(info.fileName)
        if fm.contents(atPath: outPath) == plistData {
            print("unchanged  \(outPath)")
        } else {
            do { try plistData.write(to: URL(fileURLWithPath: outPath)) } catch { fail("cannot write \(outPath): \(error)") }
            print("wrote      \(outPath)")
        }
        generated.append(info)
    }
}

if let sitePath = options.site {
    let html = buildIndex(config: config, profiles: generated)
    let dir = (sitePath as NSString).deletingLastPathComponent
    if !dir.isEmpty { try? fm.createDirectory(atPath: dir, withIntermediateDirectories: true) }
    do { try html.write(toFile: sitePath, atomically: true, encoding: .utf8) } catch { fail("cannot write \(sitePath): \(error)") }
    print("wrote      \(sitePath)")
}

print("\(generated.count) profiles from \(providerFiles.count) providers")
