#' Load Market Data from CSV
#'
#' @param path Path to the CSV file (Stooq format)
#' @return A data.frame with cleaned market data
#' @export
load_market_data <- function(path) {
  if (!file.exists(path)) {
    stop("File not found: ", path)
  }
  
  # Read CSV
  data <- utils::read.csv(path, stringsAsFactors = FALSE)
  
  # Required columns
  req_cols <- c("Date", "Open", "High", "Low", "Close", "Volume")
  if (!all(req_cols %in% colnames(data))) {
    stop("Missing required columns: ", paste(setdiff(req_cols, colnames(data)), collapse = ", "))
  }
  
  # Convert Date
  data$Date <- as.Date(data$Date)
  
  # Ensure numeric columns
  num_cols <- c("Open", "High", "Low", "Close", "Volume")
  for (col in num_cols) {
    data[[col]] <- as.numeric(data[[col]])
  }
  
  # Check for NAs after conversion
  if (any(is.na(data))) {
    warning("Dataset contains NA values after conversion. These may cause issues in simulation.")
  }
  
  # Sort by Date
  data <- data[order(data$Date), ]
  
  # Check for date continuity (gaps > 7 days might indicate missing data, though weekends/holidays are expected)
  # For now, we just ensure it's sorted.
  
  return(data)
}
