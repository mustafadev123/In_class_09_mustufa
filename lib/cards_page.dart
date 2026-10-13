import 'package:flutter/material.dart';

import 'card_form_page.dart';
import 'card_image.dart';
import 'catalogue_repository.dart';
import 'models.dart';

class CardsPage extends StatefulWidget {
  const CardsPage({
    super.key,
    required this.repository,
    required this.folder,
  });

  final CatalogueRepository repository;
  final Folder folder;

  @override
  State<CardsPage> createState() => _CardsPageState();
}

class _CardsPageState extends State<CardsPage> {
  List<CardRecord> _cards = [];
  bool _loading = true;
  bool _busy = false;
  String? _readError;
  String? _feedback;

  int get _folderId => widget.folder.id!;

  @override
  void initState() {
    super.initState();
    _loadCards();
  }

  Future<void> _loadCards({bool showLoading = true}) async {
    if (showLoading && mounted) {
      setState(() {
        _loading = true;
        _readError = null;
      });
    }
    try {
      final cards = await widget.repository.getCards(_folderId);
      if (!mounted) return;
      setState(() {
        _cards = cards;
        _loading = false;
        _readError = null;
      });
    } catch (error, stackTrace) {
      debugPrint('Card read for folder $_folderId failed: $error\n$stackTrace');
      if (!mounted) return;
      setState(() {
        _loading = false;
        _readError = 'Unable to load cards. Use Refresh to retry.';
      });
    }
  }

  /// Refreshes after a successful write without repeating the write.
  Future<void> _refreshAfterWrite(String message) async {
    try {
      final cards = await widget.repository.getCards(_folderId);
      if (!mounted) return;
      setState(() {
        _cards = cards;
        _readError = null;
        _feedback = message;
      });
    } catch (error, stackTrace) {
      debugPrint('Card refresh after write failed: $error\n$stackTrace');
      if (!mounted) return;
      setState(() {
        _feedback = '$message Refresh failed; use Refresh to retry.';
      });
    }
  }

  Future<void> _openForm({CardRecord? card}) async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _feedback = null;
    });
    List<Folder> folders;
    try {
      folders = await widget.repository.getFoldersWithCounts();
    } catch (error, stackTrace) {
      debugPrint('Folder list for form failed: $error\n$stackTrace');
      if (!mounted) return;
      setState(() {
        _busy = false;
        _feedback = 'Could not load folders for the form. Try again.';
      });
      return;
    }
    if (!mounted) return;
    final message = await Navigator.push<String>(
      context,
      MaterialPageRoute(
        builder: (context) => CardFormPage(
          repository: widget.repository,
          folders: folders,
          initialFolderId: _folderId,
          card: card,
        ),
      ),
    );
    if (!mounted) return;
    if (message == null) {
      setState(() {
        _feedback = card == null
            ? 'Add canceled; nothing was written.'
            : 'Edit of card ID ${card.id} canceled; nothing was written.';
      });
    } else {
      await _refreshAfterWrite(message);
    }
    if (mounted) setState(() => _busy = false);
  }

  Future<void> _deleteCard(CardRecord card) async {
    if (_busy) return;
    final id = card.id!;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete card?'),
        content: Text('Delete card $id, "${card.title}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (!mounted) return;
    if (confirmed != true) {
      setState(() => _feedback = 'Delete of card ID $id canceled.');
      return;
    }
    setState(() {
      _busy = true;
      _feedback = null;
    });
    String? successMessage;
    var failureMessage = '';
    try {
      final affected = await widget.repository.deleteCard(id);
      if (affected == 1) {
        successMessage = 'Deleted card ID $id: $affected row affected.';
        debugPrint(successMessage);
      } else {
        failureMessage = 'Card ID $id no longer exists.';
      }
    } catch (error, stackTrace) {
      debugPrint('Card delete failed: $error\n$stackTrace');
      failureMessage = 'Delete failed. Refresh and try again.';
    }
    if (!mounted) return;
    if (successMessage != null) {
      await _refreshAfterWrite(successMessage);
    } else {
      setState(() => _feedback = failureMessage);
      await _loadCards(showLoading: false);
    }
    if (mounted) setState(() => _busy = false);
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: !_busy,
      child: Scaffold(
        appBar: AppBar(
          title: Text('${widget.folder.id} — ${widget.folder.name}'),
          actions: [
            IconButton(
              onPressed: _busy ? null : () => _loadCards(),
              tooltip: 'Refresh',
              icon: const Icon(Icons.refresh),
            ),
          ],
        ),
        floatingActionButton: FloatingActionButton.extended(
          onPressed: _busy ? null : () => _openForm(),
          icon: const Icon(Icons.add),
          label: const Text('Add card'),
        ),
        body: SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                child: Text('Folder ID $_folderId · Cards: ${_cards.length}'),
              ),
              if (_feedback != null)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Text(_feedback!),
                ),
              const SizedBox(height: 8),
              Expanded(child: _buildBody()),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBody() {
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_readError != null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(_readError!),
            const SizedBox(height: 8),
            OutlinedButton(
              onPressed: _busy ? null : () => _loadCards(),
              child: const Text('Refresh'),
            ),
          ],
        ),
      );
    }
    if (_cards.isEmpty) {
      return const Center(
        child: Text('This folder has no cards yet. Tap "Add card".'),
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.only(bottom: 88),
      itemCount: _cards.length,
      itemBuilder: (context, index) {
        final card = _cards[index];
        final details = [
          card.suit.label,
          if (card.notes.isNotEmpty) card.notes,
          'image_ref: ${card.imageRef ?? 'NULL'}',
        ].join(' · ');
        return ListTile(
          leading: CardImage(imageRef: card.imageRef, suit: card.suit),
          title: Text('${card.id} — ${card.title}'),
          subtitle: Text(details),
          trailing: Wrap(
            children: [
              IconButton(
                onPressed: _busy ? null : () => _openForm(card: card),
                tooltip: 'Edit ${card.title}',
                icon: const Icon(Icons.edit),
              ),
              IconButton(
                onPressed: _busy ? null : () => _deleteCard(card),
                tooltip: 'Delete ${card.title}',
                icon: const Icon(Icons.delete),
              ),
            ],
          ),
        );
      },
    );
  }
}
