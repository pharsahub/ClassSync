import 'app_database.dart';

/// Database service singleton for app runtime access.
class DatabaseService {
  static final DatabaseService _instance = DatabaseService._internal();
  factory DatabaseService() => _instance;
  DatabaseService._internal();

  AppDatabase _database = AppDatabase();
  AppDatabase get db => _database;

  bool _initialized = false;
  bool get isInitialized => _initialized;

  Future<void> init({bool inMemory = false}) async {
    if (_initialized) return;
    _database = AppDatabase();
    await _database.initialize(inMemory: inMemory);
    _initialized = true;
  }

  Future<void> close() async {
    if (_initialized) {
      await _database.close();
      _initialized = false;
    }
  }
}
