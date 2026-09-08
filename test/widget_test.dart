import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:classsync/main.dart';
import 'package:classsync/core/storage/database_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();

  setUp(() async {
    final dbService = DatabaseService();
    await dbService.init(inMemory: true);
  });

  tearDown(() async {
    final dbService = DatabaseService();
    await dbService.close();
  });

  testWidgets('ClassSync multi-portal app loads smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: ClassSyncApp(),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.textContaining('ClassSync'), findsWidgets);
    expect(find.text('Teacher'), findsWidgets);
    expect(find.text('Student'), findsWidgets);
  });
}
