import 'package:flutter/material.dart';

import 'database_helper.dart';

class RosterPage extends StatefulWidget {
  const RosterPage({super.key, required this.helper});

  final DatabaseHelper helper;

  @override
  State<RosterPage> createState() => _RosterPageState();
}

class _RosterPageState extends State<RosterPage> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _ageController = TextEditingController();

  List<Map<String, Object?>> _rows = [];
  int _count = 0;
  int? _editingId;
  bool _loading = true;
  bool _busy = false;
  String? _readError;
  String? _feedback;

  bool get _isEditing => _editingId != null;

  @override
  void initState() {
    super.initState();
    _loadRoster();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _ageController.dispose();
    super.dispose();
  }

  Future<void> _loadRoster({bool showLoading = true}) async {
    if (showLoading && mounted) {
      setState(() {
        _loading = true;
        _readError = null;
      });
    }
    try {
      final rows = await widget.helper.queryAllRows();
      final count = await widget.helper.queryRowCount();
      if (!mounted) return;
      setState(() {
        _rows = rows;
        _count = count;
        _loading = false;
        _readError = null;
      });
    } catch (error, stackTrace) {
      debugPrint('Roster read failed: $error\n$stackTrace');
      if (!mounted) return;
      setState(() {
        _loading = false;
        _readError = 'Unable to load the roster. Use Refresh to retry.';
      });
    }
  }

  String? _validateName(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Enter a guest name.';
    }
    return null;
  }

  String? _validateAge(String? value) {
    final age = int.tryParse(value?.trim() ?? '');
    if (age == null) return 'Enter a whole-number age.';
    if (age < 0 || age > 130) return 'Age must be between 0 and 130.';
    return null;
  }

  Map<String, Object?>? _validatedRow() {
    if (!_formKey.currentState!.validate()) return null;
    final name = _nameController.text.trim();
    final age = int.parse(_ageController.text.trim());
    return {
      if (_editingId != null) DatabaseHelper.columnId: _editingId,
      DatabaseHelper.columnName: name,
      DatabaseHelper.columnAge: age,
    };
  }

  Future<void> _saveGuest() async {
    final row = _validatedRow();
    if (row == null || _busy) return;
    final editingId = _editingId;
    setState(() {
      _busy = true;
      _feedback = null;
    });
    var writeSucceeded = false;
    var message = '';
    try {
      if (editingId == null) {
        final id = await widget.helper.insert(row);
        writeSucceeded = true;
        message = 'Saved guest with ID $id.';
      } else {
        final affected = await widget.helper.update(row);
        if (affected != 1) {
          message = 'Guest ID $editingId no longer exists.';
        } else {
          writeSucceeded = true;
          message = 'Updated 1 guest.';
        }
      }
      if (writeSucceeded) _clearForm();
    } catch (error, stackTrace) {
      debugPrint('Roster write failed: $error\n$stackTrace');
      message = 'Save failed. Check the input and try again.';
    }
    if (!mounted) return;
    if (writeSucceeded) {
      try {
        final rows = await widget.helper.queryAllRows();
        final count = await widget.helper.queryRowCount();
        if (!mounted) return;
        setState(() {
          _rows = rows;
          _count = count;
          _readError = null;
          _feedback = message;
        });
      } catch (error, stackTrace) {
        debugPrint('Roster refresh after save failed: $error\n$stackTrace');
        if (mounted) {
          setState(() {
            _feedback = '${message.split('.').first}, but refresh failed.';
          });
        }
      }
    } else {
      setState(() {
        _feedback = message;
      });
    }
    if (mounted) {
      setState(() {
        _busy = false;
      });
    }
  }

  void _startEditing(Map<String, Object?> row) {
    if (_busy) return;
    setState(() {
      _editingId = row[DatabaseHelper.columnId] as int;
      _nameController.text = row[DatabaseHelper.columnName] as String;
      _ageController.text = '${row[DatabaseHelper.columnAge]}';
      _feedback = null;
    });
  }

  void _clearForm() {
    _editingId = null;
    _nameController.clear();
    _ageController.clear();
  }

  void _cancelEditing() {
    if (_busy) return;
    setState(() {
      _clearForm();
      _feedback = 'Edit canceled.';
    });
  }

  Future<void> _deleteGuest(Map<String, Object?> row) async {
    if (_busy) return;
    final id = row[DatabaseHelper.columnId] as int;
    final name = row[DatabaseHelper.columnName] as String;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete guest?'),
        content: Text('Delete guest $id, $name?'),
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
    if (confirmed != true || !mounted) return;
    setState(() {
      _busy = true;
      _feedback = null;
    });
    var deleted = false;
    var message = '';
    try {
      final affected = await widget.helper.delete(id);
      if (affected == 1) {
        deleted = true;
        message = 'Deleted 1 guest.';
        if (_editingId == id) _clearForm();
      } else {
        message = 'Guest ID $id no longer exists.';
      }
    } catch (error, stackTrace) {
      debugPrint('Roster delete failed: $error\n$stackTrace');
      message = 'Delete failed. Refresh the roster and try again.';
    }
    if (!mounted) return;
    if (deleted) {
      try {
        final rows = await widget.helper.queryAllRows();
        final count = await widget.helper.queryRowCount();
        if (!mounted) return;
        setState(() {
          _rows = rows;
          _count = count;
          _readError = null;
          _feedback = message;
        });
      } catch (error, stackTrace) {
        debugPrint('Roster refresh after delete failed: $error\n$stackTrace');
        if (mounted) {
          setState(() {
            _feedback = 'Deleted 1 guest, but refresh failed.';
          });
        }
      }
    } else {
      setState(() {
        _feedback = message;
      });
      await _loadRoster(showLoading: false);
    }
    if (mounted) {
      setState(() {
        _busy = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Fall Festival Roster'),
        actions: [
          IconButton(
            onPressed: _busy ? null : () => _loadRoster(),
            tooltip: 'Refresh',
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Form(
                key: _formKey,
                child: Column(
                  children: [
                    TextFormField(
                      controller: _nameController,
                      enabled: !_busy,
                      decoration: const InputDecoration(
                        labelText: 'Guest name',
                        border: OutlineInputBorder(),
                      ),
                      validator: _validateName,
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _ageController,
                      enabled: !_busy,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'Age',
                        border: OutlineInputBorder(),
                      ),
                      validator: _validateAge,
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: FilledButton(
                            onPressed: _busy ? null : _saveGuest,
                            child: Text(_isEditing ? 'Save' : 'Add guest'),
                          ),
                        ),
                        if (_isEditing) ...[
                          const SizedBox(width: 8),
                          Expanded(
                            child: OutlinedButton(
                              onPressed: _busy ? null : _cancelEditing,
                              child: const Text('Cancel edit'),
                            ),
                          ),
                        ],
                      ],
                    ),
                    if (_feedback != null) ...[
                      const SizedBox(height: 8),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: Text(_feedback!),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text('Record count: $_count'),
              ),
            ),
            const SizedBox(height: 8),
            Expanded(child: _buildRosterBody()),
          ],
        ),
      ),
    );
  }

  Widget _buildRosterBody() {
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_readError != null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(_readError!),
            const SizedBox(height: 8),
            OutlinedButton(
              onPressed: _busy ? null : () => _loadRoster(),
              child: const Text('Refresh'),
            ),
          ],
        ),
      );
    }
    if (_rows.isEmpty) {
      return const Center(child: Text('No festival guests yet'));
    }
    return ListView.builder(
      itemCount: _rows.length,
      itemBuilder: (context, index) {
        final row = _rows[index];
        final id = row[DatabaseHelper.columnId] as int;
        final name = row[DatabaseHelper.columnName] as String;
        final age = row[DatabaseHelper.columnAge] as int;
        return ListTile(
          title: Text('$id — $name'),
          subtitle: Text('Age: $age'),
          trailing: Wrap(
            children: [
              IconButton(
                onPressed: _busy ? null : () => _startEditing(row),
                tooltip: 'Edit $name',
                icon: const Icon(Icons.edit),
              ),
              IconButton(
                onPressed: _busy ? null : () => _deleteGuest(row),
                tooltip: 'Delete $name',
                icon: const Icon(Icons.delete),
              ),
            ],
          ),
        );
      },
    );
  }
}
