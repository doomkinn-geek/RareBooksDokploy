import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/models/poll_model.dart';

/// Screen for creating a new poll in a group chat
class CreatePollScreen extends ConsumerStatefulWidget {
  final String chatId;

  const CreatePollScreen({super.key, required this.chatId});

  @override
  ConsumerState<CreatePollScreen> createState() => _CreatePollScreenState();
}

class _CreatePollScreenState extends ConsumerState<CreatePollScreen> {
  final _formKey = GlobalKey<FormState>();
  final _questionController = TextEditingController();
  final List<TextEditingController> _optionControllers = [
    TextEditingController(),
    TextEditingController(),
  ];
  
  bool _allowMultipleAnswers = false;
  bool _isAnonymous = false;
  bool _isCreating = false;

  @override
  void dispose() {
    _questionController.dispose();
    for (final controller in _optionControllers) {
      controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    return Scaffold(
      appBar: AppBar(
        title: const Text('Создать голосование'),
        actions: [
          TextButton(
            onPressed: _isCreating ? null : _createPoll,
            child: _isCreating
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('Создать'),
          ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // Question field
            TextFormField(
              controller: _questionController,
              decoration: const InputDecoration(
                labelText: 'Вопрос',
                hintText: 'Введите вопрос голосования',
                border: OutlineInputBorder(),
              ),
              maxLines: 3,
              maxLength: 500,
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Введите вопрос';
                }
                return null;
              },
            ),
            
            const SizedBox(height: 24),
            
            // Options section
            Text(
              'Варианты ответа',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            
            // Option fields
            ..._buildOptionFields(),
            
            // Add option button
            if (_optionControllers.length < 10)
              TextButton.icon(
                onPressed: _addOption,
                icon: const Icon(Icons.add),
                label: const Text('Добавить вариант'),
              ),
            
            const SizedBox(height: 24),
            
            // Settings
            Text(
              'Настройки',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            
            // Multiple answers switch
            SwitchListTile(
              title: const Text('Множественный выбор'),
              subtitle: const Text('Участники могут выбрать несколько вариантов'),
              value: _allowMultipleAnswers,
              onChanged: (value) {
                setState(() => _allowMultipleAnswers = value);
              },
            ),
            
            // Anonymous switch
            SwitchListTile(
              title: const Text('Анонимное голосование'),
              subtitle: const Text('Голоса участников скрыты'),
              value: _isAnonymous,
              onChanged: (value) {
                setState(() => _isAnonymous = value);
              },
            ),
          ],
        ),
      ),
    );
  }

  List<Widget> _buildOptionFields() {
    return List.generate(_optionControllers.length, (index) {
      return Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: Row(
          children: [
            Expanded(
              child: TextFormField(
                controller: _optionControllers[index],
                decoration: InputDecoration(
                  labelText: 'Вариант ${index + 1}',
                  border: const OutlineInputBorder(),
                ),
                maxLength: 200,
                validator: (value) {
                  if (index < 2 && (value == null || value.trim().isEmpty)) {
                    return 'Обязательное поле';
                  }
                  return null;
                },
              ),
            ),
            if (index >= 2)
              IconButton(
                icon: Icon(Icons.close, color: Colors.red[400]),
                onPressed: () => _removeOption(index),
              ),
          ],
        ),
      );
    });
  }

  void _addOption() {
    if (_optionControllers.length >= 10) return;
    
    setState(() {
      _optionControllers.add(TextEditingController());
    });
  }

  void _removeOption(int index) {
    if (index < 2 || index >= _optionControllers.length) return;
    
    setState(() {
      _optionControllers[index].dispose();
      _optionControllers.removeAt(index);
    });
  }

  Future<void> _createPoll() async {
    if (!_formKey.currentState!.validate()) return;
    
    // Get non-empty options
    final options = _optionControllers
        .map((c) => c.text.trim())
        .where((text) => text.isNotEmpty)
        .toList();
    
    if (options.length < 2) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Нужно минимум 2 варианта ответа')),
      );
      return;
    }
    
    setState(() => _isCreating = true);
    
    try {
      final request = CreatePollRequest(
        chatId: widget.chatId,
        question: _questionController.text.trim(),
        options: options,
        allowMultipleAnswers: _allowMultipleAnswers,
        isAnonymous: _isAnonymous,
      );
      
      // Return the request to the caller
      if (mounted) {
        Navigator.of(context).pop(request);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Ошибка: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isCreating = false);
      }
    }
  }
}

