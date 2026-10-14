library(dplyr)
library(tidyr)
library(readr)
library(tidyquant)
library(jsonlite)

start_date <- as.Date("2020-01-02")
end_date <- as.Date("2026-07-02")

dir.create("data/raw", recursive = TRUE, showWarnings = FALSE)
dir.create("data/clean", recursive = TRUE, showWarnings = FALSE)

get_boc <- function(id, name) {
  url <- paste0(
    "https://www.bankofcanada.ca/valet/observations/", id,
    "/json?start_date=", start_date,
    "&end_date=", end_date
  )
  observations <- fromJSON(url, simplifyVector = FALSE)$observations
  tibble(
    date = as.Date(vapply(observations, function(x) x$d, character(1))),
    value = vapply(observations, function(x) {
      item <- x[[id]]
      if (is.null(item) || is.null(item$v)) NA_real_ else as.numeric(item$v)
    }, numeric(1))
  ) |>
    rename(!!name := value)
}

policy <- get_boc("V39079", "policy_rate")
corra <- get_boc("AVG.INTWO", "corra_rate")
tbill <- get_boc("TB.CDN.90D.MID", "tbill_3m")
can10 <- get_boc("BD.CDN.10YR.DQ.YLD", "bond_10y")

stopifnot(nrow(policy) > 0, nrow(corra) > 0, nrow(tbill) > 0, nrow(can10) > 0)
stopifnot(all(vapply(list(policy, corra, tbill, can10), function(x) anyDuplicated(x$date) == 0, logical(1))))

write_csv(policy, "data/raw/policy_rate_stage2b.csv")
write_csv(corra, "data/raw/corra_rate_stage2b.csv")
write_csv(tbill, "data/raw/tbill_3m_stage2b.csv")
write_csv(can10, "data/raw/bond_10y_stage2b.csv")

can_rates <- policy |>
  full_join(corra, by = "date") |>
  arrange(date) |>
  fill(policy_rate, .direction = "down") |>
  left_join(tbill, by = "date") |>
  left_join(can10, by = "date")

us10 <- read_csv(
  "https://fred.stlouisfed.org/graph/fredgraph.csv?id=DGS10",
  show_col_types = FALSE,
  na = c("", "NA", ".")
) |>
  transmute(date = as.Date(observation_date), us_bond_10y = as.numeric(DGS10)) |>
  filter(date >= start_date, date <= end_date)

write_csv(us10, "data/raw/fred_dgs10_stage2b.csv")

rates_all <- can_rates |>
  full_join(us10, by = "date") |>
  arrange(date)

stopifnot(anyDuplicated(rates_all$date) == 0)
write_csv(can_rates, "data/clean/interest_rates_canada_stage2b.csv")
write_csv(rates_all, "data/clean/interest_rates_all_stage2b.csv")

benchmarks <- tq_get(
  c("VT", "XIC.TO"),
  from = as.character(start_date),
  to = "2026-07-03"
)

stopifnot(all(c("VT", "XIC.TO") %in% unique(benchmarks$symbol)))
stopifnot(!anyNA(benchmarks$adjusted))
stopifnot(anyDuplicated(benchmarks[c("symbol", "date")]) == 0)
write_csv(benchmarks, "data/raw/benchmark_prices_stage2b.csv")

fx <- read_csv("data/clean/fx_aligned_aiq.csv", show_col_types = FALSE) |>
  mutate(date = as.Date(date))

vt_prices <- benchmarks |>
  filter(symbol == "VT") |>
  select(date, adjusted) |>
  left_join(fx, by = "date") |>
  arrange(date) |>
  mutate(adjusted_cad = adjusted * usd_cad)

stopifnot(nrow(vt_prices) == nrow(fx))
stopifnot(nrow(anti_join(vt_prices, fx, by = "date")) == 0)
stopifnot(nrow(anti_join(fx, vt_prices, by = "date")) == 0)
stopifnot(!anyNA(vt_prices$adjusted_cad))

vt_returns <- vt_prices |>
  mutate(
    return_usd = adjusted / lag(adjusted) - 1,
    return_fx = usd_cad / lag(usd_cad) - 1,
    return_cad = adjusted_cad / lag(adjusted_cad) - 1
  )

vt_error <- vt_returns |>
  filter(!is.na(return_cad)) |>
  summarise(max_error = max(abs(return_cad - ((1 + return_usd) * (1 + return_fx) - 1)))) |>
  pull(max_error)

stopifnot(vt_error < 1e-10)
write_csv(vt_prices, "data/clean/vt_prices_cad.csv")
write_csv(vt_returns, "data/clean/vt_returns_cad.csv")

xic_returns <- benchmarks |>
  filter(symbol == "XIC.TO") |>
  select(date, adjusted) |>
  arrange(date) |>
  mutate(return_cad = adjusted / lag(adjusted) - 1)

write_csv(xic_returns, "data/clean/xic_returns_cad.csv")

base_prices <- read_csv("data/clean/etf_prices_cad.csv", show_col_types = FALSE) |>
  mutate(date = as.Date(date))

four_prices <- base_prices |>
  left_join(vt_prices |> select(date, vt_cad = adjusted_cad), by = "date") |>
  left_join(xic_returns |> select(date, xic_cad = adjusted), by = "date") |>
  arrange(date)

stopifnot(anyDuplicated(four_prices$date) == 0)
stopifnot(!anyNA(four_prices))

four_returns <- four_prices |>
  mutate(
    aiq_return = aiq_cad / lag(aiq_cad) - 1,
    xre_return = xre_cad / lag(xre_cad) - 1,
    vt_return = vt_cad / lag(vt_cad) - 1,
    xic_return = xic_cad / lag(xic_cad) - 1,
    days_between = as.numeric(date - lag(date))
  ) |>
  filter(!is.na(aiq_return))

old_returns <- read_csv("data/clean/etf_returns_cad.csv", show_col_types = FALSE) |>
  select(date, aiq_old = aiq_return, xre_old = xre_return)

check <- four_returns |>
  inner_join(old_returns, by = "date") |>
  mutate(
    aiq_error = abs(aiq_return - aiq_old),
    xre_error = abs(xre_return - xre_old)
  )

stopifnot(nrow(check) == nrow(four_returns))
stopifnot(max(check$aiq_error) < 1e-10, max(check$xre_error) < 1e-10)
stopifnot(!anyNA(four_returns))

write_csv(four_prices, "data/clean/four_etf_prices_cad.csv")
write_csv(four_returns, "data/clean/four_etf_returns_cad.csv")

print(list(
  macro_rows = nrow(rates_all),
  macro_missing = colSums(is.na(rates_all)),
  vt_rows = nrow(vt_prices),
  vt_identity_error = vt_error,
  four_price_rows = nrow(four_prices),
  four_return_rows = nrow(four_returns),
  interval_counts = table(four_returns$days_between),
  stage2a_aiq_error = max(check$aiq_error),
  stage2a_xre_error = max(check$xre_error)
))
