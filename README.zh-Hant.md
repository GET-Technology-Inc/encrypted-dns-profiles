# Encrypted DNS Profiles

[English](README.md)

已簽章的 iPhone、iPad、Mac 加密 DNS 描述檔（DNS over HTTPS、DNS over TLS），由珈特科技股份有限公司維護。

下載頁面：https://get-technology-inc.github.io/encrypted-dns-profiles/

## 這是什麼

Apple 從 iOS 14 與 macOS 11 開始支援用描述檔設定 DoH 與 DoT，但系統沒有內建的設定介面。這個專案把各家公開 DNS 服務的設定整理成描述檔，並用 Apple Developer ID 憑證簽章，安裝時會顯示「已驗證」。每份描述檔只包含一個 `com.apple.dnsSettings.managed` payload，沒有憑證、沒有 VPN、沒有任何管理設定。

## 支援的供應商

| 供應商 | DoH | DoT |
| --- | --- | --- |
| Google Public DNS | `https://dns.google/dns-query` | `dns.google` |
| Cloudflare 1.1.1.1 | `https://cloudflare-dns.com/dns-query` | `cloudflare-dns.com` |
| AdGuard DNS | `https://dns.adguard-dns.com/dns-query` | `dns.adguard-dns.com` |

每個設定值的來源都寫在對應 `providers/*.json` 的 `website` 欄位。

## 專案結構

```
config.json          組織名稱、識別碼前綴、同意文字
providers/*.json     每家供應商一個檔案，附官方文件連結
Sources/generate     Swift 產生器：providers/ -> profiles/ 與 site/index.html
profiles/            未簽章的描述檔，由產生器產生並提交，方便直接閱讀
site/                下載頁面
scripts/sign.sh      用鑰匙圈裡的 Developer ID 把 profiles/ 簽到 dist/，並驗證結果
scripts/verify.sh    列出 dist/ 每個檔案的簽署者與憑證鏈
fastlane/            CI 用的 lane：用 match 取得憑證後執行 scripts/sign.sh
.github/workflows    ci.yml 檢查 PR；release.yml 簽章並發佈到 GitHub Pages
```

## 本機使用

```sh
swift run generate            # providers/ -> profiles/ + site/index.html
scripts/sign.sh               # profiles/ -> dist/（需要鑰匙圈裡有 Developer ID）
scripts/verify.sh             # 顯示 dist/ 每個檔案的簽署者
```

## 新增供應商

在 `providers/` 加一個 JSON，`id` 要跟檔名一樣，跑 `swift run generate`，把產生的 `profiles/` 與 `site/index.html` 一起提交。描述檔的 UUID 與識別碼由 `id` 決定，重新產生不會改變既有描述檔，使用者重新安裝時會被視為更新而不是另一份描述檔。

## 語言

Apple 的描述檔格式只有 `ConsentText` 支援本地化，所以描述檔的說明欄位是語言中立的技術字串，給使用者看的說明放在 `ConsentText`，有繁體中文與英文，系統會依裝置語言顯示。下載頁面每種語言各一個完整區塊，依瀏覽器語言自動選擇。

## macOS 注意事項

macOS 26 之後 DNS 設定必須是裝置層級的描述檔，否則安裝時會出現「無法安裝『VPN 服務』承載資料」。這裡的描述檔都帶 `PayloadScope: System`，在 Mac 上安裝時會要求管理者密碼，iOS 與 iPadOS 會忽略這個 key。

## 憑證更新

簽章憑證過期不影響已經安裝在裝置上的描述檔，只有過期後新下載的檔案會顯示「未驗證」。更新流程：在 Apple Developer 建一張新的 Developer ID Application 憑證（到期前即可建立，新舊可並存），用 `fastlane match import --type developer_id` 匯入 match 儲存庫，然後手動觸發或等每月排程的 Sign and publish 跑一次，網站上的檔案就會換成新憑證簽的。Sign and publish 需要 `release` Environment 的審核人批准才會發佈。


## 授權

MIT
