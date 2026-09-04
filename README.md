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

## macOS 注意事項 / macOS notes

macOS 26 之後 DNS 設定必須是裝置層級的描述檔，否則安裝時會出現「無法安裝『VPN 服務』承載資料」。這裡的描述檔都帶 `PayloadScope: System`，在 Mac 上安裝時會要求管理者密碼，iOS 與 iPadOS 會忽略這個 key。

Since macOS 26, DNS settings must be installed as a device-level profile, otherwise installation fails with "The 'VPN Service' payload could not be installed". All profiles here carry `PayloadScope: System`, so installing on a Mac asks for an administrator password. iOS and iPadOS ignore the key.

## 憑證更新 / Certificate renewal

簽章憑證過期不影響已經安裝在裝置上的描述檔，只影響過期後新下載的檔案會顯示「未驗證」。更新流程：在 Apple Developer 建一張新的 Developer ID Application 憑證（到期前即可建立，新舊可並存），用 `fastlane match import --type developer_id` 匯入 match 儲存庫，然後手動觸發或等每月排程的 Sign and publish 跑一次，網站上的檔案就會換成新憑證簽的。Sign and publish 需要 `release` Environment 的審核人批准才會發佈。

An expired signing certificate does not affect profiles already installed; only files downloaded after expiry would show as unverified. To renew: create a new Developer ID Application certificate in Apple Developer (allowed before the old one expires, both can coexist), import it with `fastlane match import --type developer_id`, then trigger Sign and publish manually or wait for the monthly schedule. The workflow publishes only after a reviewer approves the `release` environment.

## 授權 / License

MIT
