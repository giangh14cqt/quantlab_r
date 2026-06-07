library(shiny)
library(bslib)
library(plotly)
library(DT)
library(quantlab)

# ── Data discovery ─────────────────────────────────────────────────────────────
# CSV files live in data/ at the package root (development) or inst/extdata/
# (installed package).  Both locations are probed; data/ wins if it has files.

DATA_DIR <- local({
  d <- file.path(find.package("quantlab"), "data")
  if (dir.exists(d) && length(list.files(d, "\\.csv$")) > 0L) return(d)
  system.file("extdata", package = "quantlab")   # fallback for installed pkg
})

# Known display names; unknown files fall back to uppercased filename stem.
INDEX_LABELS <- c(
  "wig_d.csv" = "WIG",
  "spx_d.csv" = "S&P 500",
  "dax_d.csv" = "DAX"
)

index_label <- function(filename) {
  lbl <- INDEX_LABELS[filename]
  if (!is.na(lbl)) unname(lbl) else toupper(sub("_.*$", "", filename))
}

csv_files     <- list.files(DATA_DIR, pattern = "\\.csv$", full.names = FALSE)
index_choices <- setNames(csv_files, vapply(csv_files, index_label, character(1)))

# Position-based colour palette:
#   slot 1 → DCA for Index 1   slot 2 → Dip for Index 1   slot 3 → ATH for Index 1
#   slot 4 → DCA for Index 2   slot 5 → Dip for Index 2   slot 6 → ATH for Index 2
PALETTE <- c("#1565C0", "#C62828", "#F57C00", "#2E7D32", "#6A1B9A", "#00796B")

# ── UI ────────────────────────────────────────────────────────────────────────
ui <- page_sidebar(
  title = "QuantLab — DCA vs Dip vs ATH Dashboard",
  theme = bs_theme(bootswatch = "flatly", version = 5),

  sidebar = sidebar(
    width = 270,
    title = "Parameters",

    selectInput("index1", "Index 1",
                choices  = index_choices,
                selected = index_choices[1]),
    selectInput("index2", "Index 2 (optional — compare pair)",
                choices  = c("(none)" = "", index_choices),
                selected = ""),

    dateRangeInput(
      "date_range", "Investment Period",
      start = "2001-01-02", end = "2023-01-01",
      min   = "1991-04-16", max = Sys.Date(),
      format = "dd/mm/yyyy", separator = " — "
    ),

    tags$small(class = "text-muted",
      "Fresh-money model: each purchase injects new cash from income.",
      "The chart normalises to a wealth factor so indices are comparable."),

    hr(),
    tags$small(tags$b("DCA — Dollar-Cost Averaging"), class = "text-muted d-block mb-1"),
    sliderInput("dca_interval", "Buy every N trading days",
                min = 1, max = 63, value = 21, step = 1),
    numericInput("dca_amount", "Amount per DCA purchase",
                 value = 1000, min = 10, step = 100),

    hr(),
    tags$small(tags$b("Buy-the-Dip"), class = "text-muted d-block mb-1"),
    sliderInput("dip_pct", "Dip trigger (% below all-time high)",
                min = 1, max = 30, value = 10, step = 1),
    numericInput("dip_amount", "Amount per Dip purchase",
                 value = 5000, min = 10, step = 100),
    tags$small(class = "text-muted",
      "Deploy a larger lump sum when the market dips — simulates",
      "saving up cash and buying on weakness."),

    hr(),
    tags$small(tags$b("ATH — All-Time High / Breakout"), class = "text-muted d-block mb-1"),
    numericInput("ath_cash", "Starting Capital (All-In)",
                 value = 10000, min = 100, step = 1000),
    sliderInput("ath_lookback", "Rolling window (lookback days)",
                min = 5, max = 504, value = 252, step = 5),
    sliderInput("ath_stop_loss", "Stop Loss (%)",
                min = 0, max = 50, value = 10, step = 1),
    tags$small(class = "text-muted",
      "Buy breakouts at rolling highs with stop-loss protection."),

    hr(),
    actionButton("run_btn", "Run Comparison",
                 class = "btn-primary w-100", icon = icon("play"))
  ),

  # ── Wealth-factor chart ────────────────────────────────────────────────────
  card(
    full_screen = TRUE,
    card_header(
      "Wealth Factor",
      tooltip(
        bsicons::bs_icon("info-circle"),
        HTML(paste0(
          "<b>Wealth Factor = portfolio value / total invested &times; 100</b><br>",
          "Starts at 100 when the first purchase is made.<br>",
          "Value of 200 = portfolio worth 2&times; what was put in (100% gain).<br>",
          "Dashed line at 100 = break-even.<br><br>",
          "Normalising by cumulative invested removes the currency difference ",
          "(e.g. WIG in PLN, S&amp;P 500 in USD) and makes all series ",
          "directly comparable on one axis."
        )),
        placement = "right"
      )
    ),
    plotlyOutput("equity_plot", height = "430px")
  ),

  # ── Comparison table ───────────────────────────────────────────────────────
  card(
    card_header(
      "Strategy Comparison",
      tooltip(
        bsicons::bs_icon("info-circle"),
        HTML(paste0(
          "<b>Total Invested / Final Value</b> differ between strategies ",
          "(DCA buys more often than Dip) — do not compare them directly.<br><br>",
          "<b>Personal Return</b> = (final portfolio &minus; total invested) / ",
          "total invested. Correct base for both DCA and lump-sum.<br><br>",
          "<b>Ann. Return</b> = (1 + personal&nbsp;return)<sup>1/years</sup> &minus; 1. ",
          "Annualises the personal return; uses total invested as the capital base. ",
          "Unlike a naive CAGR (final/first&nbsp;tranche), this is valid for DCA.<br><br>",
          "<b>Sharpe (rf = 0%)</b> = mean(r) / SD(r) &times; &radic;252, where r is the ",
          "daily <em>investment</em> return with fresh-money injections removed: ",
          "r<sub>t</sub> = (&Delta;equity<sub>t</sub> &minus; inject<sub>t</sub>) / equity<sub>t&minus;1</sub>. ",
          "Without this adjustment, purchase-day capital spikes inflate SD and distort Sharpe.<br><br>",
          "<b>Max Drawdown</b> = largest peak-to-trough decline of the equity ",
          "curve. Green = best (least negative) value among active strategies."
        )),
        placement = "right"
      )
    ),
    DTOutput("metrics_table")
  )
)

# ── Server ────────────────────────────────────────────────────────────────────
server <- function(input, output, session) {

  # Load all CSVs once per session
  raw_data <- reactive({
    files <- list.files(DATA_DIR, pattern = "\\.csv$", full.names = TRUE)
    nms   <- basename(files)
    setNames(
      lapply(files, function(f)
        suppressMessages(quantlab::load_market_data(f))),
      nms
    )
  })

  clip <- function(df, from, to) df[df$Date >= from & df$Date <= to, ]

  results <- eventReactive(input$run_btn, ignoreNULL = FALSE, {
    from <- input$date_range[1]
    to   <- input$date_range[2]

    validate(
      need(!is.na(from) && !is.na(to), "Please set a valid date range."),
      need(from < to,                   "Start date must be before end date.")
    )

    idx1 <- input$index1
    idx2 <- input$index2
    use2 <- nzchar(idx2) && idx2 != idx1

    raw   <- raw_data()
    data1 <- clip(raw[[idx1]], from, to)
    nm1   <- index_label(idx1)
    validate(need(nrow(data1) > 50,
      paste0("Not enough data for ", nm1, " (need > 50 trading days).")))

    if (use2) {
      data2 <- clip(raw[[idx2]], from, to)
      nm2   <- index_label(idx2)
      validate(need(nrow(data2) > 50,
        paste0("Not enough data for ", nm2, " (need > 50 trading days).")))
    }

    cfg_dca <- quantlab::strategy_config(
      "DCA",
      initial_cash  = 0,
      invest_amount = input$dca_amount,
      dca_interval  = input$dca_interval
    )
    cfg_dip <- quantlab::strategy_config(
      "Dip",
      initial_cash  = 0,
      invest_amount = input$dip_amount,
      dip_pct       = input$dip_pct / 100
    )
    cfg_ath <- quantlab::strategy_config(
      "ATH",
      initial_cash  = input$ath_cash,
      lookback      = input$ath_lookback,
      stop_loss     = input$ath_stop_loss / 100
    )

    n_runs <- if (use2) 6L else 3L
    withProgress(message = paste0("Running ", n_runs, " backtests..."), value = 0, {
      res <- list()

      setProgress(0.1)
      res[[paste0("DCA — ", nm1)]] <- quantlab::run_backtest(data1, cfg_dca)
      setProgress(0.3)
      res[[paste0("Dip — ", nm1)]] <- quantlab::run_backtest(data1, cfg_dip)
      setProgress(0.5)
      res[[paste0("ATH — ", nm1)]] <- quantlab::run_backtest(data1, cfg_ath)

      if (use2) {
        setProgress(0.6)
        res[[paste0("DCA — ", nm2)]] <- quantlab::run_backtest(data2, cfg_dca)
        setProgress(0.8)
        res[[paste0("Dip — ", nm2)]] <- quantlab::run_backtest(data2, cfg_dip)
        setProgress(0.9)
        res[[paste0("ATH — ", nm2)]] <- quantlab::run_backtest(data2, cfg_ath)
      }

      setProgress(1.0)
    })

    res
  })

  # ── Wealth-factor chart ────────────────────────────────────────────────────
  output$equity_plot <- renderPlotly({
    req(results())
    res    <- results()
    series <- names(res)
    colors <- setNames(PALETTE[seq_along(series)], series)

    p <- plot_ly()

    for (nm in series) {
      r   <- res[[nm]]
      inv <- r$cumulative_invested
      wf  <- ifelse(inv > 0, round(r$equity / inv * 100, 2), NA_real_)
      fv  <- which(!is.na(wf) & inv > 0)[1L]
      if (is.na(fv)) next

      p <- add_lines(p,
        x    = r$dates[fv:length(r$dates)],
        y    = wf[fv:length(wf)],
        name = nm,
        line = list(color = colors[[nm]], width = 2)
      )
    }

    # Break-even reference line at 100
    all_dates <- res[[series[1]]]$dates
    p <- add_lines(p,
      x          = all_dates,
      y          = rep(100, length(all_dates)),
      name       = "Break-even (invested = portfolio)",
      line       = list(color = "#888888", width = 1, dash = "dash"),
      showlegend = TRUE
    )

    p |> layout(
      xaxis     = list(title = ""),
      yaxis     = list(
        title      = "Wealth factor (first purchase = 100)",
        ticksuffix = ""
      ),
      hovermode = "x unified",
      legend    = list(orientation = "h", y = -0.14),
      margin    = list(t = 5)
    )
  })

  # ── Comparison table ───────────────────────────────────────────────────────
  output$metrics_table <- renderDT({
    req(results())
    res    <- results()
    series <- names(res)

    rows <- lapply(series, function(nm) {
      r   <- res[[nm]]
      m   <- r$metrics
      n   <- length(r$equity)
      inv <- r$total_invested
      data.frame(
        Strategy          = nm,
        `# Purchases`     = r$n_buys,
        `Total Invested`  = formatC(round(inv, 0), format = "d", big.mark = " "),
        `Final Value`     = formatC(round(r$equity[n], 0), format = "d", big.mark = " "),
        `Personal Return` = if (!is.na(r$personal_return))
                              sprintf("%+.1f%%", r$personal_return * 100) else "—",
        `Ann. Return`     = if (!is.na(r$ann_return))
                              sprintf("%+.2f%%", r$ann_return * 100) else "—",
        `Sharpe (rf=0%)`  = sprintf("%.3f",    m$sharpe),
        `Max Drawdown`    = sprintf("%.1f%%",  m$max_drawdown * 100),
        check.names = FALSE, stringsAsFactors = FALSE
      )
    })

    df <- do.call(rbind, rows)

    # Parse formatted percentages back to numeric for highlighting.
    # Rows with 0 purchases are excluded from "best" comparison (no real result).
    # max_drawdown is stored negative ("-35.0%"), so best = which.max (closest to 0).
    parse_pct <- function(x) suppressWarnings(as.numeric(gsub("[+%\\s]", "", x)))
    active    <- df$`# Purchases` > 0   # only rows that actually traded

    best_of <- function(vals, fn) {
      candidates <- which(active)
      if (length(candidates) == 0L) return(integer(0))
      candidates[fn(vals[candidates])]
    }

    best_pr  <- best_of(parse_pct(df$`Personal Return`), which.max)
    best_ar  <- best_of(parse_pct(df$`Ann. Return`),     which.max)
    best_sh  <- best_of(as.numeric(df$`Sharpe (rf=0%)`), which.max)
    best_dd  <- best_of(parse_pct(df$`Max Drawdown`),    which.max)  # least negative

    dt <- datatable(
      df,
      rownames = FALSE,
      class    = "compact stripe",
      options  = list(
        dom        = "t",
        ordering   = FALSE,
        pageLength = nrow(df),
        columnDefs = list(list(className = "dt-center",
                               targets   = seq_len(ncol(df)) - 1L))
      )
    )

    hl <- "#C8E6C9"
    dt <- formatStyle(dt, "Personal Return",
      backgroundColor = styleRow(best_pr, hl),
      fontWeight      = styleRow(best_pr, "bold"))
    dt <- formatStyle(dt, "Ann. Return",
      backgroundColor = styleRow(best_ar, hl),
      fontWeight      = styleRow(best_ar, "bold"))
    dt <- formatStyle(dt, "Sharpe (rf=0%)",
      backgroundColor = styleRow(best_sh, hl),
      fontWeight      = styleRow(best_sh, "bold"))
    dt <- formatStyle(dt, "Max Drawdown",
      backgroundColor = styleRow(best_dd, hl),
      fontWeight      = styleRow(best_dd, "bold"))
    dt
  })
}

shinyApp(ui, server)
