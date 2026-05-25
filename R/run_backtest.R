#' Run a Full Backtest Simulation
#'
#' End-to-end backtesting pipeline:
#' \enumerate{
#'   \item Validates the S4 \code{StrategyConfig} object.
#'   \item Instantiates the appropriate R6 \code{Strategy} subclass.
#'   \item Generates trading signals (vectorized R — no loops).
#'   \item Delegates the path-dependent simulation to the compiled C++ engine.
#'   \item Returns a \code{BacktestResult} S3 object with metrics.
#' }
#'
#' @param data A \code{data.frame} produced by \code{\link{load_market_data}}.
#' @param config A validated \code{\linkS4class{StrategyConfig}} object.
#' @return A \code{BacktestResult} S3 object.
#' @seealso \code{\link{strategy_config}}, \code{\link{load_market_data}},
#'   \code{\link{compute_metrics}}
#' @export
run_backtest <- function(data, config) {

  # ── Defensive input validation ────────────────────────────────────────────
  if (!is.data.frame(data))
    stop("'data' must be a data.frame. Use load_market_data() to load it.")
  if (!methods::is(config, "StrategyConfig"))
    stop("'config' must be a StrategyConfig object. Use strategy_config().")
  methods::validObject(config)   # re-runs S4 slot-level validity checks

  req_cols <- c("Date", "Open", "High", "Low", "Close")
  missing_cols <- setdiff(req_cols, names(data))
  if (length(missing_cols) > 0L)
    stop("'data' is missing required columns: ",
         paste(missing_cols, collapse = ", "))
  if (nrow(data) == 0L) stop("'data' has zero rows.")

  # ── Instantiate R6 strategy from S4 config ────────────────────────────────
  strategy <- switch(
    config@strategy_type,
    ATH = StrategyATH$new(n = as.integer(config@lookback)),
    DCA = StrategyDCA$new(n = as.integer(config@dca_interval)),
    Dip = StrategyDip$new(dip_pct = config@dip_pct),
    stop("Unknown strategy_type: '", config@strategy_type, "'")
  )

  # ── Generate signals (vectorized R — no for-loops) ────────────────────────
  signals <- strategy$generate_signals(data)

  # ── Choose execution mode ─────────────────────────────────────────────────
  # invest_amount > 0  →  DCA accumulation mode (buy fixed amount per signal)
  # invest_amount = 0  →  all-in mode (deploy full cash on signal, then exit)
  # This allows Dip strategy to run either all-in OR as accumulation DCA-Dip.
  cpp_invest <- max(0.0, config@invest_amount)

  # ── Run the compiled C++ simulation engine ────────────────────────────────
  cpp_out <- run_simulation_cpp(
    close_prices  = data$Close,
    high_prices   = data$High,
    low_prices    = data$Low,
    signals       = as.integer(signals),
    initial_cash  = config@initial_cash,
    stop_loss_pct = config@stop_loss,
    invest_amount = cpp_invest
  )

  # ── Wrap results in S3 BacktestResult ─────────────────────────────────────
  new_backtest_result(
    equity               = cpp_out$equity,
    cash                 = cpp_out$cash,
    positions            = cpp_out$positions,
    cumulative_invested  = cpp_out$cumulative_invested,
    signals              = signals,
    dates                = data$Date,
    config               = config
  )
}

#' Launch the QuantLab Shiny Dashboard
#'
#' Opens the interactive strategy-testing dashboard in the default browser.
#'
#' @param ... Additional arguments passed to \code{shiny::runApp()}.
#' @export
launch_app <- function(...) {
  app_dir <- system.file("shiny_app", package = "quantlab")
  if (!nzchar(app_dir))
    stop("Shiny app not found. Run devtools::install() first.")
  shiny::runApp(app_dir, ...)
}
