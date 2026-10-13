import 'package:flutter/material.dart';

import 'catalogue_repository.dart';
import 'database_helper.dart';
import 'folders_page.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final helper = DatabaseHelper();
  try {
    await helper.init();
  } catch (error, stackTrace) {
    debugPrint('Database initialization failed: $error\n$stackTrace');
    runApp(
      const MaterialApp(
        home: Scaffold(
          body: Center(
            child: Text(
              'Could not open local storage. Restart the app and check the logs.',
            ),
          ),
        ),
      ),
    );
    return;
  }
  runApp(
    MaterialApp(
      title: 'Card Catalogue',
      home: FoldersPage(
        helper: helper,
        repository: CatalogueRepository(helper),
      ),
    ),
  );
}
