library(testthat)
library(quantlab)

# ── run_simulation_cpp ────────────────────────────────────────────────────────

test_that("run_simulation_cpp: simple buy and hold (no stop-loss)", {
  res <- run_simulation_cpp(
    close_prices  = c(100, 110, 120),
    high_prices   = c(105, 115, 125),
    low_prices    = c(95,  105, 115),
    signals       = c(1L, 0L, 0L),
    initial_cash  = 1000,
    stop_loss_pct = 0.0,
    invest_amount = 0.0
  )
  expect_equal(res$positions[1], 10.0)   # 1000/100 fractional shares
  expect_equal(res$cash[1], 0.0)
  expect_equal(res$equity[2], 1100)
  expect_equal(res$equity[3], 1200)
})

test_that("run_simulation_cpp: stop-loss triggers via daily low", {
  # Entry at 100, stop at 5% = 95. Low on day 1 = 95 -> triggers immediately.
  res <- run_simulation_cpp(
    close_prices  = c(100, 96, 90),
    high_prices   = c(105, 98, 92),
    low_prices    = c(95,  94, 88),
    signals       = c(1L, 0L, 0L),
    initial_cash  = 1000,
    stop_loss_pct = 0.05,
    invest_amount = 0.0
  )
  expect_equal(res$positions[1], 0)
  expect_equal(res$cash[1], 950)   # 10 shares * 95 stop price
})

test_that("run_simulation_cpp: stop_loss = 0 never exits", {
  res <- run_simulation_cpp(
    close_prices  = c(100, 50, 30),
    high_prices   = c(100, 55, 35),
    low_prices    = c(100, 48, 28),
    signals       = c(1L, 0L, 0L),
    initial_cash  = 1000,
    stop_loss_pct = 0.0,
    invest_amount = 0.0
  )
  expect_gt(res$positions[3], 0)
  expect_equal(res$equity[3], 300)
})

test_that("run_simulation_cpp: no signals keeps equity flat", {
  res <- run_simulation_cpp(
    close_prices  = c(100, 110, 120),
    high_prices   = c(105, 115, 125),
    low_prices    = c(95,  105, 115),
    signals       = c(0L, 0L, 0L),
    initial_cash  = 1000,
    stop_loss_pct = 0.10,
    invest_amount = 0.0
  )
  expect_true(all(res$positions == 0))
  expect_true(all(res$equity == 1000))
})

test_that("run_simulation_cpp: DCA accumulates with fresh-money model", {
  res <- run_simulation_cpp(
    close_prices  = c(100, 100, 100),
    high_prices   = c(100, 100, 100),
    low_prices    = c(100, 100, 100),
    signals       = c(1L, 1L, 1L),
    initial_cash  = 0,
    stop_loss_pct = 0.0,
    invest_amount = 100.0
  )
  expect_equal(res$positions[3], 3.0)
  expect_equal(res$cash[3], 0)
  expect_equal(res$cumulative_invested[3], 300)
})

test_that("run_simulation_cpp: DCA ignores stop-loss", {
  res <- run_simulation_cpp(
    close_prices  = c(100, 50),
    high_prices   = c(100, 55),
    low_prices    = c(100, 45),
    signals       = c(1L, 0L),
    initial_cash  = 1000,
    stop_loss_pct = 0.10,
    invest_amount = 500.0
  )
  expect_gt(res$positions[2], 0)   # still holding despite 50% crash
})

# ── StrategyConfig S4 ─────────────────────────────────────────────────────────

test_that("strategy_config: creates valid ATH object with stop-loss", {
  cfg <- strategy_config("ATH", lookback = 60, stop_loss = 0.05,
                          initial_cash = 5000)
  expect_s4_class(cfg, "StrategyConfig")
  expect_equal(cfg@strategy_type, "ATH")
  expect_equal(cfg@lookback, 60)
  expect_equal(cfg@stop_loss, 0.05)
})

test_that("strategy_config: stop_loss = 0 is valid (disabled)", {
  cfg <- strategy_config("ATH", stop_loss = 0)
  expect_equal(cfg@stop_loss, 0)
})

test_that("strategy_config: creates valid DCA object", {
  cfg <- strategy_config("DCA", dca_interval = 10, invest_amount = 500,
                          initial_cash = 5000)
  expect_s4_class(cfg, "StrategyConfig")
  expect_equal(cfg@dca_interval, 10)
  expect_equal(cfg@invest_amount, 500)
})

test_that("strategy_config: creates valid Dip object", {
  cfg <- strategy_config("Dip", dip_pct = 0.10)
  expect_equal(cfg@dip_pct, 0.10)
})

test_that("strategy_config: rejects unknown strategy_type", {
  expect_error(strategy_config("MACD"), "strategy_type")
})

test_that("strategy_config: rejects non-integer lookback for ATH", {
  expect_error(strategy_config("ATH", lookback = 2.5), "lookback")
})

test_that("strategy_config: rejects out-of-range stop_loss", {
  expect_error(strategy_config("ATH", stop_loss = 1.1), "stop_loss")
  expect_error(strategy_config("ATH", stop_loss = -0.01), "stop_loss")
})

test_that("strategy_config: rejects negative initial_cash", {
  expect_error(strategy_config("ATH", initial_cash = -1), "initial_cash")
})

test_that("strategy_config: accepts initial_cash = 0 (pure DCA fresh-money model)", {
  cfg <- strategy_config("DCA", initial_cash = 0, invest_amount = 500)
  expect_equal(cfg@initial_cash, 0)
})

test_that("strategy_config: rejects non-positive invest_amount for DCA", {
  expect_error(strategy_config("DCA", invest_amount = 0), "invest_amount")
})

# ── StrategyATH ───────────────────────────────────────────────────────────────

test_that("StrategyATH: no signals when data shorter than lookback", {
  s    <- StrategyATH$new(n = 10L)
  data <- data.frame(Close = seq(100, 105, length.out = 5))
  expect_equal(s$generate_signals(data), integer(5))
})

test_that("StrategyATH: signals fire on strictly increasing prices", {
  s    <- StrategyATH$new(n = 3L)
  data <- data.frame(Close = c(10, 11, 12, 13, 14))
  sigs <- s$generate_signals(data)
  expect_equal(sigs[1:3], c(0L, 0L, 0L))
  expect_equal(sigs[4:5], c(1L, 1L))
})

test_that("StrategyATH: no signal on declining prices", {
  s    <- StrategyATH$new(n = 3L)
  data <- data.frame(Close = c(14, 13, 12, 11, 10))
  expect_true(all(s$generate_signals(data) == 0L))
})

# ── StrategyDCA ───────────────────────────────────────────────────────────────

test_that("StrategyDCA: signals every n days starting from day 1", {
  s    <- StrategyDCA$new(n = 3L)
  data <- data.frame(Close = 1:10)
  sigs <- s$generate_signals(data)
  expect_equal(which(sigs == 1L), c(1L, 4L, 7L, 10L))
})

test_that("StrategyDCA: n=1 fires every day", {
  s    <- StrategyDCA$new(n = 1L)
  data <- data.frame(Close = 1:5)
  expect_true(all(s$generate_signals(data) == 1L))
})

test_that("StrategyDCA: rejects non-integer n", {
  expect_error(StrategyDCA$new(n = 1.5), "positive integer")
})

# ── StrategyDip ───────────────────────────────────────────────────────────────

test_that("StrategyDip: signals on first entry into dip zone (cummax + edge detection)", {
  # cummax:    100, 110, 120, 120, 120
  # threshold:  90,  99, 108, 108, 108   (dip_pct = 10%)
  # below:       F,   F,   F,   T,   T
  # entered:     F,   F,   F,   T,   F   <- signal only on day 4
  s    <- StrategyDip$new(dip_pct = 0.10)
  data <- data.frame(Close = c(100, 110, 120, 100, 90))
  sigs <- s$generate_signals(data)
  expect_equal(sigs[4], 1L)
  expect_equal(sigs[5], 0L)
})

test_that("StrategyDip: no signal on monotone uptrend", {
  s    <- StrategyDip$new(dip_pct = 0.05)
  data <- data.frame(Close = c(100, 110, 120, 130, 140))
  expect_true(all(s$generate_signals(data) == 0L))
})

test_that("StrategyDip: no repeat signal in consecutive dip days", {
  s    <- StrategyDip$new(dip_pct = 0.10)
  data <- data.frame(Close = c(100, 85, 84))
  expect_equal(s$generate_signals(data), c(0L, 1L, 0L))
})

test_that("StrategyDip: rejects invalid dip_pct", {
  expect_error(StrategyDip$new(dip_pct = 0), "dip_pct")
  expect_error(StrategyDip$new(dip_pct = 1), "dip_pct")
})

# ── load_market_data ──────────────────────────────────────────────────────────

test_that("load_market_data: loads WIG data with correct structure", {
  path <- system.file("extdata", "wig_d.csv", package = "quantlab")
  skip_if(!nzchar(path), "bundled data not found")
  data <- load_market_data(path)
  expect_s3_class(data, "data.frame")
  expect_true(all(c("Date","Open","High","Low","Close","Volume") %in% names(data)))
  expect_s3_class(data$Date, "Date")
  expect_gt(nrow(data), 100)
})

test_that("load_market_data: errors on missing file", {
  expect_error(load_market_data("nonexistent.csv"), "File not found")
})

test_that("load_market_data: maps Polish headers correctly", {
  tmp <- tempfile(fileext = ".csv")
  writeLines(
    c("Data,Otwarcie,Najwyzszy,Najnizszy,Zamkniecie,Wolumen",
      "2024-01-02,100,105,98,103,1000"),
    tmp
  )
  suppressMessages(data <- load_market_data(tmp))
  expect_true("Date"  %in% names(data))
  expect_true("Close" %in% names(data))
  unlink(tmp)
})

# ── compute_metrics ───────────────────────────────────────────────────────────

test_that("compute_metrics: flat equity returns zero sharpe and drawdown", {
  m <- compute_metrics(rep(1000, 252))
  expect_equal(m$total_return, 0)
  expect_equal(m$sharpe, 0)
  expect_equal(m$max_drawdown, 0)
})

test_that("compute_metrics: max_drawdown is always <= 0", {
  m <- compute_metrics(c(1000, 1100, 900, 1050))
  expect_lte(m$max_drawdown, 0)
})

test_that("compute_metrics: injection-adjusted sharpe excludes fresh-money spikes", {
  # Flat market: price constant at 100, DCA buys every day.
  # Without adjustment: each purchase creates a huge "return" spike.
  # With adjustment: r_t = 0 every day -> sharpe = 0.
  equity <- cumsum(rep(1000, 10)) # 1000,2000,...,10000 (flat price, 10 purchases)
  ci     <- cumsum(rep(1000, 10))
  m      <- compute_metrics(equity, cumulative_invested = ci)
  expect_equal(m$sharpe, 0)
})

test_that("compute_metrics: growing equity has positive total_return", {
  m <- compute_metrics(c(1000, 1100, 1200, 1500))
  expect_gt(m$total_return, 0)
  expect_gt(m$ann_return,   0)
})

# ── run_backtest (integration) ────────────────────────────────────────────────

test_that("run_backtest: ATH with stop-loss returns BacktestResult", {
  path <- system.file("extdata", "wig_d.csv", package = "quantlab")
  skip_if(!nzchar(path), "bundled data not found")
  data <- load_market_data(path)
  cfg  <- strategy_config("ATH", lookback = 252L, stop_loss = 0.10,
                           initial_cash = 10000)
  res  <- run_backtest(data, cfg)
  expect_s3_class(res, "BacktestResult")
  expect_equal(length(res$equity), nrow(data))
  expect_true(is.list(res$metrics))
})

test_that("run_backtest: DCA fresh-money — many purchases, no cash exhaustion", {
  path <- system.file("extdata", "wig_d.csv", package = "quantlab")
  skip_if(!nzchar(path), "bundled data not found")
  data <- suppressMessages(load_market_data(path))
  cfg  <- strategy_config("DCA", initial_cash = 0,
                           invest_amount = 500, dca_interval = 21L)
  res  <- run_backtest(data, cfg)
  expect_gt(res$n_buys, 50)
  expect_false(is.na(res$personal_return))
  expect_equal(res$total_invested, res$n_buys * 500)
})

test_that("run_backtest: Dip accumulation mode", {
  path <- system.file("extdata", "wig_d.csv", package = "quantlab")
  skip_if(!nzchar(path), "bundled data not found")
  data <- suppressMessages(load_market_data(path))
  cfg  <- strategy_config("Dip", dip_pct = 0.05, invest_amount = 1000,
                           initial_cash = 0)
  res  <- run_backtest(data, cfg)
  expect_s3_class(res, "BacktestResult")
  expect_gt(res$n_buys, 0)
})

test_that("run_backtest: equity vector same length as data", {
  path <- system.file("extdata", "wig_d.csv", package = "quantlab")
  skip_if(!nzchar(path), "bundled data not found")
  data <- suppressMessages(load_market_data(path))
  cfg  <- strategy_config("DCA", invest_amount = 500)
  res  <- run_backtest(data, cfg)
  expect_equal(length(res$equity), nrow(data))
})

test_that("run_backtest: errors on wrong config type", {
  data <- data.frame(Date = Sys.Date(), Open = 1, High = 1,
                     Low = 1, Close = 1, Volume = 1)
  expect_error(run_backtest(data, list(strategy_type = "ATH")), "StrategyConfig")
})
