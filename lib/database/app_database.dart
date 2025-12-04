import 'package:flutter/foundation.dart';
import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';
import 'package:sqflite_common_ffi_web/sqflite_ffi_web.dart';

class AppDatabase {
  AppDatabase._();
  static final AppDatabase instance = AppDatabase._();

  Database? _db;

  Future<Database> get database async {
    if (_db != null) return _db!;

    final factory =
        kIsWeb ? databaseFactoryFfiWebNoWebWorker : databaseFactory;
    final path =
        kIsWeb ? 'myapp.db' : join(await getDatabasesPath(), 'myapp.db');

    _db = await factory.openDatabase(
      path,
      options: OpenDatabaseOptions(
        version: 1,
        onCreate: (db, version) async {
          await db.execute(
            'CREATE TABLE favorites (recipeId TEXT PRIMARY KEY)',
          );
          await db.execute(
            'CREATE TABLE completed (recipeId TEXT PRIMARY KEY, doneAt TEXT)',
          );
        },
      ),
    );

    return _db!;
  }

  Future<Set<String>> getFavoriteIds() async {
    final db = await database;
    final result = await db.query('favorites', columns: ['recipeId']);
    return result.map((row) => row['recipeId'] as String).toSet();
  }

  Future<bool> isFavorite(String recipeId) async {
    final db = await database;
    final result = await db.query(
      'favorites',
      where: 'recipeId = ?',
      whereArgs: [recipeId],
      limit: 1,
    );
    return result.isNotEmpty;
  }

  Future<bool> toggleFavorite(String recipeId) async {
    final db = await database;
    final exists = await isFavorite(recipeId);
    if (exists) {
      await db.delete(
        'favorites',
        where: 'recipeId = ?',
        whereArgs: [recipeId],
      );
      return false;
    } else {
      await db.insert('favorites', {'recipeId': recipeId},
          conflictAlgorithm: ConflictAlgorithm.replace);
      return true;
    }
  }

  Future<Set<String>> getCompletedIds() async {
    final db = await database;
    final result = await db.query('completed', columns: ['recipeId']);
    return result.map((row) => row['recipeId'] as String).toSet();
  }

  Future<bool> isCompleted(String recipeId) async {
    final db = await database;
    final result = await db.query(
      'completed',
      where: 'recipeId = ?',
      whereArgs: [recipeId],
      limit: 1,
    );
    return result.isNotEmpty;
  }

  Future<void> markCompleted(String recipeId) async {
    final db = await database;
    await db.insert(
      'completed',
      {
        'recipeId': recipeId,
        'doneAt': DateTime.now().toIso8601String(),
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<void> debugCheckDatabase() async {
    final db = await database;
    print("===== DEBUG SQLITE =====");
    final fav = await db.query('favorites');
    print("FAVORITES:");
    print(fav);
    final done = await db.query('completed');
    print("COMPLETED:");
    print(done);
    print("===== END DEBUG =====");
  }
}
