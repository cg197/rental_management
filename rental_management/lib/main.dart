import 'package:flutter/material.dart';
import 'services/sqlite_service.dart';
import 'app.dart';

void main() async {
  // Ensure framework engine bindings are fully initialized first
  WidgetsFlutterBinding.ensureInitialized();

  // Trigger SQLite connection initialization on device startup
  final SqliteService sqliteService = SqliteService();
  await sqliteService.database;
  print("=== SQLITE DATABASE INITIALIZED SUCCESSFULLY ===");

  runApp(const PropertyManagerApp());

}