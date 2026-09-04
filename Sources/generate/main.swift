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
        "PayloadDescription": "\(transport.longName) · \(endpoint)",
        "DNSSettings": dnsSettings,
        "ProhibitDisablement": false,
    ]

    let profile: [String: Any] = [
        "PayloadType": "Configuration",
        "PayloadVersion": 1,
        "PayloadIdentifier": profileIdentifier,
        "PayloadUUID": uuidV5(name: profileIdentifier).uuidString,
        "PayloadDisplayName": displayName,
        // PayloadDescription cannot be localized, so it stays language-neutral.
        // The human-readable explanation lives in ConsentText, which the OS
        // shows in the device language.
        "PayloadDescription": "\(transport.longName) · \(endpoint)",
        "PayloadOrganization": config.organization,
        "PayloadRemovalDisallowed": false,
        // macOS 26 and later refuse to install DNS settings as a user-level
        // profile ("The 'VPN Service' payload could not be installed"), so the
        // profile has to be device-scoped. iOS and iPadOS ignore this key.
        "PayloadScope": "System",
        "ConsentText": [
            "default": "\(provider.description.en)\n\n\(config.consentText.en)",
            "en": "\(provider.description.en)\n\n\(config.consentText.en)",
            "zh-Hant": "\(provider.description.zhHant)\n\n\(config.consentText.zhHant)",
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
