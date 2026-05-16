#' Portfolio R6 Class
#'
#' @description
#' Manages cash and asset positions for the simulation.
#' @import R6
#' @export
Portfolio <- R6::R6Class(
  "Portfolio",
  public = list(
    #' @field cash Current cash balance
    cash = NULL,
    #' @field holdings Named vector of asset quantities
    holdings = NULL,
    #' @field history Data frame recording trade history
    history = NULL,
    
    #' @description Initialize a new portfolio
    #' @param initial_cash Starting cash balance
    initialize = function(initial_cash = 10000) {
      self$cash <- initial_cash
      self$holdings <- numeric(0)
      self$history <- data.frame(
        Date = as.Date(character()),
        Action = character(),
        Asset = character(),
        Qty = numeric(),
        Price = numeric(),
        Cash_After = numeric(),
        stringsAsFactors = FALSE
      )
    },
    
    #' @description Buy an asset
    #' @param date Date of transaction
    #' @param asset Ticker name
    #' @param qty Quantity to buy
    #' @param price Price per unit
    buy = function(date, asset, qty, price) {
      cost <- qty * price
      if (cost > self$cash) {
        # Simple defensive check
        qty <- floor(self$cash / price)
        cost <- qty * price
      }
      
      if (qty <= 0) return(invisible(self))
      
      self$cash <- self$cash - cost
      self$holdings[asset] <- (self$holdings[asset] %||% 0) + qty
      
      self$history <- rbind(self$history, data.frame(
        Date = date, Action = "BUY", Asset = asset, Qty = qty, Price = price, Cash_After = self$cash
      ))
      invisible(self)
    },
    
    #' @description Sell an asset
    #' @param date Date of transaction
    #' @param asset Ticker name
    #' @param qty Quantity to sell
    #' @param price Price per unit
    sell = function(date, asset, qty, price) {
      current_qty <- self$holdings[asset] %||% 0
      if (qty > current_qty) qty <- current_qty
      
      if (qty <= 0) return(invisible(self))
      
      proceeds <- qty * price
      self$cash <- self$cash + proceeds
      self$holdings[asset] <- current_qty - qty
      
      self$history <- rbind(self$history, data.frame(
        Date = date, Action = "SELL", Asset = asset, Qty = qty, Price = price, Cash_After = self$cash
      ))
      invisible(self)
    }
  )
)

# Utility for NULL handling
`%||%` <- function(a, b) if (!is.null(a)) a else b
