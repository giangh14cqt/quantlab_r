#' Compute Performance Metrics from an Equity Curve
#'
#' Calculates standard backtesting performance metrics.  All computations are
#' fully vectorized — no explicit loops.
#'
#' @section Sharpe ratio and fresh-money strategies:
#' For accumulation strategies (DCA, Dip) each purchase injects new cash into
#' the portfolio.  A naive daily return \eqn{r_t = (E_t - E_{t-1}) / E_{t-1}}
#' includes the injection as if it were a market gain, inflating both the mean
#' and SD and producing a meaningless Sharpe.
#'
#' When \code{cumulative_invested} is supplied, injection-adjusted returns are
#' used instead:
#' \deqn{r_t = \frac{(E_t - E_{t-1}) - \Delta CI_t}{E_{t-1}}}
#' where \eqn{\Delta CI_t} is the fresh cash added on day \eqn{t}.  On
#' non-purchase days \eqn{\Delta CI_t = 0} and the formula reduces to the
#' standard daily return.  The risk-free rate is set to zero so
#' \eqn{Sharpe = \bar{r} / \sigma(r) \times \sqrt{252}}.
#'
#' @section Max Drawdown explained:
#' \strong{Max Drawdown} is the largest peak-to-trough decline of the
#' \emph{entire} equity curve.  It is \emph{not} a per-trade measure.
#'
#' @param equity             Numeric vector of portfolio values (length >= 2).
#' @param cumulative_invested Optional numeric vector (same length as
#'   \code{equity}) of cumulative capital deployed.  When supplied, fresh-money
#'   injections are excluded from the Sharpe return series.
#' @param freq Integer. Trading periods per year (default 252).
#' @importFrom stats sd
#' @return A named list:
#'   \describe{
#'     \item{total_return}{Total fractional return over the period.}
#'     \item{ann_return}{Annualized return (CAGR).}
#'     \item{sharpe}{Annualized Sharpe ratio (rf = 0), injection-adjusted.}
#'     \item{max_drawdown}{Max peak-to-trough decline (negative or zero).}
#'   }
#' @export
compute_metrics <- function(equity, cumulative_invested = NULL, freq = 252L) {
  if (!is.numeric(equity) || length(equity) < 2L)
    stop("'equity' must be a numeric vector of length >= 2.")

  # DCA strategies start with equity = 0 before the first purchase.
  # Skip leading zeros so metrics are computed from the first invested day.
  first <- which(equity > 0)[1L]
  if (is.na(first)) {
    return(list(total_return = 0, ann_return = 0,
                sharpe = 0, max_drawdown = 0))
  }

  eq     <- equity[first:length(equity)]   # trimmed: first purchase onwards
  n      <- length(eq)
  n_full <- length(equity)                 # full period for annualisation

  if (n < 2L) {
    return(list(total_return = 0, ann_return = 0,
                sharpe = 0, max_drawdown = 0))
  }

  # ── Injection-adjusted daily returns ────────────────────────────────────────
  # For DCA/Dip strategies, equity jumps by invest_amount on purchase days.
  # That jump is a capital injection, not a market return — subtracting it gives
  # the true investment return: r_t = (ΔE_t − inject_t) / E_{t-1}.
  # When cumulative_invested is not supplied, inject_t = 0 for all t (standard).
  if (!is.null(cumulative_invested) &&
      length(cumulative_invested) == length(equity)) {
    ci      <- cumulative_invested[first:length(equity)]
    inject  <- c(0, diff(ci))          # daily fresh-money injection (>= 0)
    rets    <- (diff(eq) - inject[-1]) / eq[-n]
  } else {
    rets    <- diff(eq) / eq[-n]       # standard daily returns (no injections)
  }
  rets <- rets[is.finite(rets)]

  total_return <- eq[n] / eq[1L] - 1
  years        <- max(n_full / freq, 1 / freq)
  ann_return   <- (1 + total_return)^(1 / years) - 1

  sd_r   <- if (length(rets) < 2L) 0 else sd(rets)
  sharpe <- if (sd_r == 0) 0 else mean(rets) / sd_r * sqrt(freq)

  # Max drawdown: largest peak-to-trough decline (vectorized via cummax)
  peak         <- cummax(eq)
  drawdowns    <- (eq - peak) / peak
  max_drawdown <- min(drawdowns)

  list(
    total_return = total_return,
    ann_return   = ann_return,
    sharpe       = sharpe,
    max_drawdown = max_drawdown
  )
}

# ── Trade statistics helper ───────────────────────────────────────────────────

#' Count Buy Events and Completed Round-Trip Trades
#'
#' @param positions Numeric vector of daily share counts from the simulation.
#' @return Named integer list: \code{n_buys}, \code{n_sells}.
#' @keywords internal
.count_trades <- function(positions) {
  n       <- length(positions)
  pos_lag <- c(0, positions[-n])
  n_buys  <- sum(positions > pos_lag)   # any day share count increases = a buy
  n_sells <- sum(positions < pos_lag & positions == 0)  # full exits only
  list(n_buys = as.integer(n_buys), n_sells = as.integer(n_sells))
}

# ── BacktestResult S3 class ───────────────────────────────────────────────────

#' Create a BacktestResult Object (S3)
#'
#' Internal constructor called by \code{\link{run_backtest}}.  The object
#' carries \code{print}, \code{summary}, and \code{plot} methods.
#'
#' @param equity              Numeric vector — portfolio value over time.
#' @param cash                Numeric vector — cash balance over time.
#' @param positions           Numeric vector — share count over time.
#' @param cumulative_invested Numeric vector — cumulative capital deployed.
#' @param signals             Integer vector — raw strategy signals.
#' @param dates               Date vector aligned with the simulation period.
#' @param config              A \code{StrategyConfig} S4 object.
#' @return An S3 object of class \code{"BacktestResult"}.
#' @keywords internal
new_backtest_result <- function(equity, cash, positions, cumulative_invested,
                                signals, dates, config) {
  tc            <- .count_trades(positions)
  total_inv     <- cumulative_invested[length(cumulative_invested)]
  final_equity  <- equity[length(equity)]
  personal_ret  <- if (total_inv > 0) (final_equity - total_inv) / total_inv
                   else NA_real_

  # Annualised return: (1 + personal_return)^(1/years) - 1.
  # Uses total_invested as the capital base — correct for both DCA and lump-sum.
  # compute_metrics()$ann_return is NOT used here because it divides final equity
  # by eq[1] (first-day portfolio value), which is just the first tranche for DCA
  # and therefore massively overstates the return.
  years        <- max(length(equity) / 252, 1 / 252)
  ann_pers_ret <- if (!is.na(personal_ret))
                    (1 + personal_ret)^(1 / years) - 1
                  else NA_real_

  structure(
    list(
      equity               = equity,
      cash                 = cash,
      positions            = positions,
      cumulative_invested  = cumulative_invested,
      signals              = signals,
      dates                = dates,
      config               = config,
      metrics              = compute_metrics(equity, cumulative_invested),
      personal_return      = personal_ret,
      ann_return           = ann_pers_ret,
      total_invested       = total_inv,
      n_buys               = tc$n_buys,
      n_sells              = tc$n_sells
    ),
    class = "BacktestResult"
  )
}

#' Print a BacktestResult
#' @param x A \code{BacktestResult} object.
#' @param ... Ignored.
#' @export
print.BacktestResult <- function(x, ...) {
  cat("=== QuantLab Backtest Result ===\n")
  cat(sprintf("Strategy      : %s\n", x$config@strategy_type))
  cat(sprintf("Period        : %s to %s (%d days)\n",
      x$dates[1L], x$dates[length(x$dates)], length(x$dates)))
  cat(sprintf("Total Return  : %+.2f%%\n", x$metrics$total_return * 100))
  cat(sprintf("Sharpe Ratio  : %.4f\n",    x$metrics$sharpe))
  cat(sprintf("Max Drawdown  : %.2f%%\n",  x$metrics$max_drawdown * 100))
  cat(sprintf("Buy signals   : %d | Completed exits: %d\n",
      x$n_buys, x$n_sells))
  invisible(x)
}

#' Summarise a BacktestResult
#' @param object A \code{BacktestResult} object.
#' @param ... Ignored.
#' @export
summary.BacktestResult <- function(object, ...) {
  m <- object$metrics
  n <- length(object$equity)
  cat("=== Backtest Summary ===\n")
  cat(sprintf("Initial Capital   : %.2f\n",  object$equity[1L]))
  cat(sprintf("Final Capital     : %.2f\n",  object$equity[n]))
  cat(sprintf("Total Return      : %+.2f%%\n", m$total_return * 100))
  cat(sprintf("Annualized Return : %+.2f%%\n", m$ann_return   * 100))
  cat(sprintf("Sharpe Ratio      : %.4f\n",    m$sharpe))
  cat(sprintf("Max Drawdown (*)  : %.2f%%\n",  m$max_drawdown * 100))
  cat("(*) Portfolio peak-to-trough; can exceed per-trade stop-loss.\n")
  cat(sprintf("Buy events        : %d\n", object$n_buys))
  cat(sprintf("Full exits        : %d\n", object$n_sells))
  invisible(object)
}

#' Plot the Equity Curve of a BacktestResult
#' @param x A \code{BacktestResult} object.
#' @param ... Additional arguments passed to \code{plot()}.
#' @export
plot.BacktestResult <- function(x, ...) {
  old_par <- graphics::par(no.readonly = TRUE)
  on.exit(graphics::par(old_par))

  graphics::plot(
    x$dates, x$equity,
    type = "l", col = "steelblue", lwd = 2,
    main = paste("Equity Curve:", x$config@strategy_type),
    xlab = "Date", ylab = "Portfolio Value",
    ...
  )
  graphics::abline(h = x$equity[1L], col = "gray60", lty = 2)
  graphics::legend(
    "topleft",
    legend = c("Equity", "Initial Capital"),
    col    = c("steelblue", "gray60"),
    lty    = c(1, 2), lwd = c(2, 1),
    bty    = "n"
  )
  invisible(x)
}
