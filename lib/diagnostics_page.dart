import 'dart:convert';

import 'package:flutter/material.dart';

import 'database_helper.dart';

/// Read-only schema evidence for T1 (PRAGMA results and Part I rows).
class DiagnosticsPage extends StatefulWidget {
  const DiagnosticsPage({super.key, required this.helper});

  final DatabaseHelper helper;

  @override
  State<DiagnosticsPage> createState() => _DiagnosticsPageState();
}

class _DiagnosticsPageState extends State<DiagnosticsPage> {
  Map<String, Object?>? _results;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final results = await widget.helper.diagnostics();
      debugPrint('Schema diagnostics: ${jsonEncode(results)}');
      if (!mounted) return;
      setState(() {
        _results = results;
        _loading = false;
      });
    } catch (error, stackTrace) {
      debugPrint('Diagnostics failed: $error\n$stackTrace');
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = 'Diagnostics query failed. Check the logs.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Schema diagnostics'),
        actions: [
          IconButton(
            onPressed: _loading ? null : _load,
            tooltip: 'Refresh',
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: SafeArea(child: _buildBody()),
    );
  }

  Widget _buildBody() {
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_error != null) return Center(child: Text(_error!));
    final results = _results!;
    const encoder = JsonEncoder.withIndent('  ');
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text('Database: ${DatabaseHelper.databaseName}'),
        const SizedBox(height: 8),
        for (final entry in results.entries) ...[
          Text(
            entry.key,
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          SelectableText(
            encoder.convert(entry.value),
            style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
          ),
          const SizedBox(height: 12),
        ],
      ],
    );
  }
}
