#project setup

start_date <- as.Date("2020-01-02")
end_date <- as.Date("2026-07-02")

aiq <- "AIQ"
xre <- "XRE.TO"

# Load packages

library(tidyverse)
library(tidyquant)
library(lubridate)
library(PerformanceAnalytics)
library(zoo)
library(broom)
library(lmtest)
library(sandwich)
library(httr)
library(jsonlite)