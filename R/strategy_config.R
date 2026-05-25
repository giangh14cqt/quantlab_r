#' StrategyConfig S4 Class
#'
#' @description
#' Formally validated configuration object for backtesting.  S4's built-in
#' validity mechanism enforces parameter constraints before any simulation
#' runs.  Only slots relevant to the chosen \code{strategy_type} are
#' validated — others are ignored.
#'
#' @slot strategy_type Character. One of \code{"ATH"}, \code{"DCA"},
#'   \code{"Dip"}.
#' @slot lookback    Numeric. Rolling window in days (ATH only).
#' @slot stop_loss   Numeric. Stop-loss fraction in \code{[0, 1)};
#'   \code{0} disables stop-loss.  Applied in all-in mode (ATH) only.
#' @slot initial_cash Numeric. Starting capital (non-negative).
#' @slot dca_interval Numeric. Days between DCA purchases (DCA only).
#' @slot invest_amount Numeric. Fixed cash invested per signal (DCA / Dip).
#' @slot dip_pct     Numeric. Required drop from ATH in \code{(0, 1)} (Dip only).
#'
#' @importFrom methods new validObject is setClass setMethod
#' @export
setClass(
  "StrategyConfig",
  representation(
    strategy_type = "character",
    lookback      = "numeric",
    stop_loss     = "numeric",
    initial_cash  = "numeric",
    dca_interval  = "numeric",
    invest_amount = "numeric",
    dip_pct       = "numeric"
  ),
  validity = function(object) {
    errors <- character()

    # ── Universal checks ───────────────────────────────────────────────────
    valid_types <- c("ATH", "DCA", "Dip")
    if (length(object@strategy_type) != 1L ||
        !object@strategy_type %in% valid_types) {
      errors <- c(errors, paste0(
        "strategy_type must be one of: ", paste(valid_types, collapse = ", ")
      ))
    }
    if (length(object@stop_loss) != 1L ||
        object@stop_loss < 0 || object@stop_loss >= 1) {
      errors <- c(errors, "stop_loss must be a single value in [0, 1).")
    }
    if (length(object@initial_cash) != 1L || object@initial_cash < 0) {
      errors <- c(errors, "initial_cash must be a single non-negative number.")
    }

    # ── Strategy-specific checks ───────────────────────────────────────────
    st <- object@strategy_type

    if (st == "ATH") {
      if (length(object@lookback) != 1L || object@lookback <= 0 ||
          object@lookback != round(object@lookback)) {
        errors <- c(errors,
          "lookback must be a single positive integer (required for ATH).")
      }
    }

    if (st == "Dip") {
      if (length(object@dip_pct) != 1L ||
          object@dip_pct <= 0 || object@dip_pct >= 1) {
        errors <- c(errors, "dip_pct must be a single value in (0, 1).")
      }
    }

    if (st == "DCA") {
      if (length(object@dca_interval) != 1L || object@dca_interval <= 0 ||
          object@dca_interval != round(object@dca_interval)) {
        errors <- c(errors, "dca_interval must be a single positive integer.")
      }
      if (length(object@invest_amount) != 1L || object@invest_amount <= 0) {
        errors <- c(errors, "invest_amount must be a single positive number.")
      }
    }

    if (length(errors) > 0L) errors else TRUE
  }
)

#' @rdname StrategyConfig-class
#' @param object A \code{StrategyConfig} S4 object.
setMethod("show", "StrategyConfig", function(object) {
  cat("<StrategyConfig>\n")
  cat(sprintf("  Strategy    : %s\n", object@strategy_type))
  cat(sprintf("  Capital     : %.2f\n", object@initial_cash))
  cat(sprintf("  Stop-Loss   : %s\n",
    if (object@stop_loss == 0) "disabled"
    else sprintf("%.1f%%", object@stop_loss * 100)))

  switch(object@strategy_type,
    ATH = cat(sprintf("  Lookback    : %d days\n", as.integer(object@lookback))),
    Dip = cat(sprintf("  Dip Trigger : %.1f%%\n", object@dip_pct * 100)),
    DCA = {
      cat(sprintf("  Interval    : every %d trading days\n",
                  as.integer(object@dca_interval)))
      cat(sprintf("  Per Purchase: %.2f\n", object@invest_amount))
    }
  )
  invisible(object)
})

#' Create a Validated StrategyConfig Object
#'
#' Convenience constructor wrapping \code{new("StrategyConfig", ...)} and
#' immediately calling \code{validObject()}.  Unused slots receive sensible
#' defaults — only slots relevant to the chosen strategy are validated.
#'
#' @param strategy_type Character. One of \code{"ATH"}, \code{"DCA"},
#'   \code{"Dip"}.
#' @param lookback     Integer. Lookback window in days (ATH only; default 252).
#' @param stop_loss    Numeric. Stop-loss fraction, e.g. \code{0.10} for 10\%;
#'   \code{0} disables it (default).  Active in ATH all-in mode only.
#' @param initial_cash Numeric. Starting capital (default 10 000).
#' @param dca_interval Integer. Days between DCA purchases (default 21).
#' @param invest_amount Numeric. Fixed investment per signal (DCA / Dip;
#'   default 0 = all-in mode).
#' @param dip_pct      Numeric. Drop fraction to trigger Dip buy (default 0.05).
#' @return A validated \code{\linkS4class{StrategyConfig}} object.
#' @export
strategy_config <- function(strategy_type = "DCA",
                            lookback      = 252L,
                            stop_loss     = 0.0,
                            initial_cash  = 10000,
                            dca_interval  = 21L,
                            invest_amount = 0,
                            dip_pct       = 0.05) {
  cfg <- methods::new(
    "StrategyConfig",
    strategy_type = as.character(strategy_type),
    lookback      = as.numeric(lookback),
    stop_loss     = as.numeric(stop_loss),
    initial_cash  = as.numeric(initial_cash),
    dca_interval  = as.numeric(dca_interval),
    invest_amount = as.numeric(invest_amount),
    dip_pct       = as.numeric(dip_pct)
  )
  methods::validObject(cfg)
  cfg
}
