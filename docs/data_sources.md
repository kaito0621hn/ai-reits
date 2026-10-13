# Data Sources and Processing Notes

**Project:** AI Equities vs. Canadian REITs Across Interest Rate Cycles  
**Research period:** January 2, 2020 – July 2, 2026  
**Tools:** R, RStudio, tidyquant, dplyr, tidyr, jsonlite

## 1. About This Research

This project looks at how AI-related equities and Canadian real estate investment trusts (REITs) performed under different interest rate environments between 2020 and 2026.

I chose these two asset groups because they represent very different parts of the market. AI-related companies are often associated with growth expectations, technological development, and future earnings. REITs, on the other hand, are closely connected to real estate, rental income, financing costs, and property valuations.

Both may be affected by interest rates, but not necessarily in the same way.

My goal is to understand how their returns, risks, and sensitivity to changing interest rates compare. I am also interested in whether combining these two asset groups could offer diversification benefits.

The project takes the perspective of a Canadian investor. This matters because AIQ trades in US dollars, while XRE trades in Canadian dollars. Comparing their original returns without considering currency movements could give a misleading picture of what a Canadian investor would have experienced.

Before calculating risk-adjusted performance or running regressions, I first needed to collect, clean, and align the underlying data.

This document records that process, including the problems I encountered and the decisions I made along the way.

## 2. Choosing the ETFs

I use two exchange-traded funds as proxies for the asset groups in this research.

### AIQ — Global X Artificial Intelligence & Technology ETF

AIQ is used as a proxy for AI-related equities.

Rather than selecting a small number of individual technology companies, I wanted to use an ETF that provides exposure to a broader group of businesses connected to artificial intelligence and technology.

This reduces the influence of company-specific events compared with studying just one or two stocks.

However, AIQ is not a perfect representation of the entire AI industry. Its performance depends on the ETF's holdings, investment strategy, sector concentration, and portfolio changes over time.

AIQ trades in US dollars, so its returns need to be converted into Canadian dollars for the main comparison.

### XRE.TO — iShares S&P/TSX Capped REIT Index ETF

XRE is used as a proxy for Canadian publicly traded REITs.

I selected it because it provides exposure to the Canadian listed real estate sector without requiring me to construct and maintain a portfolio of individual REITs.

REITs are particularly relevant to this research because changes in interest rates can affect borrowing costs, property valuations, and the attractiveness of income-producing assets.

However, XRE represents listed REIT securities, not direct ownership of physical real estate. Its performance can also be influenced by broader stock market conditions.

XRE trades in Canadian dollars, so no currency conversion is required for its price series.

### Why use ETFs instead of individual stocks?

Using ETFs makes the comparison more manageable and reduces the risk that the findings are driven by one company's performance.

At the same time, ETF-level analysis comes with limitations. The results describe these particular funds and should not automatically be interpreted as the performance of every AI company or every Canadian real estate investment.

## 3. ETF Price Data

**Source:** Yahoo Finance  
**Access method:** R `tidyquant` package  
**Tickers:** `AIQ` and `XRE.TO`

The research uses the period from January 2, 2020, through July 2, 2026, inclusive.

The downloaded dataset contains:

| ETF | Observations | First date | Last date |
|---|---:|---|---|
| AIQ | 1,633 | 2020-01-02 | 2026-07-02 |
| XRE.TO | 1,632 | 2020-01-02 | 2026-07-02 |

The original downloaded data is stored locally in:

`data/raw/etf_prices.csv`

### Why use adjusted prices?

I use the `adjusted` price column rather than the regular closing price when calculating investment returns.

The closing price shows the market price of the ETF on a particular date. Adjusted prices account for historical corporate actions and distribution adjustments reflected by the data provider.

This distinction is especially important for REITs because distributions are an important part of their investment performance.

Using regular closing prices alone could understate the historical performance of an income-producing ETF.

However, Yahoo Finance adjusted prices are still a data-provider-based approximation. They are not necessarily identical to an investor's realized total return or an official issuer total-return index.

Before presenting final performance conclusions, I plan to compare the results with information published by the ETF issuers, paying attention to differences between market-price returns, NAV returns, and distribution assumptions.

## 4. Initial ETF Data Quality Checks

Before calculating returns, I checked whether the downloaded price data was suitable for analysis.

The checks included:

- Missing adjusted prices, closing prices, and trading volumes.
- Duplicate trading dates.
- Non-positive adjusted prices.
- Differences between US and Canadian trading calendars.
- Unusually large price changes.

Both ETFs passed the basic missing-value and duplicate-date checks.

I also found that the two ETFs did not have exactly the same trading dates.

There were:

- 1,599 dates shared by both ETFs.
- 34 dates available only for AIQ.
- 33 dates available only for XRE.

This difference is reasonable because US and Canadian exchanges do not observe exactly the same holidays.

I decided to keep the original price records unchanged rather than immediately removing dates that appeared in only one dataset.

This allows me to preserve the original information and make different alignment choices depending on the analysis.

## 5. Foreign Exchange Data

**Source:** Bank of Canada Valet API  
**Series:** `FXUSDCAD`  
**Unit:** Canadian dollars per one US dollar

The foreign exchange data covers the same research period.

The downloaded series contains 1,621 observations.

The first recorded exchange rate is:

**January 2, 2020: 1 USD = 1.2992 CAD**

The final recorded exchange rate is:

**July 2, 2026: 1 USD = 1.4181 CAD**

The exchange rate increased by approximately 9.15% between these two observations, indicating that the US dollar appreciated against the Canadian dollar over the full period.

This is a start-to-end comparison, not a description of the exchange rate's movements throughout the period.

The raw exchange rate observations are stored locally in:

`data/raw/fx_usdcad.csv`

### Why use Bank of Canada data?

I chose the Bank of Canada because it provides an official and accessible historical exchange rate series.

Using a consistent source also makes it easier to document the exchange rate definition and reproduce the analysis.

However, the Bank of Canada's daily reference rate is not necessarily the exchange rate at the exact moment an ETF closes.

For this reason, the converted prices should be treated as estimates for historical analysis, not exact executable Canadian-dollar market prices.

## 6. Checking the Exchange Rate Data

After downloading the USD/CAD series, I checked its basic quality.

The results were:

| Check | Result |
|---|---:|
| Total observations | 1,621 |
| Missing dates within recorded rows | 0 |
| Missing exchange rate values | 0 |
| Duplicate dates | 0 |
| Non-positive exchange rates | 0 |

The first and last observations matched the intended research period.

One important lesson was that having no missing values in a dataset does not mean that observations exist for every calendar day.

The Bank of Canada does not publish an observation on every weekend or holiday. These dates are absent from the dataset rather than represented as rows containing `NA`.

This became important when I started matching exchange rates with ETF prices.

## 7. The Trading Calendar Problem

The next challenge was aligning three different time series:

1. AIQ prices from the US market.
2. XRE prices from the Canadian market.
3. USD/CAD exchange rates from the Bank of Canada.

These datasets follow different trading and publication calendars.

I found that:

| Comparison | Number of dates |
|---|---:|
| AIQ trading dates without same-day FX data | 45 |
| XRE trading dates without same-day FX data | 11 |
| Dates shared by AIQ, XRE, and FX | 1,588 |

The missing same-day exchange rates were concentrated around Canadian holidays, including Canada Day, Victoria Day, Thanksgiving, Remembrance Day, and the National Day for Truth and Reconciliation.

This suggested that many of the gaps came from differences in market calendars rather than failed downloads.

However, the full list has not been independently checked against an official holiday calendar.

### My initial approach

I first joined the exchange rates directly to AIQ trading dates and used forward filling to replace missing exchange rates.

Forward filling means using the most recent preceding available observation.

For example, if an exchange rate is missing on Monday, the method may use the previous Friday's rate.

This approach avoids using a future exchange rate to fill an earlier date.

The initial dataset contained 1,633 AIQ observations and no missing exchange rates.

At first, this looked correct.

However, when I compared all 45 filled observations against the complete Bank of Canada history, only 43 matched the most recent preceding available exchange rate.

Two dates were incorrect.

### The December 2021 issue

The incorrect dates were December 27 and December 28, 2021.

The relevant observations were:

| Date | AIQ trading record | Bank of Canada FX |
|---|---|---:|
| 2021-12-23 | Yes | 1.2816 |
| 2021-12-24 | No | 1.2813 |
| 2021-12-27 | Yes | No observation |
| 2021-12-28 | Yes | No observation |
| 2021-12-29 | Yes | 1.2804 |

My first approach assigned an exchange rate of 1.2816 to December 27 and 28.

The problem was that December 24 had been removed when I restricted the data to AIQ trading dates.

Even though AIQ did not trade that day, the Bank of Canada still had a valid exchange rate observation of 1.2813.

Therefore, the most recent preceding available exchange rate for December 27 and 28 was 1.2813, not 1.2816.

This was an alignment error rather than an error in the downloaded exchange rate data.

### How I corrected it

I changed the processing order.

Instead of restricting the data to AIQ dates before filling missing values, I now:

1. Combine all AIQ trading dates with the complete FX observation calendar.
2. Sort the combined dataset by date.
3. Forward-fill missing exchange rates.
4. Keep only the AIQ trading dates after filling.

This preserves exchange rate information from days when AIQ itself was not trading.

After making the correction, I checked all 45 dates again.

**Result: 45 correct fills out of 45, with zero mismatches.**

This experience showed me that a dataset can contain no missing values and still be incorrectly aligned.

It also reinforced the importance of checking the logic behind data transformations rather than relying only on basic completeness checks.

### Limitation of forward filling

Forward filling is still an approximation.

It uses the most recent available historical observation, which may not reflect the actual exchange rate on the missing date.

The method also does not guarantee that the reference rate was available at the exact time an ETF could have been traded.

For the historical descriptive analysis, I use same-date reference rates where available and the latest preceding observation otherwise.

A trading strategy or execution-focused study would require more precise information about quote timing and data availability.

## 8. Converting AIQ Prices into Canadian Dollars

After correcting the exchange rate alignment, I converted AIQ's adjusted prices into Canadian dollars.

The formula is:

**AIQ adjusted price in CAD = AIQ adjusted price in USD × USD/CAD exchange rate**

For example, on January 2, 2020:

- AIQ adjusted price: approximately USD 17.96543.
- USD/CAD exchange rate: 1.2992.
- Converted adjusted price: approximately CAD 23.34068.

This creates a Canadian-dollar price series that can be compared with XRE.

The converted AIQ dataset contains 1,633 observations.

I checked for missing values, duplicate dates, non-positive prices, and currency conversion errors.

All these checks passed.

The converted price series is stored locally in:

`data/clean/aiq_prices_cad.csv`

## 9. Preliminary Currency Return Comparison

One of the first findings was that the choice of currency meaningfully changed AIQ's measured cumulative return.

For January 2, 2020, through July 2, 2026:

| Measure | Result |
|---|---:|
| AIQ cumulative adjusted return in USD | +244.27% |
| AIQ cumulative adjusted return in CAD | +275.78% |
| Difference | +31.51 percentage points |

The difference is explained by the interaction between AIQ's investment return and the change in the USD/CAD exchange rate.

The relationship is:

**(1 + CAD return) = (1 + USD return) × (1 + FX return)**

Over the period, the US dollar appreciated by approximately 9.15% against the Canadian dollar.

Because currency and asset returns compound together, this exchange rate movement increased AIQ's cumulative return measured in Canadian dollars by approximately 31.51 percentage points.

This does not mean that the exchange rate itself returned 31.51%.

It means that a Canadian-dollar investor's measured cumulative return was higher than the corresponding US-dollar return over this particular period.

This is a preliminary historical result. It does not establish that currency exposure always benefits Canadian investors.

## 10. Aligning AIQ and XRE for a Fair Comparison

After converting AIQ into Canadian dollars, I needed to make sure the two ETFs were compared over identical holding periods.

The correct approach is to align their prices first and then calculate returns.

If I calculated returns separately before joining the datasets, some observations could represent different holding periods because of market holidays.

For example, a return calculated from Friday to Monday should not automatically be treated as equivalent to a return calculated from Thursday to Monday.

I therefore retained only the dates on which both ETFs had price observations.

This produced:

- 1,599 common price observations.
- 1,598 holding-period return observations.
- No missing values.
- No duplicate dates.

I calculated simple returns using:

**Return = Current adjusted price / Previous adjusted price − 1**

I also recorded the number of calendar days between consecutive common trading dates.

The longest interval was six calendar days.

The aligned datasets are saved locally as:

- `data/clean/etf_prices_cad.csv`
- `data/clean/etf_returns_cad.csv`

### Why record the number of days between observations?

The return intervals are not always the same length.

Most consecutive observations are separated by one calendar day, but weekends and holidays create longer gaps.

This distinction matters when converting annual interest rates into holding-period risk-free returns.

It also matters when interpreting the time scale of return observations.

In later stages, I will use the actual interval lengths where appropriate rather than assuming that every observation represents exactly one calendar day.

## 11. Extreme Returns and Unusual Observations

I also checked for unusually large returns.

I used an absolute return threshold of 10% as a screening rule.

This is not a statistical definition of an outlier. It is simply a practical way to identify observations that deserve additional attention.

Four observations crossed this threshold in the aligned Canadian-dollar dataset:

| Date | AIQ CAD return | XRE CAD return |
|---|---:|---:|
| 2020-03-16 | −9.42% | −11.45% |
| 2020-03-18 | −2.96% | −13.91% |
| 2020-03-23 | +1.85% | −14.54% |
| 2025-04-09 | +11.83% | +3.50% |

The March 2020 observations occurred during the COVID-19 market disruption.

The April 2025 observation occurred during a period of major market volatility surrounding US trade policy announcements.

These events provide plausible historical context, but the observations have not yet been independently verified against another market-data source.

I have kept all four observations in the dataset.

Removing them simply because they are large could understate actual market risk and distort later results.

These dates may be especially important when calculating volatility, downside risk, drawdowns, and risk-adjusted performance.

Before the final report, I plan to compare the observations with independent market information and examine nearby trading days.

## 12. Reproducibility and Project Organization

An important goal of this project is to make the analysis reproducible.

The main data-processing script is:

`scripts/02_prepare_cad_returns.R`

The script:

1. Reads the locally stored raw ETF and FX datasets.
2. Aligns the complete FX calendar with AIQ trading dates.
3. Applies forward filling.
4. Checks the December 2021 alignment issue.
5. Converts AIQ adjusted prices into Canadian dollars.
6. Aligns AIQ and XRE prices.
7. Calculates returns over common holding periods.
8. Runs basic data quality checks.
9. Saves four cleaned datasets.

The script has been run successfully and reproduces 1,599 common price observations and 1,598 return intervals.

The raw and cleaned CSV files are stored locally and excluded from the public Git repository.

The repository is intended to preserve the code, methodology, documentation, and appropriate research outputs.

The processing script requires the raw input files to be available locally. It does not currently download every required input automatically.

This limitation should be addressed in the broader reproducibility workflow.

## 13. What Still Needs to Be Done

The data preparation work is not the end of the research.

Several important steps remain.

### Macroeconomic data

I still need to collect and validate interest rate data, including the Bank of Canada policy rate and suitable government bond yield series.

These will help me divide the research period into interest rate environments and examine whether AIQ and XRE respond differently to rate changes.

### Risk-free rate

I need a suitable Canadian risk-free rate series to calculate excess returns and risk-adjusted performance measures.

Because the holding periods are not always equal in length, the annual rate will need to be converted into an appropriate return for each interval.

The rate used should also be known at the beginning of the relevant interval to avoid look-ahead bias.

### Market benchmarks

I need a suitable market benchmark to estimate beta and evaluate market-adjusted performance.

A global equity benchmark is a candidate for the main comparison, while a Canadian equity benchmark may provide a useful robustness check.

The final benchmark choice and its implications must be documented.

### Independent data verification

Before drawing final conclusions, I still need to compare selected results against independent sources, including ETF issuer information where available.

This is particularly important for extreme returns, adjusted-price interpretation, and performance comparisons.

### Risk and statistical analysis

Later stages will include:

- Volatility and cumulative performance.
- Sharpe, Sortino, and Treynor ratios.
- CAPM and market beta.
- Rolling beta.
- Interest rate sensitivity regressions.
- Bank of Canada policy-event analysis.
- Diversification and correlation analysis.

These analyses will build on the cleaned Canadian-dollar return data prepared in this stage.

## 14. Current Status

At this point, the ETF and foreign exchange data have been collected, checked, and processed into comparable Canadian-dollar price and return series.

The most important methodological issue encountered so far was the December 2021 exchange rate alignment problem. Identifying and correcting it helped improve the reliability of the entire currency conversion process.

The cleaned datasets now pass the basic validation checks, and the processing steps have been organized into a reproducible R script.

However, the research is still in progress.

The results documented here are preliminary descriptive findings. They should not yet be interpreted as final evidence about which asset group performs better across interest rate cycles.

The next priority is to complete the macroeconomic data collection, verify the remaining sources, and build the foundation for risk-adjusted and regression-based analysis.