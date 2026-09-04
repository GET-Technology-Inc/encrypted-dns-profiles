# Encrypted DNS Profiles

已簽章的 iOS / iPadOS / macOS 加密 DNS 描述檔（DNS over HTTPS、DNS over TLS），由珈特科技股份有限公司（GET Technology Inc.）維護。

Signed configuration profiles that switch an Apple device to an encrypted DNS resolver. Maintained by GET Technology Inc.

## 這是什麼 / What this is

Apple 從 iOS 14 與 macOS 11 開始支援用描述檔設定 DoH / DoT，但系統沒有內建的介面。這個專案把各家公開 DNS 服務的設定整理成描述檔，並用 Apple Developer ID 憑證簽章，安裝時會顯示「已驗證」。描述檔只包含 `com.apple.dnsSettings.managed` 這一個 payload，不會安裝憑證、VPN 或任何管理設定，隨時可以移除。

Apple has supported DoH / DoT through configuration profiles since iOS 14 and macOS 11, but there is no built-in UI for it. This repository turns the published settings of public DNS providers into profiles and signs them with an Apple Developer ID certificate, so they show as Verified on install. Each profile contains a single `com.apple.dnsSettings.managed` payload and nothing else.

## 目前支援 / Providers

| Provider | DoH | DoT |
| --- | --- | --- |
| Google Public DNS | `https://dns.google/dns-query` | `dns.google` |
| Cloudflare 1.1.1.1 | `https://cloudflare-dns.com/dns-query` | `cloudflare-dns.com` |
| AdGuard DNS | `https://dns.adguard-dns.com/dns-query` | `dns.adguard-dns.com` |

設定值來源都在各自 `providers/*.json` 的 `website` 欄位。

## 專案結構 / Layout

```
config.json          組織名稱、識別碼前綴、同意文字
providers/*.json     每家供應商一個檔案，資料來源寫在 website 欄位
Sources/generate     Swift 產生器，讀 providers/ 產出 profiles/ 與 site/index.html
profiles/            未簽章的描述檔，由產生器產生並提交，方便直接閱讀
site/                下載頁面
scripts/sign.sh      用鑰匙圈裡的 Developer ID 簽章到 dist/，並驗證簽完能解回原檔
scripts/verify.sh    列出簽署者與憑證鏈
fastlane/            CI 用的 lane（match 拉憑證後呼叫 scripts/sign.sh）
.github/workflows    ci.yml 檢查 PR；release.yml 簽章並發佈到 GitHub Pages
```

## 本機使用 / Local usage

```sh
swift run generate            # providers/ -> profiles/ + site/index.html
scripts/sign.sh               # profiles/ -> dist/ (needs the Developer ID in your keychain)
scripts/verify.sh             # show signer of each file in dist/
```

## 新增供應商 / Adding a provider

在 `providers/` 加一個 JSON，`id` 要跟檔名一樣，跑 `swift run generate`，把產生的 `profiles/` 與 `site/index.html` 一起提交。描述檔的 UUID 與識別碼由 `id` 決定，不會因為重新產生而改變，所以使用者重新安裝時會被視為更新而不是另一份描述檔。

Add a JSON file under `providers/` (its `id` must match the file name), run `swift run generate`, and commit the generated `profiles/` and `site/index.html` together. UUIDs and identifiers are derived from the `id`, so regenerating never changes an existing profile unless its data changed.

## 授權 / License

MIT
