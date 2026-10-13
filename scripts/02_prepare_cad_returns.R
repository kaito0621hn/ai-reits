
# Stage 2: Prepare CAD-denominated ETF returns
# Research period: 2020-01-02 to 2026-07-02

library(dplyr)
library(tidyr)

# 1. Load raw data
etf <- read.csv("data/raw/etf_prices.csv") |>
  mutate(date = as.Date(date))

fx <- read.csv("data/raw/fx_usdcad.csv") |>
  mutate(date = as.Date(date)) |>
  arrange(date)

# 2. Extract AIQ trading dates
aiq_dates <- etf |>
  filter(symbol == "AIQ") |>
  select(date)

# 3. Align exchange rates
# Keep all FX observations before forward filling.
# This avoids losing valid FX data on non-AIQ trading days,
# such as 2021-12-24.

fx_aligned <- full_join(aiq_dates, fx, by = "date") |>
  arrange(date) |>
  fill(usd_cad, .direction = "down") |>
  semi_join(aiq_dates, by = "date")

# 4. Validate FX alignment
stopifnot(
  nrow(fx_aligned) == nrow(aiq_dates),
  !anyNA(fx_aligned$usd_cad),
  !anyDuplicated(fx_aligned$date)
)

# Verify the known calendar-alignment issue
stopifnot(
  fx_aligned$usd_cad[
    fx_aligned$date == as.Date("2021-12-27")
  ] == 1.2813,
  fx_aligned$usd_cad[
    fx_aligned$date == as.Date("2021-12-28")
  ] == 1.2813
)

# 5. Convert AIQ adjusted prices to CAD
aiq_cad <- etf |>
  filter(symbol == "AIQ") |>
  select(date, adjusted) |>
  rename(price_usd = adjusted) |>
  left_join(fx_aligned, by = "date") |>
  mutate(price_cad = price_usd * usd_cad)

# 6. Prepare XRE CAD prices
xre_cad <- etf |>
  filter(symbol == "XRE.TO") |>
  select(date, adjusted) |>
  rename(xre_cad = adjusted)

# 7. Align both ETFs on common trading dates
prices_cad <- aiq_cad |>
  select(date, price_cad) |>
  rename(aiq_cad = price_cad) |>
  inner_join(xre_cad, by = "date") |>
  arrange(date)

# 8. Calculate returns on common intervals
returns_cad <- prices_cad |>
  mutate(
    aiq_return = aiq_cad / lag(aiq_cad) - 1,
    xre_return = xre_cad / lag(xre_cad) - 1,
    days_between = as.integer(date - lag(date))
  ) |>
  filter(!is.na(aiq_return))

# 9. Validate outputs
stopifnot(
  nrow(prices_cad) == 1599,
  nrow(returns_cad) == 1598,
  !anyNA(prices_cad),
  !anyNA(returns_cad),
  !anyDuplicated(prices_cad$date),
  !anyDuplicated(returns_cad$date),
  all(prices_cad$aiq_cad > 0),
  all(prices_cad$xre_cad > 0)
)

# 10. Save clean datasets
write.csv(fx_aligned, "data/clean/fx_aligned_aiq.csv",
          row.names = FALSE)

write.csv(aiq_cad, "data/clean/aiq_prices_cad.csv",
          row.names = FALSE)

write.csv(prices_cad, "data/clean/etf_prices_cad.csv",
          row.names = FALSE)

write.csv(returns_cad, "data/clean/etf_returns_cad.csv",
          row.names = FALSE)

cat("Stage 2 CAD data preparation completed.\n")
cat("Common price dates:", nrow(prices_cad), "\n")
cat("Return intervals:", nrow(returns_cad), "\n")
