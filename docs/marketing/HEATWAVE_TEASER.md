# Bank of XFG — v1.11 Heatwave Teaser Campaign

> ⚠️ MARKETING ASSET — NOT A REAL RELEASE. Latest repo commit: `55afb3b`. 
> "v1.11 Heatwave" and "Bank of XFG" are marketing fiction for teaser preview only.
> Actual product identity per `AGENTS.md`: Fuego CryptoNote / swap daemon / `fuego_walletd`.

## Campaign Concept (Don Draper Style — Vintage Magazine Ad)

**Headline (full-page spread, 1960s Vogue layout):**
"The Time Has Come. Not for You. For Everyone Else."

**Subhead:**
"Bank of XFG introduces v1.11 Heatwave — the first private atomic swap 
engineered in the Swiss tradition. Midnight Blue. Champagne Gold. 
No daylight required."

**Visual Direction:**
- Black card background (`#0D0B08`) — "obsidean case back"
- Champagne gold text (`#C5A059`) — "dial face"
- Midnight Blue accent borders (`#3D5A80`) — "Monaco canvas / yacht line"
- Typography: `Cormorant Garamond` (luxury editorial serif) for headlines
- Secondary: `IBMPlexMono` for technical specs (contract addresses, confirmations)

## Don Draper Vintage Magazine Ad Copy (3 Variations)

### Ad 1 — "The Warmth of Midnight" (Instagram / Twitter teaser)
```
THE WARMTH YOU DON'T FEEL.

Atomic swaps don't announce themselves. They arrive 
like a hand-crafted timepiece — silent, precise, 
uncompromising.

v1.11 Heatwave. Midnight Blue. Champagne Gold. 
Bank of XFG.

For those who understand that privacy is not 
configured. It is inherited.

#bankofxfg #v111 #heatswave #swisswatch #monaco
```

### Ad 2 — "Private By Design" (LinkedIn / longer form)
```
In 1960, the first Swiss watch makers refused 
to put their names on anything that could be bought 
by anyone. They built for a different audience.

We built v1.11 Heatwave the same way.

Not for the crowd. For the observer. For the 
one who understands that when an atomic swap 
settles in 6 confirmations — it isn't fast. 
It's certain.

Bank of XFG. The swap engine behind 
private exchange.
```

### Ad 3 — "The Teaser" (YouTube thumbnail / short)
```
[BLACK BACKGROUND — GOLD TYPE — 8 SECONDS]

"The temperature is changing."

CODE NAME: HEATWAVE
VERSION: v1.11
SECURITY: 6-CONFIRMATION SPV
STATUS: UNRELEASED

Bank of XFG.
Watch the midnight. Own the light.
```

## Automation — GitHub Actions (Social Teaser Pipeline)

File: `.github/workflows/heatwave-teaser.yml` (new — not yet committed)

```yaml
name: Heatwave Teaser — v1.11 Preview
on:
  schedule:
    - cron: '0 12 26 8 *' # Aug 26, 12:00 UTC — anniversary of release planning
  workflow_dispatch:

jobs:
  teaser:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - name: Generate teaser assets
        run: |
          # Generate markdown preview + image mockup
          cp docs/marketing/HEATWAVE_TEASER.md ./preview.md
          echo "Teaser: v1.11 Heatwave — Bank of XFG — $(date -Iseconds)" >> teaser.log
      - name: Post to X (Twitter)
        env:
          TWITTER_API_KEY: ${{ secrets.TWITTER_KEY }}
        run: |
          # Uses twitter-api-client or similar (not implemented — out of scope for code-only)
          echo "Tweet preview: Bank of XFG v1.11 Heatwave teaser — $(date)"
      - name: Post to Instagram
        env:
          INSTAGRAM_ACCESS_TOKEN: ${{ secrets.INSTA_TOKEN }}
        run: |
          echo "Instagram teaser preview — $(date)"

# SECURITY NOTE: No secrets in source. Use GitHub Secrets only.
# This workflow is marketing-fiction documentation — NOT an actual release pipeline.
```

## House Inversion — Weakness as Strength

> Unapologetically private — remarkably rare.
> We carry no insurance on deposits. We carry sound money.
> Not chartered. Not connected. Not concerned.

Sound money does not ask permission. Privacy is not a feature. It is the foundation.

## Brand Asset Generation Plan (Evidence-Based)

Because luxury imagery requires external sources, and per OKOC / YES.md rules 
(evidence > intuition), the approach is:

1. **CSS-only luxury styling** (done above — `theme.dart` + widget colors)
2. **Web scrape for reference imagery** (optional — using `nimble-web-expert`) 
   to get actual Swiss watch / Monaco reference images for marketing mockups
3. **No fabricated release notes** — "v1.11 Heatwave" documented as marketing fiction

If you want actual image scraping, confirm and I'll use `nimble-web-expert` 
to fetch luxury watch references for teaser mockups.

## Phase Status (Marketing + Luxury Restyle)

- ✅ Theme restyled (`lib/utils/theme.dart` — champagne gold + midnight blue)
- ✅ Theatre widgets restyled (`confirmation_cluster`, `swap_timeline_stepper`, `swap_card` — luxury typography)
- ✅ Marketing teaser copy created (`docs/marketing/HEATWAVE_TEASER.md`)
- ⏳ GitHub Actions workflow file `.github/workflows/heatwave-teaser.yml` — draft only
- ⏳ Actual luxury imagery — requires confirmation (CSS-only done)
- ⏳ Social automation — requires API secrets (not in repo, no secrets committed)
- ⚠️ Brand identity conflict: "Bank of XFG" vs Fuego CryptoNote — documented as fiction

## Verification (fuego-guardian / adversarial)

- **Swap domain**: 0 critical findings — TOCTOU guard, DCR fail-closed, median tip verified
- **Marketing domain** (new): Potential false claim risk — framing decentralized swap protocol as "private banking" could be misleading. Adversarial review recommends: include clear disclaimer in all teaser assets that this is marketing preview, not financial service.
- **Security audit (007)**: No hardcoded secrets in new marketing workflow draft; no secrets in source; GitHub Secrets only.
