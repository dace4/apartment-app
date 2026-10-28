import 'package:flutter/material.dart';

import '../../view_models/contractors_view_model.dart';

class ContractorsView extends StatefulWidget {
  const ContractorsView({super.key, this.viewModel});
  final ContractorsViewModel? viewModel;

  @override
  State<ContractorsView> createState() => _ContractorsViewState();
}

class _ContractorsViewState extends State<ContractorsView> {
  late final viewModel = widget.viewModel ?? ContractorsViewModel();

  @override
  void initState() {
    super.initState();
    viewModel.fetchContractors();
  }

  @override
  void dispose() {
    if (widget.viewModel == null) viewModel.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Renovation contractors')),
      body: ListenableBuilder(
        listenable: viewModel,
        builder: (context, _) {
          if (viewModel.isLoading) {
            return const Center(child: CircularProgressIndicator());
          }
          if (viewModel.errorMessage != null) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(viewModel.errorMessage!),
                  TextButton(
                    onPressed: viewModel.fetchContractors,
                    child: const Text('Try again'),
                  ),
                ],
              ),
            );
          }
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              const Text(
                'Demo directory',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              const Text(
                'These contractors are fictional. Sample email addresses cannot be used to contact a real business.',
              ),
              const SizedBox(height: 24),
              DropdownButtonFormField<String>(
                key: ValueKey(viewModel.selectedCity),
                initialValue: viewModel.selectedCity ?? '',
                decoration: const InputDecoration(
                  labelText: 'City',
                  border: OutlineInputBorder(),
                ),
                isExpanded: true,
                items: [
                  const DropdownMenuItem(value: '', child: Text('All cities')),
                  for (final city in viewModel.cities)
                    DropdownMenuItem(value: city, child: Text(city)),
                ],
                onChanged: (city) =>
                    viewModel.selectCity(city == '' ? null : city),
              ),
              const SizedBox(height: 24),
              if (viewModel.contractors.isEmpty)
                const Text('No contractors found.'),
              for (final contractor in viewModel.contractors) ...[
                Text(
                  contractor.name,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 4),
                Text('${contractor.trade} · ${contractor.city}'),
                const SizedBox(height: 8),
                Text(contractor.description),
                const SizedBox(height: 8),
                SelectableText(
                  contractor.email,
                  semanticsLabel: 'Sample email: ${contractor.email}',
                ),
                const SizedBox(height: 16),
                const Divider(),
                const SizedBox(height: 16),
              ],
            ],
          );
        },
      ),
    );
  }
}
