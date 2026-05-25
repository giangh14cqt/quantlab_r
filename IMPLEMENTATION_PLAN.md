# QuantLab — Detailed Implementation Plan

This document describes the engineering phases used to build the QuantLab R package.

---

## Phase 1: Package Boilerplate & Workspace Setup ✅

**Goal:** Initialize the standard installable R package structure.

1. Initialized package skeleton and declared dependencies in `DESCRIPTION`:
   - Runtime: `R6`, `Rcpp`, `methods`, `graphics`, `utils`
   - Suggests: `testthat`, `shiny`, `bslib`, `bsicons`, `plotly`, `DT`
2. Registered Rcpp via `usethis::use_rcpp()` — adds `LinkingTo: Rcpp` and the `useDynLib` directive.
3. Set up `testthat` via `usethis::use_testthat()`.
4. Directory layout:
   - `/R` — R source files (strategy classes, config, metrics, backtest runner)
   - `/src` — C++ simulation engine
   - `/inst/extdata` — bundled market data CSVs (WIG, SPX)
   - `/inst/shiny_app` — Shiny dashboard
   - `/tests/testthat` — unit test suite

---

## Phase 2: Data Ingestion & Defensive Programming Layer ✅

**Goal:** Resilient CSV loading with automatic Polish header detection.

**Delivered:** `R/data_loader.R` — `load_market_data(path)`

Key implementation details:
- Accepts a local file path; validates it is a single character string and that the file exists.
- Trims whitespace from column names, then auto-maps Polish Stooq headers to English using a named lookup vector (e.g. `Zamkniecie → Close`, `Najwyzszy → High`).
- Validates presence of all required columns (`Date`, `Open`, `High`, `Low`, `Close`, `Volume`).
- Coerces `Date` with `as.Date()` and stops on parse failure; coerces numeric columns with `suppressWarnings(as.numeric())` and warns if NAs result.
- Enforces ascending chronological order via `order(data$Date)`.
- Warns if any rows have `High < Low` (corrupted data).

---

## Phase 3: Object-Oriented Domain Layer ✅

**Goal:** Cleanly separate configuration, strategy logic, and result representation using three R OOP systems.

### 3a. S4 Configuration — `R/strategy_config.R`

`StrategyConfig` S4 class with seven slots and a formal `validity` function:
- Universal checks: `strategy_type` must be one of `"ATH"`, `"DCA"`, `"Dip"`; `stop_loss` in `[0, 1)`; `initial_cash ≥ 0`.
- Strategy-specific checks: ATH requires integer `lookback > 0`; DCA requires integer `dca_interval > 0` and `invest_amount > 0`; Dip requires `dip_pct` in `(0, 1)`.
- `strategy_config()` constructor wraps `new("StrategyConfig", ...)` + `validObject()` for a clean user-facing API with sensible defaults.

### 3b. R6 Strategies — `R/strategy.R`

`Strategy` base class with abstract `generate_signals(data)`. Three subclasses:

| Class | Signal logic | Key vectorization |
|:------|:-------------|:------------------|
| `StrategyATH` | Buy when `Close ≥ rolling N-day max` | `embed()` + `do.call(pmax, ...)` — no R loop |
| `StrategyDCA` | Buy every N trading days | `seq(1, n_obs, by = n)` index assignment |
| `StrategyDip` | Buy first day `Close ≤ cummax(Close) × (1 − dip_pct)` | `cummax()` + boolean edge detection (`below & !lag(below)`) |

All subclasses validate constructor arguments and return an `integer` vector aligned with `nrow(data)`.

### 3c. S3 Results — `R/metrics.R`

`BacktestResult` S3 class created by `new_backtest_result()`. Fields: `equity`, `cash`, `positions`, `cumulative_invested`, `signals`, `dates`, `config`, `metrics`, `personal_return`, `ann_return`, `total_invested`, `n_buys`, `n_sells`.

Methods:
- `print.BacktestResult` — one-screen summary (strategy, period, return, Sharpe, drawdown, trade counts).
- `summary.BacktestResult` — extended metrics table.
- `plot.BacktestResult` — base R equity curve with initial capital reference line.

`compute_metrics()` computes total return, annualized CAGR, Sharpe ratio, and max drawdown. When `cumulative_invested` is supplied, uses **injection-adjusted returns**: `r_t = (ΔE_t − inject_t) / E_{t-1}` to exclude fresh-money jumps from the Sharpe calculation.

---

## Phase 4: High-Performance Simulation Engine (Rcpp) ✅

**Goal:** Path-dependent daily simulation loop in compiled C++.

**Delivered:** `src/backtest_engine.cpp` — `run_simulation_cpp()`

```cpp
// [[Rcpp::export]]
List run_simulation_cpp(NumericVector close_prices,
                        NumericVector high_prices,
                        NumericVector low_prices,
                        IntegerVector signals,
                        double        initial_cash,
                        double        stop_loss_pct,
                        double        invest_amount);
```

Two execution modes controlled by `invest_amount`:

**All-in mode** (`invest_amount = 0`): On a buy signal, all available cash is deployed as fractional shares (`cash / close_price` — no `floor()`). Stop-loss is checked every day against `low_prices`; if `low ≤ stop_price` the position closes at stop price. Only one position open at a time.

**Accumulation mode** (`invest_amount > 0`): On each buy signal, `invest_amount` is added to `total_invested` and immediately converted to fractional shares. Positions accumulate across signals. Stop-loss is disabled. `cumulative_invested` tracks total capital deployed for metrics.

Returns a named list of four numeric vectors: `equity`, `cash`, `positions`, `cumulative_invested`.

**Why fractional shares?** WIG index is ~80 000 PLN, S&P 500 ~5 000 USD — integer shares would require enormous starting capital to be meaningful.

---

## Phase 5: Analytical Shiny Dashboard ✅

**Goal:** Interactive comparison of DCA vs Buy-the-Dip across market indices.

**Delivered:** `inst/shiny_app/app.R` — launched via `launch_app()`

UI components (`bslib` + `plotly` + `DT`):
- **Sidebar:** index selector (WIG, S&P 500, DAX; optional second index for pair comparison), date range picker, DCA interval and amount, dip threshold (%) and amount, "Run Comparison" button.
- **Wealth-factor chart:** `portfolio_value / cumulative_invested × 100`, normalised so WIG (PLN) and SPX (USD) are directly comparable on one axis. Break-even line at 100.
- **Comparison table:** per-strategy metrics — number of purchases, total invested, final value, personal return, annualized return, injection-adjusted Sharpe, max drawdown. Best value per column highlighted in green.

Server: `eventReactive` on the run button executes up to 4 backtests (2 strategies × 2 indices) with a progress bar. All data loaded once per session via a top-level `reactive()`.

---

## Phase 6: Testing & Packaging ✅

**Goal:** Verify correctness and finalize the package.

**Delivered:** `tests/testthat/test-backtester.R` — 30+ unit tests

Test coverage:
- `run_simulation_cpp`: buy-and-hold math, stop-loss triggering via daily low, zero-signal flat equity, DCA accumulation, stop-loss disabled in DCA mode.
- `StrategyConfig` S4 validity: accepts valid configs, rejects unknown strategy type, non-integer lookback, out-of-range stop_loss, negative capital, zero invest_amount.
- `StrategyATH` / `StrategyDCA` / `StrategyDip`: signal logic verified against hand-calculated examples, edge cases (short data, flat prices, monotone trends), constructor validation.
- `load_market_data`: correct column mapping, error on missing file, Polish header auto-detection.
- `compute_metrics`: flat equity → zero Sharpe, growing equity → positive return, injection-adjusted Sharpe = 0 for flat-price DCA.
- `run_backtest` integration: ATH with stop-loss, DCA fresh-money model, Dip accumulation, equity vector length, wrong config type error.

Documentation generated with `devtools::document()` (roxygen2). Package passes `devtools::install()`.
