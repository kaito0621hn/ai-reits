# ETF Data Validation
# Research period: 2020-01-02 to 2026-07-02

library(dplyr)

# Load raw data
prices <- read.csv("data/raw/etf_prices.csv") |>
  mutate(date = as.Date(date))

# Data quality checks
quality_summary <- prices |>
  group_by(symbol) |>
  summarise(
    rows = n(),
    first_date = min(date),
    last_date = max(date),
    missing_adjusted = sum(is.na(adjusted)),
    missing_close = sum(is.na(close)),
    missing_volume = sum(is.na(volume)),
    duplicate_dates = sum(duplicated(date)),
    nonpositive_adjusted = sum(adjusted <= 0)
  )

# Return summary
return_summary <- prices |>
  arrange(symbol, date) |>
  group_by(symbol) |>
  summarise(
    price_return = round(
      (last(close) / first(close) - 1) * 100, 2
    ),
    adjusted_return = round(
      (last(adjusted) / first(adjusted) - 1) * 100, 2
    )
  )

# Different trading calendars
aiq <- filter(prices, symbol == "AIQ")
xre <- filter(prices, symbol == "XRE.TO")

only_aiq <- anti_join(aiq, xre, by = "date")
only_xre <- anti_join(xre, aiq, by = "date")

# Extreme daily returns
outliers <- prices |>
  arrange(symbol, date) |>
  group_by(symbol) |>
  mutate(daily_return = adjusted / lag(adjusted) - 1) |>
  filter(abs(daily_return) > 0.10)

# Save validation results
dir.create("output/tables", recursive = TRUE, showWarnings = FALSE)

write.csv(quality_summary,
          "output/tables/etf_data_quality.csv",
          row.names = FALSE)

write.csv(return_summary,
          "output/tables/etf_return_summary.csv",
          row.names = FALSE)

write.csv(outliers,
          "output/tables/etf_extreme_returns.csv",
          row.names = FALSE)

write.csv(only_aiq,
          "output/tables/aiq_only_dates.csv",
          row.names = FALSE)

write.csv(only_xre,
          "output/tables/xre_only_dates.csv",
          row.names = FALSE)

print(quality_summary)
print(return_summary)