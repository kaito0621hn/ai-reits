# Download ETF historical prices

library(tidyquant)
library(dplyr)

start_date <- as.Date("2020-01-02")
end_date <- as.Date("2026-07-02")

prices <- tq_get(
  c("AIQ", "XRE.TO"),
  get = "stock.prices",
  from = start_date,
  to = end_date + 1
)

if (is.null(prices)) {
  stop("ETF data download failed.")
}

prices <- prices |>
  filter(date >= start_date, date <= end_date)

write.csv(
  prices,
  "data/raw/etf_prices.csv",
  row.names = FALSE
)
