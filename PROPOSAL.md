# QuantLab — High-Speed Strategy Backtester

### Project Metadata
* **Team Members:** Truong Giang Do (488388), Jan Melan (434200), Sebastian Chmielewski (486770)
* **Course Info:** Advanced R Programming (Class at 3 PM)
* **Target Environment:** Antigravity IDE / R Package Framework

---

## 1. Project Overview & Objective

QuantLab is an installable R package for backtesting trading strategies on historical market data from `stooq.pl`. Rather than a one-shot analysis script, the project delivers a **reusable, parameter-driven simulation framework**: users configure strategy rules and capital parameters through a validated S4 configuration object, and the framework handles signal generation, path-dependent portfolio simulation, and performance reporting automatically.

The core deliverable is the R package plus an interactive Shiny dashboard that lets users compare two accumulation strategies — **Dollar-Cost Averaging (DCA)** and **Buy-the-Dip** — across multiple market indices and date ranges, with all performance metrics computed in real time.

### Implemented Strategies

1. **ATH — All-Time High (FOMO Investor):** Generates a buy signal whenever the closing price reaches a new rolling N-day maximum. Simulates momentum-chasing behaviour. Supports a static stop-loss checked against the daily low (intraday breach detection in C++).
2. **DCA — Dollar-Cost Averaging:** Buys a fixed monetary amount every N trading days regardless of price. Represents systematic, emotion-free investing and serves as the benchmark in the dashboard.
3. **Buy-the-Dip:** Buys a fixed amount the first day the price falls at least X% below its running all-time high. Simulates contrarian accumulation — saving cash and deploying it on weakness.

---

## 2. System Architecture & Core Components

The system is divided into four cleanly decoupled layers:

* **Data Ingestion Layer** (`R/data_loader.R`): Reads local CSV exports from `stooq.pl`, auto-detects and maps Polish column headers to English (`Data→Date`, `Zamkniecie→Close`, etc.), validates types and chronological order, and warns on corrupted High/Low rows.

* **Object-Oriented Domain Layer**: Three sub-layers using three different R OOP systems, each chosen for its strengths:
  * **S4** (`R/strategy_config.R`) — `StrategyConfig` class with formal slot-level validation. Rejects invalid parameters (out-of-range stop-loss, non-integer lookback, negative capital) before any simulation starts.
  * **R6** (`R/strategy.R`) — `Strategy` base class with `StrategyATH`, `StrategyDCA`, `StrategyDip` subclasses. Signal generation is fully vectorized using `embed()`, `cummax()`, and `seq()` — no explicit R loops.
  * **S3** (`R/metrics.R`) — `BacktestResult` class with `print`, `summary`, and `plot` methods for ergonomic result inspection.

* **High-Speed Execution Core** (`src/backtest_engine.cpp`): The single compiled C++ loop in the project. Runs `run_simulation_cpp()` which processes each trading day sequentially — necessary because stop-loss checks (using daily low prices) and position state create path dependencies that cannot be vectorized. Supports two modes: all-in (deploy full cash on signal, stop-loss active) and accumulation (inject fixed amount per signal, no stop-loss, fractional shares).

* **User Interface Layer** (`inst/shiny_app/app.R`): A `bslib`-based Shiny dashboard comparing DCA vs Buy-the-Dip across up to two market indices simultaneously. Features a wealth-factor chart (portfolio value / cumulative invested × 100) that normalizes across currencies, and a comparison table with injection-adjusted Sharpe ratio and personal return metrics.

---

## 3. Curricular Requirements Mapping

| Course Technique | Implementation in QuantLab |
| :--- | :--- |
| **Advanced Functions & Defensive Programming** | `load_market_data()` validates file existence, column presence, date parseability, and High ≥ Low integrity. `strategy_config()` wraps S4 validity checks that fail fast with descriptive messages before any simulation runs. `run_backtest()` re-validates both data and config at the entry point. |
| **Object-Oriented Programming (R6 + S4 + S3)** | Three OOP systems used deliberately: S4 for config validation (formal slots), R6 for extensible strategy classes (`StrategyATH`, `StrategyDCA`, `StrategyDip` all inherit from `Strategy`), S3 for idiomatic R output objects (`BacktestResult` with `print`/`summary`/`plot`). |
| **C++ Integration (Rcpp)** | `run_simulation_cpp()` in `src/backtest_engine.cpp` — the only for-loop in the project. Handles fractional shares, intraday stop-loss checks via daily low prices, and the DCA fresh-money injection model. Returns four named numeric vectors. |
| **Vectorization & Performance Optimization** | All signal generation is vectorized: ATH uses `embed()` + `do.call(pmax, ...)`, Dip uses `cummax()` + boolean differencing, DCA uses `seq()`. `compute_metrics()` uses `cummax()` for drawdown and vectorized return calculations. No R-level for-loops anywhere outside C++. |
| **Shiny Applications & Dashboards** | `inst/shiny_app/app.R` — reactive dashboard with `eventReactive` triggering four parallel backtests, `plotly` wealth-factor chart, and `DT` comparison table with best-value cell highlighting. Tooltips explain Sharpe adjustment and wealth factor normalization. |
| **R Package Structuring** | Installable package with `DESCRIPTION`, `NAMESPACE` (generated by roxygen2), compiled Rcpp routines registered via `R_registerRoutines`, and bundled data in `inst/extdata/`. |
| **Testing Integration** | 30+ `testthat` unit tests covering `run_simulation_cpp` edge cases, S4 validity rejection, all three R6 strategy classes, `load_market_data` error handling, `compute_metrics` math, and full `run_backtest` integration tests against real WIG data. |
| **Advanced Bonus** | Injection-adjusted Sharpe ratio: standard daily returns inflate SD on DCA purchase days (equity jumps by `invest_amount`). The adjustment `r_t = (ΔE_t − inject_t) / E_{t-1}` removes capital injections from the return series, producing a meaningful risk-adjusted metric for accumulation strategies. |
