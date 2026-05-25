#' Strategy Base R6 Class
#'
#' @description
#' Abstract base class for all trading strategies. Subclasses must implement
#' \code{generate_signals()}, which returns an integer vector aligned with the
#' input data rows (1 = buy, 0 = hold).
#'
#' @importFrom R6 R6Class
#' @export
Strategy <- R6::R6Class(
  "Strategy",
  public = list(
    #' @description Generate trading signals from market data.
    #' @param data A data.frame with at least a \code{Close} column (and
    #'   \code{Date} for date-aware strategies).
    #' @return An integer vector of length \code{nrow(data)}: 1 = buy, 0 = hold.
    generate_signals = function(data) {
      stop("Method 'generate_signals' must be implemented by the subclass.")
    }
  )
)

# ── StrategyATH ───────────────────────────────────────────────────────────────

#' All-Time High (ATH / FOMO) Strategy
#'
#' @description
#' Generates a buy signal on days where the closing price equals or exceeds the
#' rolling maximum of the previous \code{n} trading days.  Simulates the "FOMO
#' investor" who chases breakouts.  Signal generation is fully vectorized using
#' \code{embed()} — no explicit loops.
#'
#' @export
StrategyATH <- R6::R6Class(
  "StrategyATH",
  inherit = Strategy,
  public = list(
    #' @field n Rolling lookback window in trading days.
    n = NULL,

    #' @description Initialize ATH Strategy.
    #' @param n Positive integer lookback window (default 252 = ~1 trading year).
    initialize = function(n = 252L) {
      if (!is.numeric(n) || length(n) != 1L || n <= 0 || n != round(n))
        stop("'n' must be a single positive integer.")
      self$n <- as.integer(n)
    },

    #' @description Generate vectorized ATH signals.
    #' @param data data.frame with a \code{Close} column.
    generate_signals = function(data) {
      if (!is.data.frame(data) || !"Close" %in% names(data))
        stop("'data' must be a data.frame with a 'Close' column.")

      close <- data$Close
      n_obs <- length(close)
      signals <- integer(n_obs)
      if (n_obs <= self$n) return(signals)

      # embed() creates a matrix: row r => [close[r+n], close[r+n-1], ..., close[r]]
      # Column 1 = today; columns 2:(n+1) = the lookback window.
      # pmax across the window columns finds the rolling maximum — no for-loop.
      mat         <- embed(close, self$n + 1L)
      lookback_max <- do.call(pmax, as.data.frame(mat[, -1L, drop = FALSE]))
      signals[(self$n + 1L):n_obs] <- as.integer(mat[, 1L] >= lookback_max)
      signals
    }
  )
)

# ── StrategyDCA ───────────────────────────────────────────────────────────────

#' Dollar-Cost Averaging (DCA) Strategy
#'
#' @description
#' Generates a buy signal every \code{n} trading days regardless of price.
#' The C++ engine will invest a fixed \code{invest_amount} on each signal,
#' accumulating shares over time.  Represents systematic, emotion-free
#' investing and serves as a natural benchmark against timing strategies.
#'
#' @export
StrategyDCA <- R6::R6Class(
  "StrategyDCA",
  inherit = Strategy,
  public = list(
    #' @field n Investment interval in trading days.
    n = NULL,

    #' @description Initialize DCA Strategy.
    #' @param n Positive integer: days between purchases (default 21 ~ 1 month).
    initialize = function(n = 21L) {
      if (!is.numeric(n) || length(n) != 1L || n <= 0 || n != round(n))
        stop("'n' must be a single positive integer.")
      self$n <- as.integer(n)
    },

    #' @description Generate periodic buy signals (every n-th trading day).
    #' @param data data.frame (only \code{nrow} is used).
    generate_signals = function(data) {
      n_obs <- nrow(data)
      signals <- integer(n_obs)
      # Fire on days 1, 1+n, 1+2n, ... (first day included so DCA starts immediately)
      signals[seq(1L, n_obs, by = self$n)] <- 1L
      signals
    }
  )
)

# ── StrategyDip ───────────────────────────────────────────────────────────────

#' Buy-the-Dip Strategy
#'
#' @description
#' Generates a buy signal when today's close has fallen at least \code{dip_pct}
#' below the \emph{running all-time high} (up to and including today).  Uses
#' \code{cummax()} — fully vectorized, no explicit loops, no warm-up period.
#'
#' Using the running all-time high (rather than a rolling window) gives the
#' strategy a natural economic interpretation: "buy whenever the market is at
#' least X\% cheaper than it has ever been."
#'
#' @export
StrategyDip <- R6::R6Class(
  "StrategyDip",
  inherit = Strategy,
  public = list(
    #' @field dip_pct Required drop from all-time high to trigger a buy (0–1).
    dip_pct = NULL,

    #' @description Initialize Buy-the-Dip Strategy.
    #' @param dip_pct Numeric in (0, 1): minimum drop fraction (default 0.05 = 5%).
    initialize = function(dip_pct = 0.05) {
      if (!is.numeric(dip_pct) || length(dip_pct) != 1L ||
          dip_pct <= 0 || dip_pct >= 1)
        stop("'dip_pct' must be a single value in (0, 1).")
      self$dip_pct <- dip_pct
    },

    #' @description Generate vectorized dip signals using the running all-time high.
    #' @param data data.frame with a \code{Close} column.
    generate_signals = function(data) {
      if (!is.data.frame(data) || !"Close" %in% names(data))
        stop("'data' must be a data.frame with a 'Close' column.")

      close <- data$Close
      n_obs <- length(close)
      if (n_obs < 2L) return(integer(n_obs))

      # cummax() gives the running all-time high up to each day (vectorized, no loops).
      running_max <- cummax(close)
      below       <- close <= running_max * (1.0 - self$dip_pct)

      # Edge detection: fire ONLY on the first day of entering the dip zone.
      # Without this, every consecutive day below the threshold would generate
      # a signal — turning a multi-month drawdown into hundreds of buys.
      # We want to buy ONCE per dip entry, not every day while in a dip.
      entered <- below & !c(FALSE, below[-n_obs])
      as.integer(entered)
    }
  )
)

