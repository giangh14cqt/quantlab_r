# QuantLab - High-Speed Strategy Tester

### Project Metadata
* **Team Members:** Truong Giang Do (488388), Jan Melan (434200), Sebastian Chmielewski (486770)
* **Course Info:** Advanced R Programming (Class at 3 PM)
* **Target Environment:** Antigravity IDE / R Package Framework

---

## 1. Project Overview & Objective
QuantLab is an R-based tool designed for testing simple trading strategies on historical market data. Rather than evaluating a single, fixed dataset or focusing on speculative financial forecasting and exploratory data analysis, this project provides a reusable, highly scalable backtesting framework. 

The core deliverable is an installable R package that abstracts the complexities of data ingestion, stateful portfolio simulation, and programmatic trading rule evaluation. Users interact with the framework via an intuitive, web-based analytical dashboard.

### Addressing Instructor Feedback: Interactive Strategy Design
To avoid rigid or oversimplified portfolio tracking, QuantLab implements a **modular, parameter-driven rules engine** using historical data from `stooq.pl`. Instead of manually selecting entrance or exit timestamps on a chart, users configure dynamic market criteria. The platform natively evaluates the specific edge-case behaviors highlighted by our instructor:
1. **The FOMO Investor (All-Time Highs):** Evaluates asset performance when buy rules are triggered exclusively on rolling $N$-day All-Time Highs (ATH).
2. **The Doom Investor (Crash Timing):** Simulates capital performance if an investor enters the market at the worst possible chronological moments—specifically the day before historical macro-market crashes—to measure the efficacy of defensive stop-losses.
3. **Standard Technical Parameters:** Classic indicator rules (e.g., Moving Average Crossovers) with user-adjustable lookback windows.

---

## 2. System Architecture & Core Components
The system is divided into four cleanly decoupled layers mapped out inside our R package structure:

* **Data Ingestion Layer:** Imports CSV configurations or live URL streams from `stooq.pl`. It runs programmatic data cleaning, detects Polish asset formatting, and asserts timeline continuity using strict defensive logic.
* **Object-Oriented Domain Layer:** Uses R6 classes to handle stateful properties like current portfolio cash balances, open positions, active tracking of trailing stop boundaries, and execution order sheets.
* **High-Speed Execution Core:** Implements critical iterative loops inside compiled C++ (via `Rcpp`). It processes row-by-row daily timelines across decades of market history instantly, checking if stop-losses or strategy target parameters were breached inside daily high/low variations.
* **User Interface Layer:** A Shiny dashboard serving as the interactive control room. It features sidebar controls for picking tickers, tuning rule parameters, adjusting stop-losses, and triggering historical crash simulations.

---

## 3. Curricular Requirements Mapping
QuantLab satisfies the advanced technical milestones required by the course architecture:

| Course Technique | Structural Application inside QuantLab |
| :--- | :--- |
| **Advanced Functions & Defensive Programming** | Written with explicit input type-validation assertions, explicit handling of connection errors or missing data points, and auto-mapping Polish-encoded Stooq column headers into English standard structures. |
| **Object-Oriented Programming (R6)** | Utilizes mutable R6 classes (`Portfolio` and `Strategy`) to encapsulate real-time portfolio weights, transaction record databases, and dynamic internal tracking logic. |
| **C++ Integration (Rcpp)** | Offloads chronological backtesting loops to compiled C++ code, optimizing execution speeds when validating conditional intraday stop-losses across thousands of observation rows. |
| **Vectorization & Performance Optimization** | Pre-calculates signals and complex rolling technical arrays across complete data matrices using vectorized R primitives before initializing the backtest engine loops. |
| **Shiny Applications & Dashboards** | Implements modern reactive components showcasing comprehensive performance indicators (Sharpe Ratios, Max Drawdowns), transaction tables, and interactive equity curves. |
| **R Package Structuring** | Fully assembled as an installable R package featuring compiled namespaces, formal documentation files, and standard internal source paths (`/R`, `/src`, `/inst`). |
| **Testing Integration** | Validates math operations, safety exceptions, and tracking engines using explicit `testthat` automated unit test suites. |
| **Advanced Bonus Tracks** | Implements an entire structural **Simulation Framework** over multi-asset **Time Series Financial Data**. |