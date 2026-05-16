# QuantLab - High-Speed Strategy Tester

QuantLab is an R package designed for rapid backtesting of trading strategies on historical market data. It combines the flexibility of **R6 object-oriented programming** with the speed of **C++ (via Rcpp)**.

## 🚀 Getting Started

### Prerequisites
- R (>= 4.0.0)
- RStudio (recommended)
- C++ Compiler (Build Tools)

### Installation
Clone this repository and open the `quantlab.Rproj` file in RStudio. Then run:
```r
devtools::install()
```

### Usage Example
```r
library(quantlab)

# 1. Load Data
data <- load_market_data("wig_d.csv")

# 2. Setup Strategy (e.g., All-Time High with 252-day window)
strategy <- StrategyATH$new(n = 252)
signals <- strategy$generate_signals(data)

# 3. Run High-Speed Simulation (5% stop-loss)
results <- run_simulation_cpp(
  data$Close, data$High, data$Low, signals, 
  initial_cash = 10000, stop_loss_pct = 0.05
)

# 4. Analyze Results
plot(results$equity, type = "l", main = "Equity Curve")
```

## 🏗 Project Structure
- `/R`: R6 classes for Portfolios and Strategies, and the Data Loader.
- `/src`: C++ source code for the path-dependent simulation engine.
- `/tests`: Unit tests for verifying logic and math.
- `/man`: Package documentation (generated automatically).

## 📅 Roadmap (Next Steps)
Please see [TODO_NEXT.md](TODO_NEXT.md) for details on Phase 5 (Shiny Dashboard) and Phase 6 (CRAN compliance).

## 👥 Authors
- Truong Giang Do
- Jan Melan
- Sebastian Chmielewski
