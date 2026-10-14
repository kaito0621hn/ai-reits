# Stage 1–2B R Code Reference — 去重复代码与中文解析

**定位：** 这是学习手册，按实际研究任务归类，每种核心操作重点解释一次；不是把所有 Console 输入逐行重复。完整 Stage 2B 整理脚本见 `02_STAGE2B_REPRODUCIBLE.R`。

**运行前提：** 在 RStudio 打开项目根目录；安装 `dplyr`, `tidyr`, `readr`, `tidyquant`, `jsonlite`；先完成 Stage 2A，确保 `data/clean/fx_aligned_aiq.csv`、`etf_prices_cad.csv`、`etf_returns_cad.csv` 存在。脚本会重新下载当前在线数据，**不是对原历史下载快照的完全相同字节复现**。如网络、API 或数据修订导致行数变化，应先审计，不要为了凑历史行数直接删数据。

## 1. 初始化：载入包与固定日期

```r
library(dplyr)
library(tidyr)
library(readr)
library(tidyquant)
library(jsonlite)

start_date <- as.Date("2020-01-02")
end_date <- as.Date("2026-07-02")
```

**解释：** `library()` 只需要在每个新 R session 载入一次；`as.Date()` 保证日期是可比较的 Date 类型。`<-` 为对象赋值。研究日期必须固定，Yahoo 下载的 `to` 是排他的，因此下载截止日要用 `2026-07-03`。

## 2. 查找数据：从 BoC 官方目录搜索序列

```r
url <- "https://www.bankofcanada.ca/valet/lists/series/json"
series_info <- fromJSON(url, flatten = TRUE)$series

matches <- vapply(
  series_info,
  function(x) any(grepl("Treasury bills, 3-month", unlist(x), ignore.case = TRUE)),
  logical(1)
)

names(series_info)[matches]
```

**解释：** `fromJSON()` 读取 API JSON；`$series` 取官方目录；`unlist()` 将条目内容展开；`grepl()` 按关键词寻找；`any()` 判断是否存在匹配；`vapply()` 对目录的每个条目执行同样的检查，且规定输出为逻辑值。历史 `V39065` 在 Valet observations API 曾返回 404，必须使用官方目录确认的 `TB.CDN.90D.MID`。加拿大十年期序列为 `BD.CDN.10YR.DQ.YLD`。

## 3. 下载 BoC 数据：写一个函数，避免重复四遍

```r
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
```

**解释：** `function()` 封装重复下载过程；`paste0()` 组合 URL；`vapply()` 提取日期和数值；`is.null()` 处理 API 中缺少某一序列值的日期；`as.numeric()` 将文本数值转换成数字；`rename(!!name := value)` 用传入的名称命名列。**重要：** BoC 的 `2.26` 表示 `2.26%`，不是 `2.26` 的小数收益率。函数依赖第 1 节的日期对象。

## 4. 合并不同宏观经济日历

```r
can_rates <- policy |>
  full_join(corra, by = "date") |>
  arrange(date) |>
  fill(policy_rate, .direction = "down") |>
  left_join(tbill, by = "date") |>
  left_join(can10, by = "date")
```

**解释：** `full_join()` 保留双方所有日期；`left_join()` 保留左表日期；`arrange()` 排序；`fill(..., "down")` 用前一次已知政策利率补上后来日期。**不能**不加区分地 forward-fill CORRA、国债收益率和美债收益率：它们在非交易日未必有新报价。`|>` 把左边结果交给右边函数，避免反复写中间对象。

## 5. FRED 下载和固定样本过滤

```r
us10 <- read_csv(
  "https://fred.stlouisfed.org/graph/fredgraph.csv?id=DGS10",
  show_col_types = FALSE,
  na = c("", "NA", ".")
) |>
  transmute(date = as.Date(observation_date), us_bond_10y = as.numeric(DGS10)) |>
  filter(date >= start_date, date <= end_date)

rates_all <- can_rates |>
  full_join(us10, by = "date") |>
  arrange(date)
```

**解释：** FRED 默认 CSV 包含很长的历史区间，必须使用 `filter()` 限定固定研究时间。`transmute()` 只保留并创建指定列。`na` 将缺失标记识别为 `NA`。美加市场假期不同，合并后的 NA 不代表程序必然出错。

## 6. 下载市场基准

```r
benchmarks <- tq_get(
  c("VT", "XIC.TO"),
  from = "2020-01-02",
  to = "2026-07-03"
)

benchmarks |>
  group_by(symbol) |>
  summarise(rows = n(), missing_adjusted = sum(is.na(adjusted)))
```

**解释：** `tq_get()` 获取 Yahoo ETF 历史价格；`c()` 组合多个代码；`group_by()` 按 ETF 分组；`summarise()` 汇总；`n()` 计算行数；`is.na()` 检查缺失。`adjusted` 是我们后续计算收益的价格基础。若 `tq_get()` 返回 NULL，不要继续下游计算；记录报错、网络/API 状态、重试和验证。

## 7. 读回 CSV，避免依赖 Environment

```r
fx <- read_csv("data/clean/fx_aligned_aiq.csv", show_col_types = FALSE)
base_prices <- read_csv("data/clean/etf_prices_cad.csv", show_col_types = FALSE)
```

**解释：** R 对象只存在于当前会话中；保存的 CSV 仍在硬盘。我们曾遇到 `object 'fx_aligned_aiq' not found`，解决办法是从文件重新读取，而不是重新下载汇率。运行前检查 RStudio 项目工作目录是否正确。

## 8. 验证两个交易日历是否完全一致

```r
vt_dates <- benchmarks |>
  filter(symbol == "VT") |>
  select(date)

nrow(anti_join(vt_dates, fx, by = "date"))
nrow(anti_join(fx, vt_dates, by = "date"))
nrow(inner_join(vt_dates, fx, by = "date"))
```

**解释：** `anti_join()` 找左表独有日期，两个方向都查才是完整的日历相等检查；`inner_join()` 保留共同日期；`nrow()` 计算行数。实际检查为 `0, 0, 1633`，所以 VT 可以复用 Stage 2A 对齐后的汇率。

## 9. 价格换汇与收益率恒等式

```r
vt <- benchmarks |>
  filter(symbol == "VT") |>
  select(date, adjusted) |>
  left_join(fx, by = "date") |>
  arrange(date) |>
  mutate(
    adjusted_cad = adjusted * usd_cad,
    return_usd = adjusted / lag(adjusted) - 1,
    return_fx = usd_cad / lag(usd_cad) - 1,
    return_cad = adjusted_cad / lag(adjusted_cad) - 1
  )

vt |>
  filter(!is.na(return_cad)) |>
  summarise(error = max(abs(return_cad - ((1 + return_usd) * (1 + return_fx) - 1))))
```

**解释：** `mutate()` 创建变量；`lag()` 取上一交易日值；`max(abs(...))` 检查最大绝对误差。公式是 `1 + R_CAD = (1 + R_USD)(1 + R_FX)`，不是把 USD 与 FX 收益简单相加。历史最大误差约 `4.44e-16`，属于浮点数舍入级别。这里检查的是**内部公式一致性**，不是独立数据源核验。

## 10. XIC 收益率及极端值

```r
xic <- benchmarks |>
  filter(symbol == "XIC.TO") |>
  select(date, adjusted) |>
  arrange(date) |>
  mutate(return_cad = adjusted / lag(adjusted) - 1)

xic |>
  filter(!is.na(return_cad)) |>
  summarise(
    mean_return = mean(return_cad),
    sd_return = sd(return_cad),
    min_return = min(return_cad),
    max_return = max(return_cad)
  )
```

**解释：** `mean()` 求平均；`sd()` 是样本标准差，金融中常用于衡量日收益波动；`min()`、`max()` 检查极端收益。第一天 `lag()` 不存在，产生一个预期的 NA。极端值不能只因幅度大就删除。

## 11. 四 ETF：先对齐价格，再计算共同区间收益

```r
four_prices <- base_prices |>
  left_join(vt |> select(date, vt_cad = adjusted_cad), by = "date") |>
  left_join(xic |> select(date, xic_cad = adjusted), by = "date") |>
  arrange(date)

four_returns <- four_prices |>
  mutate(
    aiq_return = aiq_cad / lag(aiq_cad) - 1,
    xre_return = xre_cad / lag(xre_cad) - 1,
    vt_return = vt_cad / lag(vt_cad) - 1,
    xic_return = xic_cad / lag(xic_cad) - 1,
    days_between = as.numeric(date - lag(date))
  ) |>
  filter(!is.na(aiq_return))
```

**解释：** 美国与加拿大节假日不同，**不能**把两国分别计算的收益率直接按日期合并后就认为持有区间相同。先对齐价格，随后统一用相邻共同日期的价格计算收益。`days_between` 记录日历间隔（历史值为 1–6 天），将用于后续风险无关收益率换算和年化方法讨论。

## 12. 内部回归测试：新旧 AIQ/XRE 是否一致

```r
old <- read_csv("data/clean/etf_returns_cad.csv", show_col_types = FALSE) |>
  select(date, aiq_old = aiq_return, xre_old = xre_return)

check <- four_returns |>
  inner_join(old, by = "date") |>
  mutate(
    aiq_error = abs(aiq_return - aiq_old),
    xre_error = abs(xre_return - xre_old)
  )

stopifnot(nrow(check) == nrow(four_returns))
stopifnot(max(check$aiq_error) < 1e-10)
stopifnot(max(check$xre_error) < 1e-10)
```

**解释：** `stopifnot()` 在条件不成立时停止程序，防止错误结果继续传播。历史测试中两只 ETF 的最大差异均远小于 `1e-10`。这里的 regression testing 指**软件修改后的结果一致性检查**，不是统计回归。

## 13. 保存与验证

```r
write_csv(four_prices, "data/clean/four_etf_prices_cad.csv")
write_csv(four_returns, "data/clean/four_etf_returns_cad.csv")

file.exists("data/clean/four_etf_prices_cad.csv")
file.exists("data/clean/four_etf_returns_cad.csv")
anyDuplicated(four_prices$date)
colSums(is.na(four_returns))
```

**解释：** `write_csv()` 保存输出；`file.exists()` 确认文件存在；`anyDuplicated()` 检查重复日期（无重复返回 0）；`colSums(is.na(...))` 统计每列缺失。**文件存在并不代表源数据正确**，仍需清洁会话重跑和外部数据核验。

## 14. 代码习惯与常见坑

- `read_csv()` 读入 CSV 后最好确认日期列为 Date；若不是，显式 `mutate(date = as.Date(date))`。
- `left_join()` 前确认连接键唯一，否则可能发生 many-to-many 行数膨胀。
- `full_join()` 后要 `arrange(date)`，再做前向填充。
- 先检查交易日历，再决定能否复用对齐后的汇率。
- 不要把百分数形式的收益率 `2.26` 当作小数 `0.0226`。
- 不要把年化 3m T-bill yield 直接从日收益率中减去。
- `to` 日期的排他性需要单独检查。
- `tq_get()` 或网络 API 可能因在线数据修订而改变历史价格；记录下载日期和包版本。
- R Session 里的对象不是硬盘文件；清空 Environment 后需要 `read_csv()` 或运行脚本重建。
- 所有结果应附带样本行数、缺失、重复、起止日期、数学恒等式和新旧数据比较。

## 15. 还没有写进正式分析的代码

**目前不要把下面事项当作已经完成：** T-bill yield → holding-period risk-free return；CAPM；Sharpe/Sortino/Treynor；rolling beta；weekly interest-rate regressions；HAC/Newey–West；事件研究；外部 adjusted-price 对账；完整 Git Stage 2B checkpoint。这些属于后续阶段或审计任务。
