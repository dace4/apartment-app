/// US-09: the result of the mortgage calculator, for a loan repaid with a
/// fixed monthly payment (annuity). Amounts are in CHF.
class MortgageEstimate {
  const MortgageEstimate({
    required this.loanAmount,
    required this.monthlyPayment,
    required this.numberOfPayments,
    required this.totalPaid,
    required this.totalInterest,
    required this.firstPaymentInterest,
    required this.firstPaymentPrincipal,
  });

  /// Purchase price minus down payment.
  final double loanAmount;
  final double monthlyPayment;

  /// Duration in months.
  final int numberOfPayments;

  /// All monthly payments together.
  final double totalPaid;
  final double totalInterest;

  /// How the first monthly payment splits between interest and repayment.
  final double firstPaymentInterest;
  final double firstPaymentPrincipal;
}
