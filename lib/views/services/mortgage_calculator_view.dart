import 'package:flutter/material.dart';

import '../../view_models/mortgage_calculator_view_model.dart';
import 'widgets/mortgage_result_card.dart';

/// US-09: calculate the monthly payment of a mortgage from custom input.
class MortgageCalculatorView extends StatefulWidget {
  const MortgageCalculatorView({super.key, this.initialPrice});

  /// Pre-fills the price when opened from an apartment for sale.
  final int? initialPrice;

  @override
  State<MortgageCalculatorView> createState() => _MortgageCalculatorViewState();
}

class _MortgageCalculatorViewState extends State<MortgageCalculatorView> {
  final viewModel = MortgageCalculatorViewModel();
  final _formKey = GlobalKey<FormState>();
  late final _priceController = TextEditingController(
    text: widget.initialPrice?.toString(),
  );
  final _downPaymentController = TextEditingController();
  final _rateController = TextEditingController();
  final _yearsController = TextEditingController();

  @override
  void dispose() {
    viewModel.dispose();
    _priceController.dispose();
    _downPaymentController.dispose();
    _rateController.dispose();
    _yearsController.dispose();
    super.dispose();
  }

  void _calculate() {
    FocusScope.of(context).unfocus();
    if (!_formKey.currentState!.validate()) return;
    viewModel.calculate(
      price: _priceController.text,
      downPayment: _downPaymentController.text,
      rate: _rateController.text,
      years: _yearsController.text,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Mortgage calculator')),
      body: Align(
        alignment: Alignment.topCenter,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 560),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _buildForm(),
                const SizedBox(height: 24),
                ListenableBuilder(
                  listenable: viewModel,
                  builder: (context, _) {
                    final estimate = viewModel.estimate;
                    if (estimate == null) return const SizedBox.shrink();
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        MortgageResultCard(estimate: estimate),
                        const SizedBox(height: 8),
                        Text(
                          'Estimate only, not a loan offer.',
                          textAlign: TextAlign.center,
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ],
                    );
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildForm() {
    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextFormField(
            controller: _priceController,
            keyboardType: TextInputType.number,
            textInputAction: TextInputAction.next,
            validator: viewModel.validatePrice,
            // A result that no longer matches the fields is hidden.
            onChanged: (_) => viewModel.clearEstimate(),
            decoration: const InputDecoration(
              labelText: 'Purchase price',
              suffixText: 'CHF',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _downPaymentController,
            keyboardType: TextInputType.number,
            textInputAction: TextInputAction.next,
            validator: (value) =>
                viewModel.validateDownPayment(_priceController.text, value),
            onChanged: (_) => viewModel.clearEstimate(),
            decoration: const InputDecoration(
              labelText: 'Down payment (optional)',
              suffixText: 'CHF',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _rateController,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            textInputAction: TextInputAction.next,
            validator: viewModel.validateRate,
            onChanged: (_) => viewModel.clearEstimate(),
            decoration: const InputDecoration(
              labelText: 'Interest rate per year',
              suffixText: '%',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _yearsController,
            keyboardType: TextInputType.number,
            textInputAction: TextInputAction.done,
            validator: viewModel.validateYears,
            onChanged: (_) => viewModel.clearEstimate(),
            onFieldSubmitted: (_) => _calculate(),
            decoration: const InputDecoration(
              labelText: 'Duration',
              suffixText: 'years',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 24),
          FilledButton.icon(
            onPressed: _calculate,
            icon: const Icon(Icons.calculate_outlined),
            label: const Text('Calculate estimate'),
          ),
        ],
      ),
    );
  }
}
