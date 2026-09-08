import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/storage/app_database.dart';
import '../core/storage/database_service.dart';

final appDatabaseProvider = FutureProvider<AppDatabase>((ref) async {
  final service = DatabaseService();
  if (!service.isInitialized) {
    await service.init();
  }
  return service.db;
});
