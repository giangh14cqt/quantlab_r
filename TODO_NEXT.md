# TODO_NEXT — QuantLab Roadmap

## Phase 5: Analytical Shiny Dashboard — DONE ✅
- [x] `inst/shiny_app/app.R` — DCA vs Buy-the-Dip comparison dashboard
- [x] Sidebar controls (index selector, date range, DCA interval, dip threshold, amounts)
- [x] Wealth-factor chart (Plotly) normalised by cumulative invested
- [x] Strategy comparison table (DT) with best-value highlighting
- [x] Reactive triggers connected to Rcpp backend

## Phase 6: Testing & Packaging — DONE ✅
- [x] Full `testthat` suite (`tests/testthat/test-backtester.R`)
- [x] Documentation generated via `roxygen2` / `devtools::document()`

## Potential future work
- [ ] CRAN compliance (`devtools::check()` with zero NOTEs)
- [ ] Additional strategies (trailing stop, MA crossover)
- [ ] Multi-asset portfolio support
