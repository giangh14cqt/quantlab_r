#' Strategy Base Class
#' @importFrom R6 R6Class
#' @export
Strategy <- R6::R6Class(
  "Strategy",
  public = list(
    #' @description Generate trading signals
    #' @param data Market data frame
    #' @return An integer vector of signals (1: Buy, 0: Hold, -1: Sell)
    generate_signals = function(data) {
      stop("Method 'generate_signals' must be implemented by subclass")
    }
  )
)

#' All-Time High Strategy
#' @export
StrategyATH <- R6::R6Class(
  "StrategyATH",
  inherit = Strategy,
  public = list(
    #' @field n Rolling window for ATH calculation
    n = NULL,
    
    #' @description Initialize ATH Strategy
    #' @param n Rolling window size
    initialize = function(n = 252) {
      self$n <- n
    },
    
    #' @description Generate signals
    #' @param data Market data frame
    generate_signals = function(data) {
      # Use rolling max to find ATH
      # buy when current Close is >= max(Close) of last n days
      close <- data$Close
      n_obs <- length(close)
      signals <- rep(0, n_obs)
      
      if (n_obs < self$n) return(signals)
      
      for (i in (self$n + 1):n_obs) {
        lookback <- close[(i - self$n):(i - 1)]
        if (close[i] >= max(lookback)) {
          signals[i] <- 1
        }
      }
      return(signals)
    }
  )
)

#' Crash Test Strategy
#' @export
StrategyCrashTest <- R6::R6Class(
  "StrategyCrashTest",
  inherit = Strategy,
  public = list(
    #' @field crash_dates Dates to force market entry
    crash_dates = NULL,
    
    #' @description Initialize Crash Test Strategy
    initialize = function() {
      self$crash_dates <- as.Date(c(
        "1994-03-08", "2000-03-27", "2007-07-06", 
        "2020-02-19", "2022-02-23"
      ))
    },
    
    #' @description Generate signals
    #' @param data Market data frame
    generate_signals = function(data) {
      # Buy on the day before the crash if data matches
      # Or just buy on the closest available date in the dataset
      signals <- rep(0, nrow(data))
      match_indices <- which(data$Date %in% self$crash_dates)
      signals[match_indices] <- 1
      return(signals)
    }
  )
)
