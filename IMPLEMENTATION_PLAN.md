# QuantLab - Detailed Implementation Plan

This document maps out the specific engineering timeline for building the QuantLab R package inside the Antigravity IDE environment.

---

## Phase 1: Package Boilerplate & Workspace Setup
**Goal:** Initialize the standard structure of the installable R package.

1. Open the Antigravity IDE terminal and execute initialization commands:
   ```r
   devtools::create("quantlab")
   usethis::use_rcpp()
   usethis::use_testthat()
   ```
2. Configure the `DESCRIPTION` file with project metadata, team information, and explicitly declare required package dependencies (`R6`, `shiny`, `Rcpp`, `bslib`, `DT`, `plotly`).
3. Establish directory separation paths:
   * `/R` — R6 classes, defensive validation functions, and Shiny UI definitions.
   * `/src` — C++ compilation files for loop processing.
   * `/tests/testthat` — Evaluation scripts ensuring calculation accuracy.

---

## Phase 2: Data Ingestion & Defensive Programming Layer
**Goal:** Implement resilient functions capable of cleaning and normalizing `stooq.pl` data exports.

1. Create `R/data_loader.R` and build the primary data validation engine: `load_stooq_data(file_path_or_url)`.
2. Implement **Defensive Programming assertions**:
   * Assert file type validity and handle HTTP/HTTPS connection timeouts gracefully.
   * Detect and convert Polish headers automatically (e.g., mapping *Data* -> *Date*, *Zamkniecie* -> *Close*).
   * Confirm data is sorted in strict ascending chronological order; flag explicit errors if critical columns contain gaps or structural `NA` mutations.
3. Utilize vectorized code architectures to pre-calculate rolling market indicators (like $N$-day maximums for the All-Time High strategy variant) across the data frame columns before passing vectors downstream.

---

## Phase 3: Object-Oriented Domain Layer (R6 Classes)
**Goal:** Map business logic and real-time state tracking variables cleanly.

1. Create `R/portfolio.R` containing the `Portfolio` R6 class:
   * **Fields:** `cash`, `positions` (named vector tracking shares held), `trade_log` (data frame recording chronological history), and `equity_curve`.
   * **Methods:** `$buy(asset, qty, price)`, `$sell(asset, qty, price)`, and `$update_balance(current_price)`. Add defensive logic preventing balances from slipping below zero unless a margin parameter is allowed.
2. Create `R/strategy.R` containing the `Strategy` R6 interface:
   * Methods include `$set_parameters()` and `$generate_signals(data)`.
   * Create inherited sub-structures specifically handling instructor setups: `StrategyATH` (buying rolling highs) and `StrategyCrashTest` (forcing entry positions directly prior to known historical market corrections).

---

## Phase 4: High-Performance Simulation Engine (Rcpp)
**Goal:** Implement lightning-fast path-dependent loops in C++ to process time series records.

1. Create `src/backtest_engine.cpp`.
2. Write the execution logic function:
   ```cpp
   #include <Rcpp.h>
   using namespace Rcpp;

   // [[Rcpp::export]]
   DataFrame run_simulation_cpp(NumericVector close_prices, 
                                NumericVector high_prices, 
                                NumericVector low_prices, 
                                IntegerVector signals, 
                                double initial_cash, 
                                double stop_loss_pct) {
       // Chronological loop logic verifying trailing stop triggers 
       // and balance shifts day-by-day
       // Returns a clean DataFrame representing the portfolio history
   }
   ```
3. Run `devtools::document()` to compile C++ routines via Rcpp and register them into the package namespace.

---

## Phase 5: Analytical Shiny Dashboard Interface
**Goal:** Build a user interface allowing interactive strategy parameter changes and reporting dashboards.

1. Create `inst/shiny_app/` housing decoupled `ui.R` and `server.R` scripts.
2. **UI Implementation Components:**
   * Sidebar selection inputs to dynamically adjust lookback windows, stop-loss ratios, initial money deposits, and targeted crash scenarios.
   * File-upload drag-and-drop features to upload local Stooq downloads directly.
3. **Server Implementation Components:**
   * Reactive wrappers mapping chosen slider states straight into the compiled `Rcpp` backend execution routes.
   * Output components including value metric summary boxes (Sharpe, PnL, Drawdown), interactive timeline plots using `plotly`, and interactive log data tables via `DT`.

---

## Phase 6: Automated Testing & Packaging
**Goal:** Ensure code correctness, verify math outputs, and finalize compilation routines.

1. Implement comprehensive validation unit tests under `tests/testthat/test-backtester.R`:
   * Test that parsing errors trip gracefully when fed malformed CSV content.
   * Test a small 5-day mock historical pricing structure to mathematically verify that trailing stop-loss values trigger precisely when hit.
2. Build documentation artifacts for the package environment by executing:
   ```r
   devtools::check()
   devtools::install()
   ```