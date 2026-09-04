// Site.swift: renders site/index.html, the download page published to GitHub Pages.
//
// The page carries one complete block per language (Traditional Chinese and
// English). The block matching the browser language is shown first and a
// toggle in the header switches between them; nothing is mixed inside a block.

import Foundation

func escape(_ s: String) -> String {
    s.replacingOccurrences(of: "&", with: "&amp;")
        .replacingOccurrences(of: "<", with: "&lt;")
        .replacingOccurrences(of: ">", with: "&gt;")
        .replacingOccurrences(of: "\"", with: "&quot;")
}

private struct SiteStrings {
    let lang: String
    let lead: String
    let requirements: String
    let docs: String
    let howToTitle: String
    let steps: [String]
    let footnote: String
    let source: String
    let providerDescription: (Provider) -> String
    let categories: [Category: (title: String, blurb: String)]

    static let zhHant = SiteStrings(
        lang: "zh-Hant",
        lead: "加密 DNS 描述檔（DNS over HTTPS、DNS over TLS）。所有描述檔皆以 Apple Developer ID 簽章，安裝時會顯示「已驗證」。",
        requirements: "適用 iOS 14、iPadOS 14、macOS 11 以上。",
        docs: "官方文件",
        howToTitle: "安裝方式",
        steps: [
            "在 iPhone 或 iPad 上用 Safari 開這個頁面，點選要用的描述檔，允許下載。",
            "前往「設定」，點最上方的「已下載描述檔」，確認簽署者顯示為已驗證後安裝。",
            "在 Mac 上下載後，到「系統設定 › 一般 › 裝置管理」點兩下安裝，會要求管理者密碼。",
            "要換供應商就安裝另一份，舊的會自動被取代；要恢復預設，到「設定 › 一般 › VPN 與裝置管理」移除描述檔即可。",
        ],
        footnote: "描述檔只設定 DNS 解析器，不會安裝憑證、VPN 或任何管理設定。",
        source: "原始碼與產生流程",
        providerDescription: { $0.description.zhHant },
        categories: [
            .general: ("一般用途", "只加密 DNS 查詢，不過濾任何內容。不知道選哪個就選這一類。"),
            .security: ("安全防護", "額外擋掉已知的惡意程式與釣魚網域。"),
            .ads: ("擋廣告", "擋廣告與追蹤器，少數網站可能因此異常。"),
            .family: ("家庭保護", "擋成人內容，適合小孩使用的裝置。"),
        ]
    )

    static let en = SiteStrings(
        lang: "en",
        lead: "Configuration profiles for encrypted DNS (DNS over HTTPS and DNS over TLS). Every profile is signed with an Apple Developer ID and shows as Verified on install.",
        requirements: "Requires iOS 14, iPadOS 14 or macOS 11 and later.",
        docs: "Official documentation",
        howToTitle: "How to install",
        steps: [
            "Open this page in Safari on your iPhone or iPad, tap a profile and allow the download.",
            "Go to Settings, tap \"Profile Downloaded\" at the top, check that the signer shows as Verified, then install.",
            "On a Mac, open System Settings › General › Device Management after downloading and double-click the profile. An administrator password is required.",
            "Installing another profile replaces the previous one. To go back to the default resolver, remove the profile under Settings › General › VPN & Device Management.",
        ],
        footnote: "These profiles only set the DNS resolver. No certificates, VPNs or management payloads are installed.",
        source: "Source and build pipeline",
        providerDescription: { $0.description.en },
        categories: [
            .general: ("General", "Encrypts DNS queries, filters nothing. Pick one of these if unsure."),
            .security: ("Security", "Also blocks known malware and phishing domains."),
            .ads: ("Ad blocking", "Blocks ads and trackers; a few sites may misbehave."),
            .family: ("Family", "Blocks adult content, meant for children's devices."),
        ]
    )
}

private func renderBlock(_ t: SiteStrings, config: Config, profiles: [GeneratedProfile]) -> String {
    let grouped = Dictionary(grouping: profiles, by: { $0.provider.id })
    let order = profiles.map { $0.provider.id }.reduce(into: [String]()) { if !$0.contains($1) { $0.append($1) } }

    var cards = ""
    var currentCategory: Category? = nil
    for id in order {
        guard let items = grouped[id], let p = items.first?.provider else { continue }
        if p.category != currentCategory, let c = t.categories[p.category] {
            currentCategory = p.category
            cards += """
                <h2 class="cat">\(escape(c.title))</h2>
                <p class="blurb">\(escape(c.blurb))</p>

            """
        }
        let links = items.map { item in
            """
                  <a class="btn" href="\(escape(item.fileName))" download>\(escape(item.transport.label)) · \(escape(item.transport.longName))<small>\(escape(item.endpoint))</small></a>
            """
        }.joined(separator: "\n")
        cards += """
            <section class="card">
              <h3>\(escape(p.name))</h3>
              <p>\(escape(t.providerDescription(p)))</p>
              <p class="addr">\(escape(p.addresses.joined(separator: " · ")))</p>
              <div class="links">
        \(links)
              </div>
              <p class="src"><a href="\(escape(p.website))" rel="noopener">\(escape(t.docs))</a></p>
            </section>

        """
    }

    let steps = t.steps.map { "      <li>\(escape($0))</li>" }.joined(separator: "\n")

    return """
    <div class="lang" lang="\(t.lang)" data-lang="\(t.lang)" hidden>
      <p class="lead">\(escape(t.lead))<br>\(escape(t.requirements))</p>

    \(cards)
      <section class="howto">
        <h2>\(escape(t.howToTitle))</h2>
        <ol>
    \(steps)
        </ol>
        <p class="note">\(escape(t.footnote)) <a href="\(escape(config.siteURL))">\(escape(t.source))</a></p>
      </section>
    </div>
    """
}

func buildIndex(config: Config, profiles: [GeneratedProfile]) -> String {
    let zh = renderBlock(.zhHant, config: config, profiles: profiles)
    let en = renderBlock(.en, config: config, profiles: profiles)

    return """
    <!doctype html>
    <html lang="zh-Hant">
    <head>
    <meta charset="utf-8">
    <meta name="viewport" content="width=device-width, initial-scale=1">
    <title>\(escape(config.siteTitle))</title>
    <meta name="description" content="Signed configuration profiles for encrypted DNS (DNS over HTTPS, DNS over TLS) on iOS, iPadOS and macOS. 已簽章的加密 DNS 描述檔。">
    <style>
      :root { color-scheme: light dark; --fg: #1d1d1f; --bg: #fff; --muted: #6e6e73; --card: #f5f5f7; --accent: #0071e3; }
      @media (prefers-color-scheme: dark) { :root { --fg: #f5f5f7; --bg: #000; --muted: #a1a1a6; --card: #1c1c1e; --accent: #2997ff; } }
      * { box-sizing: border-box; }
      body { margin: 0; padding: 1.5rem 1rem 4rem; font: 16px/1.6 -apple-system, BlinkMacSystemFont, "PingFang TC", "Helvetica Neue", sans-serif; color: var(--fg); background: var(--bg); }
      main { max-width: 720px; margin: 0 auto; }
      header { display: flex; align-items: baseline; justify-content: space-between; gap: 1rem; flex-wrap: wrap; }
      h1 { font-size: 1.9rem; margin: 0; }
      .switch button { background: none; border: 1px solid var(--muted); color: var(--fg); border-radius: 999px; padding: .25rem .8rem; font: inherit; font-size: .85rem; cursor: pointer; }
      .switch button[aria-pressed="true"] { background: var(--accent); border-color: var(--accent); color: #fff; }
      .lead { color: var(--muted); margin: .5rem 0 1rem; }
      .card { background: var(--card); border-radius: 14px; padding: 1.25rem 1.25rem 1rem; margin: 1rem 0; }
      .cat { font-size: 1.35rem; margin: 2rem 0 0; }
      .blurb { color: var(--muted); margin: .15rem 0 .5rem; }
      .card h3 { margin: 0 0 .25rem; font-size: 1.15rem; }
      .card p { margin: .25rem 0; }
      .addr, .src, .note { color: var(--muted); font-size: .9rem; }
      .addr { font-family: ui-monospace, SFMono-Regular, Menlo, monospace; }
      .links { display: grid; gap: .6rem; grid-template-columns: repeat(auto-fit, minmax(240px, 1fr)); margin: .75rem 0; }
      .btn { display: block; padding: .7rem .9rem; border-radius: 10px; background: var(--accent); color: #fff; text-decoration: none; font-weight: 600; }
      .btn small { display: block; font-weight: 400; opacity: .85; font-family: ui-monospace, SFMono-Regular, Menlo, monospace; font-size: .8rem; }
      .howto { margin-top: 2rem; }
      .howto ol { padding-left: 1.25rem; }
      footer { margin-top: 2.5rem; color: var(--muted); font-size: .85rem; }
      a { color: var(--accent); }
      [hidden] { display: none !important; }
    </style>
    </head>
    <body>
    <main>
      <header>
        <h1>\(escape(config.siteTitle))</h1>
        <div class="switch" role="group">
          <button type="button" data-set-lang="zh-Hant">繁體中文</button>
          <button type="button" data-set-lang="en">English</button>
        </div>
      </header>

    \(zh)

    \(en)

      <footer>\(escape(config.organization))</footer>
    </main>
    <script>
      (function () {
        var blocks = document.querySelectorAll('[data-lang]');
        var buttons = document.querySelectorAll('[data-set-lang]');
        function show(lang) {
          blocks.forEach(function (b) { b.hidden = b.dataset.lang !== lang; });
          buttons.forEach(function (b) { b.setAttribute('aria-pressed', b.dataset.setLang === lang ? 'true' : 'false'); });
          document.documentElement.lang = lang;
        }
        buttons.forEach(function (b) { b.addEventListener('click', function () { show(b.dataset.setLang); }); });
        var preferred = (navigator.languages || [navigator.language || 'en']).some(function (l) { return /^zh/i.test(l); }) ? 'zh-Hant' : 'en';
        show(preferred);
      })();
    </script>
    </body>
    </html>

    """
}
