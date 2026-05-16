# TODO_NEXT - QuantLab Roadmap

This document tracks the tasks planned for after the completion of Phases 1-4.

## Phase 5: Analytical Shiny Dashboard
- [ ] Create `inst/shiny_app/app.R`.
- [ ] Implement Sidebar controls (Ticker, Stop-loss %, Initial Cash).
- [ ] Implement Main Panel visualizations:
    - [ ] Equity Curve (Plotly).
    - [ ] Performance Metrics Summary (Sharpe, Max Drawdown, PnL).
    - [ ] Trade Log Table (DT).
- [ ] Add reactive triggers to run the Rcpp backtester when parameters change.

## Phase 6: Testing & Packaging
- [ ] Implement full `testthat` suite in `tests/testthat/`.
- [ ] Run `devtools::check()` to ensure CRAN-like compliance.
- [ ] Generate documentation using `roxygen2` / `devtools::document()`.
- [ ] Finalize the `DESCRIPTION` file and package versioning.

