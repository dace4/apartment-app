import 'package:flutter/material.dart';

import '../../../models/mortgage_estimate.dart';
import '../../../utils/formatters.dart';

/// US-09: the monthly payment and the breakdown of an estimate.
class MortgageResultCard extends StatelessWidget {
  const MortgageResultCard({super.key, required this.estimate});

  final MortgageEstimate estimate;

  String _chf(double amount) => formatChf(amount.round());

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final years = estimate.numberOfPayments ~/ 12;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Monthly payment', style: theme.textTheme.titleMedium),
            const SizedBox(height: 4),
            Text(
              _chf(estimate.monthlyPayment),
              style: theme.textTheme.headlineMedium?.copyWith(
                color: theme.colorScheme.primary,
              ),
            ),
            const Divider(height: 32),
            _Row('Loan amount', _chf(estimate.loanAmount)),
            _Row(
              'Monthly payments',
              '${estimate.numberOfPayments} ($years years)',
            ),
            _Row('Total interest', _chf(estimate.totalInterest)),
            _Row('Total paid', _chf(estimate.totalPaid)),
            const Divider(height: 32),
            Text('First payment', style: theme.textTheme.titleSmall),
            const SizedBox(height: 4),
            _Row('Interest', _chf(estimate.firstPaymentInterest)),
            _Row('Repayment', _chf(estimate.firstPaymentPrincipal)),
          ],
        ),
      ),
    );
  }
}

/// One label and value line of the breakdown.
class _Row extends StatelessWidget {
  const _Row(this.label, this.value);

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Expanded(child: Text(label)),
          Text(value, style: Theme.of(context).textTheme.titleSmall),
        ],
      ),
    );
  }
}
