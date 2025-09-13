import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart' as p;
import '../models/chat_message.dart';
import '../models/analysis.dart';

class DatabaseService {
  static final DatabaseService _instance = DatabaseService._internal();
  factory DatabaseService() => _instance;
  DatabaseService._internal();

  static Database? _database;

  Future<Database> get database async {
    if (_database != null) {
      return _database!;
    }
    _database = await _initDb();
    return _database!;
  }

  Future<Database> _initDb() async {
    final databasePath = await getDatabasesPath();
    final path = p.join(databasePath, 'medscan_database.db');

    return openDatabase(
      path,
      version: 2,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE analyses(
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            title TEXT NOT NULL,
            timestamp TEXT NOT NULL
          )
        ''');
        await db.execute('''
          CREATE TABLE chat_messages(
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            content TEXT NOT NULL,
            isAI INTEGER NOT NULL,
            imageBase64 TEXT,
            analysisId INTEGER,
            timestamp TEXT NOT NULL,
            FOREIGN KEY (analysisId) REFERENCES analyses(id)
          )
        ''');
      },
      onUpgrade: (db, oldVersion, newVersion) async {
        if (oldVersion < 2) {
          await db.execute('DROP TABLE IF EXISTS tasks');
          await db.execute('''
            CREATE TABLE analyses(
              id INTEGER PRIMARY KEY AUTOINCREMENT,
              title TEXT NOT NULL,
              timestamp TEXT NOT NULL
            )
          ''');
          await db.execute('''
            CREATE TABLE chat_messages(
              id INTEGER PRIMARY KEY AUTOINCREMENT,
              content TEXT NOT NULL,
              isAI INTEGER NOT NULL,
              imageBase64 TEXT,
              analysisId INTEGER,
              timestamp TEXT NOT NULL,
              FOREIGN KEY (analysisId) REFERENCES analyses(id)
            )
          ''');
        }
      },
    );
  }

  // Insert a new analysis
  Future<int> insertAnalysis(Analysis analysis) async {
    final db = await database;
    return await db.insert(
      'analyses',
      analysis.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  // Insert a chat message
  Future<void> insertMessage(ChatMessage message) async {
    final db = await database;
    await db.insert(
      'chat_messages',
      message.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  // Get all messages for an analysis
  Future<List<ChatMessage>> getMessagesForAnalysis(int analysisId) async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'chat_messages',
      where: 'analysisId = ?',
      whereArgs: [analysisId],
      orderBy: 'timestamp ASC',
    );
    return List.generate(maps.length, (i) {
      return ChatMessage.fromMap(maps[i]);
    });
  }

  // Get all analyses
  Future<List<Analysis>> getAnalyses() async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'analyses',
      orderBy: 'timestamp DESC',
    );
    return List.generate(maps.length, (i) {
      return Analysis.fromMap(maps[i]);
    });
  }

  // Delete an analysis and its messages
  Future<void> deleteAnalysis(int id) async {
    final db = await database;
    await db.transaction((txn) async {
      await txn.delete(
        'chat_messages',
        where: 'analysisId = ?',
        whereArgs: [id],
      );
      await txn.delete(
        'analyses',
        where: 'id = ?',
        whereArgs: [id],
      );
    });
  }

  // Delete all analyses and messages
  Future<void> deleteAllAnalyses() async {
    final db = await database;
    await db.transaction((txn) async {
      await txn.delete('chat_messages');
      await txn.delete('analyses');
    });
  }
}