library(testthat)

test_that("run_simulation_cpp handles simple buy and hold", {
  close <- c(100, 110, 120)
  high <- c(105, 115, 125)
  low <- c(95, 105, 115)
  signals <- c(1, 0, 0) # Buy on day 1
  
  res <- run_simulation_cpp(close, high, low, signals, 1000, 0.1)
  
  # Buy 10 shares at 100 on day 1
  expect_equal(res$positions[1], 10)
  expect_equal(res$cash[1], 0)
  expect_equal(res$equity[1], 1000)
  
  # Hold on day 2 (equity = 0 + 10 * 110 = 1100)
  expect_equal(res$equity[2], 1100)
})

test_that("run_simulation_cpp triggers stop loss correctly", {
  close <- c(100, 96, 90)
  high <- c(105, 98, 92)
  low <- c(95, 94, 88) 
  signals <- c(1, 0, 0) # Buy at 100, stop loss at 10% (90)
  
  # Stop loss at 5% = 95
  res <- run_simulation_cpp(close, high, low, signals, 1000, 0.05)
  
  # Day 1: Buy at 100. Low is 95, so it triggers immediately?
  # In our loop: Buy happens at Close of day 1. 
  # Then we check stop loss... wait.
  # Let's check our C++ logic: 
  # if (signals[i] == 1) { Buy }
  # if (current_position > 0) { Check Stop Loss }
  # So if it buys on day 1, it checks stop loss on day 1 too.
  
  # Day 1: Close=100, Low=95. Stop loss price = 95. 
  # It should trigger on day 1 if we use >= or <=.
  # Our C++ code: if (low_prices[i] <= stop_loss_price)
  expect_equal(res$positions[1], 0) # Sold immediately
  expect_equal(res$cash[1], 10 * 95) # 950
})

test_that("run_simulation_cpp handles no signals", {
  close <- c(100, 110, 120)
  res <- run_simulation_cpp(close, close, close, c(0,0,0), 1000, 0.1)
  expect_equal(all(res$positions == 0), TRUE)
  expect_equal(all(res$equity == 1000), TRUE)
})
