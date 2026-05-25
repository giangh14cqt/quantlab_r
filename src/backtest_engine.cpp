#include <Rcpp.h>
#include <algorithm>
using namespace Rcpp;

//' Run Path-Dependent Portfolio Simulation (C++)
//'
//' Two execution modes controlled by \code{invest_amount}:
//'
//' \strong{All-In mode} (\code{invest_amount = 0}):
//' On a buy signal all available cash is deployed.  Stop-loss is checked
//' every day against \code{low_prices} — this intraday check is the primary
//' reason the loop runs in compiled C++ rather than interpreted R.
//' The check uses the daily low to catch intraday breaches: if the low
//' dips below the stop price the position is closed at the stop price.
//'
//' \strong{DCA / Accumulation mode} (\code{invest_amount > 0}):
//' Fresh-money model — on each buy signal \code{invest_amount} is added to
//' the cash balance (simulating a periodic salary contribution) and then
//' immediately invested.  Positions accumulate across signals; stop-loss is
//' not applied.  \code{cumulative_invested} tracks total capital deployed.
//'
//' Both modes use fractional shares — standard for index-fund / ETF
//' investing where the index level may greatly exceed the purchase amount.
//'
//' @param close_prices  Numeric vector of daily closing prices.
//' @param high_prices   Numeric vector of daily high prices (used for stop-loss).
//' @param low_prices    Numeric vector of daily low prices (used for stop-loss).
//' @param signals       Integer vector: 1 = buy signal, 0 = hold.
//' @param initial_cash  Starting cash balance (lump sum; 0 = pure DCA model).
//' @param stop_loss_pct Stop-loss fraction in [0, 1); 0 disables it.
//' @param invest_amount Periodic contribution per signal; 0 = all-in mode.
//' @return Named list with numeric vectors \code{equity}, \code{cash},
//'   \code{positions}, and \code{cumulative_invested}.
// [[Rcpp::export]]
List run_simulation_cpp(NumericVector close_prices,
                        NumericVector high_prices,
                        NumericVector low_prices,
                        IntegerVector signals,
                        double        initial_cash,
                        double        stop_loss_pct,
                        double        invest_amount) {

  int n = close_prices.size();
  NumericVector equity(n), cash(n), positions(n), cum_invested(n);

  double current_cash     = initial_cash;
  double current_position = 0.0;
  double stop_loss_price  = 0.0;
  double total_invested   = initial_cash;

  const bool use_stop_loss = (stop_loss_pct > 0.0);
  const bool is_dca        = (invest_amount  > 0.0);

  for (int i = 0; i < n; i++) {

    // ── 1. Execute buy signal ──────────────────────────────────────────────
    if (signals[i] == 1 && close_prices[i] > 0.0) {

      if (is_dca) {
        // Fresh-money: contribution arrives and is invested immediately.
        current_cash     += invest_amount;
        total_invested   += invest_amount;
        current_position += invest_amount / close_prices[i];
        current_cash     -= invest_amount;

      } else if (current_position == 0.0 && current_cash > 0.0) {
        // All-in: deploy every available cent (fractional shares).
        current_position = current_cash / close_prices[i];
        current_cash     = 0.0;
        if (use_stop_loss)
          stop_loss_price = close_prices[i] * (1.0 - stop_loss_pct);
      }
    }

    // ── 2. Stop-loss check (all-in mode only, every day) ──────────────────
    // Uses daily LOW to detect intraday breaches — impossible to vectorise
    // in R because each day's state depends on the previous day's position.
    if (!is_dca && use_stop_loss && current_position > 0.0) {
      if (low_prices[i] <= stop_loss_price) {
        current_cash     += current_position * stop_loss_price;
        current_position  = 0.0;
        stop_loss_price   = 0.0;
      }
    }

    // ── 3. Record state ────────────────────────────────────────────────────
    cash[i]         = current_cash;
    positions[i]    = current_position;
    equity[i]       = current_cash + current_position * close_prices[i];
    cum_invested[i] = total_invested;
  }

  return List::create(
    Named("equity")              = equity,
    Named("cash")                = cash,
    Named("positions")           = positions,
    Named("cumulative_invested") = cum_invested
  );
}
