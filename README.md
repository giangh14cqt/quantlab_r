# QuantLab — High-Speed Strategy Backtester

QuantLab is an R package for backtesting trading strategies on historical market data. It combines **R6 object-oriented programming** for strategy definition, a formally validated **S4 configuration layer**, and a compiled **C++ simulation engine** (via Rcpp) for path-dependent daily loops.

## Getting Started

### Prerequisites
- R (>= 4.0.0)
- RStudio (recommended)
- C++ compiler (Rtools on Windows, Xcode CLI on macOS)

### Installation

Clone this repository and open `quantlab_r.Rproj` in RStudio, then run:

```r
devtools::install()
```

### Basic usage

```r
library(quantlab)

# Load bundled WIG data
path <- system.file("extdata", "wig_d.csv", package = "quantlab")
data <- load_market_data(path)

# Configure a strategy
cfg <- strategy_config("ATH", lookback = 252L, stop_loss = 0.10,
                       initial_cash = 10000)

# Run backtest
res <- run_backtest(data, cfg)
print(res)
plot(res)
```

### DCA / Buy-the-Dip (fresh-money model)

```r
# Dollar-cost averaging: invest 500 every 21 trading days
cfg_dca <- strategy_config("DCA", invest_amount = 500, dca_interval = 21L)
res_dca <- run_backtest(data, cfg_dca)
summary(res_dca)

# Buy-the-Dip: invest 1000 whenever price drops 10% below all-time high
cfg_dip <- strategy_config("Dip", dip_pct = 0.10, invest_amount = 1000)
res_dip <- run_backtest(data, cfg_dip)
summary(res_dip)
```

### Interactive dashboard

```r
launch_app()
```

## Project Structure

```
/R          — Strategy R6 classes, S4 config, metrics, backtest runner
/src        — C++ simulation engine (Rcpp)
/inst       — Shiny dashboard (inst/shiny_app/) and bundled data (inst/extdata/)
/tests      — testthat unit tests
/man        — Auto-generated roxygen2 documentation
```

## Strategies

| Strategy | Description |
|:---------|:------------|
| `ATH`    | Buy when price hits a new rolling N-day high (FOMO investor). Supports stop-loss. |
| `DCA`    | Buy a fixed amount every N trading days regardless of price. |
| `Dip`    | Buy when price drops ≥ X% below its running all-time high. |

## Authors

- Truong Giang Do
- Jan Melan
- Sebastian Chmielewski
