import 'package:flutter/material.dart';

import 'card_image.dart';
import 'catalogue_repository.dart';
import 'models.dart';

/// One form reused for Add (card == null) and Edit (card != null).
/// Pops with a success message after a confirmed write, or null on Cancel.
class CardFormPage extends StatefulWidget {
  const CardFormPage({
    super.key,
    required this.repository,
    required this.folders,
    required this.initialFolderId,
    this.card,
  });

  final CatalogueRepository repository;
  final List<Folder> folders;
  final int initialFolderId;
  final CardRecord? card;

  @override
  State<CardFormPage> createState() => _CardFormPageState();
}

class _CardFormPageState extends State<CardFormPage> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _titleController;
  late final TextEditingController _notesController;
  late final TextEditingController _imageRefController;
  Suit? _suit;
  late int? _folderId;
  bool _busy = false;
  String? _error;

  bool get _isEditing => widget.card != null;

  @override
  void initState() {
    super.initState();
    final card = widget.card;
    _titleController = TextEditingController(text: card?.title ?? '');
    _notesController = TextEditingController(text: card?.notes ?? '');
    _imageRefController = TextEditingController(text: card?.imageRef ?? '');
    _suit = card?.suit;
    final folderId = card?.folderId ?? widget.initialFolderId;
    _folderId =
        widget.folders.any((folder) => folder.id == folderId) ? folderId : null;
  }

  @override
  void dispose() {
    _titleController.dispose();
    _notesController.dispose();
    _imageRefController.dispose();
    super.dispose();
  }

  String? _validateTitle(String? value) {
    if (value == null || value.trim().isEmpty) return 'Enter a card title.';
    return null;
  }

  String? _validateImageRef(String? value) {
    final ref = value?.trim() ?? '';
    if (ref.isEmpty) return null;
    if (!CardImage.isSupportedRef(ref)) {
      return 'Use an assets/ path or an http(s):// URL, or leave blank.';
    }
    return null;
  }

  Future<void> _save() async {
    if (_busy) return;
    if (!_formKey.currentState!.validate()) return;
    final imageRef = _imageRefController.text.trim();
    final card = CardRecord(
      id: widget.card?.id,
      title: _titleController.text.trim(),
      suit: _suit!,
      notes: _notesController.text.trim(),
      imageRef: imageRef.isEmpty ? null : imageRef,
      folderId: _folderId!,
    );
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      String message;
      if (_isEditing) {
        final affected = await widget.repository.updateCard(card);
        if (affected != 1) {
          if (!mounted) return;
          setState(() {
            _busy = false;
            _error = 'Card ID ${card.id} no longer exists '
                '($affected rows updated).';
          });
          return;
        }
        message = 'Updated card ID ${card.id}: $affected row affected.';
      } else {
        final id = await widget.repository.insertCard(card);
        message = 'Saved card "${card.title}" with ID $id.';
      }
      debugPrint(message);
      if (!mounted) return;
      Navigator.pop(context, message);
    } catch (error, stackTrace) {
      debugPrint('Card write failed: $error\n$stackTrace');
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = 'Save failed. Your input was kept; try again.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: !_busy,
      child: Scaffold(
        appBar: AppBar(
          title: Text(
            _isEditing ? 'Edit card ${widget.card!.id}' : 'Add card',
          ),
        ),
        body: SafeArea(
          child: Form(
            key: _formKey,
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                TextFormField(
                  controller: _titleController,
                  enabled: !_busy,
                  decoration: const InputDecoration(
                    labelText: 'Title',
                    border: OutlineInputBorder(),
                  ),
                  validator: _validateTitle,
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<Suit>(
                  initialValue: _suit,
                  decoration: const InputDecoration(
                    labelText: 'Suit',
                    border: OutlineInputBorder(),
                  ),
                  items: [
                    for (final suit in Suit.values)
                      DropdownMenuItem(
                        value: suit,
                        child: Text('${suit.symbol}  ${suit.label}'),
                      ),
                  ],
                  onChanged: _busy ? null : (suit) => _suit = suit,
                  validator: (suit) => suit == null ? 'Choose a suit.' : null,
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<int>(
                  initialValue: _folderId,
                  decoration: const InputDecoration(
                    labelText: 'Folder',
                    border: OutlineInputBorder(),
                  ),
                  items: [
                    for (final folder in widget.folders)
                      DropdownMenuItem(
                        value: folder.id,
                        child: Text('${folder.id} — ${folder.name}'),
                      ),
                  ],
                  onChanged: _busy ? null : (id) => _folderId = id,
                  validator: (id) => id == null ? 'Choose a folder.' : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _notesController,
                  enabled: !_busy,
                  maxLines: 3,
                  decoration: const InputDecoration(
                    labelText: 'Notes (optional)',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _imageRefController,
                  enabled: !_busy,
                  decoration: const InputDecoration(
                    labelText: 'Image reference (optional)',
                    helperText: 'assets/... or https://... — blank stores NULL',
                    border: OutlineInputBorder(),
                  ),
                  validator: _validateImageRef,
                ),
                if (_error != null) ...[
                  const SizedBox(height: 12),
                  Text(
                    _error!,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
                ],
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: FilledButton(
                        onPressed: _busy ? null : _save,
                        child: Text(_isEditing ? 'Save' : 'Add card'),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: OutlinedButton(
                        onPressed: _busy ? null : () => Navigator.pop(context),
                        child: const Text('Cancel'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
