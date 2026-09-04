# Encrypted DNS Profiles

[繁體中文](README.zh-Hant.md)

Signed configuration profiles that switch an iPhone, iPad or Mac to an encrypted DNS resolver (DNS over HTTPS or DNS over TLS). Maintained by GET Technology Inc.

Download page: https://get-technology-inc.github.io/encrypted-dns-profiles/

## What this is

Apple has supported DoH and DoT through configuration profiles since iOS 14 and macOS 11, but there is no built-in user interface for it. This repository turns the published settings of public DNS providers into profiles and signs them with an Apple Developer ID certificate, so they show as Verified on install. Each profile contains a single `com.apple.dnsSettings.managed` payload and nothing else: no certificates, no VPN, no management.

## Providers

| Provider | DoH | DoT |
| --- | --- | --- |
| Google Public DNS | `https://dns.google/dns-query` | `dns.google` |
| Cloudflare 1.1.1.1 | `https://cloudflare-dns.com/dns-query` | `cloudflare-dns.com` |
| AdGuard DNS | `https://dns.adguard-dns.com/dns-query` | `dns.adguard-dns.com` |

The source of every value is the `website` field of the matching `providers/*.json`.

## Layout

```
config.json          organization, identifier prefix, consent text
providers/*.json     one file per provider, with a link to the vendor documentation
Sources/generate     Swift generator: providers/ -> profiles/ and site/index.html
profiles/            unsigned profiles, generated and committed so they can be read as-is
site/                download page
scripts/sign.sh      signs profiles/ into dist/ with the Developer ID in the keychain and checks the result
scripts/verify.sh    prints the signer chain of each file in dist/
fastlane/            CI lane: fetch the certificate with match, then run scripts/sign.sh
.github/workflows    ci.yml checks pull requests; release.yml signs and publishes to GitHub Pages
```

## Local usage

```sh
swift run generate            # providers/ -> profiles/ + site/index.html
scripts/sign.sh               # profiles/ -> dist/ (needs the Developer ID in your keychain)
scripts/verify.sh             # show the signer of each file in dist/
```

## Adding a provider

Add a JSON file under `providers/` (its `id` must match the file name), run `swift run generate`, and commit the generated `profiles/` and `site/index.html` together. UUIDs and identifiers are derived from the `id`, so regenerating never changes an existing profile unless its data changed, and reinstalling is treated as an update rather than a second profile.

## Localization

Apple's profile format only localizes `ConsentText`, so the profile description is a language-neutral technical string and the explanation shown to the user lives in `ConsentText`, in Traditional Chinese and English. The download page has one complete block per language and picks the browser language.

## macOS notes

Since macOS 26, DNS settings must be installed as a device-level profile, otherwise installation fails with "The 'VPN Service' payload could not be installed". All profiles here carry `PayloadScope: System`, so installing on a Mac asks for an administrator password. iOS and iPadOS ignore the key.

## Certificate renewal

An expired signing certificate does not affect profiles already installed; only files downloaded after expiry would show as unverified. To renew: create a new Developer ID Application certificate in Apple Developer (allowed before the old one expires, both can coexist), import it with `fastlane match import --type developer_id`, then trigger Sign and publish manually or wait for the monthly schedule. The workflow publishes only after a reviewer approves the `release` environment.


## License

MIT
