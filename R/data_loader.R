# Polish -> English column name mapping for raw Stooq exports
.STOOQ_COL_MAP <- c(
  "Data"       = "Date",
  "Otwarcie"   = "Open",
  "Najwyzszy"  = "High",
  "Najnizszy"  = "Low",
  "Zamkniecie" = "Close",
  "Wolumen"    = "Volume"
)

#' Load Market Data from a CSV File (Stooq Format)
#'
#' Reads a CSV in Stooq format, auto-detects Polish column headers and maps
#' them to English, coerces types, and validates data integrity with defensive
#' programming checks throughout.
#'
#' @param path Character. Path to a local CSV file.
#' @return A \code{data.frame} with columns \code{Date}, \code{Open},
#'   \code{High}, \code{Low}, \code{Close}, \code{Volume}, sorted ascending
#'   by date.
#' @export
load_market_data <- function(path) {
  if (!is.character(path) || length(path) != 1L) {
    stop("'path' must be a single character string.")
  }
  if (!file.exists(path)) {
    stop("File not found: ", path)
  }

  data <- utils::read.csv(path, stringsAsFactors = FALSE)

  # Normalize column names and auto-map Polish headers
  names(data) <- trimws(names(data))
  polish_hits <- names(data) %in% names(.STOOQ_COL_MAP)
  if (any(polish_hits)) {
    names(data)[polish_hits] <- .STOOQ_COL_MAP[names(data)[polish_hits]]
    message("Mapped ", sum(polish_hits), " Polish column name(s) to English.")
  }

  req_cols <- c("Date", "Open", "High", "Low", "Close", "Volume")
  missing_cols <- setdiff(req_cols, names(data))
  if (length(missing_cols) > 0) {
    stop("Missing required columns: ", paste(missing_cols, collapse = ", "))
  }

  data$Date <- as.Date(data$Date)
  if (anyNA(data$Date)) {
    stop("Date column contains values that could not be parsed as dates.")
  }

  num_cols <- c("Open", "High", "Low", "Close", "Volume")
  for (col in num_cols) {
    data[[col]] <- suppressWarnings(as.numeric(data[[col]]))
  }

  if (anyNA(data[, num_cols])) {
    warning("Dataset contains NA values in numeric columns after conversion. ",
            "These rows may affect simulation accuracy.")
  }

  # Enforce ascending chronological order
  data <- data[order(data$Date), ]

  # Sanity check: High must be >= Low
  invalid_hl <- !is.na(data$High) & !is.na(data$Low) & (data$High < data$Low)
  if (any(invalid_hl)) {
    warning(sum(invalid_hl), " row(s) have High < Low and may be corrupted.")
  }

  data
}
