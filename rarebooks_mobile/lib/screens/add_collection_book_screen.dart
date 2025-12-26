import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import '../config/theme.dart';
import '../models/models.dart';
import '../providers/providers.dart';
import '../l10n/app_localizations.dart';

/// Add collection book screen
class AddCollectionBookScreen extends StatefulWidget {
  const AddCollectionBookScreen({super.key});

  @override
  State<AddCollectionBookScreen> createState() =>
      _AddCollectionBookScreenState();
}

class _AddCollectionBookScreenState extends State<AddCollectionBookScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _authorController = TextEditingController();
  final _yearController = TextEditingController();
  final _publisherController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _purchasePriceController = TextEditingController();
  final _estimatedValueController = TextEditingController();
  final _notesController = TextEditingController();
  String? _condition;
  DateTime? _purchaseDate;

  final List<String> _conditions = [
    'Отличное',
    'Хорошее',
    'Удовлетворительное',
    'Требует реставрации',
  ];

  @override
  void dispose() {
    _titleController.dispose();
    _authorController.dispose();
    _yearController.dispose();
    _publisherController.dispose();
    _descriptionController.dispose();
    _purchasePriceController.dispose();
    _estimatedValueController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _selectDate() async {
    final date = await showDatePicker(
      context: context,
      initialDate: _purchaseDate ?? DateTime.now(),
      firstDate: DateTime(1900),
      lastDate: DateTime.now(),
    );
    if (date != null) {
      setState(() {
        _purchaseDate = date;
      });
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    final request = CollectionBookRequest(
      title: _titleController.text.trim(),
      author: _authorController.text.trim().isNotEmpty
          ? _authorController.text.trim()
          : null,
      year: _yearController.text.trim().isNotEmpty
          ? _yearController.text.trim()
          : null,
      publisher: _publisherController.text.trim().isNotEmpty
          ? _publisherController.text.trim()
          : null,
      description: _descriptionController.text.trim().isNotEmpty
          ? _descriptionController.text.trim()
          : null,
      condition: _condition,
      purchasePrice: double.tryParse(_purchasePriceController.text),
      estimatedValue: double.tryParse(_estimatedValueController.text),
      purchaseDate: _purchaseDate,
      notes: _notesController.text.trim().isNotEmpty
          ? _notesController.text.trim()
          : null,
    );

    final book = await context.read<CollectionProvider>().addBook(request);
    if (book != null && mounted) {
      context.pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final provider = context.watch<CollectionProvider>();

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.addBook),
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => context.pop(),
        ),
        actions: [
          TextButton(
            onPressed: provider.isLoading ? null : _save,
            child: provider.isLoading
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : Text(l10n.save),
          ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // Title
            TextFormField(
              controller: _titleController,
              decoration: InputDecoration(
                labelText: '${l10n.bookTitle} *',
                prefixIcon: const Icon(Icons.title),
              ),
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Введите название книги';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),

            // Author
            TextFormField(
              controller: _authorController,
              decoration: InputDecoration(
                labelText: l10n.author,
                prefixIcon: const Icon(Icons.person),
              ),
            ),
            const SizedBox(height: 16),

            // Year and Publisher row
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _yearController,
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(
                      labelText: l10n.year,
                      prefixIcon: const Icon(Icons.calendar_today),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: TextFormField(
                    controller: _publisherController,
                    decoration: const InputDecoration(
                      labelText: 'Издательство',
                      prefixIcon: Icon(Icons.business),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Condition dropdown
            DropdownButtonFormField<String>(
              value: _condition,
              decoration: InputDecoration(
                labelText: l10n.condition,
                prefixIcon: const Icon(Icons.star),
              ),
              items: _conditions
                  .map((c) => DropdownMenuItem(value: c, child: Text(c)))
                  .toList(),
              onChanged: (value) {
                setState(() {
                  _condition = value;
                });
              },
            ),
            const SizedBox(height: 16),

            // Purchase date
            InkWell(
              onTap: _selectDate,
              child: InputDecorator(
                decoration: InputDecoration(
                  labelText: l10n.purchaseDate,
                  prefixIcon: const Icon(Icons.event),
                ),
                child: Text(
                  _purchaseDate != null
                      ? '${_purchaseDate!.day}.${_purchaseDate!.month}.${_purchaseDate!.year}'
                      : 'Выберите дату',
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Prices row
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _purchasePriceController,
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(
                      labelText: l10n.purchasePrice,
                      prefixIcon: const Icon(Icons.shopping_cart),
                      prefixText: '₽ ',
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: TextFormField(
                    controller: _estimatedValueController,
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(
                      labelText: l10n.estimatedValue,
                      prefixIcon: const Icon(Icons.trending_up),
                      prefixText: '₽ ',
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Description
            TextFormField(
              controller: _descriptionController,
              maxLines: 4,
              decoration: InputDecoration(
                labelText: l10n.description,
                alignLabelWithHint: true,
              ),
            ),
            const SizedBox(height: 16),

            // Notes
            TextFormField(
              controller: _notesController,
              maxLines: 3,
              decoration: InputDecoration(
                labelText: l10n.notes,
                alignLabelWithHint: true,
              ),
            ),
            const SizedBox(height: 24),

            // Error message
            if (provider.errorMessage != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: Text(
                  provider.errorMessage!,
                  style: const TextStyle(color: AppTheme.errorColor),
                  textAlign: TextAlign.center,
                ),
              ),

            // Save button
            SizedBox(
              height: 50,
              child: ElevatedButton(
                onPressed: provider.isLoading ? null : _save,
                child: provider.isLoading
                    ? const CircularProgressIndicator(color: Colors.white)
                    : Text(l10n.save),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

