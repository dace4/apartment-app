import 'dart:math';

import 'package:flutter/foundation.dart';

import '../models/mortgage_estimate.dart';

/// US-09: validation and calculation of the mortgage calculator screen.
/// The loan is repaid with a fixed monthly payment (annuity).
class MortgageCalculatorViewModel extends ChangeNotifier {
  static const minPrice = 10000;
  static const maxPrice = 50000000;
  static const maxRate = 20.0;
  static const maxYears = 50;

  /// Swiss amounts are rounded to 5 Rappen (0.05 CHF), in centimes.
  static const _rappenStep = 5;

  /// The last result, or null before the first calculation or after an
  /// input changed.
  MortgageEstimate? estimate;

  /// Reads a CHF amount, accepting Swiss formats like 890'000 or 890 000.
  static int? parseAmount(String? text) {
    final cleaned = (text ?? '').replaceAll(RegExp(r"[\s'’]"), '');
    return int.tryParse(cleaned);
  }

  /// Reads a rate in percent, accepting 2.5 and 2,5.
  static double? parseRate(String? text) {
    final cleaned = (text ?? '').replaceAll(RegExp(r'[\s%]'), '');
    final rate = double.tryParse(cleaned.replaceAll(',', '.'));
    // double.tryParse also accepts "NaN" and "Infinity".
    return rate != null && rate.isFinite ? rate : null;
  }

  static int? parseYears(String? text) => int.tryParse((text ?? '').trim());

  String? validatePrice(String? value) {
    final price = parseAmount(value);
    if (price == null || price < minPrice || price > maxPrice) {
      return "Enter a price from CHF 10'000 to CHF 50'000'000.";
    }
    return null;
  }

  /// Optional: an empty field means no down payment.
  String? validateDownPayment(String price, String? value) {
    if ((value ?? '').trim().isEmpty) return null;
    final downPayment = parseAmount(value);
    if (downPayment == null || downPayment < 0) {
      return 'Enter an amount in CHF, or leave it empty.';
    }
    final purchasePrice = parseAmount(price);
    if (purchasePrice != null && downPayment >= purchasePrice) {
      return 'The down payment must be lower than the price.';
    }
    return null;
  }

  String? validateRate(String? value) {
    final rate = parseRate(value);
    if (rate == null || rate < 0 || rate > maxRate) {
      return 'Enter a rate from 0 to 20 %.';
    }
    return null;
  }

  String? validateYears(String? value) {
    final years = parseYears(value);
    if (years == null || years < 1 || years > maxYears) {
      return 'Enter a duration from 1 to 50 years.';
    }
    return null;
  }

  /// Computes the estimate from the form fields. The View validates the
  /// form first; invalid input is ignored here as a safety net.
  void calculate({
    required String price,
    required String downPayment,
    required String rate,
    required String years,
  }) {
    if (validatePrice(price) != null ||
        validateDownPayment(price, downPayment) != null ||
        validateRate(rate) != null ||
        validateYears(years) != null) {
      return;
    }

    final loan = (parseAmount(price)! - (parseAmount(downPayment) ?? 0))
        .toDouble();
    final monthlyRate = parseRate(rate)! / 100 / 12;
    final months = parseYears(years)! * 12;

    // Annuity formula; without interest the loan is split evenly.
    final exactPayment = monthlyRate == 0
        ? loan / months
        : loan * monthlyRate / (1 - pow(1 + monthlyRate, -months));

    // Amounts are rounded to 5 Rappen, as usual in Switzerland. The payment
    // is rounded up so the loan is always fully repaid, and every other
    // amount is derived from it in centimes so the shown figures add up. The
    // small tolerance ignores floating-point noise such as 2400.0000000001.
    final paymentCents =
        ((exactPayment * 100 - 1e-6) / _rappenStep).ceil() * _rappenStep;
    final totalCents = paymentCents * months;
    final firstInterestCents =
        (loan * monthlyRate * 100 / _rappenStep).round() * _rappenStep;

    estimate = MortgageEstimate(
      loanAmount: loan,
      monthlyPayment: paymentCents / 100,
      numberOfPayments: months,
      totalPaid: totalCents / 100,
      totalInterest: (totalCents - loan * 100) / 100,
      firstPaymentInterest: firstInterestCents / 100,
      firstPaymentPrincipal: (paymentCents - firstInterestCents) / 100,
    );
    notifyListeners();
  }

  /// Hides a result that no longer matches the fields.
  void clearEstimate() {
    if (estimate == null) return;
    estimate = null;
    notifyListeners();
  }
}
