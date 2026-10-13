# Download Bank of Canada data

library(jsonlite)
library(dplyr)

start_date <- "2020-01-02"
end_date <- "2026-07-02"

series <- c("V39079", "AVG.INTWO", "FXUSDCAD")

for (s in series) {
  
  url <- paste0(
    "https://www.bankofcanada.ca/valet/observations/",
    s, "/json?start_date=", start_date,
    "&end_date=", end_date
  )
  
  data <- fromJSON(url, flatten = TRUE)$observations
  
  write.csv(
    data,
    paste0("data/raw/", s, ".csv"),
    row.names = FALSE
  )
  
  print(paste(s, nrow(data), "rows"))
}
