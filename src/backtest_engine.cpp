#include <Rcpp.h>
using namespace Rcpp;

// [[Rcpp::export]]
List run_simulation_cpp(NumericVector close_prices, 
                        NumericVector high_prices, 
                        NumericVector low_prices, 
                        IntegerVector signals, 
                        double initial_cash, 
                        double stop_loss_pct) {
    
    int n = close_prices.size();
    NumericVector equity(n);
    NumericVector cash(n);
    NumericVector positions(n);
    
    double current_cash = initial_cash;
    double current_position = 0;
    double entry_price = 0;
    double stop_loss_price = 0;
    
    for (int i = 0; i < n; i++) {
        // 1. Process Signal
        if (signals[i] == 1 && current_position == 0) {
            // Buy
            current_position = floor(current_cash / close_prices[i]);
            current_cash -= current_position * close_prices[i];
            entry_price = close_prices[i];
            stop_loss_price = entry_price * (1.0 - stop_loss_pct);
        }
        
        // 2. Check Stop Loss
        if (current_position > 0) {
            if (low_prices[i] <= stop_loss_price) {
                // Stop loss triggered
                // For simplicity, we sell at the stop_loss_price or at Open if it's a gap down
                // But since we don't have Open in this simple C++ call yet, we use stop_loss_price
                current_cash += current_position * stop_loss_price;
                current_position = 0;
                entry_price = 0;
            }
        }
        
        // 3. Record State
        cash[i] = current_cash;
        positions[i] = current_position;
        equity[i] = current_cash + current_position * close_prices[i];
    }
    
    return List::create(
        Named("equity") = equity,
        Named("cash") = cash,
        Named("positions") = positions
    );
}
