import 'package:flutter/material.dart';

import 'catalogue_repository.dart';
import 'database_helper.dart';
import 'models.dart';
import 'roster_page.dart';

class FoldersPage extends StatefulWidget {
  const FoldersPage({
    super.key,
    required this.helper,
    required this.repository,
  });

  final DatabaseHelper helper;
  final CatalogueRepository repository;

  @override
  State<FoldersPage> createState() => _FoldersPageState();
}

class _FoldersPageState extends State<FoldersPage> {
  List<Folder> _folders = [];
  bool _loading = true;
  bool _busy = false;
  String? _readError;
  String? _feedback;

  @override
  void initState() {
    super.initState();
    _loadFolders();
  }

  Future<void> _loadFolders({bool showLoading = true}) async {
    if (showLoading && mounted) {
      setState(() {
        _loading = true;
        _readError = null;
      });
    }
    try {
      final folders = await widget.repository.getFoldersWithCounts();
      if (!mounted) return;
      setState(() {
        _folders = folders;
        _loading = false;
        _readError = null;
      });
    } catch (error, stackTrace) {
      debugPrint('Folder read failed: $error\n$stackTrace');
      if (!mounted) return;
      setState(() {
        _loading = false;
        _readError = 'Unable to load folders. Use Refresh to retry.';
      });
    }
  }

  /// Refreshes after a successful write without repeating the write.
  Future<void> _refreshAfterWrite(String message) async {
    try {
      final folders = await widget.repository.getFoldersWithCounts();
      if (!mounted) return;
      setState(() {
        _folders = folders;
        _readError = null;
        _feedback = message;
      });
    } catch (error, stackTrace) {
      debugPrint('Folder refresh after write failed: $error\n$stackTrace');
      if (!mounted) return;
      setState(() {
        _feedback = '$message Refresh failed; use Refresh to retry.';
      });
    }
  }

  Future<void> _createFolder() async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _feedback = null;
    });
    final newId = await showDialog<int>(
      context: context,
      barrierDismissible: false,
      builder: (context) =>
          _CreateFolderDialog(repository: widget.repository),
    );
    if (!mounted) return;
    if (newId == null) {
      setState(() {
        _busy = false;
        _feedback = 'Folder creation canceled.';
      });
      return;
    }
    await _refreshAfterWrite('Created folder with ID $newId.');
    if (mounted) setState(() => _busy = false);
  }

  Future<void> _deleteFolder(Folder folder) async {
    if (_busy) return;
    final id = folder.id!;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete folder?'),
        content: Text(
          'Delete folder $id, "${folder.name}"? This also deletes its '
          '${folder.cardCount} card(s).',
        ),
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
      setState(() => _feedback = 'Delete of "${folder.name}" canceled.');
      return;
    }
    setState(() {
      _busy = true;
      _feedback = null;
    });
    String? successMessage;
    var failureMessage = '';
    try {
      final affected = await widget.repository.deleteFolder(id);
      if (affected == 1) {
        final remaining =
            await widget.repository.countCardsReferencingFolder(id);
        successMessage = 'Deleted 1 folder (ID $id). '
            'Cards still referencing ID $id: $remaining.';
        debugPrint(successMessage);
      } else {
        failureMessage = 'Folder ID $id no longer exists.';
      }
    } catch (error, stackTrace) {
      debugPrint('Folder delete failed: $error\n$stackTrace');
      failureMessage = 'Delete failed. Refresh and try again.';
    }
    if (!mounted) return;
    if (successMessage != null) {
      await _refreshAfterWrite(successMessage);
    } else {
      setState(() => _feedback = failureMessage);
      await _loadFolders(showLoading: false);
    }
    if (mounted) setState(() => _busy = false);
  }

  void _openRoster() {
    Navigator.push(
      context,
      MaterialPageRoute<void>(
        builder: (context) => RosterPage(helper: widget.helper),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Card Catalogue'),
        actions: [
          IconButton(
            onPressed: _busy ? null : _openRoster,
            tooltip: 'Part I guest roster',
            icon: const Icon(Icons.people),
          ),
          IconButton(
            onPressed: _busy ? null : () => _loadFolders(),
            tooltip: 'Refresh',
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _busy ? null : _createFolder,
        icon: const Icon(Icons.create_new_folder),
        label: const Text('New folder'),
      ),
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
              child: Text('Folders: ${_folders.length}'),
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
              onPressed: _busy ? null : () => _loadFolders(),
              child: const Text('Refresh'),
            ),
          ],
        ),
      );
    }
    if (_folders.isEmpty) {
      return const Center(
        child: Text('No folders yet. Tap "New folder" to create one.'),
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.only(bottom: 88),
      itemCount: _folders.length,
      itemBuilder: (context, index) {
        final folder = _folders[index];
        return ListTile(
          leading: const Icon(Icons.folder),
          title: Text('${folder.id} — ${folder.name}'),
          subtitle: Text('Cards: ${folder.cardCount}'),
          trailing: IconButton(
            onPressed: _busy ? null : () => _deleteFolder(folder),
            tooltip: 'Delete ${folder.name}',
            icon: const Icon(Icons.delete),
          ),
        );
      },
    );
  }
}

/// Performs the insert itself so the typed name is preserved on failure.
class _CreateFolderDialog extends StatefulWidget {
  const _CreateFolderDialog({required this.repository});

  final CatalogueRepository repository;

  @override
  State<_CreateFolderDialog> createState() => _CreateFolderDialogState();
}

class _CreateFolderDialogState extends State<_CreateFolderDialog> {
  final _controller = TextEditingController();
  bool _saving = false;
  String? _error;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_saving) return;
    final name = _controller.text.trim();
    if (name.isEmpty) {
      setState(() => _error = 'Enter a folder name.');
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final id = await widget.repository.insertFolder(name);
      if (!mounted) return;
      Navigator.pop(context, id);
    } on DuplicateFolderNameException catch (error) {
      debugPrint('Folder insert rejected: $error');
      if (!mounted) return;
      setState(() {
        _saving = false;
        _error = '$error Choose a different name.';
      });
    } catch (error, stackTrace) {
      debugPrint('Folder insert failed: $error\n$stackTrace');
      if (!mounted) return;
      setState(() {
        _saving = false;
        _error = 'Save failed. Try again.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('New folder'),
      content: TextField(
        controller: _controller,
        enabled: !_saving,
        autofocus: true,
        decoration: InputDecoration(
          labelText: 'Folder name',
          border: const OutlineInputBorder(),
          errorText: _error,
          errorMaxLines: 3,
        ),
        onSubmitted: (_) => _save(),
      ),
      actions: [
        TextButton(
          onPressed: _saving ? null : () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _saving ? null : _save,
          child: const Text('Create'),
        ),
      ],
    );
  }
}
