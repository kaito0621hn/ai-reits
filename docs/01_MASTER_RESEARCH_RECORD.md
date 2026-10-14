# AI Equities vs Canadian REITs — Master Research Record

**Coverage:** Stage 1, Stage 2A, Stage 2B (through four-ETF alignment).  
**Fixed sample:** 2020-01-02 to 2026-07-02, inclusive.  
**Repository:** https://github.com/kaito0621hn/ai-reits  
**Local project:** `C:/Users/kaito/projects/AI-REITs/ai-reits`  
**Status:** Stage 1 and Stage 2A previously checkpointed; Stage 2B data prepared and CSVs saved, but reproducible scripts, clean-session rebuild, independent review, and Git checkpoint remain outstanding.

> **Evidence standard:** This document reconstructs work from the user's reported RStudio outputs and project conversation. It is not an independent inspection of local files or an external price-source verification. Values described as approximate are rounded from reported output.

## 1. Research question and design

How do AI equities (AIQ) and Canadian REITs (XRE.TO) compare in CAD-denominated returns, risk, interest-rate sensitivity, and diversification across Bank of Canada interest-rate cycles? Market proxies: VT (global equity) and XIC.TO (Canadian equity). Interest rates: BoC policy rate, CORRA, Canada 3-month T-bill, Canada 10-year government bond yield, and US 10-year Treasury yield.

The core investor perspective is **unhedged CAD**. Adjusted ETF prices are used as the basis for historical performance. Neither ETF adjusted-price histories nor macro-series vintage histories have yet been independently reconciled.

## 2. Stage 1 — ETF acquisition and validation

- ETF price acquisition via Yahoo Finance / `tidyquant::tq_get()`; primary tickers AIQ (USD) and XRE.TO (CAD).
- Reported raw price observations: AIQ 1,633; XRE.TO 1,632.
- Common price dates: 1,599; AIQ-only dates: 34; XRE-only dates: 33.
- Observed importance of adjusted versus unadjusted close: AIQ adjusted cumulative gain approximately +244% versus close +238%; XRE adjusted approximately +20.2% versus close approximately −10% (reported Stage 1 values, not independently recomputed here).
- Noted extremes for follow-up: XRE March 2020 approximately −11.5%, −13.9%, −14.5%; AIQ April 2025 approximately +12.2% in USD. Do not remove merely for being extreme.
- Known scripts: `scripts/01_dataload_etf.R`, `scripts/01_validate_etf.R`; historical `scripts/01_download_data.R` macro draft inspected but not edited.
- Reported Git checkpoint: `9a933af` (Stage 1).
- **Open:** external adjusted-price/issuer-total-return verification, Yahoo revision risk, and exact raw snapshot reproducibility.

## 3. Stage 2A — FX conversion and synchronized AIQ/XRE returns

### 3.1 Data discovery and FX calendar

- Source: Bank of Canada Valet series `FXUSDCAD` (CAD per USD).
- Raw FX series reported 1,621 rows and saved as `data/raw/fx_usdcad.csv`.
- **Important discovery:** Forward-filling FX after restricting to ETF dates would discard an FX-only observation on **2021-12-24 (1.2813)**, relevant to AIQ 2021-12-27 and 2021-12-28. Correct approach: form the union of FX and ETF dates, sort, fill forward, and then select ETF dates.
- 45/45 missing ETF-day FX values were forward-filled according to the reported Stage 2A audit.
- FX date alignment and resulting conversion had 1,633 AIQ dates and no missing aligned FX values, later confirmed again against VT dates.

### 3.2 Formulas and outputs

`P_CAD,t = P_USD,t × FX_USDCAD,t`  
`R_CAD,t = (1 + R_USD,t)(1 + R_FX,t) − 1`

- AIQ USD adjusted cumulative return approximately +244.27%; CAD adjusted approximately +275.78%.
- Difference in cumulative returns: +31.51 percentage points; USD/CAD endpoint change approximately +9.15%. These are not additive contributions: conversion compounds multiplicatively.
- On 2020-03-16: AIQ USD return −9.831819%, FX return +0.4532048%, CAD return −9.423173%; internally consistent with multiplicative formula.
- Synchronized AIQ/XRE price dates 1,599; return intervals 1,598; interval lengths 1–6 calendar days.
- Outputs: `data/clean/fx_aligned_aiq.csv`, `aiq_prices_cad.csv`, `etf_prices_cad.csv`, `etf_returns_cad.csv`.
- Known script: `scripts/02_prepare_cad_returns.R`.
- Reported Git checkpoints `6b9cb4f` (script) and `74192ad` (documentation); pushed to origin/main and clean status reported.
- Stage 2A independent agent assessment was **PASS / Proceed on supplied evidence**, not a full external raw-data audit.
- Remaining caveats: independent adjusted-price comparison, FX reference-rate timing versus ETF close, download timestamp/vintage, forward-fill timing effects, annualization convention.

## 4. Stage 2B — Macroeconomic data discovery

### 4.1 Actual source-finding procedure

1. Defined the variables required by later analysis: Canadian risk-free proxy, monetary-policy stance, Canadian long yield, US long yield, global/Canadian equity benchmarks.
2. Used BoC Valet API and its **official series catalogue**: `https://www.bankofcanada.ca/valet/lists/series/json`.
3. Initially attempted historical ID `V39065` as a Valet observation series. It returned **HTTP 404**. This was a real failed lookup, not a successful download.
4. Loaded the catalogue using `jsonlite::fromJSON(..., flatten=TRUE)$series`, a named list of **16,170** entries as reported. Searched entries by labels/descriptions using `vapply()`, `unlist()`, and `grepl()`.
5. Identified official API series `TB.CDN.90D.MID` for **Treasury bills, 3-month**; its description mentions legacy code `(V39065)`. Identified `BD.CDN.10YR.DQ.YLD` for the Canadian 10-year benchmark bond yield.
6. Retrieved `V39079` (target overnight rate) and `AVG.INTWO` (CORRA) using BoC Valet observations.
7. Retrieved US 10-year yield from FRED `DGS10` CSV endpoint, then **explicitly filtered** its much longer history to the fixed sample.
8. Retrieved VT and XIC.TO adjusted ETF prices through Yahoo Finance using `tq_get()`, setting the exclusive `to` date to 2026-07-03 to include 2026-07-02.

### 4.2 Source register and reported checks

| Source | Series | Meaning | Reported observations | Missing |
|---|---|---|---:|---:|
| BoC Valet | `V39079` | Policy target, % | 1,682 | 0 in downloaded policy series |
| BoC Valet | `AVG.INTWO` | CORRA, % | 1,621 | 0 in downloaded CORRA series |
| BoC Valet | `TB.CDN.90D.MID` | Canadian 3m T-bill yield, % | 1,621 | 0 in downloaded series |
| BoC Valet | `BD.CDN.10YR.DQ.YLD` | Canadian 10y benchmark yield, % | 1,621 | 0 in downloaded series |
| FRED | `DGS10` | US 10y constant-maturity yield, % | 1,696 calendar rows | 70 |
| Yahoo Finance | `VT` | Global equity adjusted USD price | 1,633 | 0 |
| Yahoo Finance | `XIC.TO` | Canadian equity adjusted CAD price | 1,632 | 0 |

**Critical unit note:** a yield stored as `2.26` is **2.26%**, not decimal `2.26` or a daily realized return.

### 4.3 Macro alignment decisions

- BoC policy and CORRA full-joined on dates. Policy rate filled downward over union of calendars. Result: 1,684 rows; no missing policy values, 63 missing CORRA observations; two policy fills on CORRA-only dates (2022-08-02, 2026-04-23).
- Joined 3m T-bill and Canadian 10y bond series. Final Canadian table 1,684 rows; policy missing 0; CORRA, T-bill and Canadian 10y each missing 63.
- Full-joined Canadian table with FRED DGS10. Result: 1,696 rows, no duplicate dates. Missing: policy 12, CORRA 75, T-bill 75, Canadian 10y 75, US 10y 70.
- **Deliberate non-action:** Did not blanket-forward-fill market yields; future model-specific timing rules remain to be determined.
- Files reportedly saved: `data/clean/interest_rates_daily.csv`, `interest_rates_3m.csv`, `interest_rates_canada.csv`, `interest_rates_all.csv`; raw BoC `V39079.csv`, `AVG.INTWO.csv`, `tbill_3m.csv`, `bond_10y.csv`. FRED full raw historical CSV was not yet separately saved.

## 5. Stage 2B — Market benchmarks and currency conversion

### 5.1 VT

- VT 1,633 price observations, no missing adjusted price or duplicate dates.
- `fx_aligned_aiq` R object was missing from a later RStudio session (`object not found`); resolved by reading `data/clean/fx_aligned_aiq.csv` using `read_csv()`. Columns `date`, `usd_cad`.
- VT and aligned FX calendar cross-check: VT-only 0, FX-only 0, common 1,633, missing FX 0. **Therefore Stage 2A FX alignment safely reused for VT**, without repeating FX forward-fill.
- VT CAD adjusted prices: 1,633 rows, 0 missing.
- Calculated USD, FX, CAD returns; 1,632 intervals.
- Cumulative approximate: USD +117%, CAD +137%, FX +9.15%.
- Multiplicative return identity: max absolute error `4.440892e-16`, violations above `1e-10`: 0.
- Saved `data/clean/vt_prices_cad.csv`, `vt_returns_cad.csv`; existence confirmed.

### 5.2 XIC.TO

- XIC.TO 1,632 adjusted-price rows, no missing prices, one initial missing return (mathematically expected).
- Cumulative CAD adjusted return approximately +144%.
- Daily mean `0.000608`, daily standard deviation `0.0110`, min `−0.121`, max `+0.120`.
- Large negative returns: 2020-03-12 −12.1%; 2020-03-09 −10.4%; 2020-03-16 −9.68%; 2020-03-18 −6.89%; 2020-03-23 −5.52%.
- Large positive returns: 2020-03-24 +12.0%; 2020-03-13 +9.28%; 2025-04-09 +5.35%; 2020-04-06 +4.91%; 2020-03-25 +4.19%.
- COVID-era market stress provides context, **not independent validation** of outliers.
- Saved `data/clean/xic_returns_cad.csv`; file existence true; date duplicates 0; range 2020-01-02–2026-07-02.

## 6. Stage 2B — Four-ETF synchronization

- AIQ/VT shared 1,633 US dates; XIC had 1,632 Canadian dates. US-vs-XIC common dates 1,599; US-only 34; XIC-only 33.
- Stage 2A synchronized AIQ/XRE price file (`data/clean/etf_prices_cad.csv`) contained **1,599 rows** and columns `date`, `aiq_cad`, `xre_cad`. It is **not** XRE's independent raw calendar. Earlier inspection correctly identified this and used it as a common-date base.
- Joined VT CAD adjusted prices and XIC CAD adjusted prices to this common-date base, resulting in `four_prices` with columns `date`, `aiq_cad`, `xre_cad`, `vt_cad`, `xic_cad`.
- Four-price table: 1,599 rows, 0 missing, 0 duplicate dates.
- **Important methodological correction:** Do not simply join ETF returns computed on different national trading calendars. Instead align **prices first**, then recalculate returns on consecutive **common dates**.
- Four-return table: 1,598 intervals, 0 missing, date range 2020-01-03–2026-07-02; includes four prices, four returns and `days_between`.
- `days_between`: 1 day 1,242; 2 days 16; 3 days 269; 4 days 64; 5 days 6; 6 days 1.
- Stage 2A regression tests: AIQ maximum difference `3.587408e-15`, XRE `4.718448e-16`; 0 violations > `1e-10` for each; 1,598 matched intervals.
- Saved `data/clean/four_etf_prices_cad.csv` and `four_etf_returns_cad.csv`; user confirmed both `TRUE`.

## 7. Consolidated issue and resolution register

| ID | Stage | Detection / problem | Root cause / concern | Action taken | Verification | Status |
|---|---|---|---|---|---|---|
| I01 | 1 | Yahoo `tq_get()` initially returned NULL in early setup | Retrieval instability; precise root cause not confirmed | Explored local CSV option, later resumed Yahoo retrieval | Later data obtained; no causal diagnosis documented | Workaround successful; cause unresolved |
| I02 | 1 | AIQ and XRE had unequal dates | US/Canada market calendars differ | Identify common dates and unmatched rows | 1,599 common, 34 US-only, 33 CA-only | Addressed for common-date analysis |
| I03 | 1 | Adjusted vs close cumulative return differed markedly | Distributions and adjustment treatment matter | Adopt adjusted prices | Large reported adjusted/close difference | Choice made; external reconciliation pending |
| I04 | 1 | Extreme March 2020 / April 2025 returns | Could be genuine volatility or data issues | Retained, flagged for external comparison | No independent verification yet | Open |
| I05 | 2A | FX-only 2021-12-24 observation could be lost | Filling only after filtering ETF dates | Union FX and ETF dates before forward-fill | 45/45 ETF-day gaps filled; critical FX date retained per prior audit | Internally resolved |
| I06 | 2A | FX reference timestamp differs from ETF close | Non-synchronous observation times | Documented limitation | No quantitative sensitivity test | Open |
| I07 | 2B | BoC `V39065` observations endpoint HTTP 404 | Historical identifier not current API series key | Searched official 16,170-entry series catalogue; used `TB.CDN.90D.MID` | 1,621 valid observations | Resolved |
| I08 | 2B | Needed official Canada 10y identifier | Exact series ID initially unknown | Searched official BoC catalogue; selected `BD.CDN.10YR.DQ.YLD` | 1,621 observations, no missing/duplicates | Resolved |
| I09 | 2B | FRED DGS10 CSV covered 1962–2026, beyond sample | Full historical download by default | Filtered fixed study dates | 1,696 rows, 70 NA, 0 duplicate | Resolved sample scope |
| I10 | 2B | FRED and Canadian yield calendars contain NA after full join | Different market holidays and calendars | Preserved NA rather than blind fill | 1,696 rows; missing counts recorded | Downstream policy open |
| I11 | 2B | `fx_aligned_aiq` object not found | RStudio session object not loaded | Re-read existing Stage 2A CSV | Columns/date sample confirmed; later VT matched 1,633 dates | Resolved |
| I12 | 2B | Reusing AIQ FX calendar for VT could omit dates | ETF calendars not automatically identical | Bidirectional `anti_join` and missing checks | 0 unmatched, 1,633 matched, 0 missing | Resolved |
| I13 | 2B | Different national trading calendars distort return joins | Returns cover different preceding dates | Join adjusted **prices**, then recalculate returns | 1,599 prices, 1,598 matched intervals, 0 NA | Resolved for common calendar |
| I14 | 2B | Existing `etf_prices_cad.csv` mistaken as raw XRE dates | It already represents Stage 2A common-price dates | Inspected names and row count; used correctly as common base | 1,599 rows, three columns | Clarified; raw XRE date equivalence not separately established |
| I15 | 2B | New calculations could change old AIQ/XRE returns | Pipeline regression risk | Matched old/new returns by date and compared | Max diffs 3.59e−15 and 4.72e−16; 0 > 1e−10 | Resolved internally |
| I16 | 2B | Stage 2B code exists mainly as Console steps | Not independently reproducible from Git | Consolidation script and clean-session test required | Not yet run | Open |
| I17 | 2B | External adjusted-price verification absent | Yahoo data source/adjustment risks | Planned independent issuer/source check | Not yet done | Open |
| I18 | 2B | T-bill annualized yield not directly a daily risk-free return | Yield convention and holding interval matter | Deferred yield-to-return conversion | Not yet done | Open |
| I19 | 2B | Common interval lengths 1–6 calendar days | Market holidays/weekends | Retained `days_between` | Frequency counts sum to 1,598 | Resolved documentation; modeling choice open |
| I20 | 2B | Macro download timestamps and FRED raw snapshot incomplete | Mutable external data | Document retrieval dates, save source snapshots where allowed | Not yet done | Open |
| I21 | 2B | No independent Stage 2B review or Git checkpoint | Project handoff incomplete | Planned review after clean rebuild | Not yet done | Open |

**Important:** Some early-stage issues are reconstructed from conversation summaries rather than preserved error logs. Where root cause is unknown, it remains explicitly unknown.

## 8. Research decisions and rejected shortcuts

1. **CAD investor perspective:** convert AIQ/VT adjusted USD prices to CAD; do not compare USD AIQ with CAD XRE as if currency-neutral.
2. **Use adjusted prices:** better accommodates distributions than unadjusted close; independently validate adjustment source later.
3. **Use official BoC catalogue:** do not assume historical V-codes are valid Valet series IDs.
4. **Do not overwrite Stage 2A FX alignment:** reuse verified `fx_aligned_aiq.csv` only after verifying VT date equality.
5. **Join common prices before computing returns:** avoid different underlying holding intervals; do not merely `inner_join()` precomputed US and Canadian returns.
6. **Retain genuine-looking outliers:** flag for independent check; no arbitrary winsorization.
7. **Preserve macro missing observations:** avoid unjustified market-yield fill; model-specific alignment later.
8. **Do not add UIP to core return calculation:** UIP concerns expected exchange-rate changes and interest-rate parity; realized ETF CAD returns follow a multiplicative accounting identity.
9. **No causal language for future rate regressions:** associations require robust inference and appropriate identification.

## 9. File and checkpoint inventory

**Existing / reported scripts:** `scripts/01_dataload_etf.R`, `scripts/01_validate_etf.R`, `scripts/01_download_data.R` (old macro draft), `scripts/02_prepare_cad_returns.R`.

**Reported Stage 2B files:**

- `data/raw/V39079.csv`, `AVG.INTWO.csv`, `tbill_3m.csv`, `bond_10y.csv`, `benchmark_prices.csv`.
- `data/clean/interest_rates_daily.csv`, `interest_rates_3m.csv`, `interest_rates_canada.csv`, `interest_rates_all.csv`.
- `data/clean/vt_prices_cad.csv`, `vt_returns_cad.csv`, `xic_returns_cad.csv`, `four_etf_prices_cad.csv`, `four_etf_returns_cad.csv`.

**Git:** Stage 1 `9a933af`; Stage 2A `6b9cb4f`, `74192ad`. No confirmed Stage 2B commit. `data/raw/` and `data/clean/` are gitignored.

## 10. Priority actions before Stage 3

1. Execute consolidated Stage 2B script from a clean R session, after Stage 2A inputs are available; compare counts, ranges, errors and CSVs.
2. Check source metadata, retrieval timestamps and exact BoC/FRED/ETF units.
3. Independently validate selected Yahoo adjusted-price and extreme-return observations.
4. Confirm 3m T-bill yield quotation convention and align risk-free returns to beginning of each holding interval, with correct day count.
5. Choose and document annualization approach for common-date returns; evaluate 252-day sensitivity.
6. Obtain independent AI review; record every finding, resolution, test and remaining limitation.
7. Update `docs/data_sources.md`, issue log and decision log; commit scripts/docs and confirm clean Git status.

## 11. Reviewer handoff request

Please audit actual source files and scripts, not just this narrative. Reproduce all reported counts, missingness, date matches, USD→CAD identity, and Stage 2A regression tests. Evaluate the FX fill chronology, quote conventions, market close-time mismatch, and source revisions. Return findings with severity, exact code/data evidence, proposed fixes, required downstream reruns, and a final status of PASS / CONDITIONAL PASS / FAIL. Do not mark unresolved issues as passed.
