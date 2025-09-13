import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';

// A simple model for our data. You can replace this with your own model.
class Task {
  final int? id;
  final String title;
  final bool isCompleted;

  Task({
    this.id,
    required this.title,
    this.isCompleted = false,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'isCompleted': isCompleted ? 1 : 0,
    };
  }

  factory Task.fromMap(Map<String, dynamic> map) {
    return Task(
      id: map['id'],
      title: map['title'],
      isCompleted: map['isCompleted'] == 1,
    );
  }
}

class DatabaseService {
  // Use a singleton pattern to ensure only one instance of the database exists.
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
    // Get a location using `getDatabasesPath()` and join it with a database name.
    final databasePath = await getDatabasesPath();
    final path = join(databasePath, 'task_database.db');

    // Open the database and create a table if it doesn't exist.
    return openDatabase(
      path,
      version: 1,
      onCreate: (db, version) async {
        // Run the CREATE TABLE statement.
        await db.execute('''
          CREATE TABLE tasks(
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            title TEXT NOT NULL,
            isCompleted INTEGER NOT NULL
          )
        ''');
      },
    );
  }

  // --- CRUD Operations ---

  // Insert a task into the database.
  Future<void> insertTask(Task task) async {
    final db = await database;
    await db.insert(
      'tasks',
      task.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  // Retrieve all tasks from the database.
  Future<List<Task>> getTasks() async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query('tasks');
    return List.generate(maps.length, (i) {
      return Task.fromMap(maps[i]);
    });
  }

  // Update a task.
  Future<void> updateTask(Task task) async {
    final db = await database;
    await db.update(
      'tasks',
      task.toMap(),
      where: 'id = ?',
      whereArgs: [task.id],
    );
  }

  // Delete a task.
  Future<void> deleteTask(int id) async {
    final db = await database;
    await db.delete(
      'tasks',
      where: 'id = ?',
      whereArgs: [id],
    );
  }
}
