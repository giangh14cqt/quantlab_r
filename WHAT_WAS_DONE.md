# what_was_done — QuantLab Project Context

## What this project is

**quantlab** is an R package for backtesting trading strategies on historical market data.
It ships with a Shiny dashboard that compares DCA vs Buy-the-Dip strategies interactively.

Install and load: `devtools::install(); library(quantlab)`  
Run dashboard: `launch_app()`  
Run tests: `devtools::test()`  
Rebuild docs: `devtools::document()`

---

## Architecture (4 layers)

```
User → strategy_config() [S4]
     → run_backtest()    [R, top-level API]
       → Strategy$generate_signals() [R6 — pure R, vectorized]
       → run_simulation_cpp()        [C++ via Rcpp — path-dependent loop]
     → BacktestResult               [S3 — print/summary/plot]
```

| File | Role |
|:-----|:-----|
| `R/strategy_config.R` | S4 `StrategyConfig` class + `strategy_config()` constructor. Validates parameters before any simulation runs. |
| `R/strategy.R` | R6 base class `Strategy` + subclasses `StrategyATH`, `StrategyDCA`, `StrategyDip`. Signal generation only (returns integer vector). |
| `src/backtest_engine.cpp` | `run_simulation_cpp()` — the only for-loop in the project. Handles fractional shares, stop-loss via daily low, and DCA accumulation mode. |
| `R/run_backtest.R` | `run_backtest(data, config)` — orchestrates the three layers above. Also `launch_app()`. |
| `R/metrics.R` | `compute_metrics()`, `new_backtest_result()`, S3 methods `print/summary/plot.BacktestResult`. |
| `R/data_loader.R` | `load_market_data()` — reads Stooq CSV, auto-maps Polish headers, validates. |
| `inst/shiny_app/app.R` | Standalone Shiny app launched by `launch_app()`. Reads CSVs from `inst/extdata/`. |

---

## What changed from the project baseline

The baseline commit (`5d9ed65 "Add project baseline"`, author Truong Giang Do) was a skeleton.
Everything below was added or rewritten during development.

### Removed from baseline

| File | Reason |
|:-----|:-------|
| `R/portfolio.R` | `Portfolio` R6 class (with `$buy()`, `$sell()`, `$holdings`) — replaced entirely by the C++ engine. Maintaining mutable state in R proved unnecessary once the C++ loop handled it. |
| `man/Portfolio.Rd` | Auto-generated docs for the above. |
| `man/StrategyCrashTest.Rd` | `StrategyCrashTest` strategy (force-enter on known crash dates) — removed as the Dip strategy covers the same educational point more generally. |

### Rewritten

**`R/strategy.R`**  
Baseline `StrategyATH.generate_signals()` used an explicit `for`-loop (O(n) in R).  
Rewritten to use `embed()` — fully vectorized, no loop. Comparison:

```r
# Baseline (slow for-loop):
for (i in (self$n + 1):n_obs) {
  lookback <- close[(i - self$n):(i - 1)]
  if (close[i] >= max(lookback)) signals[i] <- 1
}

# Current (vectorized):
mat          <- embed(close, self$n + 1L)
lookback_max <- do.call(pmax, as.data.frame(mat[, -1L, drop = FALSE]))
signals[(self$n + 1L):n_obs] <- as.integer(mat[, 1L] >= lookback_max)
```

Also added input validation (`n` must be positive integer) and `StrategyDCA`, `StrategyDip` subclasses.  
`StrategyCrashTest` removed.

**`src/backtest_engine.cpp`**  
Baseline: 55 lines, integer shares (`floor(cash / price)`), 6 parameters, returns 3 vectors.  
Current: ~100 lines. Key changes:
- **Fractional shares** (`current_cash / close_prices[i]` without `floor`) — necessary because WIG/SPX index levels are in the tens of thousands; integer shares would require enormous capital.
- **`invest_amount` parameter** — enables DCA/accumulation mode. When `> 0`, fresh money is injected on each signal instead of deploying existing cash. Stop-loss is disabled in this mode.
- **`cumulative_invested` output vector** — tracks total capital deployed; used by `compute_metrics()` to compute injection-adjusted Sharpe ratio.
- **`stop_loss_price` reset on exit** — baseline left stale stop price after selling; fixed.

**`tests/testthat/test-backtester.R`**  
Baseline: 49 lines, 3 tests, no validation of S4/R6 classes.  
Current: ~330 lines, 30+ tests covering `run_simulation_cpp`, `StrategyConfig` S4 validity, all three R6 strategies, `load_market_data`, `compute_metrics`, and `run_backtest` integration.  
Baseline tests also assumed integer shares; updated to match fractional-share engine.

### Added (new files)

| File | What it does |
|:-----|:-------------|
| `R/strategy_config.R` | S4 `StrategyConfig` with slot-level validity checks. Guards against invalid lookback, stop_loss out of range, negative cash, etc. Decouples configuration from instantiation. |
| `R/metrics.R` | `compute_metrics()` with injection-adjusted Sharpe (subtracts fresh-money injections from daily returns so DCA purchase spikes don't inflate the ratio). `BacktestResult` S3 class with `print`, `summary`, `plot` methods. |
| `R/run_backtest.R` | High-level `run_backtest(data, config)` — the intended user-facing API. Validates inputs, picks the right R6 strategy, calls C++ engine, wraps output in `BacktestResult`. |
| `inst/shiny_app/app.R` | DCA vs Buy-the-Dip interactive dashboard. Uses `bslib` + `plotly` + `DT`. Wealth-factor chart (portfolio / cumulative_invested × 100) normalises across currencies so WIG (PLN) and S&P 500 (USD) are comparable on one axis. Supports optional second index for side-by-side comparison. |
| `data/spx_d.csv`, `data/dax_d.csv` | Additional market data (S&P 500, DAX). `data/wig_d.csv` moved from repo root. WIG and SPX also live in `inst/extdata/` for the installed package; DAX is in `data/` only (dev mode). |

---

## Key design decisions (rationale)

**Why fractional shares?**  
WIG20 index is ~80 000 PLN; S&P 500 ~5 000 USD. Integer shares would require hundreds of thousands in initial capital to be meaningful. Fractional shares mirror real ETF investing.

**Why injection-adjusted Sharpe?**  
In DCA mode, each purchase causes equity to jump by `invest_amount`. A naive `Δequity/equity_prev` on purchase days treats the cash injection as a market gain, inflating both mean and SD. The adjustment: `r_t = (ΔE_t − inject_t) / E_{t-1}`. On non-purchase days `inject_t = 0` and it reduces to the standard formula.

**Why S4 for config, R6 for strategies, S3 for results?**  
S4 gives formal slot validation before the simulation runs (fail fast). R6 gives mutable state if strategies ever need it (currently they don't, but the design is open). S3 is idiomatic R for output objects with `print/summary/plot`.

**Why keep the C++ loop even for DCA (no stop-loss)?**  
Uniformity: one engine handles both modes. DCA mode is fast enough in R too, but keeping it in C++ avoids branching the code path.
