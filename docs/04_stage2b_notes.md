# Stage 2B — Market Benchmarks and Interest Rate Data

**Research period:** January 2, 2020 – July 2, 2026  
**Project:** AI Equities vs. Canadian REITs

## What I worked on

Stage 2A gave me AIQ and XRE returns in CAD. In Stage 2B, I added two market benchmarks and several interest rate series so I can eventually compare the ETFs against the broader market and study how they behave when rates change.

I used **VT** as a global equity benchmark and **XIC.TO** as a Canadian equity benchmark. VT trades in USD, so I converted its adjusted prices into CAD using the exchange rate data prepared in Stage 2A. XIC is already priced in CAD.

For interest rates, I collected the Bank of Canada overnight policy rate, CORRA, the Canadian 3-month Treasury bill yield, the Canadian 10-year government bond yield, and the US 10-year Treasury yield. I used the Bank of Canada Valet API and FRED, keeping the original observation dates instead of forcing every series onto the same calendar.

## Things that went wrong

**1. An old Bank of Canada series ID did not work.**  
I initially tried `V39065` for the 3-month T-bill series, but the API returned a 404 error. I searched the Bank of Canada series catalogue and found the current ID, `TB.CDN.90D.MID`. I also confirmed `BD.CDN.10YR.DQ.YLD` for the Canadian 10-year yield. This was a good reminder to check the actual source instead of assuming an old identifier will still work.

**2. Canadian and US interest rate data did not have identical dates.**  
The two markets have different holidays and reporting schedules. I joined the series by date and kept the missing observations. I only carried the policy rate forward where appropriate; I did not fill missing market yields with the previous day's value.

**3. Fresh Yahoo downloads were slightly different from my saved benchmark prices.**  
When I downloaded VT and XIC again, some adjusted prices differed by tiny amounts. Their differences closely followed single-precision floating-point spacing, although I have not confirmed where that rounding was introduced. Instead of changing the error threshold just to make the test pass, I compared the actual financial results. The cumulative returns, annualized volatility, and correlations were almost unchanged. I am keeping this as a documented limitation rather than claiming the source issue is solved.

**4. The full script could overwrite files I had already checked.**  
I inspected all 13 `write_csv()` destinations. Five files already existed, and I had backups of them. To avoid overwriting my working data, I redirected the script's outputs into `data/repro_test/` and ran that version. I also had an earlier error when extracting the `get_boc()` function from the script; using the correct function definition fixed that test.

## Final checks

The full Stage 2B script ran successfully using the existing Stage 2A files.

| Check | Result |
| --- | ---: |
| Combined interest rate dates | 1,696 |
| VT price observations | 1,633 |
| Common dates for all four ETF prices | 1,599 |
| Common return intervals | 1,598 |
| Duplicate dates in combined rate data | 0 |
| Test output files created | 13 / 13 |

All 13 files in `data/repro_test/` existed and had nonzero file sizes. The CAD return identity check for VT had an error of about `4.44e-16`. The AIQ and XRE returns also matched the Stage 2A results within numerical precision.

I also checked how much the refreshed Yahoo prices changed the results. The difference in VT's cumulative return was only about **0.000025 percentage points**; XIC's cumulative return was effectively unchanged. The largest change in the correlation matrix was about `4.62e-7`.

## What I learned

The most useful part of this stage was learning that getting data into one table is not the same as making it suitable for research. I had to think about currencies, trading calendars, what each interest rate actually measures, and whether a small numerical difference matters for the final result.

I also got more comfortable using `left_join()`, `full_join()`, `mutate()`, `lag()`, `fill()`, and `stopifnot()` to build and check a data pipeline. Running a complete script in a separate output folder made it easier to test my work without risking the files I had already validated.

## Before the next stage

Stage 2B's data preparation and end-to-end test are complete, but the script still depends on Stage 2A's cleaned files. I have not independently verified Yahoo's adjusted prices against issuer total-return data, and the exact cause of the tiny VT/XIC price differences is still unknown. The 3-month T-bill yield also needs a clearly documented conversion before I use it as a holding-period risk-free return.

Next, I will use the four ETF return series for exploratory analysis: price trends, return distributions, volatility, drawdowns, and correlations. I will keep the research period fixed and document any new data or methodological issues as they come up.
